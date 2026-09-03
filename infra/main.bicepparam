using './main.bicep'

param location = 'eastus'
param environmentName = 'rag'
param imageName = 'rag-api'
param imageTag = 'latest'
param deployContainerApp = true
param mongoUri = readEnvironmentVariable('MONGO_URI')
param ollamaApiKey = readEnvironmentVariable('OLLAMA_API_KEY')
param tavilyApiKey = readEnvironmentVariable('TAVILY_API_KEY', '')
param ollamaHost = readEnvironmentVariable('OLLAMA_HOST', 'https://ollama.com')
param ollamaModel = readEnvironmentVariable('OLLAMA_MODEL', 'gpt-oss:20b-cloud')
