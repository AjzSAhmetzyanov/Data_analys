-- 1 task
DROP PROCEDURE IF EXISTS add_p2p_check;

CREATE
OR REPLACE PROCEDURE add_p2p_check(
    checked_ VARCHAR,
    checker_ VARCHAR,
    task_ VARCHAR,
    check_status CheckStatus,
    time_ TIME)
AS
    $$
BEGIN
            IF
check_status == 'Start' THEN
                    INSERT INTO checks(Peer, Task, "Date")
                    VALUES (
                        checker_,
                        task_,
                        CURRENT_DATE
                    );
INSERT INTO P2P("Check", CheckingPeer, State, Time)
VALUES ((SELECT MAX(id) FROM checks),
        checked_,
        check_status,
        Time_);
ELSE
                    INSERT INTO P2P("Check", CheckingPeer, State, Time)
                    VALUES (
                        (SELECT MAX(id) FROM checks c WHERE c.peer = checker_ AND task_ = c.task),
                        checked_,
                        check_status,
                        time_
                    );
END IF;
END;
    $$
language plpgsql;


-- call add_p2p_check('pika', 'bulba', 'CPP2_s21_containers', 'Start', '11:12:13');
-- call add_p2p_check('lymondgl', 'gmalaka', 'DO2_Linux Network', 'Start', '11:12:13');
-- call add_p2p_check('lymondgl', 'gmalaka', 'DO2_Linux Network', 'Success', '11:22:13');
-- call add_p2p_check('onyx', 'bulba', 'A1_Maze', 'Start', '12:12:13');
-- call add_p2p_check('onyx', 'bulba', 'A1_Maze', 'Failure', '12:22:13');
-- delete from p2p where id = 11;
-- delete from p2p where id = 12;
-- delete from p2p where id = 13;
-- delete from p2p where id = 14;

-- 2 task

DROP PROCEDURE IF EXISTS adding_checking_by_verter;

CREATE
OR REPLACE PROCEDURE adding_checking_by_verter(
    checked_ VARCHAR,
    task_ VARCHAR,
    check_status CheckStatus,
    time_ TIME)
AS
    $$
BEGIN
            IF
check_status == 'Start' THEN
                IF (
                    (
                        SELECT max(p2p.time) FROM p2p
                        JOIN checks ON p2p."Check" = checks.id
                        WHERE checks.peer = checked_
                        AND checks.task = task_
                        AND p2p.state = 'Success'
                    ) IS NOT NULL
                ) THEN
                INSERT INTO verter ("Check", State, Time)
                VALUES (
                        (SELECT DISTINCT checks.id FROM p2p
                        JOIN checks on p2p."Check" = checks.id
                        WHERE checks.peer = checked_
                        AND checks.task = task_
                        AND p2p.state = 'Success'
                    ),
                    check_status,
                    time_
                );
ELSE
                    raise EXCEPTION 'P2P STATE MUST BE SUCCESS';
END IF;
ELSE
                  INSERT INTO verter("Check", State, Time)
                    VALUES (
                            ( SELECT "Check" FROM verter
                                GROUP BY "Check" HAVING count(*) % 2 = 1
                                ),
                            check_status,
                            time_
                           );
END IF;
END;
    $$
language plpgsql;

-- call adding_checking_by_verter('pika', 'CPP9_MonitoringSystem', 'Start', '12:00:00');
-- call adding_checking_by_verter('bulba', 'CPP2_s21_containers', 'Start', '12:00:00');
-- call adding_checking_by_verter('onyx', 'CPP9_MonitoringSystem', 'Start', '12:00:00');
-- call adding_checking_by_verter('onyx', 'CPP9_MonitoringSystem', 'Failure', '12:00:00');
-- delete from verter where id = 13;
-- delete from verter where id = 14;

-- 3 task

CREATE
OR REPLACE FUNCTION check_start() RETURNS TRIGGER AS $after_adding$
BEGIN

    IF
(tg_op = 'INSERT' AND new.state <> 'Start') THEN
        IF ((SELECT id
             FROM transferredpoints
             WHERE checkingpeer = new.checkingpeer
               AND checkedpeer = (SELECT peer
                     FROM checks
                     WHERE checks.id = new."Check"
                       AND "Date" = CURRENT_DATE)) IS NULL) THEN
            INSERT INTO transferredpoints(checkingpeer, checkedpeer, pointsamount)
SELECT (SELECT peer FROM checks WHERE checks.id = new."Check"), new.checkingpeer, 1;
ELSE
UPDATE transferredpoints
SET pointsamount = (pointsamount + 1)
WHERE checkingpeer = new.checkingpeer
  AND checkedpeer = (SELECT peer
                     FROM checks
                     WHERE checks.id = new."Check"
                       AND "Date" = CURRENT_DATE);
END IF;
END IF;
RETURN NULL;
END;
$after_adding$
LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS after_adding ON p2p;
CREATE TRIGGER after_adding
    AFTER INSERT
    ON p2p
    FOR EACH ROW EXECUTE FUNCTION check_start();

-- 4 task

CREATE
OR REPLACE FUNCTION fnc_trg_xp_insert()
    RETURNS TRIGGER AS
$fnc_trg_xp_insert$
BEGIN
    IF
(tg_op = 'INSERT' AND (SELECT "Check" FROM xp WHERE "Check" = NEW."Check") IS NULL) THEN
        IF (new.xpamount <= (SELECT DISTINCT maxxp
                                       FROM tasks
                                                JOIN checks ON checks.task = tasks.title
                                       WHERE checks.task = (seleCt task FROM checks WHERE id = NEW."Check"))) THEN
            IF ((SELECT verter.state
                                       FROM verter
                                       WHERE "Check" = new."Check"
                                       ORDER BY time DESC
                                       LIMIT 1) = 'Success') THEN
                RETURN NEW;
            ELIF
((SELECT p2p.state
                                       FROM p2p
                                       WHERE "Check" = new."Check"
                                       ORDER BY time DESC
                                       LIMIT 1) = 'Success') THEN
                RETURN NEW;
END IF;
END IF;
END IF;
RETURN NULL;
END;
$fnc_trg_xp_insert$
LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS trg_xp_insert ON xp;
CREATE TRIGGER trg_xp_insert
    BEFORE INSERT
    ON xp
    FOR EACH ROW
    EXECUTE FUNCTION fnc_trg_xp_insert();
