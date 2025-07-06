# M365 Audit Log Collector - Step 4: Deploy Function Code
# Author: Bilel Azaiez
# Version: 1.0 Production

# Verify deployment configuration exists
$deploymentPath = "$workingDir\Config\DeploymentComplete.json"
if (!(Test-Path $deploymentPath)) {
    Write-Host "Deployment configuration not found. Please run Step 3 first." -ForegroundColor Red
    return
}

$deployConfig = Get-Content $deploymentPath | ConvertFrom-Json
Write-Host "Loaded deployment configuration" -ForegroundColor Green

# Create Function App structure
$functionPath = "$workingDir\FunctionApp"
Write-Host "`nPreparing Function App code..." -ForegroundColor Yellow

# Create host.json
@'
{
    "version": "2.0",
    "logging": {
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": true,
                "excludedTypes": "Request"
            }
        }
    },
    "functionTimeout": "00:10:00"
}
'@ | Out-File -FilePath "$functionPath\host.json" -Encoding UTF8

# Create requirements.psd1
@'
@{
    'Az.Accounts' = '2.*'
    'Az.Storage' = '5.*'
}
'@ | Out-File -FilePath "$functionPath\requirements.psd1" -Encoding UTF8

# Create profile.ps1
@'
# Azure Functions profile.ps1
Write-Information "M365 Audit Log Collector starting..."
'@ | Out-File -FilePath "$functionPath\profile.ps1" -Encoding UTF8

Write-Host "✓ Created Function App configuration files" -ForegroundColor Green

# Verify module files exist
Write-Host "`nChecking for required module files..." -ForegroundColor Yellow
Write-Host "Please ensure these files are in: $workingDir" -ForegroundColor Cyan
Write-Host "  - O365Management.psm1" -ForegroundColor Gray
Write-Host "  - LogAnalytics.psm1" -ForegroundColor Gray
Write-Host "  - Enrichment.psm1" -ForegroundColor Gray
Write-Host "  - function.json" -ForegroundColor Gray
Write-Host "  - run.ps1" -ForegroundColor Gray

$continue = Read-Host "`nAre all files present? (Y/N)"
if ($continue -ne 'Y') {
    Write-Host "Please add the required files and run this step again." -ForegroundColor Yellow
    return
}

# Copy module files
$moduleFiles = @("O365Management.psm1", "LogAnalytics.psm1", "Enrichment.psm1")
foreach ($module in $moduleFiles) {
    Copy-Item "$workingDir\$module" "$functionPath\Modules\$module" -Force
    Write-Host "✓ Copied $module" -ForegroundColor Green
}

# Copy function files
Copy-Item "$workingDir\function.json" "$functionPath\CollectAuditLogs\function.json" -Force
Copy-Item "$workingDir\run.ps1" "$functionPath\CollectAuditLogs\run.ps1" -Force
Write-Host "✓ Copied function files" -ForegroundColor Green

# Create deployment package
Write-Host "`nCreating deployment package..." -ForegroundColor Yellow
$zipPath = "$workingDir\FunctionApp.zip"

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Compress the function app
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($functionPath, $zipPath)

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host "✓ Created deployment package: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Green

# Deploy to Azure
Write-Host "`nDeploying to Azure Function App..." -ForegroundColor Yellow
Write-Host "Target: $($deployConfig.Resources.FunctionApp.Name)" -ForegroundColor Cyan
Write-Host "This may take 2-5 minutes..." -ForegroundColor Gray

try {
    Publish-AzWebApp `
        -ResourceGroupName $deployConfig.ResourceGroup `
        -Name $deployConfig.Resources.FunctionApp.Name `
        -ArchivePath $zipPath `
        -Force
    
    Write-Host "✓ Deployment successful" -ForegroundColor Green
}
catch {
    Write-Host "✗ Deployment failed: $_" -ForegroundColor Red
    return
}

# Restart Function App
Write-Host "`nRestarting Function App..." -ForegroundColor Yellow
Restart-AzFunctionApp `
    -ResourceGroupName $deployConfig.ResourceGroup `
    -Name $deployConfig.Resources.FunctionApp.Name `
    -Force

Write-Host "✓ Function App restarted" -ForegroundColor Green

# Display summary
Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "         M365 AUDIT LOG COLLECTOR DEPLOYMENT COMPLETE           " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Function App: $($deployConfig.Resources.FunctionApp.Name)" -ForegroundColor Cyan
Write-Host "Next run: Within 5 minutes (runs every 5 minutes)" -ForegroundColor Yellow
Write-Host "Data location: Log Analytics Workspace '$($deployConfig.Resources.LogAnalytics.WorkspaceName)'" -ForegroundColor Yellow
Write-Host "`nRun Step 5 to validate the deployment" -ForegroundColor White
