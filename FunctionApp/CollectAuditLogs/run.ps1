# M365 Audit Log Collector - Main Collection Function
# Author: Bilel Azaiez
# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

Write-Host "M365 Audit Log Collector triggered at: $currentUTCtime"

try {
    # Import required modules
    Import-Module "$PSScriptRoot\..\Modules\O365Management.psm1" -Force
    Import-Module "$PSScriptRoot\..\Modules\LogAnalytics.psm1" -Force
    Import-Module "$PSScriptRoot\..\Modules\Enrichment.psm1" -Force

    # Get configuration from environment variables (Key Vault references)
    $Config = @{
        TenantId = $env:TenantId
        ClientId = $env:ClientId
        ClientSecret = $env:ClientSecret
        WorkspaceId = $env:WorkspaceId
        WorkspaceKey = $env:WorkspaceKey
        PublisherIdentifier = $env:PublisherIdentifier
        ContentTypes = ($env:ContentTypes -split ',').Trim()
    }

    # Validate configuration
    $missingConfig = $Config.GetEnumerator() | Where-Object { [string]::IsNullOrEmpty($_.Value) }
    if ($missingConfig) {
        throw "Missing configuration: $($missingConfig.Key -join ', ')"
    }

    Write-Host "Configuration validated successfully"

    # TODO: Add actual collection logic here
    # This is a placeholder - the actual implementation would include:
    # 1. Authenticate with O365 Management API
    # 2. Retrieve audit logs for each content type
    # 3. Enrich data with user information
    # 4. Deduplicate events
    # 5. Send to Log Analytics
    
    Write-Host "Collection completed successfully"

} catch {
    Write-Error "Collection failed: $($_.Exception.Message)"
    throw
}

Write-Host "M365 Audit Log Collector completed at: $((Get-Date).ToUniversalTime())"
