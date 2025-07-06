# LogAnalytics PowerShell Module
# Handles Log Analytics workspace data ingestion

function Send-LogAnalyticsData {
    <#
    .SYNOPSIS
    Sends data to Log Analytics workspace using HTTP Data Collector API
    
    .DESCRIPTION
    Takes JSON data and sends it to a Log Analytics workspace custom log table
    
    .PARAMETER WorkspaceId
    The Log Analytics workspace ID
    
    .PARAMETER WorkspaceKey
    The Log Analytics workspace shared key
    
    .PARAMETER LogType
    The custom log table name (without _CL suffix)
    
    .PARAMETER JsonData
    The data to send as JSON string
    
    .PARAMETER TimeStampField
    Optional field name to use as the timestamp
    
    .EXAMPLE
    Send-LogAnalyticsData -WorkspaceId "workspace-id" -WorkspaceKey "key" -LogType "M365ExchangeAudit" -JsonData $jsonData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [string]$LogType,
        
        [Parameter(Mandatory = $true)]
        [string]$JsonData,
        
        [Parameter(Mandatory = $false)]
        [string]$TimeStampField = ""
    )
    
    try {
        # Create the function to create the authorization signature
        function Build-Signature {
            param(
                [string]$customerId,
                [string]$sharedKey,
                [string]$date,
                [int]$contentLength,
                [string]$method,
                [string]$contentType,
                [string]$resource
            )
            
            $xHeaders = "x-ms-date:" + $date
            $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
            
            $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
            $keyBytes = [Convert]::FromBase64String($sharedKey)
            
            $sha256 = New-Object System.Security.Cryptography.HMACSHA256
            $sha256.Key = $keyBytes
            $calculatedHash = $sha256.ComputeHash($bytesToHash)
            $encodedHash = [Convert]::ToBase64String($calculatedHash)
            $authorization = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
            return $authorization
        }
        
        # Create the function to create and post the request
        $method = "POST"
        $contentType = "application/json"
        $resource = "/api/logs"
        $rfc1123date = [DateTime]::UtcNow.ToString("r")
        $contentLength = ([System.Text.Encoding]::UTF8.GetBytes($JsonData)).Length
        $signature = Build-Signature -customerId $WorkspaceId -sharedKey $WorkspaceKey -date $rfc1123date -contentLength $contentLength -method $method -contentType $contentType -resource $resource
        
        $uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
        
        $headers = @{
            "Authorization"        = $signature
            "Log-Type"            = $LogType
            "x-ms-date"           = $rfc1123date
            "time-generated-field" = $TimeStampField
        }
        
        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $JsonData -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Information "Successfully sent data to Log Analytics table: $LogType"
            return $true
        }
        else {
            Write-Error "Failed to send data to Log Analytics. Status Code: $($response.StatusCode)"
            return $false
        }
    }
    catch {
        Write-Error "Error sending data to Log Analytics: $($_.Exception.Message)"
        throw
    }
}

function Format-LogAnalyticsData {
    <#
    .SYNOPSIS
    Formats data for Log Analytics ingestion
    
    .DESCRIPTION
    Converts PowerShell objects to JSON format suitable for Log Analytics ingestion
    
    .PARAMETER Data
    The data objects to format
    
    .PARAMETER MaxBatchSize
    Maximum number of records per batch (default: 1000)
    
    .EXAMPLE
    $formatted = Format-LogAnalyticsData -Data $auditLogs -MaxBatchSize 500
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxBatchSize = 1000
    )
    
    try {
        if (-not $Data -or $Data.Count -eq 0) {
            Write-Information "No data to format"
            return @()
        }
        
        # Split data into batches
        $batches = @()
        for ($i = 0; $i -lt $Data.Count; $i += $MaxBatchSize) {
            $end = [Math]::Min($i + $MaxBatchSize - 1, $Data.Count - 1)
            $batch = $Data[$i..$end]
            
            # Convert to JSON
            $jsonBatch = $batch | ConvertTo-Json -Depth 10 -Compress
            
            $batches += @{
                Data = $jsonBatch
                RecordCount = $batch.Count
            }
        }
        
        Write-Information "Formatted $($Data.Count) records into $($batches.Count) batches"
        return $batches
    }
    catch {
        Write-Error "Error formatting data for Log Analytics: $($_.Exception.Message)"
        throw
    }
}

function Get-LogTypeFromContentType {
    <#
    .SYNOPSIS
    Maps O365 content types to Log Analytics table names
    
    .DESCRIPTION
    Returns the appropriate Log Analytics custom log table name for a given O365 content type
    
    .PARAMETER ContentType
    The O365 Management API content type
    
    .EXAMPLE
    $logType = Get-LogTypeFromContentType -ContentType "Audit.Exchange"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContentType
    )
    
    $mapping = @{
        'Audit.Exchange'            = 'M365ExchangeAudit'
        'Audit.SharePoint'          = 'M365SharePointAudit'
        'Audit.AzureActiveDirectory' = 'M365AzureADAudit'
        'Audit.General'             = 'M365TeamsAudit'
        'DLP.All'                   = 'M365DLPEvents'
    }
    
    if ($mapping.ContainsKey($ContentType)) {
        return $mapping[$ContentType]
    }
    else {
        Write-Warning "Unknown content type: $ContentType. Using generic table name."
        return 'M365UnknownAudit'
    }
}

function Send-CollectionSummary {
    <#
    .SYNOPSIS
    Sends collection summary data to Log Analytics
    
    .DESCRIPTION
    Records collection statistics and health information for monitoring
    
    .PARAMETER WorkspaceId
    The Log Analytics workspace ID
    
    .PARAMETER WorkspaceKey
    The Log Analytics workspace shared key
    
    .PARAMETER Summary
    The collection summary object
    
    .EXAMPLE
    Send-CollectionSummary -WorkspaceId "workspace-id" -WorkspaceKey "key" -Summary $summaryData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [object]$Summary
    )
    
    try {
        $jsonData = $Summary | ConvertTo-Json -Depth 5 -Compress
        
        $result = Send-LogAnalyticsData -WorkspaceId $WorkspaceId -WorkspaceKey $WorkspaceKey -LogType "M365AuditCollectionSummary" -JsonData $jsonData
        
        if ($result) {
            Write-Information "Collection summary sent successfully"
        }
        else {
            Write-Error "Failed to send collection summary"
        }
        
        return $result
    }
    catch {
        Write-Error "Error sending collection summary: $($_.Exception.Message)"
        throw
    }
}

function Send-CollectionError {
    <#
    .SYNOPSIS
    Sends error information to Log Analytics
    
    .DESCRIPTION
    Records collection errors for troubleshooting and monitoring
    
    .PARAMETER WorkspaceId
    The Log Analytics workspace ID
    
    .PARAMETER WorkspaceKey
    The Log Analytics workspace shared key
    
    .PARAMETER ErrorData
    The error information object
    
    .EXAMPLE
    Send-CollectionError -WorkspaceId "workspace-id" -WorkspaceKey "key" -ErrorData $errorInfo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [object]$ErrorData
    )
    
    try {
        $jsonData = $ErrorData | ConvertTo-Json -Depth 5 -Compress
        
        $result = Send-LogAnalyticsData -WorkspaceId $WorkspaceId -WorkspaceKey $WorkspaceKey -LogType "M365AuditCollectionErrors" -JsonData $jsonData
        
        if ($result) {
            Write-Information "Collection error sent successfully"
        }
        else {
            Write-Error "Failed to send collection error"
        }
        
        return $result
    }
    catch {
        Write-Error "Error sending collection error: $($_.Exception.Message)"
        throw
    }
}

# Export module functions
Export-ModuleMember -Function Send-LogAnalyticsData, Format-LogAnalyticsData, Get-LogTypeFromContentType, Send-CollectionSummary, Send-CollectionError
