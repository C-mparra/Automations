# Define logging function
function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$Timestamp - $Message"
}

Write-Log "Starting ConnectActive installation..."

# Retrieve Nilear API ID from NinjaOne Document
$NilearAPIID = Ninja-Property-Docs-Get 'Automation' 'nilearapi'

if (-not $NilearAPIID) {
    Write-Log "Error: Could not retrieve Nilear API ID from NinjaOne. Exiting."
    Exit 1
}

Write-Log "Loaded Nilear API ID: $NilearAPIID"

# Define API Base URL
$BaseAPIURL = "https://api.nilear.com/os/server/json/powershellUpload/$NilearAPIID"

# Verify PowerShell Version
if ($host.version.major -lt 3) {
    Write-Warning "PowerShell needs to be at least version 3. Exiting."
    Exit 1
}

# Ensure ConnectActive EventLog source exists
if (![System.Diagnostics.EventLog]::SourceExists("ConnectActive")) {
    New-EventLog -LogName Application -Source "ConnectActive"
}

Write-EventLog -LogName Application -Source "ConnectActive" -EntryType Information -EventID 1 -Category 0 -Message "Starting ConnectActive script."

# Check and load Active Directory module
if (!(Get-Module ActiveDirectory)) {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
}

if (!(Get-Module ActiveDirectory)) {
    Write-Log "Error: Failed to load Active Directory Module."
    Exit 1
}

Write-Log "Active Directory module loaded successfully."

# Force TLS v1.2 for security
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Function to upload data to Nilear
function Upload-ToNilear {
    param (
        [string]$DataType,
        [string]$Query
    )

    Write-Log "Retrieving ${DataType} data from Active Directory..."
    $adResults = Invoke-Expression $Query | ConvertTo-Json -Compress
    $adResults = '{"adObjects": ' + $adResults + '}'
    $adResults = ([System.Text.Encoding]::UTF8.GetBytes($adResults))

    # Upload data to Nilear
    $URL = "$BaseAPIURL/$DataType"
    try {
        $Response = Invoke-RestMethod -Uri $URL -ContentType "application/json" -Method POST -Body $adResults
        if ($Response -eq "SUCCESS") {
            Write-Log "${DataType} data successfully uploaded to Nilear."
            Write-EventLog -LogName Application -Source "ConnectActive" -EntryType Information -EventID 5 -Category 0 -Message "${DataType} data successfully uploaded."
        } else {
            Write-Log "Error uploading ${DataType} data to Nilear: ${Response}"
            Exit 1
        }
    } catch {
        Write-Log "API call failed for ${DataType}: $($_.Exception.Message)"
        Exit 1
    }
}

# Upload Users
Upload-ToNilear -DataType "users" -Query "Get-ADUser -Filter 'enabled -eq `$true' -Properties *"

# Upload Groups
Upload-ToNilear -DataType "groups" -Query "Get-ADGroup -Filter * -Properties *"

# Upload Organizational Units (OUs)
Upload-ToNilear -DataType "nodes" -Query "Get-ADOrganizationalUnit -Filter * -Properties *"

Write-Log "ConnectActive data upload completed successfully."
Write-Log "ConnectActive script has completed."
Exit 0
