// Example of execution:
// az deployment group create --resource-group MyRg --template-file main.bicep

// Location
param Location string = 'UK South'

// Log Analytic Workspace
param LawName string = 'poc-updatemanamgenet-lag04111'
param LawSku string = 'pergb2018'

param AutomationAccountName string = 'automationaccount04111'

var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') 

resource Lag 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: LawName
  location: Location
  properties:{
    sku:{
      name: LawSku
    }
  }
}

resource AutomationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: AutomationAccountName
  location: Location
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    sku: {
      name: 'Basic'
    }
  }
}

resource LinkAutomationAccount 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-08-01' = {
  name: '${Lag.name}/Automation'
  dependsOn:[
    Lag
    AutomationAccount
  ]
  properties: {
    resourceId: AutomationAccount.id
  }
}

resource Az_ResourceGraph 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  name: '${AutomationAccountName}/Az.ResourceGraph'
  dependsOn: [
    AutomationAccount
  ]
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/Az.ResourceGraph/0.11.0'
      version: '0.11.0'
    }
  }
}

resource Updates 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Updates(${LawName})'
  location: Location
  plan: {
    name: 'Updates(${LawName})'
    product: 'OMSGallery/Updates'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: Lag.id
  }
}

resource Runbook_PreTasks 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/UM-PreTasks'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/bszabados-Insight/AzureUpdateManagerWithTags/main/runbooks/UM-PreTasks.ps1'
    }
  }
}

resource Runbook_PostTasks 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/UM-PostTasks'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/bszabados-Insight/AzureUpdateManagerWithTags/main/runbooks/UM-PostTasks.ps1'      
    }
  }
}

param assignmentName string = guid(resourceGroup().id)
resource SystemAssignedManagedIdentityRgContributor 'Microsoft.Authorization/roleAssignments@2020-03-01-preview' = {
  name: assignmentName
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: AutomationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
