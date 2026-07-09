package mock;

import io.karatelabs.core.MockServer;

/**
 * Starts the benefits/disability mock API defined in benefits-mock.feature.
 * Used both standalone (main method, for manual/local runs) and programmatically
 * from TestRunner so the whole suite is self-contained (mock starts before tests run).
 */
public class MockServerRunner {

    public static MockServer start(int port) {
        return MockServer
                .feature("classpath:mock/benefits-mock.feature")
                .port(port)
                .start();
    }

    public static void main(String[] args) {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8099;
        MockServer server = start(port);
        System.out.println("Benefits mock API running on http://localhost:" + port);
        server.waitSync();
    }
}
