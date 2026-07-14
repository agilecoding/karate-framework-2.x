## Use alias for sql columns to match api payload keys exactly
#1. Use SQL Aliasing for Single-Line Matching
## instead of --- SELECT FIRST_NAME, LAST_NAME, BIRTH_DT FROM DISABILITY_LEDGER WHERE APP_ID = '123' ---
## use --- SELECT FIRST_NAME AS "firstName", LAST_NAME AS "lastName", BIRTH_DT AS "dob" FROM DISABILITY_LEDGER WHERE APP_ID = '123' ----
## in karate feature file ---
* def rows = dbHelper.query(sqlQuery)
# Deep match the API payload directly against the database row!
And match rows[0] contains payload
## 2. Parameterize and Externalize SQL Queries
##Avoid hardcoding SQL strings inside your scenario files. To keep your features clean and allow SQL queries to be reused or easily updated:
##Store queries in a central JSON, YAML, or helper file (e.g., queries.json or a helper JS function).
##Use a helper function to replace placeholders dynamically.
##Example queries.json: 
{
  "getDisabilityLedger": "SELECT FIRST_NAME AS \"firstName\", LAST_NAME AS \"lastName\" FROM DISABILITY_LEDGER WHERE APPLICATION_ID = '<appId>'"
}
## in karate feature file:
* def queries = read('classpath:tests/db/queries.json')
* def rawQuery = queries.getDisabilityLedger
* def formattedQuery = rawQuery.replaceAll('<appId>', response.applicationId)
* def rows = db2Helper.query(formattedQuery)
And match rows[0] contains payload

## 3. Create a Reusable "DB Validator" Called Feature
## If you have multiple endpoints performing similar validations, package the validation logic into a reusable feature file (e.g., db-validator.feature) and invoke it using karate.call().
###
## db-validator.feature (The Reusable Template):
@ignore
Feature: Reusable DB Verifier
Scenario:
  * def rows = dbHelper.query(query)
  # Verify we got exactly one record
  And match rows == '#[1]'
  # Verify the fields match the expected JSON schema/values passed in
  And match rows[0] contains expected

  ## in main API test feature file:
Given path '/api/disability/apply'
And request payload
When method post
Then status 201

# Define your SQL query matching the payload structure
* def sql = "SELECT FIRST_NAME AS 'firstName', LAST_NAME AS 'lastName' FROM DISABILITY_LEDGER WHERE APPLICATION_ID = '" + response.applicationId + "'"

# Call the validator
* call read('classpath:tests/db/db-validator.feature') { dbHelper: db2Helper, query: #(sql), expected: #(payload) }
  
##4. Handle DB2 Specifics Gracefully
#Case Sensitivity in Column Aliases: DB2 defaults to returning column names in uppercase (e.g., FIRST_NAME). Ensure your DbHelper.java is case-insensitive, or explicitly wrap your SQL aliases in double quotes (e.g., SELECT FIRST_NAME AS "firstName") so DB2 preserves the exact casing needed for JSON matching.
# Data Type Normalization: DB2 often pads CHAR columns with trailing spaces, and represents decimal fields/dates differently than JSON. Ensure your Java DbHelper cleans up these types (e.g., calling .trim() on String results) before returning the list of maps to Karate to avoid false-negative mismatches.


#### DONT DO PRACTICES #####
#1. Do NOT Instantiate the DB Utility in karate-config.js
# A common mistake is instantiating a new database instance inside karate-config.js globally like this:
## example:
// AVOID THIS FOR MULTI-THREADED/PARALLEL RUNS
function fn() {
  var DbHelper = Java.type('tests.db.DbHelper');
  return {
    dbHelper: new DbHelper() 
  };
}

## 2. Implement a Connection Pool in your Java Utility (The Best Approach)
# To optimize performance and let a framework handle the opening/closing of sockets automatically, use a lightweight Java connection pooler like HikariCP inside your DbHelper.java
## JAVA CODE:
package tests.db;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;

public class DbHelper {
    private static HikariDataSource dataSource;
    private final JdbcTemplate jdbc;

    // Use a static block so the pool initializes ONCE globally for all parallel tests
    static {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:db2://your-host:50000/YOURDB");
        config.setUsername("user");
        config.setPassword("pass");
        config.setMaximumPoolSize(10); // Match this to your Karate parallel thread count
        config.setMinimumIdle(2);
        
        dataSource = new HikariDataSource(config);
    }

    public DbHelper() {
        this.jdbc = new JdbcTemplate(dataSource);
    }

    public List<Map<String, Object>> query(String sql) {
        // JdbcTemplate automatically borrows and CLOSES/RETURNS the connection to the pool!
        return jdbc.queryForList(sql);
    }
}

## 3. If Using Standard JDBC, Use a try-with-resources Block
## If you are writing pure JDBC rather than using a connection pool, you must explicitly close the Connection, Statement, and ResultSet objects. The most performant way to ensure they close automatically (even if the SQL query fails) is via Java's try-with-resources:
public List<Map<String, Object>> query(String sql) {
    List<Map<String, Object>> rows = new ArrayList<>();
    
    // Automatically closes connection, statement, and resultSet when block exits
    try (Connection conn = DriverManager.getConnection(url, user, pass);
         PreparedStatement stmt = conn.prepareStatement(sql);
         ResultSet rs = stmt.executeQuery()) {
         
         // Logic to parse rs into List<Map>...
         
    } catch (SQLException e) {
        throw new RuntimeException(e);
    }
    return rows;
}

## 4. Performance Tuning inside Karate Feature Files
#To make your feature files fast and lightweight when handling DB validations:
# Use karate.callSingle() for DB Data Setup: If you need to seed or wipe the database before a test suite begins, do it inside karate-config.js wrapped in karate.callSingle(). This guarantees the setup script runs exactly once per test suite execution, rather than hitting the DB before every scenario.
# Limit your SQL Selects: Don't do SELECT * FROM TABLE. Only alias the exact fields you want to match against your API payload (e.g., SELECT FIRST_NAME AS "firstName"). This limits the data payload sent across the network from DB2 to your test JVM.
