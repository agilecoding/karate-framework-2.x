package utils;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Generic JDBC helper shared by both Postgres and DB2 validation tests - one class,
 * parameterized by JDBC URL/credentials, avoids duplicating query/mapping logic per vendor.
 * Requires the matching driver on the classpath (postgresql / com.ibm.db2:jcc, see pom.xml).
 *
 *   * def DbHelper = Java.type('utils.DbHelper')
 *   * def pg = new DbHelper(db.postgres.url, db.postgres.user, db.postgres.password)
 *   * def rows = pg.query("SELECT * FROM eligibility WHERE ssn = '123456788'")
 */
public class DbHelper {

    private final String url;
    private final String user;
    private final String password;

    public DbHelper(String url, String user, String password) {
        this.url = url;
        this.user = user;
        this.password = password;
    }

    public List<Map<String, Object>> query(String sql) {
        List<Map<String, Object>> rows = new ArrayList<>();
        try (Connection conn = DriverManager.getConnection(url, user, password);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            ResultSetMetaData meta = rs.getMetaData();
            int cols = meta.getColumnCount();
            while (rs.next()) {
                Map<String, Object> row = new LinkedHashMap<>();
                for (int i = 1; i <= cols; i++) {
                    row.put(meta.getColumnLabel(i), rs.getObject(i));
                }
                rows.add(row);
            }
        } catch (SQLException e) {
            throw new RuntimeException("DB query failed against " + url + ": " + e.getMessage(), e);
        }
        return rows;
    }

    public int update(String sql) {
        try (Connection conn = DriverManager.getConnection(url, user, password);
             Statement stmt = conn.createStatement()) {
            return stmt.executeUpdate(sql);
        } catch (SQLException e) {
            throw new RuntimeException("DB update failed against " + url + ": " + e.getMessage(), e);
        }
    }
}
