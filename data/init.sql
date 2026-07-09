-- Seed data for the Postgres DB-validation tests (tests/db/db-validation.feature).
-- Loaded automatically by docker-compose on first container start.

CREATE TABLE eligibility (
  ssn      VARCHAR(9) PRIMARY KEY,
  eligible BOOLEAN NOT NULL
);

CREATE TABLE disability_application (
  application_id VARCHAR(36) PRIMARY KEY,
  ssn             VARCHAR(9) NOT NULL,
  status          VARCHAR(20) NOT NULL,
  submitted_at    TIMESTAMP NOT NULL DEFAULT now()
);

-- Matches the eligibility logic in mock/benefits-mock.feature: last digit even = eligible.
INSERT INTO eligibility (ssn, eligible) VALUES ('123456788', true);
INSERT INTO eligibility (ssn, eligible) VALUES ('123456787', false);
