# 📖 Detailed Deployment Guide

*Author: Bilel Azaiez*

## 🎯 Overview

This guide provides detailed instructions for deploying the M365 Audit Log Collector solution.

## 📋 Prerequisites

### 🔧 System Requirements
- **Windows 10/11** or **Windows Server 2019+**
- **PowerShell 7.4+** installed
- **Administrator privileges** for module installation
- **Internet connectivity** for Azure and O365 APIs

### 🌐 Azure Requirements
- **Azure Subscription** with Contributor role
- **Access to create** Resource Groups, Function Apps, Key Vaults, Log Analytics
- **Permission to register** Azure AD applications

### 🏢 Microsoft 365 Requirements
- **Global Administrator** or **Application Administrator** role
- **Exchange Administrator** role (for Exchange audit logs)
- **Security Administrator** role (for DLP events)
- **M365 E3/E5** license or equivalent

## 🚀 Step-by-Step Deployment

### Step 0: Environment Preparation

1. **Install PowerShell 7.4+**
   ```powershell
   winget install Microsoft.PowerShell
   ```

2. **Run Prerequisites Script**
   ```powershell
   .\Scripts\0-Prerequisites.ps1
   ```

### Step 1: Azure AD App Registration

1. **Run App Registration Script**
   ```powershell
   .\Scripts\1-AppRegistration.ps1
   ```

2. **Configure API Permissions in Azure Portal**
   - Navigate to **Azure AD > App registrations**
   - Select your app: **M365-Audit-Log-Collector**
   - Go to **API permissions**
   - Add the following permissions:

   **Office 365 Management APIs:**
   - `ActivityFeed.Read`
   - `ActivityFeed.ReadDlp`
   - `ServiceHealth.Read`

   **Microsoft Graph:**
   - `AuditLog.Read.All`
   - `Directory.Read.All`
   - `Group.Read.All`
   - `InformationProtectionPolicy.Read.All`
   - `Organization.Read.All`
   - `User.Read.All`

3. **Grant Admin Consent**
   - Click **Grant admin consent for [your organization]**
   - Confirm the consent

### Step 2: Enable O365 API Subscriptions

```powershell
.\Scripts\2-EnableSubscriptions.ps1
```

This script will:
- ✅ Authenticate with O365 Management API
- ✅ Enable audit log subscriptions for all M365 services
- ✅ Verify subscription status
- ✅ Save configuration for next steps

### Step 3: Deploy Azure Infrastructure

```powershell
.\Scripts\3-DeployInfrastructure.ps1
```

**Resources Created:**
- 📊 **Log Analytics Workspace** (or use existing)
- 🔧 **Azure Function App** (PowerShell 7.4)
- 🔐 **Key Vault** (for secure secret storage)
- 💾 **Storage Account** (for Function App)
- 📈 **Application Insights** (for monitoring)
- 🆔 **Managed Identity** (for secure access)

### Step 4: Deploy Function Code

⚠️ **Important**: Before running this step, ensure you have the following files:
- `O365Management.psm1`
- `LogAnalytics.psm1`
- `Enrichment.psm1`
- `function.json`
- `run.ps1`

```powershell
.\Scripts\4-DeployFunction.ps1
```

### Step 5: Validation

```powershell
.\Scripts\5-Validation.ps1
```

## 🔍 Troubleshooting

### Common Issues

**❌ "Failed to get token" Error**
- **Solution**: Verify API permissions are configured and admin consent granted

**❌ "Key Vault access denied" Error**
- **Solution**: Ensure you have Key Vault Secrets Officer role

**❌ "Function deployment failed" Error**
- **Solution**: Check if Function App name is globally unique

**❌ "No data appearing in Log Analytics" Error**
- **Solution**: Wait 15-30 minutes for first run, check Function App logs

### Validation Steps

1. **Check Function App Status**
   ```powershell
   Get-AzFunctionApp -ResourceGroupName "rg-m365-audit-prod"
   ```

2. **Verify Key Vault Secrets**
   ```powershell
   Get-AzKeyVaultSecret -VaultName "kv-m365-audit-prod"
   ```

3. **Monitor Function Execution**
   - Go to Azure Portal > Function App > Monitor
   - Check for successful executions every 5 minutes

## 🎛️ Configuration Options

### Environment Variables

The solution supports the following configuration options:

| Setting | Default | Description |
|---------|---------|-------------|
| `EnableUserEnrichment` | `true` | Add user details to audit logs |
| `EnableLabelSync` | `true` | Sync sensitivity labels |
| `EnableDeduplication` | `true` | Remove duplicate events |
| `ContentTypes` | All services | Which M365 services to collect |

### Performance Tuning

For high-volume environments:
- Increase `FUNCTIONS_WORKER_PROCESS_COUNT` to 6-8
- Consider Premium Function App plan
- Monitor Log Analytics ingestion limits

## 🔄 Maintenance

### Regular Tasks
- ✅ **Monitor collection health** weekly
- ✅ **Review Key Vault secret expiry** monthly
- ✅ **Update PowerShell modules** quarterly
- ✅ **Review Log Analytics retention** annually

### Secret Rotation
Client secrets expire every 2 years. To rotate:
1. Create new secret in Azure AD app
2. Update Key Vault secret
3. Restart Function App

## 📊 Monitoring

### Key Metrics to Monitor
- Collection success rate (>95%)
- Average collection duration (<5 minutes)
- Error count (should be minimal)
- Data volume trends

### Alerting Rules
Set up alerts for:
- Function execution failures
- High error rates
- Significant data volume drops
- Long collection durations

## 🎯 Next Steps

After successful deployment:
1. 📊 **Create Azure Workbooks** for visualization
2. 🚨 **Set up alert rules** for monitoring
3. 🔍 **Explore sample queries** in Examples folder
4. 📈 **Consider additional data sources** for correlation
