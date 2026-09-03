# Azure deployment

This deployment creates a resource group containing Azure Container Registry, a Container Apps managed environment, one Container App, Log Analytics, and workspace-based Application Insights. The app uses a system-assigned managed identity with the `AcrPull` role, so no registry password is stored in the app.

## Prerequisites

- Azure CLI with the Container Apps extension
- Docker logged in to the target Azure subscription
- MongoDB Atlas network access configured for the Container Apps outbound addresses
- Ollama Cloud/API access and a Tavily key when web search is enabled

The existing `.env` file contains credentials. Rotate those credentials before deployment and never commit that file.

## Deploy

From PowerShell at the repository root:

```powershell
az login
az account set --subscription '<subscription-id>'
$env:MONGO_URI = '<mongodb-connection-string>'
$env:OLLAMA_API_KEY = '<ollama-api-key>'
$env:TAVILY_API_KEY = '<tavily-api-key>'
$env:OLLAMA_HOST = 'https://ollama.com'
$env:OLLAMA_MODEL = 'gpt-oss:20b-cloud'

az deployment sub create `
  --location eastus `
  --resource-group rag-rg `
  --template-file infra/main.bicep `
  --parameters infra/main.bicepparam
```

The deployment outputs the registry name, Container App URL, and monitoring resource names.

## Build and deploy the image

The Bicep deployment expects the image to exist in the created registry. Build and push it, then update the Container App revision:

```powershell
$registry = az deployment sub show `
  --name main `
  --query properties.outputs.registryName.value `
  --output tsv

az acr build --registry $registry --image rag-api:latest .

az containerapp update `
  --name (az deployment sub show --name main --query properties.outputs.containerAppName.value --output tsv) `
  --resource-group (az deployment sub show --name main --query properties.outputs.resourceGroupName.value --output tsv) `
  --image "$registry.azurecr.io/rag-api:latest"
```

For a first deployment, create `rag-rg` first, deploy with `deployContainerApp=false` to create the registry and monitoring resources, push the image, and rerun with `deployContainerApp=true` to create/update the app.

Application logs and traces are available in the Container App Log stream and Application Insights. Custom RAG metrics are emitted as OpenTelemetry metrics and can be queried in the Application Insights workspace; there is no Prometheus, Grafana, or Jaeger dependency in Azure.
