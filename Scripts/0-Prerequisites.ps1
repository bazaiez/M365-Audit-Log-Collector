# M365 Audit Log Collector - Prerequisites Setup
# Author: Bilel Azaiez  
# Version: 1.0 Production

# Install required PowerShell modules only
Write-Host "Installing required PowerShell modules..." -ForegroundColor Yellow

$requiredModules = @(
    'Az.Accounts',
    'Az.Resources', 
    'Az.OperationalInsights',
    'Az.KeyVault',
    'Az.Storage',
    'Az.Web',
    'Az.ApplicationInsights',
    'AzureAD'
)

foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module..." -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    } else {
        Write-Host "$module already installed" -ForegroundColor Green
    }
}

# Create working directory structure
$workingDir = "C:\M365-Audit-Collector"
Write-Host "`nCreating working directory structure..." -ForegroundColor Yellow

$directories = @(
    "$workingDir",
    "$workingDir\Config",
    "$workingDir\FunctionApp",
    "$workingDir\FunctionApp\Modules",
    "$workingDir\FunctionApp\CollectAuditLogs",
    "$workingDir\Scripts",
    "$workingDir\Documentation"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "Created: $dir" -ForegroundColor Gray
    }
}

Set-Location $workingDir
Write-Host "`n✓ Prerequisites complete. Working directory: $workingDir" -ForegroundColor Green
