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

function installCrystalDiskInfoPortable {
    # Clean up any previous broken installs
    choco uninstall crystaldiskinfo.portable -y --remove-dependencies | Out-Null
    Start-Sleep -Seconds 2

    Write-Output "Installing CrystalDiskInfo Portable via Chocolatey..."
    choco install crystaldiskinfo.portable --force -y --no-progress
    Start-Sleep -Seconds 5
}

function Get-CrystalDiskInfoSMARTStatus {
    $portablePath = "$env:ProgramData\chocolatey\lib\crystaldiskinfo.portable\tools"
    if (!(Test-Path $portablePath)) {
        Write-Output "ERROR: Portable CrystalDiskInfo path not found."
        return
    }

    $exe = Get-ChildItem $portablePath -Filter "DiskInfo*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Output "ERROR: CrystalDiskInfo executable not found."
        return
    }

    $outputFile = "$env:TEMP\CrystalDiskInfo_SmartStatus.txt"
    & "$($exe.FullName)" /CopyExit "$outputFile"
    Start-Sleep -Seconds 5

    if (Test-Path $outputFile) {
        Write-Output "`n--- CrystalDiskInfo SMART Status ---"
        Get-Content $outputFile
        Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "ERROR: No SMART status file was generated."
    }
}

Write-Output "Action: Install CrystalDiskInfo Portable & Retrieve SMART Status"
checkChoco
installCrystalDiskInfoPortable
Get-CrystalDiskInfoSMARTStatus
Write-Output "Script complete."
exit 0
