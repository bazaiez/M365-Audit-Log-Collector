# M365 Audit Log Collector - Step 5: Validation
# Author: Bilel Azaiez
# Version: 1.0 Production

# Load deployment configuration
$deploymentPath = "$workingDir\Config\DeploymentComplete.json"
$deployConfig = Get-Content $deploymentPath | ConvertFrom-Json

Write-Host "M365 Audit Log Collector - Deployment Validation" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Check Function App status
Write-Host "`nChecking Function App status..." -ForegroundColor Yellow
$functionApp = Get-AzFunctionApp `
    -ResourceGroupName $deployConfig.ResourceGroup `
    -Name $deployConfig.Resources.FunctionApp.Name

$status = if ($functionApp.State -eq "Running") { "✓ Running" } else { "✗ $($functionApp.State)" }
Write-Host "Function App Status: $status" -ForegroundColor Cyan

# Validation queries
$queries = @{
    "1. Check Collection Summary" = @"
M365AuditCollectionSummary_CL
| where TimeGenerated > ago(1h)
| project TimeGenerated, TotalRecords_d, TotalBlobs_d, ErrorCount_d, Success_b, DurationSeconds_d
| order by TimeGenerated desc
| take 10
"@

    "2. View Data by Table" = @"
search "M365*" 
| where TimeGenerated > ago(1h)
| summarize RecordCount = count() by Type
| where Type !contains "Summary" and Type !contains "Error"
| order by RecordCount desc
"@

    "3. Check User Enrichment" = @"
union M365*_CL
| where TimeGenerated > ago(1h)
| where isnotempty(UserDisplayName_s)
| project TimeGenerated, Type, UserId_s, UserDisplayName_s, UserDepartment_s, UserManager_s
| take 20
"@

    "4. View DLP Events" = @"
M365DLP*_CL
| where TimeGenerated > ago(24h)
| summarize Count = count() by Type, Workload_s
| order by Count desc
"@

    "5. Check Errors" = @"
M365AuditCollectionErrors_CL
| where TimeGenerated > ago(24h)
| project TimeGenerated, ErrorMessage_s, ErrorDetails_s
| order by TimeGenerated desc
| take 10
"@

    "6. Sensitivity Labels" = @"
M365SensitivityLabels_CL
| where TimeGenerated > ago(7d)
| project DisplayName_s, Name_s, Id_g, IsActive_b
| distinct DisplayName_s, Name_s, Id_g, IsActive_b
"@
}

# Display queries
Write-Host "`n=== VALIDATION QUERIES ===" -ForegroundColor Yellow
Write-Host "Run these queries in Log Analytics after 10-15 minutes:" -ForegroundColor Gray
Write-Host "Workspace: $($deployConfig.Resources.LogAnalytics.WorkspaceName)" -ForegroundColor Cyan

foreach ($queryName in $queries.Keys | Sort-Object) {
    Write-Host "`n$queryName" -ForegroundColor Green
    Write-Host $queries[$queryName] -ForegroundColor Gray
}

# Quick links
Write-Host "`n=== QUICK LINKS ===" -ForegroundColor Yellow

$subscriptionId = (Get-AzContext).Subscription.Id
$baseUrl = "https://portal.azure.com/#"

$links = @{
    "Function App Monitor" = "$baseUrl@microsoft.onmicrosoft.com/resource/subscriptions/$subscriptionId/resourceGroups/$($deployConfig.ResourceGroup)/providers/Microsoft.Web/sites/$($deployConfig.Resources.FunctionApp.Name)/functionsMonitor"
    "Log Analytics" = "$baseUrl@microsoft.onmicrosoft.com/resource$($deployConfig.Resources.LogAnalytics.ResourceId)/logs"
    "Key Vault" = "$baseUrl@microsoft.onmicrosoft.com/resource/subscriptions/$subscriptionId/resourceGroups/$($deployConfig.ResourceGroup)/providers/Microsoft.KeyVault/vaults/$($deployConfig.Resources.KeyVault.Name)/secrets"
}

foreach ($linkName in $links.Keys) {
    Write-Host "`n$linkName :" -ForegroundColor Cyan
    Write-Host $links[$linkName] -ForegroundColor White
}

# Explanation of enrichment
Write-Host "`n=== DATA ENRICHMENT EXPLANATION ===" -ForegroundColor Yellow
Write-Host @"
User Enrichment adds these fields directly to audit log tables:
- UserDisplayName_s: Full name of the user
- UserDepartment_s: User's department  
- UserJobTitle_s: User's job title
- UserManager_s: User's manager name
- UserOfficeLocation_s: User's office location

NO SEPARATE TABLE - data is added as fields to existing tables:
- M365ExchangeAudit_CL (Exchange logs with user details)
- M365SharePointAudit_CL (SharePoint logs with user details)
- M365DLPExchange_CL (DLP events with user details)
- etc.

Sensitivity labels are stored in: M365SensitivityLabels_CL
"@ -ForegroundColor Gray

# Save validation script
$validationScript = @"
# Quick validation script
`$workspace = "$($deployConfig.Resources.LogAnalytics.WorkspaceName)"
Write-Host "Checking for data in workspace: `$workspace" -ForegroundColor Yellow

# Add your Log Analytics query code here
"@

$validationScript | Out-File "$workingDir\Scripts\QuickValidation.ps1"

Write-Host "`n✓ Validation complete!" -ForegroundColor Green
Write-Host "All scripts saved in: $workingDir" -ForegroundColor Yellow
