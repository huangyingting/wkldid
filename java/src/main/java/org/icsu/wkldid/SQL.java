package org.icsu.wkldid;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import com.microsoft.sqlserver.jdbc.SQLServerDataSource;

public class SQL {
    public static void main(String[] args) throws Exception {    
        // Retrieve environment variables
        String sqlServerName = System.getenv("SQL_SERVER_FQDN");
        String databaseName = System.getenv("SQL_DATABASE_NAME");

        if (sqlServerName == null || databaseName == null) {
            System.err.println("Environment variables SQL_SERVER_FQDN and SQL_DATABASE_NAME must be set.");
            return;
        }

        SQLServerDataSource ds = new SQLServerDataSource();
        ds.setServerName(sqlServerName); 
        ds.setDatabaseName(databaseName);
        ds.setAuthentication("ActiveDirectoryDefault");

        try (Connection connection = ds.getConnection()) {
            while (true) {
                try (Statement stmt = connection.createStatement();
                     ResultSet rs = stmt.executeQuery("SELECT SUSER_SNAME()")) {
                    if (rs.next()) {
                        System.out.println("You have successfully logged on as: " + rs.getString(1));
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }

                // Sleep for 15 seconds
                Thread.sleep(15000);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}