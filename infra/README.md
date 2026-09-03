# Azure deployment

This deployment creates Azure Container Registry, a Container Apps managed environment, one Container App, Log Analytics, and workspace-based Application Insights in the `rag-rg` resource group. The app uses a system-assigned managed identity with the `AcrPull` role, so no registry password is stored in the app.

## Prerequisites

- Azure CLI with the Container Apps extension
- Docker Desktop running for local image builds
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

az group create --name rag-rg --location eastus

az deployment group create `
  --resource-group rag-rg `
  --name rag-bootstrap `
  --template-file infra/main.bicep `
  --parameters infra/main.bicepparam deployContainerApp=false
```

The bootstrap deployment creates the registry and monitoring resources before an image exists.

## Build and deploy the image

The Bicep deployment expects the image to exist in the created registry. Build and push it, then update the Container App revision:

```powershell
$registry = az deployment group show `
  --resource-group rag-rg `
  --name rag-bootstrap `
  --query properties.outputs.registryName.value `
  --output tsv

az acr login --name $registry
docker build --tag "$registry.azurecr.io/rag-api:latest" .
docker push "$registry.azurecr.io/rag-api:latest"

az deployment group create `
  --resource-group rag-rg `
  --name rag-deploy `
  --template-file infra/main.bicep `
  --parameters infra/main.bicepparam imageTag=latest deployContainerApp=true
```

The GitHub Actions workflow performs this same bootstrap, runner-side Docker build/push, and final deployment automatically. It uses the commit SHA as the image tag. ACR Tasks are not used because they may be disabled by subscription policy.

Application logs and traces are available in the Container App Log stream and Application Insights. Custom RAG metrics are emitted as OpenTelemetry metrics and can be queried in the Application Insights workspace; there is no Prometheus, Grafana, or Jaeger dependency in Azure.
