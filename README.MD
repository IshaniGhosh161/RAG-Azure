#### Create Virtual Environment
python -m venv .venv

#### Activate the Virtual environment
.venv\Scripts\activate

#### Import required library
For a faster Windows install, install the CPU-only Torch wheel first and let pip reuse its local download cache:

```powershell
python -m pip install --upgrade pip
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
python -m pip install -r requirements.txt
python -m pip install -r requirements-dev.txt
```

The reranker requires `torch` and `sentence-transformers`; those are the main reason the first installation is large. Do not use `--no-cache-dir` for local `.venv` setup. It saves disk space but makes repeated installs download everything again.

#### Run FastAPI app first
python -m uvicorn backend.api:app --host 0.0.0.0 --port 5000

#### Create or rebuild the FAISS index
python indexing/create_index.py

#### Run API tests (API must be running)
pytest tests

Logs are written to `log/app.log` by default. Set `LOG_LEVEL` or `LOG_FILE` to override the logging configuration. Azure deployments send container logs, traces, requests, dependencies, and custom RAG metrics to Azure Monitor, Log Analytics, and Application Insights.

#### Run with Docker Compose
docker compose up --build

The browser frontend and FastAPI API are available at `http://localhost:5000`.
Interactive API documentation is available at `http://localhost:5000/docs`.
Set your MongoDB Atlas connection string as `MONGO_URI` in `.env`, along with `OLLAMA_HOST`, `OLLAMA_API_KEY`, and `TAVILY_API_KEY` when required. Ensure your Docker host IP is allowed in the Atlas network access list.

For Azure Container Apps deployment with Azure Container Registry, Log Analytics, and Application Insights, see [infra/README.md](infra/README.md).

#### Run the test suite
.venv\Scripts\python.exe -m pytest tests -q

GitHub Actions validates Python compilation, tests, Bicep, and the Docker image for pull requests to `main` or `master`. A push to `main` or `master` also deploys to Azure Container Apps. The deploy job builds the image on the GitHub runner and pushes it directly to Azure Container Registry; it does not use Docker Hub or ACR Tasks.

Add these secrets to the GitHub `production` environment used by the workflow:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
MONGO_URI
OLLAMA_API_KEY
TAVILY_API_KEY
```

`TAVILY_API_KEY` may be empty when web search is not used. `APPLICATIONINSIGHTS_CONNECTION_STRING` is not a GitHub secret: Bicep creates Application Insights and passes its generated connection string to Container Apps.

For GitHub Actions, fulfil the **Azure OIDC prerequisite**

The Azure app registration/service principal represented by AZURE_CLIENT_ID must have:

A federated credential for the GitHub `production` environment.
`Contributor` permission on the `rag-rg` resource group.
`User Access Administrator` permission on `rag-rg`, because Bicep assigns `AcrPull` to the Container App identity.

Getting **AZURE_CLIENT_ID**

You need an Azure App Registration configured for GitHub OIDC.

Run these commands locally after `az login`:
```powershell
$subscriptionId = az account show --query id --output tsv
$tenantId = az account show --query tenantId --output tsv

$app = az ad app create `
  --display-name "rag-azure-github-actions"

$clientId = $app | ConvertFrom-Json | Select-Object -ExpandProperty appId
$objectId = $app | ConvertFrom-Json | Select-Object -ExpandProperty id

$clientId
$tenantId
$subscriptionId
```
Then create a service principal:
```powershell
az ad sp create --id $clientId
```

Assign it permission to deploy:
```powershell
az role assignment create `
  --assignee $clientId `
  --role Contributor `
  --scope "/subscriptions/$subscriptionId/resourceGroups/rag-rg"
```

Assign permission to create the ACR pull role assignment:

```powershell
az role assignment create `
  --assignee-object-id $objectId `
  --assignee-principal-type ServicePrincipal `
  --role "User Access Administrator" `
  --scope "/subscriptions/$subscriptionId/resourceGroups/rag-rg"
```

The workflow uses `environment: production`, so create this federated credential. The repository and owner IDs below must match the subject shown in the GitHub Actions `azure/login` log:
```powershell
$objectId = az ad app show `
  --id $clientId `
  --query id `
  --output tsv

$credential = @{
  name      = "github-production-env"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:IshaniGhosh161@168971196/RAG-Azure@1356082961:environment:production"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 3

$credential | Set-Content .\github-production.json -Encoding utf8

az ad app federated-credential create `
  --id $objectId `
  --parameters '@github-production.json'

Remove-Item .\github-production.json
```

Do not create a separate branch credential for the current workflow. It is using the `production` environment subject. After adding the credential and GitHub environment secrets, push to `main` or rerun the failed workflow.