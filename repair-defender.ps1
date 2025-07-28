$MaxAttempts = 3
$Attempt = 0
$NeedsRepair = $true
$FailedReasons = @()

function Test-DefenderFeatureInstalled {
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft.Windows.Defender" -ErrorAction Stop
        return $feature.State -eq "Enabled"
    } catch {
        $script:FailedReasons += "Failed to query Defender feature state"
        return $false
    }
}

function Install-DefenderFeature {
    Write-Output "Attempting to install Microsoft Defender capability..."
    try {
        dism.exe /Online /Add-Capability /CapabilityName:Microsoft.Windows.Defender~~~~0.0.1.0 | Out-Null
        Write-Output "Defender capability installation attempted."
    } catch {
        $script:FailedReasons += "Failed to install Defender capability using DISM"
    }
}

function Get-DefenderStatus {
    try {
        $svc = Get-Service windefend -ErrorAction SilentlyContinue
        $prefs = Get-MpPreference -ErrorAction SilentlyContinue
        $nis = Get-Service WdNisSvc -ErrorAction SilentlyContinue
        $tamper = "Unknown"

        if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
            if (Test-Path "HKLM:\Software\Microsoft\Windows Defender\Features") {
                $tp = Get-ItemPropertyValue -Path "HKLM:\Software\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue
                $tamper = if ($tp -eq 5) { "Enabled" } else { "Disabled" }
            }
        } else {
            $tamper = "N/A (Server OS)"
        }

        return @{
            DefenderService = if ($svc) { $svc.Status } else { "Not Found" }
            RealTimeProtection = if ($prefs.DisableRealtimeMonitoring -eq $false) { "Enabled" } else { "Disabled" }
            BehaviorMonitoring = if ($prefs.DisableBehaviorMonitoring -eq $false) { "Enabled" } else { "Disabled" }
            TamperProtection = $tamper
        }
    } catch {
        return $null
    }
}

function Set-DefenderConfiguration {
    try {
        Set-Service -Name "WinDefend" -StartupType Automatic -ErrorAction SilentlyContinue
        Set-Service -Name "WdNisSvc" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "WinDefend" -ErrorAction SilentlyContinue
        Start-Service -Name "WdNisSvc" -ErrorAction SilentlyContinue
    } catch {
        $script:FailedReasons += "Could not start Defender services"
    }

    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    } catch {
        $script:FailedReasons += "Failed to configure Defender preferences (cmdlets may be broken or blocked)"
    }
}

function Repair-DefenderPlatform {
    $platform = Get-ChildItem "C:\ProgramData\Microsoft\Windows Defender\Platform" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1

    if (-not $platform) {
        $script:FailedReasons += "Defender Platform folder not found"
        return
    }

    $mofPath = Join-Path $platform.FullName "MsSecWMI.mof"

    if (-not (Test-Path $mofPath)) {
        $script:FailedReasons += "MsSecWMI.mof not found in Defender Platform"
    } else {
        Write-Output "Recompiling MsSecWMI.mof..."
        mofcomp $mofPath | Out-Null
    }
}

function Invoke-DefenderRepair {
    param([bool]$RunDismSfc = $false)

    Write-Output "Attempting Defender repair (DISM/SFC: $RunDismSfc)..."

    $binary = "C:\Program Files\Windows Defender\MsMpEng.exe"
    if (-not (Test-Path $binary)) {
        $script:FailedReasons += "Defender binary missing: MsMpEng.exe"
    }

    Set-DefenderConfiguration

    if ($RunDismSfc) {
        try {
            Write-Output "Running DISM RestoreHealth..."
            dism.exe /Online /Cleanup-Image /RestoreHealth | Out-Null

            Write-Output "Running System File Checker..."
            sfc /scannow | Out-Null
        } catch {
            $script:FailedReasons += "DISM or SFC failed to execute"
        }
    }

    Repair-DefenderPlatform
}

# Initial feature check
if (-not (Test-DefenderFeatureInstalled)) {
    Write-Output "Microsoft Defender is not installed. Attempting to install..."
    Install-DefenderFeature
    Start-Sleep -Seconds 10
}

# Check for active third-party antivirus in Security Center
try {
    $avRegistered = Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntivirusProduct -ErrorAction Stop |
    Where-Object {
        $dn = $_.displayName.ToLower()
        -not ($dn -match "windows defender" -or $dn -match "microsoft defender")
    }

    if ($avRegistered) {
        # Check if Malwarebytes is among the detected AV products
        $hasMWB = $avRegistered | Where-Object { $_.displayName -like "*Malwarebytes*" }

        if ($hasMWB) {
            Write-Output "Malwarebytes detected in Security Center. Proceeding with Defender repair attempts."
        } else {
            Write-Output "Another third-party antivirus product detected:"
            $avRegistered | ForEach-Object { Write-Output "- $($_.displayName)" }
            Write-Output "Microsoft Defender will remain disabled while another AV is active."
            Write-Output "Exiting without attempting repair."
            exit 0
        }
    } else {
        Write-Output "No third-party antivirus products detected."
    }
} catch {
    Write-Output "Unable to query Security Center for AV status: $_"
}


# Main repair loop
while ($NeedsRepair -and $Attempt -lt $MaxAttempts) {
    $Attempt++
    Write-Output "`nRepair attempt $Attempt of $MaxAttempts"
    $runDism = ($Attempt -eq 1)
    $FailedReasons = @()

    Invoke-DefenderRepair -RunDismSfc:$runDism

    Start-Sleep -Seconds 10
    $status = Get-DefenderStatus

    if ($status -and $status.DefenderService -eq "Running" -and $status.RealTimeProtection -eq "Enabled" -and $status.BehaviorMonitoring -eq "Enabled") {
        $NeedsRepair = $false
        Write-Output "`nDefender appears to be working correctly after repair."
    } else {
        if ($Attempt -eq $MaxAttempts) {
            Write-Output "`nDefender repair failed after $MaxAttempts attempts."

            Write-Output "`n---- DIAGNOSTIC SUMMARY ----"
            if ($status) {
                Write-Output "Defender Service: $($status.DefenderService)"
                Write-Output "Real-Time Protection: $($status.RealTimeProtection)"
                Write-Output "Behavior Monitoring: $($status.BehaviorMonitoring)"
                Write-Output "Tamper Protection: $($status.TamperProtection)"
            } else {
                Write-Output "Could not retrieve Defender status."
            }

            if ($FailedReasons.Count -gt 0) {
                Write-Output "`nPotential reasons for failure:"
                foreach ($reason in $FailedReasons) {
                    Write-Output "- $reason"
                }
            } else {
                Write-Output "No specific failure reasons captured."
            }

            Write-Output "`nPlease investigate manually or escalate for advanced repair."
        } else {
            Write-Output "Repair incomplete. Retrying..."
        }
    }
}

exit 0
