$backupZipUrl = ""
$workingDir = "C:\Temp\RMM\CrystalDisk"

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
    Write-Output "Installing CrystalDiskInfo Portable via Chocolatey..."
    try {
        choco uninstall crystaldiskinfo.portable -y --remove-dependencies | Out-Null
        Start-Sleep -Seconds 2
        choco install crystaldiskinfo.portable --force -y --no-progress
        Start-Sleep -Seconds 5
        return $true
    } catch {
        Write-Output "Chocolatey install failed. Will use fallback."
        return $false
    }
}

function useFallbackInstaller {
    Write-Output "Downloading fallback ZIP..."
    $zipPath = "$env:TEMP\CrystalDiskBackup.zip"

    if (Test-Path $workingDir) {
        Remove-Item $workingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $workingDir -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $backupZipUrl -OutFile $zipPath -UseBasicParsing
        if ((Get-Content $zipPath -First 1) -like "*<html*") {
            Write-Output "ERROR: Fallback download returned HTML. Check the link."
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            return
        }

        Expand-Archive -Path $zipPath -DestinationPath $workingDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Write-Output "Fallback CrystalDiskInfo extracted to $workingDir"
        runCrystalDiskInfoFromPath -basePath $workingDir

    } catch {
        Write-Output "ERROR: Failed to download or extract fallback CrystalDiskInfo."
    }
}

function runCrystalDiskInfoFromPath {
    param (
        [string]$basePath
    )

    $exe = Get-ChildItem $basePath -Filter "DiskInfo*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $exe) {
        Write-Output "ERROR: CrystalDiskInfo executable not found in path: $basePath"
        return
    }

    Write-Output "Running CrystalDiskInfo with /CopyExit to capture SMART status..."
    & "$($exe.FullName)" /CopyExit

    $logFile = Join-Path (Split-Path $exe.FullName) "DiskInfo.txt"

    $waitSeconds = 0
    $maxWait = 20
    $lastSize = -1

    while ($waitSeconds -lt $maxWait) {
        if (Test-Path $logFile) {
            $currentSize = (Get-Item $logFile).Length
            if ($currentSize -eq $lastSize -and $currentSize -gt 0) {
                break
            }
            $lastSize = $currentSize
        }
        Start-Sleep -Seconds 1
        $waitSeconds++
    }

    if (Test-Path $logFile) {
        Write-Output "`n--- CrystalDiskInfo SMART Status ---"
        Get-Content $logFile
        Write-Output "`n--- End of Report ---"
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "ERROR: SMART status output file not found after $maxWait seconds."
    }
}

Write-Output "Action: Install CrystalDiskInfo Portable and Retrieve SMART Info"
checkChoco
$installed = installCrystalDiskInfoPortable

if ($installed -and (Test-Path "$env:ProgramData\chocolatey\lib\crystaldiskinfo.portable\tools")) {
    runCrystalDiskInfoFromPath -basePath "$env:ProgramData\chocolatey\lib\crystaldiskinfo.portable\tools"
} else {
    Write-Output "Chocolatey install failed or directory missing. Using fallback method."
    useFallbackInstaller
}

Write-Output "Script complete."
exit 0