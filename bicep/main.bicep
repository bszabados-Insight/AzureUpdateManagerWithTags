// Example of execution:
// az deployment group create --resource-group MyRg --template-file main.bicep

// Location
param Location string = 'UK South'
param LocationShort string = 'uks'

// Vnet
param VNetName string = '${LocationShort}-spoke-vnet'
param VNetAddressSpace array = [
  '10.0.0.0/16'
]
param VnetSubnetWorkloadAddressSpace string = '10.0.0.0/24'

// Log Analytic Workspace
param LawName string = 'poc-updatemanamgenet-lag04111'
param LawSku string = 'pergb2018'

param AutomationAccountName string = 'automationaccount04111'

var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') 

// VMs 
param VmSize string = 'Standard_B2s'
param VmWindows_2019DC bool = true
param VmWindows_2016 bool = true

param adminUsername string = 'User01'
param adminPassword string = 'HelloFromPatching!)1=&1154'


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

resource Runbook_ScheduleUpdatesWithVmsTags 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/UM-ScheduleUpdatesWithVmsTags'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/dawlysd/azure-update-management-with-tags/main/runbooks/UM-ScheduleUpdatesWithVmsTags.ps1'      
    }
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
      uri: 'https://raw.githubusercontent.com/dawlysd/azure-update-management-with-tags/main/runbooks/UM-PreTasks.ps1'
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
      uri: 'https://raw.githubusercontent.com/dawlysd/azure-update-management-with-tags/main/runbooks/UM-PostTasks.ps1'      
    }
  }
}

resource Runbook_CleanUpSchedules 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/UM-CleanUp-Schedules'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/dawlysd/azure-update-management-with-tags/main/runbooks/UM-CleanUp-Schedules.ps1'        
    }
  }
}

resource Runbook_CleanUpSnapshots 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/UM-CleanUp-Snapshots'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/dawlysd/azure-update-management-with-tags/main/runbooks/UM-CleanUp-Snapshots.ps1'           
    }
  }
}

resource DailySchedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/Schedules-ScheduleVmsWithTags'
  properties:{
    description: 'Schedule daily'
    startTime: ''
    frequency: 'Day'
    interval: 1
  }
}

param Sched1Guid string = newGuid()
resource ScheduleRunbook_ScheduleUpdatesWithVmsTags 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/${Sched1Guid}'
  properties:{
    schedule:{
      name: split(DailySchedule.name, '/')[1]
    }
    runbook:{
      name: split(Runbook_ScheduleUpdatesWithVmsTags.name, '/')[1]
    }
  }
}

param Sched2Guid string = newGuid()
resource ScheduleRunbook_CleanUpSnapshots 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/${Sched2Guid}'
  properties:{
    schedule:{
      name: split(DailySchedule.name, '/')[1]
    }
    runbook:{
      name: split(Runbook_CleanUpSnapshots.name, '/')[1]
    }
  }
}

param Sched3Guid string = newGuid()
resource ScheduleRunbook_CleanUpSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/${Sched3Guid}'
  properties:{
    schedule:{
      name: split(DailySchedule.name, '/')[1]
    }
    runbook:{
      name: split(Runbook_CleanUpSchedules.name, '/')[1]
    }
  }
}

resource Vnet 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: VNetName
  location: Location
  properties: {
    addressSpace: {
      addressPrefixes: VNetAddressSpace
    }
    subnets: [
      {
        name: 'workload'
        properties: {
          addressPrefix: VnetSubnetWorkloadAddressSpace
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

module Win01 'ModuleVM.bicep' = if (VmWindows_2019DC) {
  name: 'Win01'
  params:{
    VmName: 'VmWin2019DC'
    VmLocation: Location
    VmSize: VmSize
    VmOsType: 'Windows' 
    VmOsPublisher: 'MicrosoftWindowsServer' 
    VmOsOffer: 'WindowsServer' 
    VmOsSku: '2019-Datacenter' 
    VmOsVersion: 'latest'
    VmNicSubnetId: Vnet.properties.subnets[0].id
    WorkspaceId: Lag.properties.customerId 
    WorkspaceKey: listKeys(Lag.id, '2015-03-20').primarySharedKey
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags_policy_update: 'Friday;10:00 PM;Never;*java*;'
  }
}

module Win02 'ModuleVM.bicep' = if (VmWindows_2016) {
  name: 'Win02'
  params:{
    VmName: 'VmWin2016'
    VmLocation: Location
    VmSize: VmSize
    VmOsType: 'Windows' 
    VmOsPublisher: 'MicrosoftWindowsServer' 
    VmOsOffer: 'WindowsServer' 
    VmOsSku: '2016-datacenter-gensecond' 
    VmOsVersion: 'latest' 
    VmNicSubnetId: Vnet.properties.subnets[0].id
    WorkspaceId: Lag.properties.customerId 
    WorkspaceKey: listKeys(Lag.id, '2015-03-20').primarySharedKey
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags_policy_update: 'Tuesday,Sunday;08:00 AM;IfRequired;;TeamA@abc.com'
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
