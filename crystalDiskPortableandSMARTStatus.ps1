function checkChoco {
    $chocoExe = "$env:ProgramData\chocolatey\bin\choco.exe"

    if (Test-Path $chocoExe) {
        if ($env:Path -notlike "*chocolatey*") {
            $env:Path += ";$env:ProgramData\chocolatey\bin"
            Write-Output "Chocolatey was installed but not in PATH. PATH updated for session."
        } else {
            Write-Output "Chocolatey is already installed and in PATH."
        }
    } else {
        Write-Output "Chocolatey not found. Installing..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Start-Sleep -Seconds 5

        if (Test-Path $chocoExe) {
            $env:Path += ";$env:ProgramData\chocolatey\bin"
            Write-Output "Chocolatey installed and added to PATH."
        } else {
            Write-Output "ERROR: Chocolatey install failed or choco.exe not found."
            exit 1
        }
    }
}

function installCrystalDiskInfoPortable {
    Write-Output "Installing CrystalDiskInfo Portable..."
    choco uninstall crystaldiskinfo.portable -y --remove-dependencies | Out-Null
    Start-Sleep -Seconds 2
    choco install crystaldiskinfo.portable --force -y --no-progress
    Start-Sleep -Seconds 5
}

function runCrystalDiskInfoAndOutputSMART {
    $portablePath = "$env:ProgramData\chocolatey\lib\crystaldiskinfo.portable\tools"
    if (!(Test-Path $portablePath)) {
        Write-Output "ERROR: CrystalDiskInfo portable path not found."
        exit 1
    }

    $exe = Get-ChildItem $portablePath -Filter "DiskInfo*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Output "ERROR: CrystalDiskInfo executable not found."
        exit 1
    }

    $outputFile = "$env:TEMP\CrystalDiskInfo_SmartStatus.txt"
    Write-Output "Running CrystalDiskInfo to capture SMART status..."
    & "$($exe.FullName)" /CopyExit "$outputFile"
    Start-Sleep -Seconds 5

    if (Test-Path $outputFile) {
        Write-Output "`n--- CrystalDiskInfo SMART Status ---"
        Get-Content $outputFile
        Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "ERROR: SMART status output file not found."
    }
}

Write-Output "Action: Install CrystalDiskInfo Portable and Retrieve SMART Info"
checkChoco
installCrystalDiskInfoPortable
runCrystalDiskInfoAndOutputSMART
Write-Output "Script complete."
exit 0
