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

function installCrystalDiskInfoFull {
    $installPath = "$env:ProgramFiles\CrystalDiskInfo"
    if (-not (Test-Path $installPath)) {
        Write-Output "Installing CrystalDiskInfo full version via Chocolatey..."
        choco install crystaldiskinfo.install -y --no-progress
        Start-Sleep -Seconds 5
    } else {
        Write-Output "CrystalDiskInfo already installed at: $installPath"
    }

    # Confirm EXE
    $exe = Get-ChildItem "$installPath" -Filter "DiskInfo*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) {
        Write-Output "CrystalDiskInfo successfully installed."
        Write-Output "Executable path: $($exe.FullName)"
    } else {
        Write-Output "WARNING: CrystalDiskInfo installed, but executable not found in expected location."
    }
}

Write-Output "Action: Install CrystalDiskInfo"
checkChoco
installCrystalDiskInfoFull
Write-Output "Script complete."
exit 0
