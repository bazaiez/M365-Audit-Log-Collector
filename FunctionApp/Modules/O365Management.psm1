# O365Management PowerShell Module
# Handles Office 365 Management API interactions

function Get-O365ManagementToken {
    <#
    .SYNOPSIS
    Gets an access token for the Office 365 Management API
    
    .DESCRIPTION
    Authenticates with Azure AD using client credentials and returns an access token
    for accessing the Office 365 Management API
    
    .PARAMETER TenantId
    The Azure AD tenant ID
    
    .PARAMETER ClientId
    The Azure AD application client ID
    
    .PARAMETER ClientSecret
    The Azure AD application client secret
    
    .EXAMPLE
    $token = Get-O365ManagementToken -TenantId "tenant-id" -ClientId "client-id" -ClientSecret "client-secret"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    
    try {
        $body = @{
            grant_type    = "client_credentials"
            resource      = "https://manage.office.com"
            client_id     = $ClientId
            client_secret = $ClientSecret
        }
        
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token" `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop
        
        return $response.access_token
    }
    catch {
        Write-Error "Failed to get O365 Management API token: $($_.Exception.Message)"
        throw
    }
}

function Get-O365AuditContent {
    <#
    .SYNOPSIS
    Retrieves audit content from Office 365 Management API
    
    .DESCRIPTION
    Gets available content URIs and downloads audit log content for specified content types
    
    .PARAMETER AccessToken
    The access token for O365 Management API
    
    .PARAMETER TenantId
    The Azure AD tenant ID
    
    .PARAMETER ContentType
    The type of content to retrieve (e.g., Audit.Exchange, Audit.SharePoint)
    
    .PARAMETER StartTime
    The start time for content retrieval (optional)
    
    .PARAMETER EndTime
    The end time for content retrieval (optional)
    
    .EXAMPLE
    $content = Get-O365AuditContent -AccessToken $token -TenantId "tenant-id" -ContentType "Audit.Exchange"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ContentType,
        
        [Parameter(Mandatory = $false)]
        [datetime]$StartTime,
        
        [Parameter(Mandatory = $false)]
        [datetime]$EndTime
    )
    
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        # Build URI for content listing
        $baseUri = "https://manage.office.com/api/v1.0/$TenantId/activity/feed/subscriptions/content"
        $uri = "$baseUri" + "?contentType=$ContentType"
        
        if ($StartTime) {
            $uri += "&startTime=$($StartTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))"
        }
        
        if ($EndTime) {
            $uri += "&endTime=$($EndTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))"
        }
        
        # Get available content URIs
        Write-Information "Getting content URIs for $ContentType"
        $contentUris = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri -ErrorAction Stop
        
        if (-not $contentUris -or $contentUris.Count -eq 0) {
            Write-Information "No content available for $ContentType"
            return @()
        }
        
        Write-Information "Found $($contentUris.Count) content URIs for $ContentType"
        
        # Download content from each URI
        $allContent = @()
        foreach ($contentUri in $contentUris) {
            try {
                Write-Information "Downloading content from: $($contentUri.contentUri)"
                $content = Invoke-RestMethod -Method Get -Headers $headers -Uri $contentUri.contentUri -ErrorAction Stop
                
                if ($content) {
                    $allContent += $content
                }
            }
            catch {
                Write-Warning "Failed to download content from $($contentUri.contentUri): $($_.Exception.Message)"
            }
        }
        
        Write-Information "Retrieved $($allContent.Count) total events for $ContentType"
        return $allContent
    }
    catch {
        Write-Error "Failed to get audit content for $ContentType`: $($_.Exception.Message)"
        throw
    }
}

function Test-O365Subscription {
    <#
    .SYNOPSIS
    Tests if a subscription is active for a content type
    
    .DESCRIPTION
    Checks if the specified content type subscription is active and receiving data
    
    .PARAMETER AccessToken
    The access token for O365 Management API
    
    .PARAMETER TenantId
    The Azure AD tenant ID
    
    .PARAMETER ContentType
    The content type to check
    
    .EXAMPLE
    $isActive = Test-O365Subscription -AccessToken $token -TenantId "tenant-id" -ContentType "Audit.Exchange"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ContentType
    )
    
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        $uri = "https://manage.office.com/api/v1.0/$TenantId/activity/feed/subscriptions/list"
        $subscriptions = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri -ErrorAction Stop
        
        $subscription = $subscriptions | Where-Object { $_.contentType -eq $ContentType }
        
        if ($subscription -and $subscription.status -eq "enabled") {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-Warning "Failed to check subscription status for $ContentType`: $($_.Exception.Message)"
        return $false
    }
}

# Export module functions
Export-ModuleMember -Function Get-O365ManagementToken, Get-O365AuditContent, Test-O365Subscription
