# M365 Audit Log Collector - Step 3: Deploy Azure Infrastructure
# Author: Bilel Azaiez
# Version: 1.0 Production

# Load configurations
$appConfigPath = "$workingDir\Config\AppRegistration.json"
$subConfigPath = "$workingDir\Config\SubscriptionConfig.json"

if (!(Test-Path $appConfigPath) -or !(Test-Path $subConfigPath)) {
    Write-Host "Configuration files not found. Please run Steps 1 and 2 first." -ForegroundColor Red
    return
}

$appConfig = Get-Content $appConfigPath | ConvertFrom-Json
$subConfig = Get-Content $subConfigPath | ConvertFrom-Json

# Get current Azure context
$azContext = Get-AzContext
if (!$azContext) {
    Connect-AzAccount
    $azContext = Get-AzContext
}

Write-Host "Connected to subscription: $($azContext.Subscription.Name)" -ForegroundColor Green

# Configuration
$deploymentConfig = @{
    Environment = "prod"
    Location = "eastus"
    ResourceGroupName = "rg-m365-audit-prod"
    
    # Resource names (meaningful, no random numbers)
    WorkspaceName = "law-m365-audit-prod"
    FunctionAppName = "func-m365-audit-prod"
    StorageAccountName = "stm365auditprod"  # Must be globally unique, lowercase, no dashes
    KeyVaultName = "kv-m365-audit-prod"     # Must be globally unique
    AppInsightsName = "ai-m365-audit-prod"
}

# Display configuration
Write-Host "`n=== DEPLOYMENT CONFIGURATION ===" -ForegroundColor Yellow
$deploymentConfig.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)" -ForegroundColor Cyan
}

# Check for existing Log Analytics Workspaces
Write-Host "`nSearching for existing Log Analytics Workspaces..." -ForegroundColor Yellow
$allWorkspaces = Get-AzOperationalInsightsWorkspace

$selectedWorkspace = $null
if ($allWorkspaces.Count -gt 0) {
    Write-Host "`nFound existing Log Analytics Workspaces:" -ForegroundColor Yellow
    $i = 1
    foreach ($ws in $allWorkspaces) {
        Write-Host "$i. $($ws.Name) (RG: $($ws.ResourceGroupName), Location: $($ws.Location))" -ForegroundColor Cyan
        $i++
    }
    Write-Host "$i. Create new Log Analytics Workspace" -ForegroundColor Green
    
    $selection = Read-Host "`nSelect workspace (1-$i)"
    if ($selection -ge 1 -and $selection -le $allWorkspaces.Count) {
        $selectedWorkspace = $allWorkspaces[$selection - 1]
        Write-Host "Selected: $($selectedWorkspace.Name)" -ForegroundColor Green
    }
}

# Confirm deployment
Write-Host "`n=== DEPLOYMENT SUMMARY ===" -ForegroundColor Yellow
Write-Host "Resource Group: $($deploymentConfig.ResourceGroupName)" -ForegroundColor Cyan
Write-Host "Location: $($deploymentConfig.Location)" -ForegroundColor Cyan
if ($selectedWorkspace) {
    Write-Host "Log Analytics: $($selectedWorkspace.Name) (existing)" -ForegroundColor Cyan
} else {
    Write-Host "Log Analytics: $($deploymentConfig.WorkspaceName) (new)" -ForegroundColor Cyan
}

$confirm = Read-Host "`nProceed with deployment? (Y/N)"
if ($confirm -ne 'Y') {
    Write-Host "Deployment cancelled." -ForegroundColor Red
    return
}

# Create Resource Group
Write-Host "`nCreating Resource Group..." -ForegroundColor Yellow
New-AzResourceGroup `
    -Name $deploymentConfig.ResourceGroupName `
    -Location $deploymentConfig.Location `
    -Tag @{
        Purpose = "M365 Audit Log Collection"
        Environment = $deploymentConfig.Environment
        CreatedBy = $azContext.Account.Id
        CreatedDate = (Get-Date).ToString('yyyy-MM-dd')
    }

# Handle Log Analytics Workspace
if ($selectedWorkspace) {
    $workspace = $selectedWorkspace
    Write-Host "`nUsing existing Log Analytics Workspace: $($workspace.Name)" -ForegroundColor Green
} else {
    Write-Host "`nCreating Log Analytics Workspace..." -ForegroundColor Yellow
    $workspace = New-AzOperationalInsightsWorkspace `
        -ResourceGroupName $deploymentConfig.ResourceGroupName `
        -Name $deploymentConfig.WorkspaceName `
        -Location $deploymentConfig.Location `
        -Sku "PerGB2018" `
        -RetentionInDays 90
    Write-Host "✓ Created workspace" -ForegroundColor Green
}

# Get workspace keys
$workspaceKeys = Get-AzOperationalInsightsWorkspaceSharedKey `
    -ResourceGroupName $workspace.ResourceGroupName `
    -Name $workspace.Name

Write-Host "Workspace ID: $($workspace.CustomerId)" -ForegroundColor Cyan

# Create Application Insights
Write-Host "`nCreating Application Insights..." -ForegroundColor Yellow
$appInsights = New-AzApplicationInsights `
    -ResourceGroupName $deploymentConfig.ResourceGroupName `
    -Name $deploymentConfig.AppInsightsName `
    -Location $deploymentConfig.Location `
    -WorkspaceResourceId $workspace.ResourceId `
    -Kind "web" `
    -ApplicationType "web"

# Create Storage Account
Write-Host "`nCreating Storage Account..." -ForegroundColor Yellow
$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $deploymentConfig.ResourceGroupName `
    -Name $deploymentConfig.StorageAccountName `
    -Location $deploymentConfig.Location `
    -SkuName "Standard_LRS" `
    -Kind "StorageV2" `
    -AccessTier "Hot" `
    -EnableHttpsTrafficOnly $true `
    -MinimumTlsVersion "TLS1_2"

# Create Key Vault
Write-Host "`nCreating Key Vault..." -ForegroundColor Yellow
$keyVault = New-AzKeyVault `
    -ResourceGroupName $deploymentConfig.ResourceGroupName `
    -VaultName $deploymentConfig.KeyVaultName `
    -Location $deploymentConfig.Location `
    -EnabledForDeployment `
    -EnabledForTemplateDeployment `
    -EnablePurgeProtection `
    -SoftDeleteRetentionInDays 90 `
    -Sku "Standard"

# Grant current user Key Vault permissions
Write-Host "`nConfiguring Key Vault access for current user..." -ForegroundColor Yellow
$myObjectId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account.Id).Id
$subscriptionId = (Get-AzContext).Subscription.Id

# Assign Key Vault Secrets Officer role to current user
New-AzRoleAssignment `
    -ObjectId $myObjectId `
    -RoleDefinitionName "Key Vault Secrets Officer" `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/$($deploymentConfig.ResourceGroupName)/providers/Microsoft.KeyVault/vaults/$($deploymentConfig.KeyVaultName)"

Write-Host "✓ Granted Key Vault Secrets Officer role to current user" -ForegroundColor Green

# Store secrets in Key Vault
Write-Host "`nStoring secrets in Key Vault..." -ForegroundColor Yellow
$secrets = @{
    "ClientId" = $appConfig.ClientId
    "ClientSecret" = $appConfig.ClientSecret
    "WorkspaceId" = $workspace.CustomerId
    "WorkspaceKey" = $workspaceKeys.PrimarySharedKey
    "PublisherGuid" = $subConfig.PublisherId
}

foreach ($secretName in $secrets.Keys) {
    $secretValue = ConvertTo-SecureString $secrets[$secretName] -AsPlainText -Force
    Set-AzKeyVaultSecret `
        -VaultName $deploymentConfig.KeyVaultName `
        -Name $secretName `
        -SecretValue $secretValue | Out-Null
    Write-Host "✓ Stored secret: $secretName" -ForegroundColor Green
}

# Create Function App
Write-Host "`nCreating Function App..." -ForegroundColor Yellow
$functionApp = New-AzFunctionApp `
    -ResourceGroupName $deploymentConfig.ResourceGroupName `
    -Name $deploymentConfig.FunctionAppName `
    -StorageAccountName $deploymentConfig.StorageAccountName `
    -Location $deploymentConfig.Location `
    -Runtime "PowerShell" `
    -RuntimeVersion "7.4" `
    -FunctionsVersion "4" `
    -OSType "Windows"

# Enable Managed Identity
Write-Host "`nEnabling System Managed Identity..." -ForegroundColor Yellow
$functionAppIdentity = Update-AzFunctionApp `
    -ResourceGroupName $deploymentConfig.ResourceGroupName `
    -Name $deploymentConfig.FunctionAppName `
    -IdentityType SystemAssigned `
    -Force

Start-Sleep -Seconds 20  # Wait for identity to be created

# Grant Key Vault access to Function App
Write-Host "`nConfiguring Key Vault access policy..." -ForegroundColor Yellow
Set-AzKeyVaultAccessPolicy `
    -VaultName $deploymentConfig.KeyVaultName `
    -ObjectId $functionAppIdentity.IdentityPrincipalId `
    -PermissionsToSecrets Get,List

# Configure Function App settings
Write-Host "`nConfiguring Function App settings..." -ForegroundColor Yellow
$appSettings = @{
    # Core settings
    "TenantId" = $appConfig.TenantId
    "ClientId" = "@Microsoft.KeyVault(VaultName=$($deploymentConfig.KeyVaultName);SecretName=ClientId)"
    "ClientSecret" = "@Microsoft.KeyVault(VaultName=$($deploymentConfig.KeyVaultName);SecretName=ClientSecret)"
    "WorkspaceId" = "@Microsoft.KeyVault(VaultName=$($deploymentConfig.KeyVaultName);SecretName=WorkspaceId)"
    "WorkspaceKey" = "@Microsoft.KeyVault(VaultName=$($deploymentConfig.KeyVaultName);SecretName=WorkspaceKey)"
    "PublisherIdentifier" = "@Microsoft.KeyVault(VaultName=$($deploymentConfig.KeyVaultName);SecretName=PublisherGuid)"
    
    # Content configuration
    "ContentTypes" = "Audit.General,DLP.All,Audit.Exchange,Audit.SharePoint,Audit.AzureActiveDirectory"
    
    # Feature flags
    "EnableUserEnrichment" = "true"
    "EnableLabelSync" = "true"
    "EnableServiceHealth" = "true"
    "EnableDeduplication" = "true"
    
    # Performance settings
    "FUNCTIONS_WORKER_PROCESS_COUNT" = "4"
    "FUNCTIONS_WORKER_RUNTIME" = "powershell"
    "AzureWebJobsFeatureFlags" = "EnableWorkerIndexing"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    
    # Monitoring
    "APPINSIGHTS_INSTRUMENTATIONKEY" = $appInsights.InstrumentationKey
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = $appInsights.ConnectionString
    
    # PowerShell settings
    "PSWorkerInProcConcurrencyUpperBound" = "10"
}

Update-AzFunctionAppSetting `
    -ResourceGroupName $deploymentConfig.ResourceGroupName `
    -Name $deploymentConfig.FunctionAppName `
    -AppSetting $appSettings `
    -Force

# Save deployment configuration
$deploymentComplete = @{
    DeploymentDate = Get-Date
    ResourceGroup = $deploymentConfig.ResourceGroupName
    Resources = @{
        FunctionApp = @{
            Name = $deploymentConfig.FunctionAppName
            IdentityObjectId = $functionAppIdentity.IdentityPrincipalId
        }
        LogAnalytics = @{
            WorkspaceId = $workspace.CustomerId
            WorkspaceName = $workspace.Name
            ResourceId = $workspace.ResourceId
        }
        KeyVault = @{
            Name = $deploymentConfig.KeyVaultName
            VaultUri = $keyVault.VaultUri
        }
        StorageAccount = @{
            Name = $deploymentConfig.StorageAccountName
        }
        ApplicationInsights = @{
            Name = $deploymentConfig.AppInsightsName
            InstrumentationKey = $appInsights.InstrumentationKey
        }
    }
}

$deploymentComplete | ConvertTo-Json -Depth 5 | Out-File "$workingDir\Config\DeploymentComplete.json"

Write-Host "`n✓ Azure infrastructure deployment completed!" -ForegroundColor Green
Write-Host "Configuration saved to: $workingDir\Config\DeploymentComplete.json" -ForegroundColor Yellow
