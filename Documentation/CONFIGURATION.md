# ⚙️ Advanced Configuration

*Author: Bilel Azaiez*

## 🎛️ Function App Settings

### Core Configuration
| Setting | Default | Description |
|---------|---------|-------------|
| `TenantId` | From setup | Your M365 tenant ID |
| `ClientId` | From Key Vault | Azure AD app client ID |
| `ClientSecret` | From Key Vault | Azure AD app secret |
| `WorkspaceId` | From Key Vault | Log Analytics workspace ID |
| `WorkspaceKey` | From Key Vault | Log Analytics shared key |
| `PublisherIdentifier` | From Key Vault | O365 API publisher GUID |

### Content Type Configuration
```json
"ContentTypes": "Audit.General,DLP.All,Audit.Exchange,Audit.SharePoint,Audit.AzureActiveDirectory"
```

**Available Content Types:**
- `Audit.Exchange` - Exchange mailbox and admin activities
- `Audit.SharePoint` - SharePoint and OneDrive activities  
- `Audit.AzureActiveDirectory` - Azure AD sign-ins and directory changes
- `Audit.General` - Teams, Forms, Stream, Power Platform
- `DLP.All` - Data Loss Prevention events across all workloads

### Feature Flags
| Setting | Default | Description |
|---------|---------|-------------|
| `EnableUserEnrichment` | `true` | Add user details from Microsoft Graph |
| `EnableLabelSync` | `true` | Sync Microsoft Purview sensitivity labels |
| `EnableServiceHealth` | `true` | Collect service health events |
| `EnableDeduplication` | `true` | Remove duplicate events |

### Performance Settings
| Setting | Default | Description |
|---------|---------|-------------|
| `FUNCTIONS_WORKER_PROCESS_COUNT` | `4` | Number of worker processes |
| `PSWorkerInProcConcurrencyUpperBound` | `10` | PowerShell concurrency limit |
| `WEBSITE_RUN_FROM_PACKAGE` | `1` | Run from deployment package |

## 🔧 Customization Options

### Custom Table Names
To use custom table names, modify the `LogAnalytics.psm1` module:

```powershell
# Default table mapping
$TableMapping = @{
    'Audit.Exchange' = 'M365ExchangeAudit_CL'
    'Audit.SharePoint' = 'M365SharePointAudit_CL'
    'Audit.AzureActiveDirectory' = 'M365AzureADAudit_CL'
    'Audit.General' = 'M365TeamsAudit_CL'
    'DLP.All' = 'M365DLPEvents_CL'
}

# Custom table mapping example
$TableMapping = @{
    'Audit.Exchange' = 'CustomExchange_CL'
    'Audit.SharePoint' = 'CustomSharePoint_CL'
    'Audit.AzureActiveDirectory' = 'CustomAzureAD_CL'
    'Audit.General' = 'CustomTeams_CL'
    'DLP.All' = 'CustomDLP_CL'
}
```

### Custom Enrichment Fields
Modify `Enrichment.psm1` to add custom user attributes:

```powershell
# Default enrichment fields
$UserProperties = @(
    'displayName',
    'department', 
    'jobTitle',
    'manager',
    'officeLocation',
    'companyName'
)

# Add custom fields
$UserProperties += @(
    'employeeId',
    'costCenter',
    'division',
    'customAttribute1'
)
```

### Filtering Events
Add custom filtering logic in `run.ps1`:

```powershell
# Filter out test users
$FilteredEvents = $Events | Where-Object {
    $_.UserId -notlike "*test*" -and
    $_.UserId -notlike "*service*"
}

# Filter by specific operations
$FilteredEvents = $Events | Where-Object {
    $_.Operation -in @('FileDownloaded', 'FileUploaded', 'FileShared')
}
```

## 🕐 Schedule Configuration

### Default Schedule
The function runs every 5 minutes using a timer trigger:
```json
{
    "schedule": "0 */5 * * * *",
    "useMonitor": true
}
```

### Custom Schedules
Modify `function.json` for different intervals:

```json
// Every minute (high frequency)
"schedule": "0 * * * * *"

// Every 10 minutes
"schedule": "0 */10 * * * *"

// Every hour
"schedule": "0 0 * * * *"

// Business hours only (9 AM - 5 PM, weekdays)
"schedule": "0 0 9-17 * * 1-5"
```

## 🔐 Security Configuration

### Key Vault Integration
The solution uses Key Vault references in Function App settings:
```
@Microsoft.KeyVault(VaultName=kv-m365-audit-prod;SecretName=ClientId)
```

### Managed Identity Permissions
The Function App's managed identity needs:
- **Key Vault**: Secrets Get, List
- **Log Analytics**: Contributor (for data ingestion)

### Network Security
For enhanced security, configure:

1. **Virtual Network Integration**
   ```powershell
   # Add Function App to VNet
   Set-AzWebApp -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod" -VnetName "vnet-security"
   ```

2. **Private Endpoints**
   - Key Vault private endpoint
   - Log Analytics private endpoint

3. **IP Restrictions**
   ```powershell
   # Allow only specific IP ranges
   $AccessRestriction = @{
       ipAddress = "192.168.1.0/24"
       action = "Allow"
       tag = "Default"
       name = "AllowCorporateNetwork"
   }
   Set-AzWebAppAccessRestrictionRule -ResourceGroupName "rg-m365-audit-prod" -WebAppName "func-m365-audit-prod" -Name $AccessRestriction.name -IpAddress $AccessRestriction.ipAddress -Action $AccessRestriction.action
   ```

## 📊 Log Analytics Configuration

### Custom Log Retention
Set different retention periods per table:
```powershell
# 2 years for audit logs
Set-AzOperationalInsightsDataExport -ResourceGroupName "rg-m365-audit-prod" -WorkspaceName "law-m365-audit-prod" -TableName "M365ExchangeAudit_CL" -RetentionInDays 730

# 90 days for collection summaries  
Set-AzOperationalInsightsDataExport -ResourceGroupName "rg-m365-audit-prod" -WorkspaceName "law-m365-audit-prod" -TableName "M365AuditCollectionSummary_CL" -RetentionInDays 90
```

### Data Export
Configure continuous export for long-term storage:
```powershell
# Export to Storage Account
$ExportRule = @{
    DataExportName = "M365AuditExport"
    TableNames = @("M365*_CL")
    Destination = "/subscriptions/{subscription-id}/resourceGroups/rg-m365-audit-prod/providers/Microsoft.Storage/storageAccounts/stm365auditprod"
}
```

### Data Transformation
Use transformation rules to modify data before ingestion:
```kql
// Example transformation - mask sensitive data
source
| extend UserIdMasked = case(
    UserId_s contains "admin", "***ADMIN***",
    UserId_s contains "service", "***SERVICE***", 
    UserId_s
)
| project-away UserId_s
| project-rename UserId_s = UserIdMasked
```

## 🚀 Scaling Configuration

### Premium Function Plan
For high-volume environments:
```powershell
# Create Premium plan
New-AzFunctionAppPlan -ResourceGroupName "rg-m365-audit-prod" -Name "plan-m365-audit-premium" -Location "East US" -Sku "EP1" -WorkerType "Windows"

# Update Function App to use Premium plan
Set-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod" -PlanName "plan-m365-audit-premium"
```

### Auto-scaling Rules
```powershell
# CPU-based scaling
$ScaleRule = New-AzAutoscaleRule -MetricName "CpuPercentage" -MetricResourceId $FunctionAppId -Operator "GreaterThan" -MetricStatistic "Average" -Threshold 70 -TimeGrain "00:01:00" -ScaleActionCooldown "00:05:00" -ScaleActionDirection "Increase" -ScaleActionScaleType "ChangeCount" -ScaleActionValue 1

$ScaleProfile = New-AzAutoscaleProfile -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 1 -Rules $ScaleRule -Name "DefaultProfile"

Add-AzAutoscaleSetting -Location "East US" -Name "M365AuditAutoScale" -ResourceGroupName "rg-m365-audit-prod" -TargetResourceId $FunctionAppId -AutoscaleProfiles $ScaleProfile
```

### Load Balancing
For multiple regions:
```powershell
# Deploy to multiple regions with Traffic Manager
$Regions = @("East US", "West Europe", "Southeast Asia")

foreach ($Region in $Regions) {
    # Deploy Function App to each region
    # Configure Traffic Manager profile
}
```

## 🔍 Monitoring Configuration

### Application Insights
Enhanced monitoring configuration:
```json
{
    "sampling": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20,
        "excludedTypes": "Request;Exception"
    },
    "customDimensions": {
        "Environment": "Production",
        "Application": "M365AuditCollector"
    }
}
```

### Custom Metrics
Add custom metrics in PowerShell:
```powershell
# Track custom metrics
$TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
$TelemetryClient.TrackMetric("RecordsProcessed", $RecordCount)
$TelemetryClient.TrackMetric("ProcessingDuration", $Duration.TotalSeconds)
```

### Health Checks
Implement health check endpoint:
```powershell
# Health check function
function Test-SystemHealth {
    $Health = @{
        KeyVaultAccess = Test-KeyVaultConnection
        O365ApiAccess = Test-O365Connection  
        LogAnalyticsAccess = Test-LogAnalyticsConnection
        LastSuccessfulRun = Get-LastSuccessfulRun
    }
    return $Health
}
```

## 🎯 Environment-Specific Configuration

### Development Environment
```powershell
# Shorter retention, more verbose logging
$DevSettings = @{
    "EnableDeduplication" = "false"
    "LogLevel" = "Debug"
    "RetentionDays" = "30"
    "TestMode" = "true"
}
```

### Production Environment
```powershell
# Optimized for performance and cost
$ProdSettings = @{
    "EnableDeduplication" = "true"
    "LogLevel" = "Information" 
    "BatchSize" = "1000"
    "MaxConcurrency" = "8"
}
```

### Disaster Recovery
```powershell
# Backup configuration
$BackupConfig = @{
    BackupKeyVault = "kv-m365-audit-backup"
    BackupWorkspace = "law-m365-audit-backup"
    BackupRegion = "West US 2"
    RPO = "1 hour"
    RTO = "30 minutes"
}
```

## 📋 Configuration Validation

### Pre-deployment Checklist
```powershell
# Validation script
function Test-Configuration {
    $ValidationResults = @()
    
    # Test Azure connectivity
    $ValidationResults += Test-AzConnection
    
    # Test Key Vault access
    $ValidationResults += Test-KeyVaultAccess
    
    # Test O365 API permissions
    $ValidationResults += Test-O365Permissions
    
    # Test Log Analytics workspace
    $ValidationResults += Test-LogAnalyticsAccess
    
    return $ValidationResults
}
```

### Post-deployment Verification
```powershell
# Verify all settings are applied correctly
$CurrentSettings = Get-AzFunctionAppSetting -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod"
$ExpectedSettings = Get-Content "ExpectedSettings.json" | ConvertFrom-Json

$ConfigurationDrift = Compare-Object $CurrentSettings $ExpectedSettings
if ($ConfigurationDrift) {
    Write-Warning "Configuration drift detected!"
}
```
