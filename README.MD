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

To run the published Docker Hub image locally, replace `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username:

```powershell
docker pull YOUR_DOCKERHUB_USERNAME/chatbot-rag:latest
$env:DOCKERHUB_IMAGE = "YOUR_DOCKERHUB_USERNAME/chatbot-rag"
docker compose --env-file path to .env\.env -f path to docker compose\docker-compose.yml up --no-build -d
OR
docker compose up -d
```

The image is published by GitHub Actions after a successful push to `main` or `master`. Configure the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`; create the `chatbot-rag` repository on Docker Hub first. The existing CI secrets are still required for the Compose health checks.

#### Run the test suite
.venv\Scripts\python.exe -m pytest tests -q

GitHub Actions runs Python compilation, the test suite, and a Docker image build for pushes and pull requests to `main` or `master`.
The workflow also runs the image and checks `/api/health`. Add these repository secrets for that container check: `MONGO_URI`, `OLLAMA_HOST` (optional), `OLLAMA_API_KEY`, and `TAVILY_API_KEY`.

For Github Action have to fulfil **Azure OIDC prerequisite**

The Azure app registration/service principal represented by AZURE_CLIENT_ID must have:

A federated credential for this GitHub repository and the `main/master` branch.
Contributor permission on the subscription or at least the `rag-rg` resource group.
Permission to create role assignments, because Bicep assigns `AcrPull` to the Container App identity.

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
```powersheel
az ad sp create --id $clientId
```

Assign it permission to deploy:
```powershell
az role assignment create `
  --assignee $clientId `
  --role Contributor `
  --scope "/subscriptions/$subscriptionId"
```

You must also create a federated credential for the GitHub repository:
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