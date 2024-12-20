package org.icsu.wkldid;

import java.util.Map;

import com.azure.security.keyvault.secrets.SecretClient;
import com.azure.security.keyvault.secrets.SecretClientBuilder;
import com.azure.security.keyvault.secrets.models.KeyVaultSecret;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.identity.DefaultAzureCredential;

public class KV {
    public static void main(String[] args) {
        Map<String, String> env = System.getenv();
        String keyVaultUrl = env.get("KEYVAULT_URL");
        String secretName = env.get("KEYVAULT_SECRET_NAME");

        SecretClient secretClient = new SecretClientBuilder()
                .vaultUrl(keyVaultUrl)
                .credential(new DefaultAzureCredentialBuilder().build())
                .buildClient();
        while (true) {
            try {
                KeyVaultSecret secret = secretClient.getSecret(secretName);        
                System.out.println("Successfully got secret: " + secret.getValue());
                Thread.sleep(15000);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }            
    }
}