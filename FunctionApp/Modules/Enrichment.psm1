# Enrichment PowerShell Module
# Handles data enrichment with user details and other contextual information

function Get-GraphAccessToken {
    <#
    .SYNOPSIS
    Gets an access token for Microsoft Graph API
    
    .DESCRIPTION
    Authenticates with Azure AD using client credentials and returns an access token
    for accessing Microsoft Graph API
    
    .PARAMETER TenantId
    The Azure AD tenant ID
    
    .PARAMETER ClientId
    The Azure AD application client ID
    
    .PARAMETER ClientSecret
    The Azure AD application client secret
    
    .EXAMPLE
    $token = Get-GraphAccessToken -TenantId "tenant-id" -ClientId "client-id" -ClientSecret "client-secret"
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
            scope         = "https://graph.microsoft.com/.default"
            client_id     = $ClientId
            client_secret = $ClientSecret
        }
        
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop
        
        return $response.access_token
    }
    catch {
        Write-Error "Failed to get Microsoft Graph access token: $($_.Exception.Message)"
        throw
    }
}

function Get-UserDetails {
    <#
    .SYNOPSIS
    Retrieves user details from Microsoft Graph
    
    .DESCRIPTION
    Gets user information including display name, department, manager, etc. from Microsoft Graph
    
    .PARAMETER AccessToken
    The Microsoft Graph access token
    
    .PARAMETER UserId
    The user ID (UPN or Object ID)
    
    .EXAMPLE
    $userDetails = Get-UserDetails -AccessToken $token -UserId "user@domain.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$UserId
    )
    
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        # Clean up UserId - remove domain suffixes and special characters that might cause issues
        $cleanUserId = $UserId -replace '#EXT#.*', '' -replace '_.*#EXT#', ''
        
        $uri = "https://graph.microsoft.com/v1.0/users/$cleanUserId" + "?`$select=displayName,department,jobTitle,officeLocation,companyName,manager"
        
        $user = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri -ErrorAction Stop
        
        # Get manager details if available
        $managerName = $null
        if ($user.manager) {
            try {
                $managerUri = "https://graph.microsoft.com/v1.0/users/$cleanUserId/manager?`$select=displayName"
                $manager = Invoke-RestMethod -Method Get -Headers $headers -Uri $managerUri -ErrorAction SilentlyContinue
                $managerName = $manager.displayName
            }
            catch {
                Write-Information "Could not retrieve manager details for user: $UserId"
            }
        }
        
        return @{
            DisplayName = $user.displayName
            Department = $user.department
            JobTitle = $user.jobTitle
            OfficeLocation = $user.officeLocation
            CompanyName = $user.companyName
            Manager = $managerName
        }
    }
    catch {
        Write-Information "Could not retrieve user details for: $UserId. Error: $($_.Exception.Message)"
        return @{
            DisplayName = $null
            Department = $null
            JobTitle = $null
            OfficeLocation = $null
            CompanyName = $null
            Manager = $null
        }
    }
}

function Add-UserEnrichment {
    <#
    .SYNOPSIS
    Enriches audit log data with user details
    
    .DESCRIPTION
    Takes audit log events and adds user information from Microsoft Graph
    
    .PARAMETER Events
    Array of audit log events to enrich
    
    .PARAMETER AccessToken
    Microsoft Graph access token
    
    .PARAMETER UserCache
    Hashtable to cache user details and avoid duplicate API calls
    
    .EXAMPLE
    $enrichedEvents = Add-UserEnrichment -Events $auditEvents -AccessToken $token -UserCache $cache
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Events,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$UserCache = @{}
    )
    
    try {
        if (-not $Events -or $Events.Count -eq 0) {
            Write-Information "No events to enrich"
            return @()
        }
        
        $enrichedEvents = @()
        $userFieldMappings = @('UserId', 'User', 'ActorUserId', 'MailboxOwnerUPN')
        
        foreach ($event in $Events) {
            $enrichedEvent = $event.PSObject.Copy()
            
            # Find the user field in the event
            $userId = $null
            foreach ($field in $userFieldMappings) {
                if ($event.$field -and $event.$field -ne 'System' -and $event.$field -notmatch '^S-\d') {
                    $userId = $event.$field
                    break
                }
            }
            
            if ($userId) {
                # Check cache first
                if ($UserCache.ContainsKey($userId)) {
                    $userDetails = $UserCache[$userId]
                }
                else {
                    # Get user details from Graph
                    $userDetails = Get-UserDetails -AccessToken $AccessToken -UserId $userId
                    $UserCache[$userId] = $userDetails
                }
                
                # Add enrichment fields to event
                $enrichedEvent | Add-Member -NotePropertyName 'UserDisplayName' -NotePropertyValue $userDetails.DisplayName -Force
                $enrichedEvent | Add-Member -NotePropertyName 'UserDepartment' -NotePropertyValue $userDetails.Department -Force
                $enrichedEvent | Add-Member -NotePropertyName 'UserJobTitle' -NotePropertyValue $userDetails.JobTitle -Force
                $enrichedEvent | Add-Member -NotePropertyName 'UserOfficeLocation' -NotePropertyValue $userDetails.OfficeLocation -Force
                $enrichedEvent | Add-Member -NotePropertyName 'UserCompanyName' -NotePropertyValue $userDetails.CompanyName -Force
                $enrichedEvent | Add-Member -NotePropertyName 'UserManager' -NotePropertyValue $userDetails.Manager -Force
            }
            
            $enrichedEvents += $enrichedEvent
        }
        
        Write-Information "Enriched $($enrichedEvents.Count) events with user details"
        return $enrichedEvents
    }
    catch {
        Write-Error "Error enriching events with user details: $($_.Exception.Message)"
        return $Events  # Return original events if enrichment fails
    }
}

function Get-SensitivityLabels {
    <#
    .SYNOPSIS
    Retrieves sensitivity labels from Microsoft Graph
    
    .DESCRIPTION
    Gets the list of sensitivity labels configured in Microsoft Purview
    
    .PARAMETER AccessToken
    Microsoft Graph access token
    
    .EXAMPLE
    $labels = Get-SensitivityLabels -AccessToken $token
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        $uri = "https://graph.microsoft.com/v1.0/security/informationProtection/sensitivityLabels"
        
        $response = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri -ErrorAction Stop
        
        $labels = @()
        foreach ($label in $response.value) {
            $labels += @{
                Id = $label.id
                Name = $label.name
                DisplayName = $label.displayName
                Description = $label.description
                IsActive = $label.isActive
                Color = $label.color
                Sensitivity = $label.sensitivity
                Tooltip = $label.tooltip
            }
        }
        
        Write-Information "Retrieved $($labels.Count) sensitivity labels"
        return $labels
    }
    catch {
        Write-Warning "Could not retrieve sensitivity labels: $($_.Exception.Message)"
        return @()
    }
}

function Add-SensitivityLabelEnrichment {
    <#
    .SYNOPSIS
    Enriches events with sensitivity label information
    
    .DESCRIPTION
    Adds human-readable sensitivity label names to events that have label IDs
    
    .PARAMETER Events
    Array of events to enrich
    
    .PARAMETER SensitivityLabels
    Array of sensitivity label objects
    
    .EXAMPLE
    $enrichedEvents = Add-SensitivityLabelEnrichment -Events $events -SensitivityLabels $labels
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Events,
        
        [Parameter(Mandatory = $true)]
        [array]$SensitivityLabels
    )
    
    try {
        if (-not $Events -or $Events.Count -eq 0) {
            return @()
        }
        
        if (-not $SensitivityLabels -or $SensitivityLabels.Count -eq 0) {
            Write-Information "No sensitivity labels provided for enrichment"
            return $Events
        }
        
        # Create lookup hashtable for performance
        $labelLookup = @{}
        foreach ($label in $SensitivityLabels) {
            $labelLookup[$label.Id] = $label
        }
        
        $enrichedEvents = @()
        foreach ($event in $Events) {
            $enrichedEvent = $event.PSObject.Copy()
            
            # Look for sensitivity label fields
            $labelFields = @('SensitivityLabelId', 'LabelId', 'InformationBarrierSegmentId')
            
            foreach ($field in $labelFields) {
                if ($event.$field -and $labelLookup.ContainsKey($event.$field)) {
                    $label = $labelLookup[$event.$field]
                    $enrichedEvent | Add-Member -NotePropertyName 'SensitivityLabelName' -NotePropertyValue $label.DisplayName -Force
                    $enrichedEvent | Add-Member -NotePropertyName 'SensitivityLabelDescription' -NotePropertyValue $label.Description -Force
                    break
                }
            }
            
            $enrichedEvents += $enrichedEvent
        }
        
        Write-Information "Enriched events with sensitivity label information"
        return $enrichedEvents
    }
    catch {
        Write-Error "Error enriching events with sensitivity labels: $($_.Exception.Message)"
        return $Events
    }
}

function Remove-DuplicateEvents {
    <#
    .SYNOPSIS
    Removes duplicate events from the collection
    
    .DESCRIPTION
    Uses event properties to create a hash and remove duplicate events
    
    .PARAMETER Events
    Array of events to deduplicate
    
    .EXAMPLE
    $uniqueEvents = Remove-DuplicateEvents -Events $allEvents
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Events
    )
    
    try {
        if (-not $Events -or $Events.Count -eq 0) {
            return @()
        }
        
        $uniqueEvents = @()
        $seenHashes = @{}
        
        foreach ($event in $Events) {
            # Create a hash based on key event properties
            $hashFields = @('CreationTime', 'Operation', 'UserId', 'ObjectId', 'ClientIP')
            $hashString = ""
            
            foreach ($field in $hashFields) {
                if ($event.$field) {
                    $hashString += $event.$field
                }
            }
            
            # Generate hash
            $hasher = [System.Security.Cryptography.SHA256]::Create()
            $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashString))
            $hash = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
            
            # Check if we've seen this hash before
            if (-not $seenHashes.ContainsKey($hash)) {
                $seenHashes[$hash] = $true
                $uniqueEvents += $event
            }
        }
        
        $duplicatesRemoved = $Events.Count - $uniqueEvents.Count
        if ($duplicatesRemoved -gt 0) {
            Write-Information "Removed $duplicatesRemoved duplicate events"
        }
        
        return $uniqueEvents
    }
    catch {
        Write-Error "Error removing duplicate events: $($_.Exception.Message)"
        return $Events
    }
}

# Export module functions
Export-ModuleMember -Function Get-GraphAccessToken, Get-UserDetails, Add-UserEnrichment, Get-SensitivityLabels, Add-SensitivityLabelEnrichment, Remove-DuplicateEvents
