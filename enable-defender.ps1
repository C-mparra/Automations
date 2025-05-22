# Enable-Defender.ps1
# Attempts to enable Microsoft Defender; reports only if unsuccessful


function Get-DefenderStatus {
    try {
        $defenderService = Get-Service windefend -ErrorAction SilentlyContinue
        $defenderPrefs = Get-MpPreference -ErrorAction SilentlyContinue
        $nisService = Get-Service WdNisSvc -ErrorAction SilentlyContinue
        $tamperProtection = "Unknown"

        if ((Get-CimInstance -ClassName win32_operatingsystem).producttype -eq 1) {
            try {
                if (Test-Path "HKLM:\Software\Microsoft\Windows Defender\Features") {
                    $tpValue = Get-ItemPropertyValue -Path "HKLM:\Software\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue
                    $tamperProtection = if ($tpValue -eq 5) { "Enabled" } else { "Disabled" }
                } else {
                    $tamperProtection = "Registry Key Not Found"
                }
            } catch {
                $tamperProtection = "Error checking"
            }
        } else {
            $tamperProtection = "N/A (Server OS)"
        }

        return @{
            DefenderService = if ($defenderService) { $defenderService.Status } else { "Not Found" }
            DefenderStartType = if ($defenderService) { $defenderService.StartType } else { "Unknown" }
            RealTimeProtection = if ($defenderPrefs.DisableRealtimeMonitoring -eq $false) { "Enabled" } else { "Disabled" }
            BehaviorMonitoring = if ($defenderPrefs.DisableBehaviorMonitoring -eq $false) { "Enabled" } else { "Disabled" }
            NetworkInspection = if ($nisService) { $nisService.Status } else { "Not Found" }
            NetworkInspectionStartType = if ($nisService) { $nisService.StartType } else { "Unknown" }
            TamperProtection = $tamperProtection
        }
    } catch {
        return $null
    }
}

function Start-DefenderService {
    param($Name, $DisplayName)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        Set-Service -Name $Name -StartupType Automatic -ErrorAction SilentlyContinue
        if ($svc.Status -ne 'Running') {
            Start-Service -Name $Name -ErrorAction SilentlyContinue
        }
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
        if ($avProducts) {
            Write-Output "`nThird-party antivirus detected:"
            $avProducts | ForEach-Object { Write-Output "- $($_.displayName)" }
        } else {
            Write-Output "No third-party antivirus detected."
        }
    } catch {
        Write-Output "Unable to check for third-party antivirus."
    }
}

# --- MAIN EXECUTION ---

Write-Output "Enabling Microsoft Defender..."

# Apply settings and start services
Set-DefenderPolicy
Set-DefenderPreferences
Start-DefenderService -Name "WinDefend" -DisplayName "Microsoft Defender Antivirus Service"
Start-DefenderService -Name "WdNisSvc" -DisplayName "Microsoft Defender Network Inspection Service"

Start-Sleep -Seconds 10

$status = Get-DefenderStatus

# Determine success
$defenderOK = (
    $status -and
    $status.DefenderService -eq "Running" -and
    $status.RealTimeProtection -eq "Enabled" -and
    $status.BehaviorMonitoring -eq "Enabled"
)

if ($defenderOK) {
    Write-Output "Defender is enabled and running normally."
} else {
    Write-Output "`nWARNING: Defender may not be fully functional. Please review the status below."

    Write-Output "`n----- WINDOWS DEFENDER STATUS -----"
    Write-Output "Defender Service: $($status.DefenderService) (StartType: $($status.DefenderStartType))"
    Write-Output "Realtime Protection: $($status.RealTimeProtection)"
    Write-Output "Behavior Monitoring: $($status.BehaviorMonitoring)"
    Write-Output "Network Inspection: $($status.NetworkInspection) (StartType: $($status.NetworkInspectionStartType))"
    Write-Output "Tamper Protection: $($status.TamperProtection)"
    Write-Output "-----------------------------------"

    Get-ThirdPartyAV
    Write-Output "`nNext step: Run the Defender repair script to attempt restoration."
}

exit 0
