param (
    [Parameter(Mandatory=$true)]
    [string]$PackageName
)

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

function installChocoPackage {
    param (
        [string]$Name
    )

    if (-not $Name) {
        Write-Output "ERROR: No package name specified."
        exit 1
    }

    Write-Output "Installing package '$Name' via Chocolatey..."
    choco install $Name --force -y --no-progress
}

checkChoco
installChocoPackage -Name $PackageName
Write-Output "Chocolatey package '$PackageName' installation complete."
exit 0
