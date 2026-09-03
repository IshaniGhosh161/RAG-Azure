targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Short deployment name used in resource names.')
param environmentName string = 'rag'

@description('Container image repository name in ACR.')
param imageName string = 'rag-api'

@description('Container image tag to deploy.')
param imageTag string = 'latest'

@description('Set false for the first deployment to create the registry and monitoring resources before pushing the image.')
param deployContainerApp bool = true

@secure()
@description('MongoDB connection string. Keep this in deployment secrets.')
param mongoUri string

@secure()
@description('Ollama API key.')
param ollamaApiKey string

@secure()
@description('Tavily API key. Leave empty when web search is not used.')
param tavilyApiKey string = ''

@description('Ollama endpoint, for example https://ollama.com.')
param ollamaHost string = 'https://ollama.com'

@description('Ollama model name.')
param ollamaModel string = 'gpt-oss:20b-cloud'

param cpuCores string = '2.0'
param memorySize string = '4Gi'
param minReplicas int = 1
param maxReplicas int = 3

var suffix = toLower(uniqueString(subscription().id, environmentName, location))
var registryName = toLower(replace('${environmentName}${suffix}acr', '-', ''))
var logAnalyticsName = '${environmentName}-${suffix}-logs'
var appInsightsName = '${environmentName}-${suffix}-appi'
var managedEnvironmentName = '${environmentName}-${suffix}-aca-env'
var containerAppName = '${environmentName}-${suffix}-api'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableIpMasking: false
    RetentionInDays: 30
  }
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: managedEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = if (deployContainerApp) {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 5000
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'mongo-uri'
          value: mongoUri
        }
        {
          name: 'ollama-api-key'
          value: ollamaApiKey
        }
        {
          name: 'tavily-api-key'
          value: tavilyApiKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${registry.properties.loginServer}/${imageName}:${imageTag}'
          resources: {
            cpu: json(cpuCores)
            memory: memorySize
          }
          env: [
            {
              name: 'MONGO_URI'
              secretRef: 'mongo-uri'
            }
            {
              name: 'OLLAMA_API_KEY'
              secretRef: 'ollama-api-key'
            }
            {
              name: 'TAVILY_API_KEY'
              secretRef: 'tavily-api-key'
            }
            {
              name: 'OLLAMA_HOST'
              value: ollamaHost
            }
            {
              name: 'OLLAMA_MODEL'
              value: ollamaModel
            }
            {
              name: 'HF_EMBEDDING_MODEL'
              value: 'nomic-ai/nomic-embed-text-v1.5'
            }
            {
              name: 'HF_EMBEDDING_DEVICE'
              value: 'cpu'
            }
            {
              name: 'HF_EMBEDDING_BATCH_SIZE'
              value: '8'
            }
            {
              name: 'RETRIEVAL_K'
              value: '10'
            }
            {
              name: 'RERANK_TOP_N'
              value: '5'
            }
            {
              name: 'ENABLE_RERANKER'
              value: 'true'
            }
            {
              name: 'FAST_MODE'
              value: 'false'
            }
            {
              name: 'LOG_LEVEL'
              value: 'INFO'
            }
            {
              name: 'LOG_FILE'
              value: ''
            }
            {
              name: 'HOST'
              value: '0.0.0.0'
            }
            {
              name: 'PORT'
              value: '5000'
            }
            {
              name: 'OTEL_SERVICE_NAME'
              value: containerAppName
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/api/health'
                port: 5000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/api/health'
                port: 5000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployContainerApp) {
  scope: registry
  name: guid(registry.id, containerApp.id, 'acrpull')
  properties: {
    principalId: containerApp!.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

output resourceGroupName string = resourceGroup().name
output registryName string = registry.name
output registryLoginServer string = registry.properties.loginServer
output containerAppName string = deployContainerApp ? containerApp!.name : ''
output containerAppUrl string = deployContainerApp ? 'https://${containerApp!.properties.configuration.ingress.fqdn}' : ''
output applicationInsightsName string = appInsights.name
output logAnalyticsWorkspaceName string = logAnalytics.name
