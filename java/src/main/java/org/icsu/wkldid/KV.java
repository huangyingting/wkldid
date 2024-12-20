package org.icsu.wkldid;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.security.keyvault.secrets.SecretClient;
import com.azure.security.keyvault.secrets.SecretClientBuilder;
import com.azure.security.keyvault.secrets.models.KeyVaultSecret;

import java.util.Map;

public class KV {
    private static SecretClient secretClient;
    private static String secretName;
    private static volatile boolean running = true;

    public static void main(String[] args) {
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
        Map<String, String> env = System.getenv();
        String keyVaultUrl = env.get("KEYVAULT_URL");
        secretName = env.get("KEYVAULT_SECRET_NAME");

        if (keyVaultUrl == null || secretName == null) {
            System.err.println("Error: Environment variables KEYVAULT_URL or KEYVAULT_SECRET_NAME is missing.");
            return false;
        }

        secretClient = new SecretClientBuilder()
                .vaultUrl(keyVaultUrl)
                .credential(new DefaultAzureCredentialBuilder().build())
                .buildClient();

        return true;
    }

    public static void run() {
        try {
            KeyVaultSecret secret = secretClient.getSecret(secretName);
            System.out.println("Secret: " + secret.getValue());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}