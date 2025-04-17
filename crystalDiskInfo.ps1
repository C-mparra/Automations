function checkChoco {
    if (!(Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Output "Chocolatey not found. Installing..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } else {
        Write-Output "Chocolatey is already installed."
    }
}

# : Install CrystalDiskInfo if not present
function installCrystalDiskInfo {
    $installPath = "$env:ProgramFiles\CrystalDiskInfo"
    if (-not (Test-Path $installPath)) {
        Write-Output "Installing CrystalDiskInfo via Chocolatey..."
        choco install crystaldiskinfo -y --no-progress
        Start-Sleep -Seconds 5
    } else {
        Write-Output "CrystalDiskInfo already installed at $installPath"
    }
}

function Get-SMARTStatus {
    $exe = Get-ChildItem "$env:ProgramFiles\CrystalDiskInfo" -Filter "DiskInfo*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Output "ERROR: CrystalDiskInfo executable not found after installation."
        return
    }

    $outputPath = "$env:TEMP\CrystalDiskInfo_SmartStatus.txt"
    Write-Output "Running CrystalDiskInfo to gather SMART status..."
    & "$($exe.FullName)" /CopyExit $outputPath
    Start-Sleep -Seconds 5

    if (Test-Path $outputPath) {
        Write-Output "`n=== SMART Status ==="
        Get-Content $outputPath
        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "ERROR: SMART status output file not found."
    }
}

Write-Output "Starting CrystalDiskInfo SMART diagnostic..."

checkChoco
installCrystalDiskInfo
Get-SMARTStatus

Write-Output "CrystalDiskInfo SMART check complete."
exit 0
