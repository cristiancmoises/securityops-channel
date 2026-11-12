-- Cuirass does not propagate a root build's priority through BuildDependencies.
-- Keep the dependency closure of pending SecurityOps jobs, including jobs
-- waiting on failed dependencies in the latest completed evaluation, ahead of
-- the general Guix channel backlog without deleting build records or history.
BEGIN;

WITH RECURSIVE securityops_roots(id) AS (
  SELECT b.id
    FROM Builds AS b
    JOIN Evaluations AS e ON e.id = b.evaluation
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
    FROM Builds AS b
    JOIN Evaluations AS e ON e.id = b.evaluation
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
