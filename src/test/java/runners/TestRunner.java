package runners;

import io.karatelabs.core.MockServer;
import io.karatelabs.core.Runner;
import io.karatelabs.core.SuiteResult;
import mock.MockServerRunner;
import net.masterthought.cucumber.Configuration;
import net.masterthought.cucumber.ReportBuilder;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Single entry point for the whole suite.
 * - Starts the mock API in-process (so `mvn test` is self-contained; only Kafka + Postgres
 *   need to be up separately via docker-compose).
 * - Runs every *.feature under tests/ in parallel via Karate's Runner.
 * - Emits Karate's built-in HTML/JSON reports (target/karate-reports) AND a classic
 *   Cucumber-style HTML report (target/cucumber-html-reports) generated from the same
 *   cucumber-format JSON, so both report styles are available out of the box.
 */
class TestRunner {

    private static MockServer mockServer;

    @BeforeAll
    static void startMock() {
        mockServer = MockServerRunner.start(8099);
    }

    @AfterAll
    static void stopMock() {
        if (mockServer != null) {
            mockServer.stopAndWait();
        }
    }

    @Test
    void runSuite() throws IOException {
        SuiteResult results = Runner.path("classpath:tests")
                .outputCucumberJson(true)
                .parallel(5);

        generateCucumberHtmlReport(results.getReportDir());

        Assertions.assertEquals(0, results.getScenarioFailedCount(), String.join("\n", results.getErrors()));
    }

    private static void generateCucumberHtmlReport(Path karateOutputPath) throws IOException {
        List<String> jsonPaths;
        try (Stream<Path> stream = Files.walk(karateOutputPath)) {
            jsonPaths = stream
                    .filter(p -> p.toString().endsWith(".json"))
                    .map(Path::toString)
                    .collect(Collectors.toList());
        }
        if (jsonPaths.isEmpty()) {
            return;
        }
        Configuration config = new Configuration(new File("target"), "karate-framework-2.x");
        ReportBuilder reportBuilder = new ReportBuilder(jsonPaths, config);
        reportBuilder.generateReports();
    }
}
