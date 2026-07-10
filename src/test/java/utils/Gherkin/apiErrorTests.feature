Feature: API Error Response Tests (Reusable)
# Now you can call this function with different data sets, keeping your tests DRY:
# One place to maintain request logic — if you add logging, headers, or retry logic, you only change it in common-errors.feature.
# Easy to scale — just add more rows in the Examples table.
# Readable reports — Karate will show each row as a separate scenario in the report.
# Extensible — you can add extra assertions (e.g., check for response.error) inside the function if you want.

  Background:
    * url baseUrl
    * def verifyError = call read('common-errors.feature@verify error code')

  Scenario Outline: Verify common error codes
    * call verifyError
      """
      {
        url: '<endpoint>',
        method: '<httpMethod>',
        requestBody: <payload>,
        headers: <hdrs>,
        expectedStatus: <statusCode>
      }
      """

  Examples:
    | endpoint             | httpMethod | payload               | hdrs                                  | statusCode |
    | /api/resource        | post       | { invalid: 'data' }   | {}                                    | 400        |
    | /api/protected       | get        | null                  | { Authorization: 'invalid-token' }    | 401        |
    | /api/admin           | get        | null                  | { Authorization: 'user-token' }       | 403        |
    | /api/resource        | get        | null                  | { Accept: 'application/xml' }         | 406        |
    | /api/resource        | get        | null                  | {}                                    | 429        |
    | /api/error-trigger   | get        | null                  | {}                                    | 500        |
    | /api/down-service    | get        | null                  | {}                                    | 503        |


  Scenario: uitility javascript
    * eval
    """
        const uuid = crypto.randomUUID();
        const timestamp = new Date().toISOString();
        env.set("request_id", uuid);
        env.set("timestamp", timestamp);
        const bodyJson = JSON.parse(request.body);
        console.log("Request ID:", bodyJson.id);
        const json = JSON.parse(response.body);
        const userId = json.data?.id;
        const token = json.data?.token;
        env.set("user_id", userId);
        env.set("auth_token", token);
        console.log("User ID:", userId);
        //extract values from an xml response
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(response.body, "application/xml");
        const orderId = xmlDoc.getElementsByTagName("orderId")[0]?.textContent;
        env.set("order_id", orderId);
        console.log("Order ID:", orderId);
        // sample test script - json aassertion
        const json = JSON.parse(response.body);

        test("status code is 200", () => {
        expect(response.status).toBe(200);
        });

        test("user ID is present", () => {
        expect(json.data?.user?.id).toBeDefined();
        });

        // sample test script - xml assertion
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(response.body, "application/xml");

        const status = xmlDoc.getElementsByTagName("status")[0]?.textContent;

        test("Status is SUCCESS", () => {
        expect(status).toBe("SUCCESS");
        });
    """

Feature: Validate PDF Response

Scenario: Get PDF and verify content type
  Given url 'https://example.com/api/report.pdf'
  When method GET
  Then status 200
  And match responseHeaders['Content-Type'][0] contains 'application/pdf'
  And match response startsWith '%PDF-'
  * def path = karate.write(response, 'output/report.pdf')
  * print 'PDF saved to:', path