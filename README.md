# karate-framework-2.x

Karate framework covering: a mock API, REST test suites, Kafka
event-driven testing, and DB validation, all runnable locally with one Maven command.

## What's hosted, and by what

| Component | Hosted by | Notes |
|---|---|---|
| Benefits/disability mock API | Karate itself (`io.karatelabs.core.MockServer`), in-process on port 8099 | `mock/benefits-mock.feature`. Starts automatically in `TestRunner` via `@BeforeAll`, or standalone via `MockServerRunner.main()` (also defaults to 8099). |
| Kafka broker | Docker (`docker-compose.yml`) | Real broker on `localhost:9092`. Not simulated - the mock actually publishes to it. Images are pulled via `mirror.gcr.io` rather than `docker.io` directly, since some networks/sandboxes can reach Docker Hub's mirror but not its own CDN. |
| Postgres | Docker (`docker-compose.yml`), seeded by `data/init.sql` | Real DB on `localhost:5432`. |
| DB2 | Not hosted here | `DbHelper` + `db-validation.feature` include a working pattern, tagged `@ignore`, for wiring up a real instance. |
| Test runner + reports | JUnit 5 (Jupiter 6.x) + Karate 2.0.10 + `cucumber-reporting` | `runners/TestRunner.java`. Karate moved from Intuit (`com.intuit.karate`) to Karate Labs (`io.karatelabs`) as of 2.x; this project uses the native `io.karatelabs` API throughout, not the deprecated `com.intuit.karate` compatibility shim. |

## End-to-end flow

1. `docker-compose up -d` starts Kafka (+ Zookeeper) and Postgres, and seeds two eligibility
   rows into Postgres.
2. `mvn test` launches `TestRunner`, which in `@BeforeAll` starts the mock API in-process on
   `:8099` by loading `mock/benefits-mock.feature`.
3. Karate's `Runner.path("classpath:tests")` discovers and runs every `.feature` under
   `tests/` in parallel (5 threads).
4. Each feature reads shared config (base URL, JWT, Kafka/DB settings) from
   `karate-config.js`, merged with env-specific overrides from `karate-local.js` when
   `karate.env=local` (the default).
5. REST-only tests (`tests/eligibility`, `tests/disability`) call the mock directly over
   HTTP and assert on status/schema/headers/etc.
6. `POST /api/disability/apply`, when it succeeds inside the mock, uses `KafkaProducerHelper`
   (via Karate's Java interop) to publish an event to the real Kafka broker on the
   `disability.application.events` topic - so the mock isn't just returning canned JSON, it's
   driving a real downstream side effect.
7. `tests/kafka` features consume from that real broker with `KafkaConsumerHelper` to verify
   the event was published correctly (and, in one scenario, that no event is published when
   the request is rejected).
8. `tests/db` features call the mock, then query Postgres directly with `DbHelper` to
   cross-check API responses against the system of record.
9. After the run, `TestRunner` generates a classic Cucumber-style HTML report
   (`target/cucumber-html-reports`) from the same cucumber-format JSON that Karate's own
   built-in HTML report (`target/karate-reports`) is built from - both are produced from one
   test run, no extra config.

## Project layout

```
karate-framework-2.x/
├── pom.xml
├── docker-compose.yml
├── data/init.sql                          # Postgres seed data
└── src/test/java/                         # Karate convention: features + *.js live next to .java
    ├── karate-config.js                   # base config, loaded for every run
    ├── karate-local.js                    # local-env overrides (JWT), merged when karate.env=local
    ├── runners/TestRunner.java            # JUnit5 entry point, starts mock, runs suite, builds reports
    ├── mock/
    │   ├── benefits-mock.feature          # the application under test
    │   └── MockServerRunner.java          # starts the mock in-process or standalone
    ├── utils/
    │   ├── KafkaProducerHelper.java
    │   ├── KafkaConsumerHelper.java
    │   └── DbHelper.java                  # generic JDBC helper, reused for Postgres + DB2
    └── tests/
        ├── eligibility/get-eligibility.feature
        ├── disability/apply-disability.feature
        ├── kafka/kafka-produce-consume.feature
        └── db/db-validation.feature
```

## Running it

```bash
docker-compose up -d          # Kafka + Postgres
mvn test                      # starts the mock, runs everything under tests/, builds reports
```

Reports land in:
- `target/karate-reports/karate-summary.html` - Karate's built-in report
- `target/cucumber-html-reports/overview-features.html` - classic Cucumber-style report
- `target/surefire-reports/` - JUnit XML for CI

Run a single feature during development:

```bash
mvn test -Dtest=TestRunner -Dkarate.options="classpath:tests/eligibility/get-eligibility.feature"
```

Run the mock standalone (e.g. to hit it from Postman while iterating). Note `MockServerRunner`
is a test class, so `exec:java` needs `test-compile` (not plain `compile`) and the test
classpath scope - both are required or you'll get a `ClassNotFoundException`:

```bash
mvn test-compile exec:java -Dexec.mainClass=mock.MockServerRunner -Dexec.classpathScope=test
```

This starts the mock on `:8099` by default; pass a port as the program argument to override,
e.g. add `-Dexec.args=8081`.

## Requirements to run

- JDK 21 (the project targets bytecode release 21 - Karate 2.x's own baseline - so this is a
  hard requirement, not just a minimum), Maven 3.6+
- Docker (for Kafka + Postgres) - or point `karate-config.js` at existing instances and skip
  `docker-compose`
- DB2 tests are `@ignore`d by default since no DB2 instance is bundled; point
  `db.db2.url`/user/password in `karate-config.js` at a real instance, seed
  `DISABILITY_LEDGER`, and remove the `@ignore` tag to enable them. The `com.ibm.db2:jcc`
  driver in `pom.xml` may need pulling from an internal/IBM Maven mirror if Central is
  blocked in your environment.

## Known issues

- With Kafka + Postgres up, 27 of 31 scenarios pass. The remaining 4 all cluster around
  scenarios that clear/omit the `Authorization` header (`header Authorization = ''`) to test
  the "missing auth" 401 path, in `get-eligibility.feature` and `apply-disability.feature`.
  Those scenarios - and, seemingly at random, whichever *other* scenario runs adjacent to them -
  end up receiving each other's response status codes. This reproduces identically whether the
  suite runs in parallel or with `.parallel(1)` (fully sequential), and reordering the
  scenarios only shifts which ones are affected rather than fixing it - so it isn't a race
  condition or a bug in this project's test code. Mock server logic is independently verified
  correct (confirmed via direct `curl` calls with and without the header). This points to a
  transport-layer/response-correlation bug in Karate 2.0.10's very new HTTP client
  (`io.karatelabs.http`), worth a bug report to Karate Labs.

## Notes / deliberate deviations

- Karate's actual env-config convention is a fixed `karate-config.js` plus one file per
  environment named `karate-<env>.js` (e.g. `karate-local.js`, `karate-qa.js`) - **not**
  `karate-config-<env>.js`. This project follows the real convention (`karate-local.js`)
  rather than the literal filename, since `karate-config-local.js` isn't a name Karate's
  config loader resolves automatically.
- The mock keeps application state in an in-memory JS map (`applications`) inside the
  feature's `Background`, which Karate initializes once when the mock server starts and
  keeps in scope for the process lifetime - this is the standard way Karate mocks simulate
  a datastore without a real DB.
- `db-validation.feature`'s Postgres eligibility scenarios run against real seeded data and
  pass out of the box; the "insert-after-POST" and DB2 scenarios are included as ready-to-use
  patterns (`@ignore`d) since the mock doesn't persist applications to a real database - wire
  them up once your actual service does.
