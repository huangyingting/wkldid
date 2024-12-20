## Using Azure Workload Identity with Azure Services

### Integrating AKS with Azure Workload Identity
```bash
# Azure CLI
az login
# Azure kubernetes service
RESOURCE_GROUP="AKSSEA"
LOCATION="southeastasia"
CLUSTER_NAME="akssea"
```

```bash
# Azure workload identity
SERVICE_ACCOUNT_NAMESPACE="wlid"
SERVICE_ACCOUNT_NAME="wlidsa"
SUBSCRIPTION="$(az account show --query id --output tsv)"
USER_ASSIGNED_IDENTITY_NAME="mid"
FEDERATED_IDENTITY_CREDENTIAL_NAME="fedid"
```

```bash
# Create resource group and aks
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
  "subject": "system:serviceaccount:wlid:wlidsa",
  "systemData": null,
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials"
}
```
### Accessing Azure Key Vault with Azure Workload Identity
```bash
# Azure key vault
KEYVAULT_RESOURCE_GROUP="KV"
KEYVAULT_NAME="wlidkv"
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
  name: wlid-java
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: ghcr.io/huangyingting/wlid/wlid-java:latest
      name: wlid-java
      command: ["/bin/sh"]
      args: ["-c", "java -cp app.jar org.icsu.wlid.KV"]
      env:
      - name: KEYVAULT_URL
        value: ${KEYVAULT_URL}
      - name: KEYVAULT_SECRET_NAME
        value: ${KEYVAULT_SECRET_NAME}
  nodeSelector:
    kubernetes.io/os: linux
EOF

kubectl logs wlid -n "${SERVICE_ACCOUNT_NAMESPACE}"
```

### Accessing Azure SQL Database with Azure Workload Identity

#### Create Azure SQL Database
```bash
SQL_RESOURCE_GROUP="SQL"
SQL_SERVER_NAME="wlid"
SQL_DATABASE_NAME="wlid"
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


# Add myself as admin user
az sql server ad-admin create \
--resource-group $SQL_RESOURCE_GROUP \
--server-name $SQL_SERVER_NAME \
--display-name $SIGNED_IN_USER_DSP_NAME \
--object-id $SIGNED_IN_USER_OBJ_ID

# Enable Azure AD only authentication
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
# Get the server FQDN
SQL_SERVER_FQDN=$(az sql server show -g $SQL_RESOURCE_GROUP -n $SQL_SERVER_NAME -o tsv --query fullyQualifiedDomainName)

# Generate the user creation command
# Copy the output of the following to run against your SQL Server after logged in
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
  name: wlid-java
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: ghcr.io/huangyingting/wlid/wlid-java:latest
      name: wlid-java
      env:
      - name: SQL_SERVER_FQDN
        value: ${SQL_SERVER_FQDN}
      - name: SQL_DATABASE_NAME
        value: ${SQL_DATABASE_NAME}
  nodeSelector:
    kubernetes.io/os: linux
EOF
```
### Terraform deployment
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

### Reference:
[Accessing Azure SQL DB via Workload Identity and Managed Identity
](https://azureglobalblackbelts.com/2021/09/21/workload-identity-azuresql-example.html)

[Connect using Microsoft Entra authentication
](https://learn.microsoft.com/en-us/sql/connect/jdbc/connecting-using-azure-active-directory-authentication)
