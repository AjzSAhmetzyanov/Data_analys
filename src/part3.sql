-- 1 task
DROP FUNCTION IF EXISTS more_human_readable();

CREATE OR REPLACE FUNCTION more_human_readable()
    RETURNS TABLE
            (
                Peer1        VARCHAR,
                Peer2        VARCHAR,
                PointsAmount INT
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT t1.checkingpeer, t1.checkedpeer, (t1.pointsamount - t2.pointsamount)
                  FROM transferredpoints t1
                           JOIN transferredpoints t2 ON t1.checkingpeer = t2.checkedpeer AND
                                                        t1.checkedpeer = t2.checkingpeer
                  ORDER BY 1);
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM more_human_readable();

-- 2 task
DROP FUNCTION IF EXISTS following_form();

CREATE OR REPLACE FUNCTION following_form()
    RETURNS TABLE
            (
                Peer VARCHAR,
                Task VARCHAR,
                XP   INT
            )
AS
$$
BEGIN
    RETURN QUERY (SELECT c.peer, c.task, x.xpamount
                  FROM checks c
                           JOIN xp x ON c.id = x."Check"
                           JOIN p2p p on c.id = p."Check"
                  WHERE p.state = 'Success'
                  ORDER BY 1);
END;
$$ LANGUAGE plpgsql;

-- SELECT *
-- FROM following_form();

-- 3 task
DROP FUNCTION IF EXISTS hard_workers();

CREATE OR REPLACE FUNCTION hard_workers(day_ DATE)
    RETURNS SETOF VARCHAR
AS
$$
BEGIN
    RETURN QUERY (SELECT peer FROM timetracking WHERE "Date" = day_ GROUP BY peer, "Date" HAVING COUNT("State") = 3);
END;
$$ LANGUAGE plpgsql;

-- SELECT *
-- FROM hard_workers('2020-01-02');

-- 4 task
DROP PROCEDURE IF EXISTS change_points(ref_ refcursor);

CREATE OR REPLACE PROCEDURE change_points(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        SELECT checkingpeer AS Peer, (COALESCE(c.sum_points, 0) - COALESCE(p.sum_points, 0)) AS PointsChange
        FROM (
                 SELECT checkingpeer, (SUM(pointsamount)) AS sum_points
                 FROM transferredpoints
                 GROUP BY checkingpeer
             ) AS c
                 JOIN (
            SELECT checkedpeer, (SUM(pointsamount)) AS sum_points
            FROM transferredpoints
            GROUP BY checkedpeer
        ) AS p ON c.checkingpeer = p.checkedpeer
        ORDER BY Peer, PointsChange DESC;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL change_points('ref');
-- FETCH ALL IN "ref";
-- END;

-- 5 task
DROP PROCEDURE IF EXISTS change_points_campus(ref_ refcursor);

CREATE OR REPLACE PROCEDURE change_points_campus(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        SELECT Peer1 AS Peer, (COALESCE(c.sum_points, 0) - COALESCE(p.sum_points, 0)) AS PointsChange
        FROM (
                 SELECT Peer1, (SUM(pointsamount)) AS sum_points
                 FROM more_human_readable()
                 GROUP BY Peer1
             ) AS c
                 JOIN (
            SELECT Peer2, (SUM(pointsamount)) AS sum_points
            FROM more_human_readable()
            GROUP BY Peer2
        ) AS p ON c.Peer1 = p.Peer2
        ORDER BY Peer, PointsChange DESC;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL change_points('ref');
-- FETCH ALL IN "ref";
-- END;

-- 6 task
DROP PROCEDURE IF EXISTS most_frequently(ref_ refcursor);

CREATE OR REPLACE PROCEDURE most_frequently(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        SELECT t1."Date", t1.task
        FROM (
                 SELECT "Date", task, COUNT(*) AS counts
                 FROM checks
                 GROUP BY "Date", task
             ) AS t1
                 INNER JOIN (
            SELECT "Date", MAX(counts) AS max_counts
            FROM (
                     SELECT "Date", task, COUNT(*) AS counts
                     FROM checks
                     GROUP BY "Date", task
                 ) AS t2
            GROUP BY "Date"
        ) AS t3 ON t1."Date" = t3."Date" AND t1.counts = t3.max_counts;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL most_frequently('ref');
-- FETCH ALL IN "ref";
-- END;

-- 7 task
DROP PROCEDURE IF EXISTS task_completed(block VARCHAR, ref_ refcursor);

CREATE OR REPLACE PROCEDURE task_completed(block VARCHAR, ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        WITH max_task AS (SELECT MAX(title) max_t FROM tasks WHERE title LIKE CONCAT(block, '%')),
             block_task AS (SELECT * FROM checks WHERE task LIKE CONCAT(block, '%')),
             success_task AS (SELECT c.id, peer, task, "Date"
                              FROM checks c
                                       JOIN p2p p on c.id = p."Check"
                              WHERE state = 'Success')
        SELECT bt.peer "Peer", bt."Date" "Day"
        FROM block_task bt
                 JOIN max_task mt ON bt.task = mt.max_t
                 JOIN success_task st ON st.id = bt.id;
END ;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL task_completed('CPP','ref');
-- FETCH ALL IN "ref";
-- END;

-- 8 task
DROP PROCEDURE IF EXISTS recommend_peer(ref_ refcursor);

CREATE OR REPLACE PROCEDURE recommend_peer(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        WITH find_friends AS (SELECT nickname,
                                     (CASE WHEN nickname = friends.peer1 THEN peer2 ELSE peer1 END) AS frineds
                              FROM peers
                                       JOIN friends
                                            ON peers.nickname = friends.peer1 OR peers.nickname = friends.peer2),
             find_reccommend AS (SELECT nickname, COUNT(recommendedpeer) AS count_rec, recommendedpeer
                                 FROM find_friends
                                          JOIN recommendations ON find_friends.frineds = recommendations.peer
                                 WHERE find_friends.nickname != recommendations.recommendedpeer
                                 GROUP BY nickname, recommendedpeer),
             find_max AS (SELECT nickname, MAX(count_rec) AS max_count
                          FROM find_reccommend
                          GROUP BY nickname)
        SELECT find_reccommend.nickname AS peer, recommendedpeer
        FROM find_reccommend
                 JOIN find_max ON find_reccommend.nickname = find_max.nickname AND
                                  find_reccommend.count_rec = find_max.max_count;
END;
$$ LANGUAGE plpgsql;
--
-- BEGIN;
-- CALL recommend_peer('ref');
-- FETCH ALL IN "ref";
-- END;

-- 9 task
DROP PROCEDURE IF EXISTS percent_peer(
    block_1 text, block_2 text,
    RESULT INOUT refcursor
);

CREATE OR REPLACE PROCEDURE percent_peer(
    block_1 text, block_2 text,
    RESULT INOUT refcursor)
AS
$$
BEGIN
    OPEN RESULT FOR
        WITH only_task1 AS (
            SELECT COUNT(DISTINCT c1.peer) * 100 / (SELECT COUNT(*) FROM peers) AS only_tasks1
            FROM checks c1
            WHERE c1.task LIKE block_1
              AND NOT EXISTS(
                    SELECT 1
                    FROM checks c2
                    WHERE c1.peer = c2.peer
                      AND c2.task NOT LIKE block_2
                )
        ),
             only_task2 AS (
                 SELECT COUNT(DISTINCT c1.peer) * 100 / (SELECT COUNT(*) FROM peers) AS only_tasks2
                 FROM checks c1
                 WHERE c1.task LIKE block_2
                   AND NOT EXISTS(
                         SELECT 1
                         FROM checks c2
                         WHERE c1.peer = c2.peer
                           AND c2.task NOT LIKE block_2
                     )
             ),
             block1_block2 AS (
                 SELECT COUNT(DISTINCT peer) * 100 / (SELECT COUNT(*) FROM peers) AS tasks1_and_tasks2
                 FROM checks
                 WHERE task LIKE block_1
                   AND peer IN (
                     SELECT peer
                     FROM checks
                     WHERE task LIKE block_2
                 )
             ),
             not_started AS (
                 SELECT COUNT(*) * 100 / (SELECT COUNT(*) FROM peers) AS not_started
                 FROM peers p
                 WHERE NOT EXISTS(
                         SELECT 1
                         FROM checks c
                         WHERE p.nickname = c.peer
                     )
             )
        SELECT only_task1.only_tasks1          AS "StartedBlock1",
               only_task2.only_tasks2          AS "StartedBlock2",
               block1_block2.tasks1_and_tasks2 AS "StartedBothBlocks",
               not_started.not_started         AS "DidntStartAnyBlock"
        FROM only_task1
                 CROSS JOIN only_task2
                 CROSS JOIN block1_block2
                 CROSS JOIN not_started;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL percent_peer('D%', 'C%', 'RESULT');
--     FETCH ALL IN "RESULT";
-- END;

-- 10 task
DROP PROCEDURE IF EXISTS successful_checks_birthday(RESULT INOUT refcursor);

CREATE OR REPLACE PROCEDURE successful_checks_birthday(RESULT INOUT refcursor)
AS
$$
BEGIN
    OPEN RESULT FOR
        WITH peers_month_day AS (
            SELECT
                nickname,
                date_part('month', birthday) AS p_month,
                date_part('day', birthday) AS p_day
            FROM
                peers
        ),
        checks_month_day AS (
            SELECT
                checks.id,
                peer,
                date_part('month', "Date") AS c_month,
                date_part('day', "Date") AS c_day,
                p2p.state AS p_state,
                verter.state AS v_state
            FROM
                checks
                JOIN p2p ON checks.id = p2p."Check"
                LEFT JOIN verter ON checks.id = verter."Check"
            WHERE
                p2p.state IN ('Success', 'Failure')
                AND (verter.state IN ('Success', 'Failure') OR verter.state IS NULL)
        ),
        joined_tables AS (
            SELECT *
            FROM peers_month_day AS pmd
            JOIN checks_month_day AS cmd ON pmd.p_day = cmd.c_day AND pmd.p_month = cmd.c_month
        ),
        count_success AS (
            SELECT COUNT(*) AS s_count
            FROM joined_tables
            WHERE p_state = 'Success' AND (v_state = 'Success' OR v_state IS NULL)
        ),
        count_failure AS (
            SELECT COUNT(*) AS f_count
            FROM joined_tables
            WHERE p_state = 'Failure' AND (v_state = 'Failure' OR v_state IS NULL)
        ),
        count_peers AS (
            SELECT COUNT(nickname) AS all_count
            FROM peers
        )
        SELECT
           ((SELECT s_count FROM count_success) * 100) / (SELECT all_count FROM count_peers) AS successful_checks,
            ((SELECT f_count FROM count_failure) * 100) / (SELECT all_count FROM count_peers) AS unsuccessful_checks;

END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL successful_checks_birthday('RESULT');
--     FETCH ALL IN "RESULT";
-- END;

-- 11 task
DROP PROCEDURE IF EXISTS complete_1_2(task_1 VARCHAR, task_2 VARCHAR, task_3 VARCHAR, ref_ refcursor);

CREATE OR REPLACE PROCEDURE complete_1_2(task_1 VARCHAR, task_2 VARCHAR, task_3 VARCHAR, ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        WITH success_task1 AS (SELECT *
                               FROM checks c
                                        JOIN verter v on c.id = v."Check"
                               WHERE c.task = task_1 AND v.state = 'Success'
                                  OR v.state IS NULL),
             success_task2 AS (SELECT *
                               FROM checks c
                                        JOIN verter v on c.id = v."Check"
                               WHERE c.task = task_2 AND v.state = 'Success'
                                  OR v.state IS NULL),
             failure_task3 AS (SELECT *
                               FROM checks c
                                        JOIN verter v on c.id = v."Check"
                               WHERE c.task = task_3 AND v.state = 'Failure'
                                  OR v.state IS NULL)
        SELECT *
        FROM ((SELECT * FROM success_task1)
              INTERSECT
              (SELECT * FROM success_task2)
              INTERSECT
              (SELECT * FROM failure_task3)) AS new_table;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL complete_1_2('C2_SimpleBashUtils', 'DO2_Linux Network', 'DO1_Linux', 'ref');
-- FETCH ALL IN "ref";
-- END;

-- 12 task
DROP PROCEDURE IF EXISTS precending_tasks(ref_ refcursor);

CREATE OR REPLACE PROCEDURE precending_tasks(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        WITH RECURSIVE r AS (SELECT (CASE WHEN tasks.parenttask IS NULL THEN 0 ELSE 1 END) AS counter,
                                        tasks.title, tasks.parenttask AS current_task, tasks.parenttask
                                 FROM tasks
                                 UNION ALL
                SELECT (CASE WHEN child.parenttask IS NOT NULL THEN counter + 1 ELSE counter END) AS counter,
                        child.title AS title, child.parenttask AS current_task, parrent.title AS parrenttask
                        FROM tasks AS child
                        CROSS JOIN r AS parrent
                        WHERE parrent.title LIKE child.parenttask)
            SELECT title AS Task, MAX(counter) AS PrevCount
            FROM r
            GROUP BY title
            ORDER BY task;

END;
$$LANGUAGE plpgsql;

-- BEGIN;
-- CALL precending_tasks('ref');
-- FETCH ALL IN "ref";
-- END;

-- 13 task
DROP PROCEDURE IF EXISTS lucky_days(ref_ refcursor);

CREATE OR REPLACE PROCEDURE lucky_days(N INT, ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        WITH t AS (SELECT *
                       FROM checks
                       JOIN p2p ON checks.id = p2p."Check"
                       LEFT JOIN verter ON checks.id = verter."Check"
                       JOIN tasks ON checks.task = tasks.title
                       JOIN xp ON checks.id = xp."Check"
                       WHERE p2p.state = 'Success' AND (verter.state = 'Success' OR verter.state IS NULL))
        SELECT "Date"
        FROM t
        WHERE t.xpamount >= t.maxxp * 0.8
        GROUP BY "Date"
        HAVING COUNT("Date") >= N;

END;
$$LANGUAGE plpgsql;

-- BEGIN;
-- CALL lucky_days(2,'ref');
-- FETCH ALL IN "ref";
-- END;

-- 14 task
DROP PROCEDURE IF EXISTS highest_amount(ref_ refcursor);

CREATE OR REPLACE PROCEDURE highest_amount(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        SELECT peer, SUM(xpamount) as XP
        FROM xp
                 JOIN checks c on c.id = xp."Check"
        GROUP BY peer
        ORDER BY XP DESC
        limit 1;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL highest_amount('ref');
-- FETCH ALL IN "ref";
-- END;

-- 15 task
DROP PROCEDURE IF EXISTS peer_least(time_ TIME, N INT, ref_ refcursor);

CREATE OR REPLACE PROCEDURE peer_least(time_ TIME, N INT, ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
        SELECT peer
        FROM (SELECT peer, MIN(time) AS min_time, "Date"
              FROM timetracking
              WHERE "State" = 1
              GROUP BY "Date", peer) AS t
        WHERE min_time < time_
        GROUP BY peer
        HAVING COUNT(peer) >= N;
END;
$$ LANGUAGE plpgsql;
--
-- BEGIN;
-- CALL peer_least('19:00:00', 1, 'ref');
-- FETCH ALL IN "ref";
-- END;

-- 16 task
DROP PROCEDURE IF EXISTS always_in_campus(N int, M int, ref refcursor);

CREATE OR REPLACE PROCEDURE always_in_campus(N int, M int, ref refcursor) AS $$
    BEGIN
       OPEN ref FOR
            SELECT peer
            FROM (SELECT peer, "Date", (COUNT(*) - 1) AS counts
                  FROM timetracking
                  WHERE "State" = 2 AND "Date" > (current_date - N)
                  GROUP BY peer, "Date") AS t
            GROUP BY peer
            HAVING SUM(counts) > M;
    END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL always_in_campus(1000, 0, 'ref');
-- FETCH ALL IN "ref";
-- END;

-- 17 task
DROP PROCEDURE IF EXISTS percentage_early(ref_ refcursor);

CREATE OR REPLACE PROCEDURE percentage_early(ref_ refcursor)
AS
$$
BEGIN
    OPEN ref_ FOR
     WITH birthday_month AS (SELECT nickname, date_part('month', birthday) AS b_month
                                FROM peers),
             all_entries AS (SELECT COUNT(*) AS sum_entries, b_month
                             FROM (SELECT peer, "Date", b_month
                                   FROM timetracking
                                   JOIN birthday_month ON timetracking.peer = birthday_month.nickname
                                   WHERE 'State' = 'Success' AND date_part('month', "Date") = b_month
                                   GROUP BY peer, "Date", b_month) AS t
                             GROUP BY b_month),
        all_entries_early_12 AS (SELECT COUNT(*) AS sum_early_entries, b_month
                                 FROM (SELECT peer, "Date", b_month
                                       FROM timetracking
                                       JOIN birthday_month ON timetracking.peer = birthday_month.nickname
                                       WHERE 'State' = 'Success' AND date_part('month', "Date") = b_month AND time < '12:00:00'
                                       GROUP BY peer, "Date", b_month) AS t
                                 GROUP BY b_month)
        SELECT (CASE WHEN a1.b_month = 1 THEN 'January'
                WHEN a1.b_month = 2 THEN 'February'
                WHEN a1.b_month = 3 THEN 'March'
                WHEN a1.b_month = 4 THEN 'April'
                WHEN a1.b_month = 5 THEN 'May'
                WHEN a1.b_month = 6 THEN 'June'
                WHEN a1.b_month = 7 THEN 'July'
                WHEN a1.b_month = 8 THEN 'August'
                WHEN a1.b_month = 9 THEN 'September'
                WHEN a1.b_month = 10 THEN 'October'
                WHEN a1.b_month = 11 THEN 'November' ELSE 'December' END) AS month,
               (a2.sum_early_entries * 100) / a1.sum_entries AS EarlyEntries
        FROM all_entries AS a1
        JOIN all_entries_early_12 AS a2 ON a1.b_month = a2.b_month;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL percentage_early('ref_');
FETCH ALL IN "ref";
END;