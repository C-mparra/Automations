function Get-LoggedInUser {
    $user = (Get-WmiObject -Class Win32_ComputerSystem).UserName
    return $user
}

function Get-InstalledPrinters {
    $printers = Get-Printer
    if ($printers.Count -eq 0) {
        Write-Output "No printers found on this system."
    } else {
        Write-Output "`n--- Installed Printers ---"
        foreach ($printer in $printers) {
            Write-Output "Name: $($printer.Name) | Driver: $($printer.DriverName) | Port: $($printer.PortName)"
        }
    }
}

function Get-DefaultPrinter {
    try {
        $default = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Printer | Where-Object { $_.Default -eq $true }
        if ($default) {
            Write-Output "`n--- Default Printer ---"
            Write-Output "Name: $($default.Name)"
            Write-Output "Driver: $($default.DriverName)"
            Write-Output "Port: $($default.PortName)"
        } else {
            Write-Output "No default printer is set."
        }
    } catch {
        Write-Output "Error retrieving default printer: $_"
    }
}

function Get-UserMappedPrinters {
    $sid = (Get-WmiObject -Class Win32_UserAccount | Where-Object { "$($_.Domain)\$($_.Name)" -eq $user }).SID
    $regPath = "Registry::HKEY_USERS\$sid\Printers\Connections"

    if (Test-Path $regPath) {
        $connections = Get-ChildItem -Path $regPath
        if ($connections.Count -eq 0) {
            Write-Output "`n--- No per-user mapped printers found in registry ---"
        } else {
            Write-Output "`n--- Per-User Mapped Printers ---"
            foreach ($conn in $connections) {
                Write-Output "Mapped Printer: $($conn.PSChildName)"
            }
        }
    } else {
        Write-Output "`nCould not locate user-mapped printers in registry (may require profile to be loaded)."
    }
}

$user = Get-LoggedInUser

if (-not $user) {
    Write-Output "No user is currently logged in. Showing system-wide printers only."
    Get-InstalledPrinters
    Get-DefaultPrinter
} else {
    Write-Output "Logged in user: $user"
    Get-InstalledPrinters
    Get-DefaultPrinter
    Get-UserMappedPrinters
}

Write-Output "Script Completed"
exit 0
