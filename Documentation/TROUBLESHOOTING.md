# 🔍 Troubleshooting Guide

*Author: Bilel Azaiez*

## 🚨 Common Issues & Solutions

### 🔐 Authentication Issues

#### ❌ "Failed to get token" Error
**Symptoms:**
- Authentication fails in Step 2
- Error message about invalid client credentials

**Solutions:**
1. ✅ **Verify API Permissions**
   - Go to Azure Portal → Azure AD → App registrations
   - Select your app → API permissions
   - Ensure all required permissions are added
   - **Grant admin consent** if not already done

2. ✅ **Check Client Secret**
   - Verify secret hasn't expired
   - Ensure no extra spaces when copying
   - Regenerate secret if needed

3. ✅ **Verify Tenant ID**
   - Confirm you're using the correct tenant ID
   - Check tenant domain matches your organization

#### ❌ "Admin consent required" Error
**Solution:**
- Only Global Administrator can grant consent
- Go to Azure Portal → Azure AD → App registrations → Your App → API permissions
- Click **Grant admin consent for [organization]**

### 🔧 Function App Issues

#### ❌ Function Not Executing
**Check Function App Status:**
```powershell
$functionApp = Get-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod"
Write-Host "Status: $($functionApp.State)"
```

**Solutions:**
1. ✅ **Restart Function App**
   ```powershell
   Restart-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod"
   ```

2. ✅ **Check Application Settings**
   - Verify Key Vault references are working
   - Test Key Vault access permissions

3. ✅ **Review Function Logs**
   - Go to Azure Portal → Function App → Monitor
   - Check Application Insights for detailed logs

#### ❌ "Key Vault access denied" Error
**Symptoms:**
- Function can't read secrets from Key Vault
- HTTP 403 errors in logs

**Solutions:**
1. ✅ **Verify Managed Identity**
   ```powershell
   $functionApp = Get-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod"
   Write-Host "Identity: $($functionApp.Identity)"
   ```

2. ✅ **Check Key Vault Access Policy**
   ```powershell
   Get-AzKeyVaultAccessPolicy -VaultName "kv-m365-audit-prod"
   ```

3. ✅ **Recreate Access Policy**
   ```powershell
   Set-AzKeyVaultAccessPolicy -VaultName "kv-m365-audit-prod" -ObjectId $functionApp.IdentityPrincipalId -PermissionsToSecrets Get,List
   ```

### 📊 Data Collection Issues

#### ❌ No Data in Log Analytics
**Wait Time:** Allow 15-30 minutes for first data to appear

**Check Steps:**
1. ✅ **Verify Function Execution**
   - Check Function App → Monitor for successful runs
   - Look for timer trigger executions every 5 minutes

2. ✅ **Check O365 Subscriptions**
   ```powershell
   # Re-run subscription script to verify
   .\Scripts\2-EnableSubscriptions.ps1
   ```

3. ✅ **Validate Log Analytics Connection**
   ```kql
   Heartbeat
   | where Computer contains "Azure"
   | order by TimeGenerated desc
   | take 5
   ```

#### ❌ Partial Data Collection
**Symptoms:**
- Some M365 services have data, others don't
- Inconsistent data volume

**Solutions:**
1. ✅ **Check Content Type Subscriptions**
   - Verify all required content types are enabled
   - Some services may need additional licensing

2. ✅ **Review Function Timeout**
   - Increase function timeout if processing takes too long
   - Check for rate limiting in logs

3. ✅ **Monitor API Limits**
   - O365 Management API has throttling limits
   - Check for HTTP 429 responses

### 🔄 Duplicate Data Issues

#### ❌ Seeing Duplicate Events
**Built-in Protection:** Solution includes deduplication

**If Still Seeing Duplicates:**
1. ✅ **Check Deduplication Setting**
   ```powershell
   Get-AzFunctionAppSetting -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod" | Where-Object {$_.Name -eq "EnableDeduplication"}
   ```

2. ✅ **Verify Hash Generation**
   - Check function logs for hash calculation
   - Ensure consistent data formatting

### 🚀 Performance Issues

#### ❌ Slow Data Collection
**Symptoms:**
- Function takes >10 minutes to complete
- Timeouts in function execution

**Solutions:**
1. ✅ **Upgrade Function Plan**
   ```powershell
   # Consider Premium plan for high volume
   Update-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod" -PlanName "Premium"
   ```

2. ✅ **Increase Worker Processes**
   ```powershell
   $settings = @{"FUNCTIONS_WORKER_PROCESS_COUNT" = "8"}
   Update-AzFunctionAppSetting -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod" -AppSetting $settings
   ```

3. ✅ **Optimize Batch Sizes**
   - Reduce batch size for large environments
   - Process content types in parallel

## 🔍 Diagnostic Commands

### Check Overall Health
```powershell
# Function App Status
Get-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod" | Select-Object Name, State, Location

# Key Vault Secrets
Get-AzKeyVaultSecret -VaultName "kv-m365-audit-prod" | Select-Object Name, Enabled

# Log Analytics Workspace
Get-AzOperationalInsightsWorkspace | Where-Object {$_.Name -like "*m365*"}
```

### Monitor Data Flow
```kql
// Check recent collection summary
M365AuditCollectionSummary_CL
| where TimeGenerated > ago(6h)
| project TimeGenerated, TotalRecords_d, Success_b, DurationSeconds_d, ErrorCount_d
| order by TimeGenerated desc

// Check for errors
M365AuditCollectionErrors_CL
| where TimeGenerated > ago(24h)
| project TimeGenerated, ErrorMessage_s, ErrorDetails_s
| order by TimeGenerated desc

// Data volume by service
search "M365*_CL"
| where TimeGenerated > ago(1h)
| summarize Count = count() by Type
| order by Count desc
```

## 🆘 Getting Help

### Log Collection for Support
When opening an issue, include:

1. **Function App Logs**
   ```powershell
   # Export logs from Application Insights
   # Include last 24 hours of data
   ```

2. **Configuration Details**
   ```powershell
   # Function App settings (redact secrets)
   Get-AzFunctionAppSetting -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod"
   ```

3. **Error Messages**
   - Exact error text
   - Screenshot if helpful
   - PowerShell version
   - Azure PowerShell module versions

### Self-Service Fixes

#### Quick Reset Procedure
If everything seems broken:

1. **Restart Function App**
   ```powershell
   Restart-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod" -Name "func-m365-audit-prod"
   ```

2. **Re-run Key Steps**
   ```powershell
   # Re-enable subscriptions
   .\Scripts\2-EnableSubscriptions.ps1
   
   # Validate deployment
   .\Scripts\5-Validation.ps1
   ```

3. **Check Recent Data**
   ```kql
   search "M365*"
   | where TimeGenerated > ago(30m)
   | summarize count() by Type
   ```

### Contact Information
- 🐛 **Bug Reports**: [GitHub Issues](../../issues)
- 💡 **Feature Requests**: [GitHub Discussions](../../discussions)
- 📖 **Documentation**: [Wiki](../../wiki)

## 📋 Prevention Checklist

### Before Deployment
- ✅ Verify Azure subscription permissions
- ✅ Confirm M365 Global Admin access
- ✅ Check PowerShell version (7.4+)
- ✅ Review organization's security policies

### During Deployment
- ✅ Save all displayed secrets and IDs
- ✅ Grant admin consent immediately after app creation
- ✅ Verify each step completes successfully
- ✅ Test Key Vault access before proceeding

### After Deployment
- ✅ Set up monitoring alerts
- ✅ Document any customizations
- ✅ Schedule regular health checks
- ✅ Plan for secret rotation schedule
