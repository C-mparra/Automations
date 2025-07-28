function Get-DefenderStatus {
    $status = @{
        DefenderService = "Unknown"
        DefenderStartType = "Unknown"
        RealTimeProtection = "Unknown"
        BehaviorMonitoring = "Unknown"
        NetworkInspection = "Unknown"
        NetworkInspectionStartType = "Unknown"
        TamperProtection = "Unknown"
        EngineHealth = "Unknown"
        DefinitionAgeHours = "Unknown"
        CmdletResponsive = $false
    }

    try {
        $svc = Get-Service windefend -ErrorAction SilentlyContinue
        $nis = Get-Service WdNisSvc -ErrorAction SilentlyContinue
        $prefs = Get-MpPreference -ErrorAction SilentlyContinue

        $status.DefenderService = if ($svc) { $svc.Status } else { "Not Found" }
        $status.DefenderStartType = if ($svc) { $svc.StartType } else { "Unknown" }
        $status.NetworkInspection = if ($nis) { $nis.Status } else { "Not Found" }
        $status.NetworkInspectionStartType = if ($nis) { $nis.StartType } else { "Unknown" }
        $status.RealTimeProtection = if ($prefs.DisableRealtimeMonitoring -eq $false) { "Enabled" } else { "Disabled" }
        $status.BehaviorMonitoring = if ($prefs.DisableBehaviorMonitoring -eq $false) { "Enabled" } else { "Disabled" }

        if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
            if (Test-Path "HKLM:\Software\Microsoft\Windows Defender\Features") {
                $tp = Get-ItemPropertyValue -Path "HKLM:\Software\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue
                $status.TamperProtection = if ($tp -eq 5) { "Enabled" } else { "Disabled" }
            }
        } else {
            $status.TamperProtection = "N/A (Server OS)"
        }

        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $status.EngineHealth = if ($mp.AntivirusEnabled -and $mp.AMServiceEnabled -and $mp.RealTimeProtectionEnabled) { "Healthy" } else { "Issues" }

            $lastUpdate = $mp.AntispywareSignatureLastUpdated
            if ($lastUpdate) {
                $age = (New-TimeSpan -Start $lastUpdate -End (Get-Date)).TotalHours
                $status.DefinitionAgeHours = [math]::Round($age, 1)
            }

            $status.CmdletResponsive = $true
        } catch {
            $status.CmdletResponsive = $false
            $status.EngineHealth = "Unresponsive"
        }

        return $status
    } catch {
        return $null
    }
}

function Check-DefenderGpoSettings {
    Write-Output "`n----- GROUP POLICY REGISTRY OVERRIDES -----"
    $basePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    $rtPath = Join-Path $basePath "Real-Time Protection"

    if (-not (Test-Path $basePath)) {
        Write-Output "No Defender GPO keys found."
        return
    }

    $checkedValues = @{
        "DisableAntiSpyware" = "$basePath"
        "DisableAntiVirus" = "$basePath"
        "DisableRealtimeMonitoring" = "$rtPath"
        "DisableBehaviorMonitoring" = "$rtPath"
        "DisableOnAccessProtection" = "$rtPath"
        "DisableScanOnRealtimeEnable" = "$rtPath"
    }

    foreach ($kvp in $checkedValues.GetEnumerator()) {
        $path = $kvp.Value
        $name = $kvp.Key
        try {
            $val = Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue
            if ($val -eq 1) {
                Write-Output "$name : BLOCKING (1) at $path"
            } elseif ($val -eq 0) {
                Write-Output "$name : Allowed (0) at $path"
            }
        } catch {
            Write-Output "$name : Not Present"
        }
    }
}


function Get-DefenderRegistryStatus {
    $regStatus = @{
        DisableAntiSpyware = "Not Set"
        DisableAntiVirus = "Not Set"
        RealTimeProtectionPolicies = @{}
    }

    $basePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    $rtpPath = Join-Path $basePath "Real-Time Protection"

    if (Test-Path $basePath) {
        try {
            $regStatus.DisableAntiSpyware = (Get-ItemPropertyValue -Path $basePath -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue)
        } catch {}
        try {
            $regStatus.DisableAntiVirus = (Get-ItemPropertyValue -Path $basePath -Name "DisableAntiVirus" -ErrorAction SilentlyContinue)
        } catch {}
    }

    if (Test-Path $rtpPath) {
        foreach ($name in @("DisableBehaviorMonitoring", "DisableOnAccessProtection", "DisableScanOnRealtimeEnable", "DisableRealtimeMonitoring")) {
            try {
                $val = Get-ItemPropertyValue -Path $rtpPath -Name $name -ErrorAction SilentlyContinue
                if ($val -ne $null) {
                    $regStatus.RealTimeProtectionPolicies[$name] = $val
                }
            } catch {}
        }
    }

    return $regStatus
}

function Test-DefenderFeatureInstalled {
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName Windows-Defender | Select-Object -ExpandProperty State
        return $feature -eq "Enabled"
    } catch {
        return $false
    }
}

function Set-DefenderPolicy {
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" `
        -Name "DisableAntiSpyware" -Value 0 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null

    $rtPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
    if (-not (Test-Path $rtPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "Real-Time Protection" -Force | Out-Null
    }

    New-ItemProperty -Path $rtPath -Name "DisableBehaviorMonitoring" -Value 0 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path $rtPath -Name "DisableOnAccessProtection" -Value 0 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path $rtPath -Name "DisableScanOnRealtimeEnable" -Value 0 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
}

function Set-DefenderPreferences {
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
}

function Get-ThirdPartyAV {
    try {
        $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntivirusProduct -ErrorAction Stop

        $nonDefenderAVs = $avProducts | Where-Object {
            $dn = $_.displayName.ToLower()
            -not ($dn -match "windows defender" -or $dn -match "microsoft defender" -or $dn -match "security essentials")
        }

        if ($nonDefenderAVs) {
            Write-Output "`nThird-party antivirus detected:"
            $nonDefenderAVs | ForEach-Object { Write-Output "- $($_.displayName)" }
        } else {
            Write-Output "No third-party antivirus detected."
        }
    } catch {
        Write-Output "Unable to check for third-party antivirus."
    }
}

function Get-DefenderEventLog {
    Write-Output "`nRecent Defender-related errors (last 10 minutes):"
    try {
        $events = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -ErrorAction Stop |
            Where-Object { $_.TimeCreated -gt (Get-Date).AddMinutes(-10) -and $_.LevelDisplayName -in @("Error", "Critical") }

        if ($events.Count -eq 0) {
            Write-Output "No recent critical Defender errors found."
        } else {
            foreach ($evt in $events) {
                Write-Output "- [$($evt.TimeCreated)] $($evt.Id): $($evt.Message)"
            }
        }
    } catch {
        Write-Output "Failed to read Defender event log: $_"
    }
}

# --- MAIN EXECUTION ---

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $osName = $os.Caption
    $osVersion = $os.Version
    $osBuild = $os.BuildNumber
    $arch = (Get-CimInstance Win32_Processor).AddressWidth

    Write-Output "----- SYSTEM INFO -----"
    Write-Output "OS: $osName"
    Write-Output "Version: $osVersion (Build $osBuild)"
    Write-Output "Architecture: $arch-bit"

    $defenderSupport = "Likely Supported"

    if ($osName -match "LTSC" -or $osVersion -eq "10.0.17763") {
        $defenderSupport = "Limited (LTSC - GUI/WMI may be missing)"
        Write-Output "Detected: LTSC Edition (Defender features may be limited or missing)."
    }
    elseif ($osName -match "Windows Server") {
        $defenderSupport = "Manual Install Required"
        Write-Output "Detected: Windows Server (Defender must be manually enabled)."
    }
    elseif ($osName -match "N Edition" -or $osName -match "KN Edition") {
        Write-Output "Detected: N/KN Edition (UI components may be missing)."
    }

    # Check for S Mode
    try {
        $regPath = "HKLM:\SYSTEM\Setup\State"
        if ((Get-ItemProperty -Path $regPath -Name "ImageState" -ErrorAction SilentlyContinue) -match "SMode") {
            $defenderSupport = "Supported (S Mode - Defender enforced)"
            Write-Output "Detected: Windows in S Mode (Defender is required and enforced)."
        }
    } catch {}

    Write-Output "Defender Compatibility: $defenderSupport"
    Write-Output "------------------------`n"
} catch {
    Write-Output "Unable to retrieve OS info."
}
Check-DefenderGpoSettings


Write-Output "Enabling Microsoft Defender..."

Set-DefenderPolicy
Set-DefenderPreferences

Start-Service -Name "WinDefend" -ErrorAction SilentlyContinue
Set-Service -Name "WinDefend" -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name "WdNisSvc" -ErrorAction SilentlyContinue
Set-Service -Name "WdNisSvc" -StartupType Automatic -ErrorAction SilentlyContinue

# Confirm Defender stays running
$stable = $false
for ($i = 0; $i -lt 6; $i++) {
    Start-Sleep -Seconds 5
    $svc = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        $stable = $true
    } else {
        $stable = $false
        break
    }
}

$status = Get-DefenderStatus

if ($stable -and $status -and
    $status.DefenderService -eq "Running" -and
    $status.RealTimeProtection -eq "Enabled" -and
    $status.BehaviorMonitoring -eq "Enabled") {

    Write-Output "Defender is enabled and running normally."

} else {
    Write-Output "`nWARNING: Defender may not be fully functional. Please review the status below."

    Write-Output "`n----- WINDOWS DEFENDER STATUS -----"
    Write-Output "Defender Service: $($status.DefenderService) (StartType: $($status.DefenderStartType))"
    Write-Output "Realtime Protection: $($status.RealTimeProtection)"
    Write-Output "Behavior Monitoring: $($status.BehaviorMonitoring)"
    Write-Output "Network Inspection: $($status.NetworkInspection) (StartType: $($status.NetworkInspectionStartType))"
    Write-Output "Tamper Protection: $($status.TamperProtection)"
    Write-Output "Engine Health: $($status.EngineHealth)"
    Write-Output "Definition Age (hours): $($status.DefinitionAgeHours)"
    Write-Output "Cmdlets Responsive: $($status.CmdletResponsive)"
    Write-Output "-----------------------------------"

    Get-ThirdPartyAV
    Get-DefenderEventLog

    $featureInstalled = Test-DefenderFeatureInstalled
    $registryStatus = Get-DefenderRegistryStatus

    Write-Output "`n----- ADDITIONAL DIAGNOSTICS -----"
    Write-Output "Defender feature installed: $featureInstalled"
    Write-Output "DisableAntiSpyware: $($registryStatus.DisableAntiSpyware)"
    Write-Output "DisableAntiVirus: $($registryStatus.DisableAntiVirus)"

    if ($registryStatus.RealTimeProtectionPolicies.Count -gt 0) {
        Write-Output "Real-Time Protection policy overrides:"
        foreach ($kvp in $registryStatus.RealTimeProtectionPolicies.GetEnumerator()) {
            Write-Output "- $($kvp.Key): $($kvp.Value)"
        }
    } else {
        Write-Output "No Real-Time Protection policy overrides detected."
    }
    Write-Output "-----------------------------------"

}

exit 0
