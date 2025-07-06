# M365 Audit Log Collector - Step 2: Enable API Subscriptions
# Author: Bilel Azaiez
# Version: 1.0 Production

# Load configuration
$configPath = "$workingDir\Config\AppRegistration.json"
if (!(Test-Path $configPath)) {
    Write-Host "App registration config not found. Please run Step 1 first." -ForegroundColor Red
    return
}

$appConfig = Get-Content $configPath | ConvertFrom-Json
Write-Host "Loaded configuration for: $($appConfig.AppName)" -ForegroundColor Green

# Generate Publisher ID
$publisherId = [guid]::NewGuid().ToString()
Write-Host "Generated Publisher ID: $publisherId" -ForegroundColor Cyan

# Function to get O365 Management API token
function Get-O365ManagementToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    $body = @{
        grant_type    = "client_credentials"
        resource      = "https://manage.office.com"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }
    
    try {
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token" `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop
        
        return $response.access_token
    }
    catch {
        Write-Host "Failed to get token. Please verify:" -ForegroundColor Red
        Write-Host "1. API permissions are configured correctly" -ForegroundColor Yellow
        Write-Host "2. Admin consent has been granted" -ForegroundColor Yellow
        Write-Host "3. Client ID and Secret are correct" -ForegroundColor Yellow
        throw $_
    }
}

# Get token
Write-Host "`nGetting O365 Management API token..." -ForegroundColor Yellow
try {
    $token = Get-O365ManagementToken `
        -TenantId $appConfig.TenantId `
        -ClientId $appConfig.ClientId `
        -ClientSecret $appConfig.ClientSecret
    Write-Host "✓ Successfully authenticated" -ForegroundColor Green
}
catch {
    Write-Host "Authentication failed. Error: $_" -ForegroundColor Red
    return
}

$headers = @{ 
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

# Content types to enable
$contentTypes = @(
    @{Name = "Audit.AzureActiveDirectory"; Description = "Azure AD sign-ins and directory changes"},
    @{Name = "Audit.Exchange"; Description = "Exchange mailbox and admin activities"},
    @{Name = "Audit.SharePoint"; Description = "SharePoint and OneDrive activities"},
    @{Name = "Audit.General"; Description = "Teams, Forms, Stream, and other M365 services"},
    @{Name = "DLP.All"; Description = "Data Loss Prevention events across all workloads"}
)

Write-Host "`nEnabling O365 Management API subscriptions..." -ForegroundColor Yellow
Write-Host "This enables collection of audit logs from M365 services" -ForegroundColor Gray

$subscriptionResults = @()
foreach ($contentType in $contentTypes) {
    Write-Host "`n$($contentType.Name) - $($contentType.Description)" -ForegroundColor Cyan
    Write-Host "Enabling..." -NoNewline
    
    try {
        $uri = "https://manage.office.com/api/v1.0/$($appConfig.TenantId)/activity/feed/subscriptions/start?contentType=$($contentType.Name)&PublisherIdentifier=$publisherId"
        $response = Invoke-RestMethod -Method Post -Headers $headers -Uri $uri -ErrorAction Stop
        
        Write-Host " SUCCESS" -ForegroundColor Green
        $subscriptionResults += [PSCustomObject]@{
            ContentType = $contentType.Name
            Status = "Enabled"
            StatusDetail = $response.status
        }
    }
    catch {
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($_.Exception.Response.StatusCode -eq 'BadRequest' -or $errorMessage.error.message -like "*already enabled*") {
            Write-Host " ALREADY ENABLED" -ForegroundColor Yellow
            $subscriptionResults += [PSCustomObject]@{
                ContentType = $contentType.Name
                Status = "Already Enabled"
                StatusDetail = "Subscription was previously enabled"
            }
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  Error: $_" -ForegroundColor Red
            $subscriptionResults += [PSCustomObject]@{
                ContentType = $contentType.Name
                Status = "Failed"
                StatusDetail = $_.Exception.Message
            }
        }
    }
}

# Verify all subscriptions
Write-Host "`n`nVerifying active subscriptions..." -ForegroundColor Yellow
$listUri = "https://manage.office.com/api/v1.0/$($appConfig.TenantId)/activity/feed/subscriptions/list"
$activeSubscriptions = Invoke-RestMethod -Method Get -Headers $headers -Uri $listUri

# Display results
Write-Host "`n=== SUBSCRIPTION STATUS ===" -ForegroundColor Yellow
$subscriptionResults | Format-Table ContentType, Status, StatusDetail -AutoSize

Write-Host "`n=== ACTIVE SUBSCRIPTIONS ===" -ForegroundColor Yellow
$activeSubscriptions | Format-Table contentType, status, webhook -AutoSize

# Save subscription configuration
$subscriptionConfig = @{
    PublisherId = $publisherId
    ConfiguredDate = Get-Date
    Subscriptions = $subscriptionResults
    ActiveSubscriptions = $activeSubscriptions
}

$subConfigPath = "$workingDir\Config\SubscriptionConfig.json"
$subscriptionConfig | ConvertTo-Json -Depth 5 | Out-File $subConfigPath

Write-Host "`n✓ Subscription configuration complete" -ForegroundColor Green
Write-Host "Publisher ID: $publisherId" -ForegroundColor Cyan
Write-Host "Configuration saved to: $subConfigPath" -ForegroundColor Green

# Check if all succeeded
$failedSubs = $subscriptionResults | Where-Object {$_.Status -eq "Failed"}
if ($failedSubs) {
    Write-Host "`nWARNING: Some subscriptions failed to enable" -ForegroundColor Yellow
    Write-Host "Please check the errors above and ensure all API permissions are granted" -ForegroundColor Yellow
}
