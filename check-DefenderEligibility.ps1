#backup for new changed version
$psVersion = $host.Version.Major

# Function for PowerShell 3.0 & 4.0
$scriptPS34 = {
    Write-Host "� Running PowerShell 3/4 compatible script..." -ForegroundColor Yellow

    # Get OS Version Information
    $os = Get-WmiObject Win32_OperatingSystem
    $osVersion = $os.Version -as [version]
    $osCaption = $os.Caption

    # Define Minimum Eligible Versions
    $huntressMinServerVersion = [version]"6.1"  # Windows Server 2008 R2 and above
    $huntressMinWorkstationVersion = [version]"6.1.7601"  # Windows 7 and above

    $defenderMinServerVersion = [version]"10.0.0"  # Windows Server 2016 and above
    $defenderMinWorkstationVersion = [version]"10.0.0"  # Windows 10 and above

    # Determine if OS is a Server
    $isServer = ($osCaption -match "Server")

    # Check Huntress Eligibility
    if (($isServer -and $osVersion -ge $huntressMinServerVersion) -or (-not $isServer -and $osVersion -ge $huntressMinWorkstationVersion)) {
        ninja-property-set huntressEligible Yes
    } else {
        ninja-property-set huntressEligible No
    }

    # Check Windows Defender Eligibility
    if (($isServer -and $osVersion -ge $defenderMinServerVersion) -or (-not $isServer -and $osVersion -ge $defenderMinWorkstationVersion)) {
        ninja-property-set windefendEligible Yes
    } else {
        ninja-property-set windefendEligible No
    }
}

# Function for PowerShell 5+
$scriptPS5 = {
    Write-Host "� Running PowerShell 5+ script..." -ForegroundColor Cyan

    # Get OS Version Information
    $os = Get-CimInstance Win32_OperatingSystem
    $osVersion = [version]$os.Version
    $osCaption = $os.Caption

    # Define Minimum Eligible Versions
    $huntressMinServerVersion = [version]"6.1"  # Windows Server 2008 R2 and above
    $huntressMinWorkstationVersion = [version]"6.1.7601"  # Windows 7 and above

    $defenderMinServerVersion = [version]"10.0.0"  # Windows Server 2016 and above
    $defenderMinWorkstationVersion = [version]"10.0.0"  # Windows 10 and above

    # Determine if OS is a Server
    $isServer = ($osCaption -match "Server")

    # Check Huntress Eligibility
    if (($isServer -and $osVersion -ge $huntressMinServerVersion) -or (-not $isServer -and $osVersion -ge $huntressMinWorkstationVersion)) {
        ninja-property-set huntressEligible Yes
    } else {
        ninja-property-set huntressEligible No
    }

    # Check Windows Defender Eligibility
    if (($isServer -and $osVersion -ge $defenderMinServerVersion) -or (-not $isServer -and $osVersion -ge $defenderMinWorkstationVersion)) {
        ninja-property-set windefendEligible Yes
    } else {
        ninja-property-set windefendEligible No
    }
}

# Execute the appropriate script based on PowerShell version
if ($psVersion -eq 3 -or $psVersion -eq 4) {
    & $scriptPS34
} elseif ($psVersion -ge 5) {
    & $scriptPS5
} else {
    Write-Host "⚠️ Unsupported PowerShell version: $psVersion" -ForegroundColor Red
}
