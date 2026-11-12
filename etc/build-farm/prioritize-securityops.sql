-- Cuirass does not propagate a root build's priority through BuildDependencies.
-- Keep the dependency closure of pending SecurityOps jobs, including jobs
-- waiting on failed dependencies in the latest completed evaluation, ahead of
-- the general Guix channel backlog without deleting build records or history.
-- Builds are reused across evaluations; Jobs identifies the current evaluation.
BEGIN;

-- Cuirass can leave a build at "dependency failed" after its requirements
-- succeed.  Requeue only nodes reachable from the latest completed
-- SecurityOps jobs, and only after all their recorded requirements succeed.
WITH RECURSIVE latest(id) AS (
  SELECT MAX(id) FROM Evaluations
   WHERE specification = 'securityops' AND status = 0
), roots(id) AS (
  SELECT job.build
    FROM Jobs AS job
    JOIN latest ON job.evaluation = latest.id
), required(id) AS (
  SELECT id FROM roots
  UNION
  SELECT dependency.target
    FROM BuildDependencies AS dependency
    JOIN required ON dependency.source = required.id
), retry(id) AS (
  SELECT b.id
    FROM required
    JOIN Builds AS b ON b.id = required.id
   WHERE b.status = 2
     AND EXISTS (SELECT 1 FROM BuildDependencies AS d
                  WHERE d.source = b.id)
     AND NOT EXISTS (
       SELECT 1 FROM BuildDependencies AS d
         JOIN Builds AS required ON required.id = d.target
        WHERE d.source = b.id AND required.status <> 0)
)
UPDATE Builds
   SET status = -2, priority = 0
 WHERE status = 2 AND id IN (SELECT id FROM retry);

WITH RECURSIVE securityops_roots(id) AS (
  SELECT b.id
    FROM Jobs AS job
    JOIN Evaluations AS e ON e.id = job.evaluation
    JOIN Builds AS b ON b.id = job.build
   WHERE e.specification = 'securityops'
     AND (b.status < 0 OR
          (b.status = 2 AND e.id = (
            SELECT MAX(id) FROM Evaluations
             WHERE specification = 'securityops' AND status = 0)))
), required(id) AS (
  SELECT id FROM securityops_roots
  UNION
  SELECT dependency.target
    FROM BuildDependencies AS dependency
    JOIN required ON dependency.source = required.id
)
UPDATE Builds
   SET priority = 0,
       status = CASE WHEN status = 4 THEN -2 ELSE status END
 WHERE id IN (SELECT id FROM required)
   AND (priority > 0 OR status = 4);

-- The local Cuirass builder submits all pending derivations as one shuffled
-- list, regardless of priority.  Keep disabled mirror jobsets recorded while
-- excluding their scheduled backlog from the SecurityOps build lane.
WITH RECURSIVE securityops_roots(id) AS (
  SELECT b.id
    FROM Jobs AS job
    JOIN Evaluations AS e ON e.id = job.evaluation
    JOIN Builds AS b ON b.id = job.build
   WHERE e.specification = 'securityops'
     AND (b.status < 0 OR
          (b.status = 2 AND e.id = (
            SELECT MAX(id) FROM Evaluations
             WHERE specification = 'securityops' AND status = 0)))
), required(id) AS (
  SELECT id FROM securityops_roots
  UNION
  SELECT dependency.target
    FROM BuildDependencies AS dependency
    JOIN required ON dependency.source = required.id
)
UPDATE Builds AS build
   SET status = 4
  FROM Evaluations AS evaluation,
       Specifications AS specification
 WHERE build.evaluation = evaluation.id
   AND specification.name = evaluation.specification
   AND specification.is_active = 0
   AND build.status < 0
   AND build.id NOT IN (SELECT id FROM required);

COMMIT;
