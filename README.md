# Azure Workload Identity E2E Demo
## Overview

This repository demonstrates Azure Workload Identity end-to-end with:

- GitHub Actions deploying Terraform to Azure using OIDC (no client secret), plus Java image build
- AKS pods accessing Azure Key Vault and Azure SQL using a user-assigned managed identity (no secrets in pods)

Use the guided sections below to understand the concepts, how this repo is organized, and how the included workflows operate. All existing step-by-step commands are retained further down.

## What is Azure Workload Identity?

Workload identity lets applications (workloads) authenticate to clouds without storing credentials. In Azure, this is enabled by federated identity credentials that trust an external identity provider’s OIDC tokens (for example, AKS or GitHub Actions) to obtain Microsoft Entra ID tokens for a managed identity or service principal.

Key ideas:

- OpenID Connect (OIDC) federation: Azure validates a signed token from an issuer (e.g., AKS’s OIDC endpoint or GitHub’s OIDC provider) and, if claims match a configured subject, issues an access token for the target identity.
- Managed identity: A first-class identity in Microsoft Entra ID (user-assigned in this repo) used by workloads to call Azure services (Key Vault, SQL, etc.).
- No secrets: Pods and CI jobs don’t need to store client secrets; they exchange short‑lived tokens securely.

### How AKS Workload Identity works (in this repo)

1. AKS cluster is created with OIDC issuer and workload identity enabled.
2. A user-assigned managed identity (UAMI) is created in Azure.
3. A federated identity credential is added to that UAMI, trusting the AKS OIDC issuer and a specific Kubernetes ServiceAccount subject (system:serviceaccount:<namespace>:<name>).
4. A ServiceAccount is annotated with the UAMI client ID and the pod is labeled to opt-in to workload identity.
5. The Azure SDK in the container uses DefaultAzureCredential to read the projected OIDC token and exchanges it for an Azure AD token representing the UAMI.
6. With appropriate RBAC/roles, the pod calls Key Vault, SQL, etc., without any stored secrets.

In the Java sample:

- `KV` reads `KEYVAULT_URL` and `KEYVAULT_SECRET_NAME`, authenticates via DefaultAzureCredential, and retrieves a secret from Key Vault.
- `SQL` uses Microsoft Entra (ActiveDirectoryDefault) authentication to connect to Azure SQL. Database permissions are granted to the UAMI mapped as an external user in SQL.

### How GitHub Actions workload identity works (in this repo)

1. The workflow requests an OIDC token by setting `permissions: id-token: write`.
2. `azure/login` exchanges the OIDC token for a Microsoft Entra token using a federated credential configured for the GitHub repository/environment.
3. Terraform authenticates via OIDC (`ARM_USE_OIDC=true`) to provision Azure resources without any client secret.

## Repository structure

- `java/` – Simple Java apps demonstrating access via workload identity.
  - Uses Gradle. Dockerfile builds `wkldid-java` image.
  - Entrypoints:
    - `org.icsu.wkldid.KV` – reads a secret from Key Vault
    - `org.icsu.wkldid.SQL` – queries sample data from Azure SQL with AAD auth
    - `org.icsu.wkldid.All` – runs both on a loop
  - Expected env vars when running in AKS:
    - `KEYVAULT_URL`, `KEYVAULT_SECRET_NAME`
    - `SQL_SERVER_FQDN`, `SQL_DATABASE_NAME`

- `terraform/` – Infrastructure as code.
  - `bootstrap/` – One-time state and identity setup
    - Resource group for shared infra
    - Storage account + container for Terraform state
    - Managed identity + (via modules) federated credential for GitHub OIDC
  - `infra/` – Main environment deployment driven by CI
  - `modules/`:
    - `aks/` – AKS with OIDC issuer and workload identity enabled
    - `azure_keyvault/` – Key Vault instance
    - `azure_sql/` – Azure SQL Server/DB configuration
    - `user_assigned_identity/` – UAMI used by workloads
    - `federated_credential/` – Federated identity credential bindings
    - `role_assignment/`, `entra_id_role_assignment/` – RBAC assignments
    - `resource_group/` – Resource group creation
    - `github_environment/` – GitHub environment wiring for OIDC
    - `terraform_azurerm_backend/` – Remote backend wiring

## CI/CD workflows (.github/workflows)

This repo includes four GitHub Actions workflows. Secrets expected (set at repo/org level): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TFSTATE_RESOURCE_GROUP_NAME`, `TFSTATE_STORAGE_ACCOUNT_NAME`, `TFSTATE_CONTAINER_NAME`, `RESOURCE_NAME`, `LOCATION`.

1) Build and Push Java Docker Image – `build-java.yml`

- Triggers: on push/pull_request changing files under `java/**` on `main`.
- Steps: checkout, setup Java 21, Gradle build, Docker login to GHCR, build and push `ghcr.io/<owner>/<repo>/wkldid-java:latest`.
- Permissions: `packages: write` to push the image.

2) Deploy Infrastructure – `deploy-infra.yml`

- Triggers: on pull requests touching `terraform/**`, and manual `workflow_dispatch` with `environment` input (`dev|staging|prod`).
- OIDC: `permissions: id-token: write` and `ARM_USE_OIDC=true`; uses `azure/login@v2` to exchange the GitHub OIDC token.
- Steps: fmt, init (remote backend from secrets), validate, plan/apply with variables (`resource_name`, `location`, `environment`, `outbound_ip`).
- Reporting: comments on PR and opens an issue summarizing the apply outcome and logs.

3) Destroy Infrastructure – `destroy-infra.yml`

- Trigger: manual `workflow_dispatch` with `environment` input.
- OIDC: same as deploy; runs `terraform destroy` with the same variables; opens an issue with logs; fails the job if destroy fails.

---

## Manual Deployment

### Integrating AKS with Azure Workload Identity
```bash
# Azure CLI
az login
# Azure Kubernetes Service (AKS)
RESOURCE_GROUP="AKSSEA"
LOCATION="southeastasia"
CLUSTER_NAME="akssea"
```

```bash
# Azure workload identity
SERVICE_ACCOUNT_NAMESPACE="wkldid"
SERVICE_ACCOUNT_NAME="sawkldid"
SUBSCRIPTION="$(az account show --query id --output tsv)"
USER_ASSIGNED_IDENTITY_NAME="wkldid"
FEDERATED_IDENTITY_CREDENTIAL_NAME="fedcred"
```

```bash
# Create resource group and AKS
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"
az aks create --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys --location "${LOCATION}" --dns-name-prefix "${CLUSTER_NAME}" --nodepool-name syspool --node-count 1 --node-vm-size Standard_B2s

AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"

az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"

USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"

USER_ASSIGNED_OBJ_ID=$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'principalId' -o tsv)

az aks get-credentials --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --admin

kubectl create ns "${SERVICE_ACCOUNT_NAMESPACE}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
EOF

az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange
```

```json
{
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "id": "/subscriptions/c6cfb3cd-9c53-471e-b519-dd4cfa647d88/resourcegroups/AKSSEA/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mid/federatedIdentityCredentials/fedid",
  "issuer": "https://southeastasia.oic.prod-aks.azure.com/7b800a60-9ab3-46bf-a60f-a96d0c7dc2a9/979860b4-7221-4030-89c0-0f0ab3d58fc4/",
  "name": "fedid",
  "resourceGroup": "AKSSEA",
  "subject": "system:serviceaccount:wkldid:sawkldid",
  "systemData": null,
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials"
}
```
### Accessing Azure Key Vault with Azure Workload Identity
```bash
# Azure key vault
KEYVAULT_RESOURCE_GROUP="KV"
KEYVAULT_NAME="wkldidkv"
KEYVAULT_SECRET_NAME="secret"

# Create key vault and application to use key vault
az group create --name "${KEYVAULT_RESOURCE_GROUP}" --location "${LOCATION}"

az keyvault create \
    --name "${KEYVAULT_NAME}" \
    --resource-group "${KEYVAULT_RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --enable-purge-protection \
    --enable-rbac-authorization

KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "${KEYVAULT_RESOURCE_GROUP}" --name "${KEYVAULT_NAME}" --query id --output tsv)

az role assignment create --assignee "\<user-email\>" --role "Key Vault Secrets Officer" --scope "${KEYVAULT_RESOURCE_ID}"

az keyvault secret set \
    --vault-name "${KEYVAULT_NAME}" \
    --name "${KEYVAULT_SECRET_NAME}" \
    --value "Azure Workload Identity Secret"

IDENTITY_PRINCIPAL_ID=$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)

az role assignment create --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" --role "Key Vault Secrets User" --scope "${KEYVAULT_RESOURCE_ID}" --assignee-principal-type ServicePrincipal

KEYVAULT_URL="$(az keyvault show --resource-group ${KEYVAULT_RESOURCE_GROUP} --name ${KEYVAULT_NAME} --query properties.vaultUri --output tsv)"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wkldid-java
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: ghcr.io/huangyingting/wkldid/wkldid-java:latest
      name: wkldid-java
      command: ["/bin/sh"]
      args: ["-c", "java -cp app.jar org.icsu.wkldid.KV"]
      env:
      - name: KEYVAULT_URL
        value: ${KEYVAULT_URL}
      - name: KEYVAULT_SECRET_NAME
        value: ${KEYVAULT_SECRET_NAME}
  nodeSelector:
    kubernetes.io/os: linux
EOF

kubectl logs wkldid-java -n "${SERVICE_ACCOUNT_NAMESPACE}"
```

### Accessing Azure SQL Database with Azure Workload Identity

#### Create Azure SQL Database
```bash
SQL_RESOURCE_GROUP="SQL"
SQL_SERVER_NAME="sqlwkldid"
SQL_DATABASE_NAME="wkldid"
SQL_USERNAME="azadmin"
SQL_PASSWORD="P@ssw0rd"

# Specify appropriate IP address values for your environment
# to limit access to the SQL Database server
MY_IP=$(curl icanhazip.com)

# Get user info for adding admin user
SIGNED_IN_USER_OBJ_ID=$(az ad signed-in-user show -o tsv --query id)
SIGNED_IN_USER_DSP_NAME=$(az ad signed-in-user show -o tsv --query userPrincipalName)

# Create the SQL Server Instance
az sql server create \
  --name $SQL_SERVER_NAME \
  --resource-group $SQL_RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $SQL_USERNAME \
  --admin-password $SQL_PASSWORD

# Allow your ip through the server firewall
az sql server firewall-rule create \
  --resource-group $SQL_RESOURCE_GROUP \
  --server $SQL_SERVER_NAME \
  -n AllowIp \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP

# Allow azure services through the server firewall
az sql server firewall-rule create \
  --resource-group $SQL_RESOURCE_GROUP \
  --server $SQL_SERVER_NAME \
  -n AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Add signed-in user as Microsoft Entra admin
az sql server ad-admin create \
--resource-group $SQL_RESOURCE_GROUP \
--server-name $SQL_SERVER_NAME \
--display-name $SIGNED_IN_USER_DSP_NAME \
--object-id $SIGNED_IN_USER_OBJ_ID

# Enable Microsoft Entra-only authentication
az sql server ad-only-auth enable \
--resource-group $SQL_RESOURCE_GROUP \
--name $SQL_SERVER_NAME

# Create the Database
az sql db create --resource-group $SQL_RESOURCE_GROUP --server $SQL_SERVER_NAME \
--name $SQL_DATABASE_NAME \
--sample-name AdventureWorksLT \
--edition GeneralPurpose \
--compute-model Serverless \
--family Gen5 \
--min-capacity 0.5 \
--capacity 1 \
--backup-storage-redundancy Local
```

#### Assign db reader role to workload identity in Azure SQL Database
```bash
# Generate T-SQL to create external user and grant db_datareader
echo "CREATE USER [${USER_ASSIGNED_IDENTITY_NAME}] FROM EXTERNAL PROVIDER WITH OBJECT_ID='${USER_ASSIGNED_OBJ_ID}'" > create_user.sql
echo "GO" >> create_user.sql
echo "ALTER ROLE db_datareader ADD MEMBER [${USER_ASSIGNED_IDENTITY_NAME}]" >> create_user.sql
echo "GO" >> create_user.sql

# Login to the SQL DB via interactive login
sqlcmd --authentication-method=ActiveDirectoryAzCli -S $SQL_SERVER_FQDN -d $SQL_DATABASE_NAME --i create_user.sql

rm create_user.sql
```

#### Access Azure SQL Database from AKS
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wkldid-java
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: ghcr.io/huangyingting/wkldid/wkldid-java:latest
      name: wkldid-java
      env:
      - name: SQL_SERVER_FQDN
        value: ${SQL_SERVER_FQDN}
      - name: SQL_DATABASE_NAME
        value: ${SQL_DATABASE_NAME}
  nodeSelector:
    kubernetes.io/os: linux
EOF
```

## Terraform Deployment
Terraform deployment is available in [terraform](terraform) folder.
Steps to deploy:
```bash
cd terraform/bootstrap
terraform init
terraform apply
```
The bootstrap directory contains Terraform configuration files that set up the following resources:
- A resource group to hold related resources
- A managed identity that allows GitHub Actions workflows to access resources in Azure
- An Azure storage account to store the Terraform state file

Further resources will be deployed using the `deploy-infra.yml` workflow.

## Keycloak
```bash
export CLIENTNAME=
export SECRET=

KEYCLOAK_RESPONSE=$(curl --request POST "https://fqdn/realms/master/protocol/openid-connect/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=$CLIENTNAME" \
  --data-urlencode "client_secret=$SECRET" \
  --data-urlencode "scope=openid" \
  --data-urlencode "grant_type=client_credentials")
```

## Debugging
```bash
kubectl expose pod mitmproxy --port 8080 -n ${SERVICE_ACCOUNT_NAMESPACE}
kubectl run -n ${SERVICE_ACCOUNT_NAMESPACE} -it --rm --restart=Never --image mitmproxy/mitmproxy mitmproxy -- bash
```

```bash
OVERRIDES=$(cat <<EOF
    {
        "metadata": {"labels":{"azure.workload.identity/use": "true"}},
        "spec": {"serviceAccountName": "${SERVICE_ACCOUNT_NAME}"}
    }
EOF
)
kubectl run -n ${SERVICE_ACCOUNT_NAMESPACE} -it --rm --restart=Never \
    --image=ubuntu:22.04 azure-cli \
    --overrides "$OVERRIDES" \
    -- bash -c \
    '
    apt update
    apt install curl -y
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    curl --proxy http://mitmproxy:8080 http://mitm.it/cert/pem -o /usr/local/share/ca-certificates/mitmproxy.crt
    update-ca-certificates
    export https_proxy=http://mitmproxy:8080
    cp /etc/ssl/certs/ca-certificates.crt /opt/az/lib/python3.12/site-packages/certifi/cacert.pem
    az login --federated-token "$(cat $AZURE_FEDERATED_TOKEN_FILE)" --service-principal -u $AZURE_CLIENT_ID -t $AZURE_TENANT_ID
    exec bash
    '
```


```text
[04:31:58.359] HTTP(S) proxy listening at *:8080.
[04:32:06.773][10.244.0.26:44104] client connect
[04:32:06.785][10.244.0.26:44104] server connect raw.githubusercontent.com:443 (185.199.109.133:443)
10.244.0.26:44104: HEAD https://raw.githubusercontent.com/
                << 301 Moved Permanently 0b
[04:32:06.831][10.244.0.26:44104] client disconnect
[04:32:06.832][10.244.0.26:44104] server disconnect raw.githubusercontent.com:443 (185.199.109.133:443)
[04:32:06.834][10.244.0.26:44108] client connect
[04:32:06.840][10.244.0.26:44108] server connect raw.githubusercontent.com:443 (185.199.109.133:443)
10.244.0.26:44108: GET https://raw.githubusercontent.com/Azure/azure-cli/main/src/azure-cli-core/setup…
                << 200 OK 1.3k
[04:32:06.868][10.244.0.26:44108] client disconnect
[04:32:06.869][10.244.0.26:44108] server disconnect raw.githubusercontent.com:443 (185.199.109.133:443)
[04:32:06.872][10.244.0.26:44118] client connect
[04:32:06.878][10.244.0.26:44118] server connect raw.githubusercontent.com:443 (185.199.111.133:443)
10.244.0.26:44118: GET https://raw.githubusercontent.com/Azure/azure-cli/main/src/azure-cli-telemetry/…
                << 200 OK 677b
[04:32:06.899][10.244.0.26:44118] client disconnect
[04:32:06.901][10.244.0.26:44118] server disconnect raw.githubusercontent.com:443 (185.199.111.133:443)
[04:32:09.126][10.244.0.26:44124] client connect
[04:32:09.203][10.244.0.26:44124] server connect login.microsoftonline.com:443 (20.190.144.160:443)
10.244.0.26:44124: GET https://login.microsoftonline.com/cda45820-586e-4720-95ae-98bf6b86d670/v2.0/.we…
                << 200 OK 1.7k
10.244.0.26:44124: POST https://login.microsoftonline.com/cda45820-586e-4720-95ae-98bf6b86d670/oauth2/v…
                << 200 OK 1.7k
[04:32:11.005][10.244.0.26:44132] client connect
[04:32:11.051][10.244.0.26:44132] server connect management.azure.com:443 (4.150.240.10:443)
10.244.0.26:44132: GET https://management.azure.com/subscriptions?api-version=2022-12-01
                << 200 OK 444b
[04:32:11.268][10.244.0.26:44132] client disconnect
[04:32:11.270][10.244.0.26:44132] server disconnect management.azure.com:443 (4.150.240.10:443)
[04:32:11.359][10.244.0.26:44124] client disconnect
[04:32:11.361][10.244.0.26:44124] server disconnect login.microsoftonline.com:443 (20.190.144.160:443)
[04:32:11.483][10.244.0.26:44140] client connect
[04:32:11.603][10.244.0.26:44140] server connect dc.services.visualstudio.com:443 (20.213.196.212:443)
10.244.0.26:44140: POST https://dc.services.visualstudio.com/v2/track
                << 200 OK 62b
[04:32:12.113][10.244.0.26:44140] server disconnect dc.services.visualstudio.com:443 (20.213.196.212:443)
[04:32:12.114][10.244.0.26:44140] client disconnect

```

```bash
AZURE_TENANT_ID=cda45820-586e-4720-95ae-98bf6b86d670
AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/azure-identity-token
AZURE_AUTHORITY_HOST=https://login.microsoftonline.com/
AZURE_CLIENT_ID=6eb42820-8a10-4c05-ac5b-1b083f333666
```

```bash
https://southeastasia.oic.prod-aks.azure.com/cda45820-586e-4720-95ae-98bf6b86d670/f6cfcb74-f63c-4fa3-9cd8-24ccd8958c68/.well-known/openid-configuration
```

```json
{
  "issuer": "https://southeastasia.oic.prod-aks.azure.com/cda45820-586e-4720-95ae-98bf6b86d670/f6cfcb74-f63c-4fa3-9cd8-24ccd8958c68/",
  "jwks_uri": "https://southeastasia.oic.prod-aks.azure.com/cda45820-586e-4720-95ae-98bf6b86d670/f6cfcb74-f63c-4fa3-9cd8-24ccd8958c68/openid/v1/jwks",
  "response_types_supported": [
    "id_token"
  ],
  "subject_types_supported": [
    "public"
  ],
  "id_token_signing_alg_values_supported": [
    "RS256"
  ]
}
```
```bash
https://southeastasia.oic.prod-aks.azure.com/cda45820-586e-4720-95ae-98bf6b86d670/f6cfcb74-f63c-4fa3-9cd8-24ccd8958c68/openid/v1/
```

```json
{
  "keys": [
    {
      "use": "sig",
      "kty": "RSA",
      "kid": "7gwE9ShhS3dml7V8Csg26saXyN8u-GKAPTxO0ZPbnos",
      "alg": "RS256",
      "n": "2WEhKYvzA22zBWO9ZIPaxnijA_IWncgbQHSDRbDiNvhjP8tGrBJK4wZIrilaTMQ6mzslPmiURXqgrducTTjr3Hkpcf5dxIpDVWYnyToJjRQOsy0ShxOizk8866TnXaAzzXIcFHMEkvPDqshUhgcbVR2W0iv7iNaCe1Whf497aIAtbKhrktyEsDqEv2RM6F1LlzYD-BzrjcwCFrrIevIDK7LPgAotaN6QXjPYygax3RKx5cNOS0VJv0hKLUpAswnn-LOcjeHW96AQxEfbZ1csz0tycJHKQyyhGQfbKydMpWVzXMmWMrheNPx_ehQWOrBwTX4ZEG5D88yjKO6FQR2ngwDxAYlNW3nwRG5lrQtgAit1xyNK4O8PmN7AJ3dQZ7KgYh7I8nc0zXANogi5T_U_1j8x5Wn9NpHzo-zgEuhv7LSUDhsiI57OTpftvSRRp5RZp8cW31mo25W8q0tLwwwsiOYbY062zosgccZQXwKaw4qps5S3BQjSOLo5g33730vLG16v8F5NopG8VdhoVbq7yPfeltScXPSk30Z5TX78MxFRTmh7gc_-79EVPGwckyeX09m6kd2ah5QuZBDXPctU7rGKbXvHrvHeJ3D0WvpNAs_CvPM4ShbyPbtNP5HXg7JUk-HJO3VCSZaaIvwUdSqgpA4e2y57WSyV921W_eeGvj8",
      "e": "AQAB"
    },
    {
      "use": "sig",
      "kty": "RSA",
      "kid": "S6CkIBcFtsNYUg1sdVDyOoeoBt7rDA3V2c4nXJ8_ucQ",
      "alg": "RS256",
      "n": "yPfvqgeaEt9387XQd68RBI0AFZRAbca3FLLyXJrNEPFzLFJTGfwOizXv_7r0xdKnCyuiMHSvPH8b1zoppEbv_a769F2nJB4m0kmwpuSKSkaGHon2x9DEZxkm4_PxapyrP5vm-AUX3NuLQU6gYOLdmYLAfmWxjpkWAsRZXz9HJXbu3_Y5a26PeDcUy3COLfbruJs6Sl6nI-IK_PXtf8m_LxCN5PZXrr6Q_4_SxkfUTSu_k5hvULEYY5gztScnyMD-zFp2nO48dEq9vRS2kvgabWm_sT23Z7BnwQCQetK7pIJNyRgcW8iNNXAVdyX2Td1BLFpzGJqBo4XrOtg4dm6mNkTVueNgqog_nmd6CT7mfrcQ59l5p_dRxIuP4yVDGX0fgl15h6WHiGhyeWXwY3KwiO-mgcfEUfLAJxr4zsZ8oE8H5HLUCjAEvSGfdZFUH5RZwhc_WcQw2xMpfP51JMCB2eFHMZa0aNR0jgh20jl15j3qSiG0nl1E5ZauZ9TQKvrN-IFOfdsKjSeKV7oVA_LxqEbLc0y0zcOsIpowel78KbxLmG9i0dRKaOITOESzih87uPvVmlpxclwMEhi8ZGFQc0BGHZwOZSbHgWupyldhuJky1GA5n9zYbYa7NBFSrAUOiXP-cqm4CGFArNf1Nh40RlQ8CmCVAplrTNYghmtC5gs",
      "e": "AQAB"
    }
  ]
}
```

```json
{
  "aud": [
    "api://AzureADTokenExchange"
  ],
  "exp": 1734755019,
  "iat": 1734751419,
  "iss": "https://southeastasia.oic.prod-aks.azure.com/cda45820-586e-4720-95ae-98bf6b86d670/f6cfcb74-f63c-4fa3-9cd8-24ccd8958c68/",
  "jti": "6e0d4d77-15ef-4b3e-aee1-2584ce138345",
  "kubernetes.io": {
    "namespace": "wkldid",
    "node": {
      "name": "aks-syspool-10485676-vmss000000",
      "uid": "57a2ac64-7286-48f4-9d84-d389a0ea039a"
    },
    "pod": {
      "name": "azure-cli",
      "uid": "0241cb78-9a08-43d6-9f47-aaee6f152687"
    },
    "serviceaccount": {
      "name": "sawkldiddev5861",
      "uid": "fd317523-e86a-4601-af92-979938702fdd"
    }
  },
  "nbf": 1734751419,
  "sub": "system:serviceaccount:wkldid:sawkldiddev5861"
}
```


## References:
[Identity in the cloud](https://blog.identitydigest.com/)

[Accessing Azure SQL DB via Workload Identity and Managed Identity
](https://azureglobalblackbelts.com/2021/09/21/workload-identity-azuresql-example.html)

[Connect using Microsoft Entra authentication
](https://learn.microsoft.com/en-us/sql/connect/jdbc/connecting-using-azure-active-directory-authentication)

[Using Federated Identities in Azure AKS
](https://stvdilln.medium.com/using-federated-identities-in-azure-aks-a440feb4a1ce)

[Connect your Kubernetes application to your database without any credentials (and securely)](https://alexisplantin.fr/workload-identity-federation/)

[Third case: Access token request with a federated credential
](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#third-case-access-token-request-with-a-federated-credential)