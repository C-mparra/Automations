$computerName = $env:COMPUTERNAME
$domainName = (Get-WmiObject Win32_ComputerSystem).Domain
$outputFolder = "C:\Temp"

if (-not (Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
}

# Get list of approved admin usernames from Ninja custom field
try {
    $approvedRaw = Ninja-Property-Get approvedToBeAdmins
    if (-not $approvedRaw) {
        Write-Output "No users listed in approvedToBeAdmins field."
        $approvedAccounts = @()
    } else {
        $approvedAccounts = $approvedRaw -split '[,;]' | ForEach-Object { $_.Trim().ToLower() }
    }
} catch {
    Write-Output "No currently approved accounts in custom field."
    $approvedAccounts = @()
}

# Determine PowerShell version
$psMajorVersion = $PSVersionTable.PSVersion.Major

$localAdmins = @()
$useFallback = $false

if ($psMajorVersion -ge 5) {
    try {
        $localAdmins = Get-LocalGroupMember -Group "Administrators"
    } catch {
        Write-Warning "Falling back to legacy method: $_"
        $useFallback = $true
    }
} else {
    Write-Output "PowerShell version too old, using fallback method."
    $useFallback = $true
}

# Use fallback if necessary
if ($useFallback) {
    try {
        $localAdmins = net localgroup administrators | Where-Object {
            $_ -and ($_ -notmatch "command completed") -and ($_ -notmatch "^-+$") -and ($_ -notmatch "Alias name") -and ($_ -notmatch "comment") -and ($_ -notmatch "^Members")
        } | ForEach-Object {
            [PSCustomObject]@{ Name = $_.Trim(); ObjectClass = "User" }
        }
    } catch {
        Write-Error "Unable to retrieve local group members: $_"
        exit 0
    }
}

$flaggedAccounts = @()

foreach ($admin in $localAdmins) {
    $username = $admin.Name
    $isGroup = ($admin.ObjectClass -eq 'Group')

    if ($isGroup -and $username -match "Domain Admins") {
        continue
    }

    $shortName = $username -replace "^$computerName\\", "" -replace "^$domainName\\", ""
    $normalized = $shortName.ToLower()

    if ($approvedAccounts -contains $normalized) {
        continue
    }

    if ($normalized -match "administrator|admin$") {
        continue
    }

    $lastLogon = "Unavailable"

    try {
        if ($psMajorVersion -ge 5) {
            $localUser = Get-LocalUser -Name $shortName -ErrorAction Stop
            if ($localUser.LastLogon) {
                $lastLogon = $localUser.LastLogon
            } else {
                $lastLogon = "Never logged in (Inactive > 30 days)"
            }
        } else {
            throw "Local user check unsupported in PowerShell < 5"
        }
    } catch {
        try {
            $adUser = Get-ADUser -Identity $shortName -Properties LastLogonDate -ErrorAction Stop
            if ($adUser.LastLogonDate) {
                $lastLogon = $adUser.LastLogonDate
            } else {
                $lastLogon = "Never logged in (Inactive > 30 days)"
            }
        } catch {
            $lastLogon = "Unavailable"
        }
    }

    $entry = [PSCustomObject]@{
        Computer    = $computerName
        Username    = $username
        LastLogon   = $lastLogon
        DetectedAt  = Get-Date
    }

    $flaggedAccounts += $entry
}

# Prepare the unapproved admins information as a string with last logon
$unapprovedAdminsInfo = $flaggedAccounts | ForEach-Object {
    "$($_.Username) - Last logon: $($_.LastLogon)"
} | Out-String

# Trim trailing newline from string
$unapprovedAdminsInfo = $unapprovedAdminsInfo.Trim()

# Write to NinjaOne custom field using Ninja-Property-Set
if ($flaggedAccounts.Count -gt 0) {
    try {
        Ninja-Property-Set unapprovedAdmins $unapprovedAdminsInfo
        Write-Output "Unapproved admin information has been written to the custom field."
    } catch {
        Write-Error "Failed to update the custom field in NinjaOne: $_"
    }

    Write-Output "Unapproved admin accounts found:"
    $flaggedAccounts | ForEach-Object {
        Write-Output "$($_.Username) on $($_.Computer) | Last logon: $($_.LastLogon)"
    }
} else {
    Write-Output "No unauthorized local admin accounts found."
}

exit 0
