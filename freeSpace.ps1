$Drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$TotalSizeGB = [math]::Round($Drive.Size / 1GB, 2)
$FreeSpaceGB = [math]::Round($Drive.FreeSpace / 1GB, 2)
$FreePercentBefore = [math]::Round(($Drive.FreeSpace / $Drive.Size) * 100, 2)

Write-Output "Disk Space Before Cleanup:"
Write-Output "  Free Space: $FreeSpaceGB GB"
Write-Output "  Total Size: $TotalSizeGB GB"
Write-Output "  Free Percentage: $FreePercentBefore %"

# Clear Recycle Bin
try {
    Get-ChildItem -Path 'C:\$Recycle.Bin' -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
} catch {
    Write-Output "ERROR: Could not access Recycle Bin - $_"
}

# Clear user temp and INetCache
$Users = Get-ChildItem -Path 'C:\Users' -Directory
foreach ($User in $Users) {
    foreach ($Path in @('AppData\Local\Temp', 'AppData\Local\Microsoft\Windows\INetCache')) {
        $FullPath = Join-Path -Path $User.FullName -ChildPath $Path
        if (Test-Path $FullPath) {
            try {
                Remove-Item -Path "$FullPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Output "ERROR: Failed to clear $FullPath - $_"
            }
        }
    }
}

# Clear system temp
$SystemTempPath = "C:\Windows\Temp"
if (Test-Path $SystemTempPath) {
    try {
        Remove-Item -Path "$SystemTempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Output "ERROR: Failed to clear $SystemTempPath - $_"
    }
}

# DISM Cleanup — skip if reboot pending
$PendingReboot = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'

if ($PendingReboot) {
    Write-Output "DISM skipped: Pending reboot detected."
} else {
    try {
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online", "/Cleanup-Image", "/StartComponentCleanup" -NoNewWindow -Wait

    } catch {
        Write-Output "ERROR: DISM cleanup failed - $_"
    }
}

# Windows Update Cache Cleanup
try {
    Stop-Service -Name "wuauserv" -Force
    Start-Sleep -Seconds 5
    try {
        Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction Stop
    } catch {
        # Take ownership and retry
        takeown /F "C:\Windows\SoftwareDistribution\Download" /R /D Y | Out-Null
        icacls "C:\Windows\SoftwareDistribution\Download" /grant SYSTEM:F /T | Out-Null
        try {
            Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Output "ERROR: Windows Update cache cleanup failed after permissions fix."
        }
    } finally {
        Start-Service -Name "wuauserv"
    }
} catch {
    Write-Output "ERROR: Could not stop Windows Update service - $_"
}

# Prefetch Cleanup
$PrefetchPath = "C:\Windows\Prefetch"
if (Test-Path $PrefetchPath) {
    try {
        Remove-Item -Path "$PrefetchPath\*" -Force -ErrorAction SilentlyContinue -Confirm:$false
    } catch {
        Write-Output "ERROR: Failed to clear prefetch - $_"
    }
}

# Disable hibernation
try {
    powercfg -h off
} catch {
    Write-Output "ERROR: Could not disable hibernation - $_"
}

# Clear browser cache (again for good measure)
foreach ($User in $Users) {
    $CachePath = Join-Path -Path $User.FullName -ChildPath 'AppData\Local\Microsoft\Windows\INetCache'
    if (Test-Path $CachePath) {
        try {
            Remove-Item -Path "$CachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Output "ERROR: Could not clear IE/Edge cache - $CachePath - $_"
        }
    }
}

# Clear Windows Error Reporting
$WERPath = "C:\ProgramData\Microsoft\Windows\WER"
if (Test-Path $WERPath) {
    try {
        Remove-Item -Path "$WERPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Output "ERROR: Could not clear WER files - $_"
    }
}

# Clear Downloaded Program Files
$DPFPath = "C:\Windows\Downloaded Program Files"
if (Test-Path $DPFPath) {
    try {
        Remove-Item -Path "$DPFPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Output "ERROR: Could not clear Downloaded Program Files - $_"
    }
}


$SQLDetected = $false
$SQLServices = Get-Service | Where-Object { $_.Name -like "MSSQL*" -or $_.Name -like "SQLAgent*" }
if ($SQLServices) { $SQLDetected = $true }

$SQLRegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"
if (Test-Path $SQLRegPath) { $SQLDetected = $true }

if ($SQLDetected) {
    Write-Output "INFO: SQL Server detected. Skipping Windows Installer orphan cleanup."
} else {
    # Orphaned MSI registry keys
    $RegistryKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products")
    foreach ($RegPath in $RegistryKeys) {
        if (Test-Path $RegPath) {
            Get-ChildItem -Path $RegPath | ForEach-Object {
                $InstallProps = "$($_.PSPath)\InstallProperties"
                if (!(Test-Path $InstallProps)) {
                    try {
                        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        Write-Output "ERROR: Failed to remove orphaned MSI key - $_"
                    }
                }
            }
        }
    }

    # Orphaned MSI files
    $InstallerPath = "C:\Windows\Installer"
    if (Test-Path $InstallerPath) {
        try {
            $UsedFiles = Get-WmiObject -Query "SELECT Name FROM Win32_Product" | ForEach-Object { $_.Name }
            Get-ChildItem -Path $InstallerPath -Recurse | Where-Object {
                $_.Name -match ".*\.msi|.*\.msp" -and $UsedFiles -notcontains $_.Name
            } | ForEach-Object {
                Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Output "ERROR: Failed during MSI orphan file cleanup - $_"
        }
    }
}

$Drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$FreeSpaceAfterGB = [math]::Round($Drive.FreeSpace / 1GB, 2)
$FreePercentAfter = [math]::Round(($Drive.FreeSpace / $Drive.Size) * 100, 2)
$TargetPercent = 20

Write-Output "Disk Space After Cleanup:"
Write-Output "  Free Space: $FreeSpaceAfterGB GB"
Write-Output "  Free Percentage: $FreePercentAfter %"

if ($FreePercentAfter -lt $TargetPercent) {
    $TargetBytes = $Drive.Size * ($TargetPercent / 100)
    $BytesNeeded = $TargetBytes - $Drive.FreeSpace
    $MBNeeded = [math]::Round($BytesNeeded / 1MB, 2)
    Write-Output "WARNING: Still below $TargetPercent% free. Need to clear an additional $MBNeeded MB to reach target."
} else {
    Write-Output "Disk space is above $TargetPercent% threshold. No further action needed."
}

Write-Output "System cleanup complete."
exit 0
