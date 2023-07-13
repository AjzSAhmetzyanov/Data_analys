DROP TABLE IF EXISTS Tasks, P2P, TransferredPoints, Friends, Recommendations, TimeTracking, Checks, Peers, Verter, XP;

DROP TYPE IF EXISTS CheckStatus;

CREATE DATABASE INFO_21;

CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE IF NOT EXISTS Peers
(
    Nickname VARCHAR(255) PRIMARY KEY NOT NULL,
    Birthday DATE                     NOT NULL
);

CREATE TABLE IF NOT EXISTS Tasks
(
    Title      VARCHAR(255) PRIMARY KEY NOT NULL,
    ParentTask VARCHAR(255),
    MaxXP      INT                      NOT NULL,
    CHECK (MaxXP >= 0),
    CONSTRAINT FK_TASKS_TASKS_TITLE FOREIGN KEY (ParentTask) REFERENCES Tasks (Title)
);

CREATE TABLE IF NOT EXISTS Checks
(
    ID     INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Peer   VARCHAR(255) NOT NULL,
    Task   VARCHAR(255) NOT NULL,
    "Date" DATE         NOT NULL,
    FOREIGN KEY (Task) REFERENCES Tasks (Title),
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    CONSTRAINT unique_check UNIQUE (Peer, Task)
);

CREATE TABLE IF NOT EXISTS P2P
(
    ID           INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    "Check"      INT          NOT NULL,
    CheckingPeer VARCHAR(255) NOT NULL,
    State        CheckStatus  NOT NULL,
    Time         TIME         NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID),
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname),
    CONSTRAINT unique_p2p UNIQUE (State, "Check")
);

CREATE TABLE IF NOT EXISTS Verter
(
    ID      INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    "Check" INT         NOT NULL,
    State   CheckStatus NOT NULL,
    Time    TIME        NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID),
    CONSTRAINT unique_verter UNIQUE (State, "Check")
);

CREATE TABLE IF NOT EXISTS TransferredPoints
(
    ID           INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    CheckingPeer VARCHAR(255) NOT NULL,
    CheckedPeer  VARCHAR(255) NOT NULL,
    PointsAmount INT,
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname),
    FOREIGN KEY (CheckedPeer) REFERENCES Peers (Nickname)
--     CONSTRAINT unique_transferredpoints UNIQUE (CheckingPeer, CheckedPeer)
);

CREATE TABLE IF NOT EXISTS Friends
(
    ID    INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Peer1 VARCHAR(255) NOT NULL,
    Peer2 VARCHAR(255) NOT NULL,
    FOREIGN KEY (Peer1) REFERENCES Peers (Nickname),
    FOREIGN KEY (Peer2) REFERENCES Peers (Nickname),
    CONSTRAINT unique_friends UNIQUE (Peer1, Peer2)
);

CREATE TABLE IF NOT EXISTS Recommendations
(
    ID              INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Peer            VARCHAR(255) NOT NULL,
    RecommendedPeer VARCHAR(255) NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (RecommendedPeer) REFERENCES Peers (Nickname),
    CONSTRAINT unique_recommendations UNIQUE (Peer, RecommendedPeer)
);

CREATE TABLE IF NOT EXISTS TimeTracking
(
    ID      INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Peer    VARCHAR(255) NOT NULL,
    "Date"  DATE         NOT NULL,
    Time    TIME         NOT NULL,
    "State" INT          NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    CHECK ("State" IN (1, 2))
);

CREATE TABLE IF NOT EXISTS XP
(
    ID       INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    "Check"  INT NOT NULL,
    XPAmount INT,
    FOREIGN KEY ("Check") REFERENCES Checks (ID),
    CHECK ( XPAmount >= 0),
    CONSTRAINT unique_xp UNIQUE ("Check")
);

-- Проверка наличия таблиц
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';

INSERT INTO Peers (Nickname, Birthday)
VALUES ('lymondgl', '1996-07-27'),
       ('gmalaka', '1996-06-26'),
       ('tartaruc', '1996-05-25'),
       ('onyx', '1996-04-24'),
       ('pokemon', '1996-03-23'),
       ('bulba', '1996-02-22'),
       ('pika', '1996-01-21'),
       ('hfast', '1996-01-20'),
       ('nfarfetch', '1996-01-19');

INSERT INTO Tasks (Title, ParentTask, MaxXp)
VALUES ('C2_SimpleBashUtils', NULL, 250),
       ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
       ('C4_s21_math', 'C2_SimpleBashUtils', 300),
       ('C5_s21_decimal', 'C4_s21_math', 350),
       ('C6_s21_matrix', 'C5_s21_decimal', 200),
       ('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
       ('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
       ('DO1_Linux', 'C3_s21_string+', 300),
       ('DO2_Linux Network', 'DO1_Linux', 250),
       ('DO3_LinuxMonitoring v1.0', 'DO2_Linux Network', 350),
       ('DO4_LinuxMonitoring v2.0', 'DO3_LinuxMonitoring v1.0', 350),
       ('DO5_SimpleDocker', 'DO3_LinuxMonitoring v1.0', 300),
       ('DO6_CICD', 'DO5_SimpleDocker', 300),
       ('CPP1_s21_matrix+', 'C8_3DViewer_v1.0', 300),
       ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350),
       ('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600),
       ('CPP4_3DViewer_v2.0', 'CPP3_SmartCalc_v2.0', 750),
       ('CPP5_3DViewer_v2.1', 'CPP4_3DViewer_v2.0', 600),
       ('CPP6_3DViewer_v2.2', 'CPP4_3DViewer_v2.0', 800),
       ('CPP7_MLP', 'CPP4_3DViewer_v2.0', 700),
       ('CPP8_PhotoLab_v1.0', 'CPP4_3DViewer_v2.0', 450),
       ('CPP9_MonitoringSystem', 'CPP4_3DViewer_v2.0', 1000),
       ('A1_Maze', 'CPP4_3DViewer_v2.0', 300),
       ('A2_SimpleNavigator v1.0', 'A1_Maze', 400),
       ('A3_Parallels', 'A2_SimpleNavigator v1.0', 300),
       ('A4_Crypto', 'A2_SimpleNavigator v1.0', 350),
       ('A5_s21_memory', 'A2_SimpleNavigator v1.0', 400),
       ('A6_Transactions', 'A2_SimpleNavigator v1.0', 700),
       ('A7_DNA Analyzer', 'A2_SimpleNavigator v1.0', 800),
       ('A8_Algorithmic trading', 'A2_SimpleNavigator v1.0', 800),
       ('SQL1_Bootcamp', 'C8_3DViewer_v1.0', 1500),
       ('SQL2_Info21 v1.0', 'SQL1_Bootcamp', 500),
       ('SQL3_RetailAnalitycs v1.0', 'SQL2_Info21 v1.0', 600);

INSERT INTO Checks (Peer, Task, "Date")
VALUES ('lymondgl', 'SQL1_Bootcamp', '2023-06-09'),
       ('gmalaka', 'A6_Transactions', '2022-12-14'),
       ('tartaruc', 'A3_Parallels', '2023-01-06'),
       ('onyx', 'CPP9_MonitoringSystem', '2023-02-26'),
       ('pokemon', 'CPP6_3DViewer_v2.2', '2023-01-20'),
       ('bulba', 'CPP2_s21_containers', '2022-06-30'),
       ('pika', 'DO1_Linux', '2022-05-09'),
       ('hfast', 'A7_DNA Analyzer', '2022-11-09'),
       ('nfarfetch', 'DO2_Linux Network', '2022-11-30'),
       ('gmalaka', 'SQL1_Bootcamp', '2023-06-09'),
       ('lymondgl', 'A6_Transactions', '2022-12-14'),
       ('onyx', 'A3_Parallels', '2023-01-06'),
       ('tartaruc', 'CPP9_MonitoringSystem', '2023-02-26'),
       ('bulba', 'CPP6_3DViewer_v2.2', '2023-01-20'),
       ('pokemon', 'CPP2_s21_containers', '2022-06-30'),
       ('hfast', 'DO1_Linux', '2022-05-09'),
       ('pika', 'A7_DNA Analyzer', '2022-11-09'),
       ('onyx', 'DO2_Linux Network', '2022-11-30');

INSERT INTO P2P ("Check", CheckingPeer, State, Time)
VALUES (1, 'lymondgl', 'Start', '18:30:21'),
       (1, 'lymondgl', 'Success', '19:01:12'),
       (2, 'pika', 'Start', '13:02:01'),
       (2, 'pika', 'Success', '13:10:01'),
       (3, 'bulba', 'Start', '09:11:45'),
       (3, 'bulba', 'Failure', '11:06:23'),
       (4, 'onyx', 'Start', '19:10:45'),
       (4, 'onyx', 'Success', '20:06:23'),
       (5, 'gmalaka', 'Start', '20:11:45'),
       (5, 'gmalaka', 'Success', '20:15:23'),
       (6, 'pika', 'Start', '00:00:00'),
       (7, 'lymondgl', 'Start', '11:11:45'),
       (7, 'lymondgl', 'Success', '11:15:23'),
       (8, 'onyx', 'Start', '10:51:45'),
       (8, 'onyx', 'Success', '11:15:13');

INSERT INTO Verter ("Check", State, Time)
VALUES (1, 'Start', '19:21:12'),
       (1, 'Success', '19:51:12'),
       (2, 'Start', '13:30:01'),
       (2, 'Success', '14:00:01'),
       (4, 'Start', '20:26:23'),
       (4, 'Success', '20:56:23'),
       (5, 'Start', '19:21:12'),
       (5, 'Success', '19:51:12'),
       (7, 'Start', '11:35:23'),
       (7, 'Failure', '12:05:23'),
       (8, 'Start', '11:35:13'),
       (8, 'Success', '12:05:13');

INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
VALUES ('lymondgl', 'pika', 1),
       ('pika', 'lymondgl', 1),
       ('onyx', 'bulba', 4),
       ('gmalaka', 'lymondgl', 1),
       ('hfast', 'lymondgl', 1),
       ('lymondgl', 'onyx', 1),
       ('bulba', 'onyx', 10);

INSERT INTO Friends (Peer1, Peer2)
VALUES ('lymondgl', 'pika'),
       ('pika', 'bulba'),
       ('onyx', 'hfast'),
       ('gmalaka', 'lymondgl'),
       ('lymondgl', 'hfast'),
       ('pika', 'hfast'),
       ('bulba', 'onyx');

INSERT INTO Recommendations (Peer, RecommendedPeer)
VALUES ('lymondgl', 'pika'),
       ('pika', 'bulba'),
       ('onyx', 'hfast'),
       ('gmalaka', 'lymondgl'),
       ('lymondgl', 'hfast'),
       ('pika', 'hfast'),
       ('bulba', 'onyx');

INSERT INTO XP ("Check", XPAmount)
VALUES (1, 1500),
       (2, 700),
       (4, 1000),
       (5, 800),
       (8, 800);

INSERT INTO TimeTracking (Peer, "Date", Time, "State")
VALUES ('lymondgl', '2023-01-30', '11:05:16', 1),
       ('lymondgl', '2023-01-30', '20:15:22', 2),
       ('pika', '2023-02-01', '17:13:01', 1),
       ('pika', '2023-02-01', '03:10:12', 2),
       ('bulba', '2022-09-03', '12:45:38', 1),
       ('bulba', '2022-09-03', '22:43:56', 2),
       ('pokemon', '2022-12-23', '08:00:00', 1),
       ('pokemon', '2023-12-23', '21:00:00', 2),
       ('hfast', '2020-01-02', '00:00:00', 1);

CREATE OR REPLACE PROCEDURE export(IN tablename VARCHAR, IN path TEXT, IN separator CHAR) AS $$
    BEGIN
            EXECUTE format('copy %s to ''%s'' delimiter ''%s'' csv header;',
                           tablename, path, separator);
    END;
$$ language plpgsql;

CREATE OR REPLACE PROCEDURE import(IN table_name VARCHAR, IN file_path TEXT, IN separator CHAR) AS $$
    BEGIN
        EXECUTE FORMAT('copy %s from ''%s'' delimiter ''%s'' csv header;', table_name, file_path, separator);
    END;
$$ language plpgsql;

-- Check Exists procedure;
SELECT proname
FROM pg_catalog.pg_proc
WHERE pronamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = 'public');


-- Call export into files
-- CALL export('Peers', '/tmp/peers.csv', ',');
-- CALL export('Tasks', '/tmp/tasks.csv', ',');
-- CALL export('Checks', '/tmp/checks.csv', ',');
-- CALL export('P2P', '/tmp/p2p.csv', ',');
-- CALL export('verter', '/tmp/verter.csv', ',');
-- CALL export('transferredpoints', '/tmp/transferredpoints.csv', ',');
-- CALL export('friends', '/tmp/friends.csv', ',');
-- CALL export('recommendations', '/tmp/recommendations.csv', ',');
-- CALL export('xp', '/tmp/xp.csv', ',');
-- CALL export('timetracking', '/tmp/timetracking.csv', ',');

-- TRUNCATE TABLE Peers CASCADE;
-- TRUNCATE TABLE Tasks CASCADE;
-- TRUNCATE TABLE Checks CASCADE;
-- TRUNCATE TABLE P2P CASCADE;
-- TRUNCATE TABLE Verter CASCADE;
-- TRUNCATE TABLE Transferredpoints CASCADE;
-- TRUNCATE TABLE Friends CASCADE;
-- TRUNCATE TABLE Recommendations CASCADE;
-- TRUNCATE TABLE XP CASCADE;
-- TRUNCATE TABLE TimeTracking CASCADE;

-- Call import into files
-- CALL import('Peers', '/tmp/peers.csv', ',');
-- CALL import('Tasks', '/tmp/tasks.csv', ',');
-- CALL import('Checks', '/tmp/checks.csv', ',');
-- CALL import('P2P', '/tmp/p2p.csv', ',');
-- CALL import('verter', '/tmp/verter.csv', ',');
-- CALL import('transferredpoints', '/tmp/transferredpoints.csv', ',');
-- CALL import('friends', '/tmp/friends.csv', ',');
-- CALL import('recommendations', '/tmp/recommendations.csv', ',');
-- CALL import('xp', '/tmp/xp.csv', ',');
-- CALL import('timetracking', '/tmp/timetracking.csv', ',');
