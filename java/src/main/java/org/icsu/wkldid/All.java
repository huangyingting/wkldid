package org.icsu.wkldid;

public class All {
    private static volatile boolean running = true;

    public static void main(String[] args) throws Exception {
        if (!KV.init() || !SQL.init()) {
            return;
        }

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            running = false;
            System.out.println("Shutting down...");
        }));

        while (running) {
            try {
                KV.run();
                SQL.run();
                Thread.sleep(15000); // Sleep for 15 seconds
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                System.err.println("Thread was interrupted, Failed to complete operation");
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}