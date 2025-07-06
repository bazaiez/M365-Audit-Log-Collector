# M365 Audit Log Collector - Step 1: App Registration
# Author: Bilel Azaiez
# Version: 1.0 Production

# Connect to Azure
Write-Host "`nConnecting to Azure..." -ForegroundColor Yellow
Connect-AzAccount
$azContext = Get-AzContext

# Verify connection
if (!$azContext) {
    Write-Host "Failed to connect to Azure. Please run Connect-AzAccount" -ForegroundColor Red
    return
}

Write-Host "Connected to Azure Subscription: $($azContext.Subscription.Name)" -ForegroundColor Green
Write-Host "Tenant ID: $($azContext.Tenant.Id)" -ForegroundColor Cyan

# Connect to Azure AD
Write-Host "`nConnecting to Azure AD..." -ForegroundColor Yellow
Connect-AzureAD -TenantId $azContext.Tenant.Id

# Configuration
$config = @{
    AppName = "M365-Audit-Log-Collector"
    SecretName = "M365AuditCollectorSecret"
    SecretDurationYears = 2
    Description = "Collects M365 audit logs for Azure Sentinel"
}

# Create application
Write-Host "`nCreating Azure AD Application..." -ForegroundColor Yellow
$app = New-AzureADApplication `
    -DisplayName $config.AppName `
    -IdentifierUris "api://m365-audit-collector-$((New-Guid).ToString())"

Write-Host "✓ Created application: $($app.DisplayName)" -ForegroundColor Green

# Create client secret
Write-Host "Creating client secret..." -ForegroundColor Yellow
$startDate = Get-Date
$endDate = $startDate.AddYears($config.SecretDurationYears)
$appSecret = New-AzureADApplicationPasswordCredential `
    -ObjectId $app.ObjectId `
    -CustomKeyIdentifier $config.SecretName `
    -StartDate $startDate `
    -EndDate $endDate

# Create service principal
Write-Host "Creating service principal..." -ForegroundColor Yellow
$sp = New-AzureADServicePrincipal -AppId $app.AppId

# Get tenant information
$tenant = Get-AzureADTenantDetail
$tenantId = $tenant.ObjectId
$tenantDomain = ($tenant.VerifiedDomains | Where-Object {$_.Initial}).Name

# Prepare output
$appConfig = [ordered]@{
    AppName = $config.AppName
    TenantId = $tenantId
    TenantDomain = $tenantDomain
    ClientId = $app.AppId
    ClientSecret = $appSecret.Value
    ObjectId = $app.ObjectId
    ServicePrincipalId = $sp.ObjectId
    CreatedDate = Get-Date
    SecretExpiry = $endDate
}

# Display critical information
Write-Host "`n" -NoNewline
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "                    SAVE THESE VALUES                           " -ForegroundColor Red -BackgroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "Tenant ID:      $tenantId" -ForegroundColor Cyan
Write-Host "Client ID:      $($app.AppId)" -ForegroundColor Cyan
Write-Host "Client Secret:  $($appSecret.Value)" -ForegroundColor Cyan
Write-Host "Secret Expiry:  $endDate" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow

# Save configuration
$configPath = "$workingDir\Config\AppRegistration.json"
$appConfig | ConvertTo-Json -Depth 5 | Out-File $configPath
Write-Host "`nConfiguration saved to: $configPath" -ForegroundColor Green

# Instructions for next step
Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Yellow
Write-Host "1. Go to Azure Portal > Azure Active Directory > App registrations" -ForegroundColor White
Write-Host "2. Select '$($config.AppName)'" -ForegroundColor White
Write-Host "3. Configure API permissions as follows:" -ForegroundColor White
Write-Host "   - Office 365 Management APIs: ActivityFeed.Read, ActivityFeed.ReadDlp, ServiceHealth.Read" -ForegroundColor Gray
Write-Host "   - Microsoft Graph: AuditLog.Read.All, Directory.Read.All, Group.Read.All," -ForegroundColor Gray
Write-Host "     InformationProtectionPolicy.Read.All, Organization.Read.All, User.Read.All" -ForegroundColor Gray
Write-Host "4. Grant admin consent" -ForegroundColor White
Write-Host "5. Run Step 2 script to continue" -ForegroundColor White
