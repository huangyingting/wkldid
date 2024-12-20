output "azure_sql_server_fqdn" {
  value       = module.azure_sql.server_fqdn
  description = "Azure SQL server full qualified domain name"
}

output "azure_sql_database_name" {
  value       = module.azure_sql.database_name
  description = "Azure SQL server database name"
}

output "service_account_namespace" {
  value       = local.namespace
  description = "Namespace of the service account"
}

output "service_account_name" {
  value       = local.serviceaccount
  description = "Name of the service account"
}

output "user_assigned_identity_client_id" {
  value       = module.user_assigned_identity.client_id
  description = "The client ID of the user assigned identity"
}

output "kubectl_commands" {
  value = <<EOF
kubectl create ns ${local.namespace}

cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${module.user_assigned_identity.client_id}
  name: ${local.serviceaccount}
  namespace: ${local.namespace}
EOT

cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wkldid-java
  namespace: ${local.namespace}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${local.serviceaccount}
  containers:
    - image: ghcr.io/huangyingting/wkldid/wkldid-java:latest
      name: wkldid-java
      env:
      - name: KEYVAULT_URL
        value: ${module.azure_keyvault.vault_url}
      - name: KEYVAULT_SECRET_NAME
        value: ${module.azure_keyvault.secret_name}
      - name: SQL_SERVER_FQDN
        value: ${module.azure_sql.server_fqdn}
      - name: SQL_DATABASE_NAME
        value: ${module.azure_sql.database_name}
  nodeSelector:
    kubernetes.io/os: linux
EOT

cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wkldid-java
  namespace: ${local.namespace}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${local.serviceaccount}
  containers:
    - image: ghcr.io/huangyingting/wkldid/wkldid-java:latest
      name: wkldid-java
      command: ["/bin/sh"]
      args: ["-c", "java -cp app.jar org.icsu.wkldid.KV"]
      env:
      - name: KEYVAULT_URL
        value: ${module.azure_keyvault.vault_url}
      - name: KEYVAULT_SECRET_NAME
        value: ${module.azure_keyvault.secret_name}
  nodeSelector:
    kubernetes.io/os: linux
EOT

cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wkldid-java
  namespace: ${local.namespace}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${local.serviceaccount}
  containers:
    - image: ghcr.io/huangyingting/wkldid/wkldid-java:latest
      name: wkldid-java
      command: ["/bin/sh"]
      args: ["-c", "java -cp app.jar org.icsu.wkldid.SQL"]
      env:
      - name: SQL_SERVER_FQDN
        value: ${module.azure_sql.server_fqdn}
      - name: SQL_DATABASE_NAME
        value: ${module.azure_sql.database_name}
  nodeSelector:
    kubernetes.io/os: linux
EOT

kubectl logs wkldid -n ${local.namespace}
EOF

  description = "Kubectl commands"
}
