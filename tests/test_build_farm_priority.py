"""Exercise the production Cuirass prioritizer with reused build records."""

import sqlite3
import unittest
from pathlib import Path

SQL = (
    Path(__file__).resolve().parents[1] / "etc/build-farm/prioritize-securityops.sql"
).read_text()


class PrioritizeSecurityOpsTest(unittest.TestCase):
    def test_requeues_reused_internal_dependency_before_its_root(self):
        db = sqlite3.connect(":memory:")
        db.executescript(
            """
            CREATE TABLE Evaluations (id INTEGER, specification TEXT, status INTEGER);
            CREATE TABLE Specifications (name TEXT, is_active INTEGER);
            CREATE TABLE Builds (id INTEGER, evaluation INTEGER, status INTEGER,
                                 priority INTEGER);
            CREATE TABLE Jobs (name TEXT, evaluation INTEGER, build INTEGER,
                               status INTEGER);
            CREATE TABLE BuildDependencies (source INTEGER, target INTEGER);

            INSERT INTO Evaluations VALUES (10, 'securityops', 0),
                                           (11, 'securityops', 0);
            INSERT INTO Specifications VALUES ('securityops', 1);
            INSERT INTO Builds VALUES (101, 10, 2, 5),
                                      (102, 11, 2, 5),
                                      (103, 11, 2, 5),
                                      (201, 10, 0, 5),
                                      (202, 10, 1, 5),
                                      (301, 10, 2, 5),
                                      (302, 10, 2, 5),
                                      (303, 10, 2, 5),
                                      (304, 10, 2, 5);
            INSERT INTO Jobs VALUES ('old', 10, 101, 2),
                                    ('ready-later', 11, 102, 2),
                                    ('blocked', 11, 103, 2);
            INSERT INTO BuildDependencies VALUES (101, 301),
                                                 (102, 302),
                                                 (103, 303),
                                                 (301, 201),
                                                 (302, 201),
                                                 (303, 202),
                                                 (304, 201);
            """
        )

        db.executescript(SQL)
        rows = dict(db.execute("SELECT id, status FROM Builds"))
        self.assertEqual(rows[101], 2)
        self.assertEqual(rows[102], 2)
        self.assertEqual(rows[103], 2)
        self.assertEqual(rows[301], 2)
        self.assertEqual(rows[302], -2)
        self.assertEqual(rows[303], 2)
        self.assertEqual(rows[304], 2)

        db.execute("UPDATE Builds SET status = 0 WHERE id = 302")
        db.executescript(SQL)
        self.assertEqual(
            db.execute("SELECT status FROM Builds WHERE id = 102").fetchone(), (-2,)
        )

    def test_requeues_latest_failed_dependency_only_after_requirements_succeed(self):
        db = sqlite3.connect(":memory:")
        db.executescript(
            """
            CREATE TABLE Evaluations (id INTEGER, specification TEXT, status INTEGER);
            CREATE TABLE Specifications (name TEXT, is_active INTEGER);
            CREATE TABLE Builds (id INTEGER, evaluation INTEGER, status INTEGER,
                                 priority INTEGER);
            CREATE TABLE Jobs (name TEXT, evaluation INTEGER, build INTEGER,
                               status INTEGER);
            CREATE TABLE BuildDependencies (source INTEGER, target INTEGER);

            INSERT INTO Evaluations VALUES (10, 'securityops', 0),
                                           (11, 'securityops', 0);
            INSERT INTO Specifications VALUES ('securityops', 1);
            INSERT INTO Builds VALUES (101, 10, 2, 5),
                                      (102, 11, 2, 5),
                                      (103, 11, 2, 5),
                                      (201, 11, 0, 5),
                                      (202, 11, 1, 5);
            INSERT INTO Jobs VALUES ('old', 10, 101, 2),
                                    ('ready', 11, 102, 2),
                                    ('blocked', 11, 103, 2);
            INSERT INTO BuildDependencies VALUES (101, 201),
                                                 (102, 201),
                                                 (103, 202);
            """
        )

        db.executescript(SQL)
        rows = dict(db.execute("SELECT id, status FROM Builds"))
        self.assertEqual(rows[101], 2)
        self.assertEqual(rows[102], -2)
        self.assertEqual(rows[103], 2)

    def test_latest_job_reactivates_canceled_dependencies_of_reused_build(self):
        db = sqlite3.connect(":memory:")
        db.executescript(
            """
            CREATE TABLE Evaluations (id INTEGER, specification TEXT, status INTEGER);
            CREATE TABLE Specifications (name TEXT, is_active INTEGER);
            CREATE TABLE Builds (id INTEGER, evaluation INTEGER, status INTEGER,
                                 priority INTEGER);
            CREATE TABLE Jobs (name TEXT, evaluation INTEGER, build INTEGER,
                               status INTEGER);
            CREATE TABLE BuildDependencies (source INTEGER, target INTEGER);

            INSERT INTO Evaluations VALUES (1, 'guix', 0),
                                           (10, 'securityops', 0),
                                           (11, 'securityops', 0);
            INSERT INTO Specifications VALUES ('guix', 0), ('securityops', 1);
            INSERT INTO Builds VALUES (101, 10, 2, 5),
                                      (102, 1, 4, 5),
                                      (103, 1, -2, 5),
                                      (104, 11, -2, 5),
                                      (105, 1, 4, 5);
            INSERT INTO Jobs VALUES ('reused', 10, 101, 2),
                                    ('reused', 11, 101, 2),
                                    ('pending', 11, 104, -2);
            INSERT INTO BuildDependencies VALUES (101, 102), (104, 105);
            """
        )

        db.executescript(SQL)
        rows = dict(db.execute("SELECT id, status FROM Builds"))
        self.assertEqual(rows[102], -2)
        self.assertEqual(rows[105], -2)
        self.assertEqual(rows[103], 4)


if __name__ == "__main__":
    unittest.main()
