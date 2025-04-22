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

Write-Output "===== Printer Info Script Started ====="

$user = Get-LoggedInUser

if (-not $user) {
    Write-Output "No user is currently logged in. Cannot retrieve user-specific printers."
} else {
    Write-Output "Logged in user: $user"
    Get-InstalledPrinters
    Get-DefaultPrinter
}

Write-Output "===== Script Completed ====="
exit 0
