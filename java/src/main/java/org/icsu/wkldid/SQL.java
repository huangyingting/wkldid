package org.icsu.wkldid;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import com.microsoft.sqlserver.jdbc.SQLServerDataSource;

public class SQL {
    private static SQLServerDataSource ds;
    private static volatile boolean running = true;

    public static void main(String[] args) throws Exception {
        if (!init()) {
            return;
        }

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            running = false;
            System.out.println("Shutting down...");
        }));

        while (running) {
            try {
                run();
                Thread.sleep(15000); // Sleep for 15 seconds
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                System.err.println("Thread was interrupted, Failed to complete operation");
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    public static boolean init() {
        // Retrieve environment variables
        String sqlServerName = System.getenv("SQL_SERVER_FQDN");
        String databaseName = System.getenv("SQL_DATABASE_NAME");

        if (sqlServerName == null || databaseName == null) {
            System.err.println("Error: Environment variables SQL_SERVER_FQDN and SQL_DATABASE_NAME must be set.");
            return false;
        }

        ds = new SQLServerDataSource();
        ds.setServerName(sqlServerName);
        ds.setDatabaseName(databaseName);
        ds.setAuthentication("ActiveDirectoryDefault");

        return true;
    }

    public static void run() {
        String query = "SELECT TOP 1 pc.Name as CategoryName, p.name as ProductName " +
                       "FROM SalesLT.ProductCategory pc " +
                       "JOIN SalesLT.Product p ON pc.productcategoryid = p.productcategoryid;";
        try (Connection connection = ds.getConnection();
             Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {
            if (rs.next()) {
                String categoryName = rs.getString("CategoryName");
                String productName = rs.getString("ProductName");
                System.out.println("Category Name: " + categoryName);
                System.out.println("Product Name: " + productName);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}