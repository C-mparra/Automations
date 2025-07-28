Set-ExecutionPolicy RemoteSigned -Scope Process -Force
Import-Module PSWindowsUpdate -Force
Get-WindowsUpdate -MicrosoftUpdate -IsInstalled:$false


# when scripts aren't working
 Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
 
Get-ChildItem -Path "D:\" -Recurse -Filter "SentinelOne-win32_windows_legacy_v2_1_0_86.exe" -ErrorAction SilentlyContinue

Get-Process -Name powershell | ForEach-Object { $_.Kill() }

Expand-Archive -Path "C:\Temp\FirefoxPortable.zip" -DestinationPath "C:\Temp\Firefox" -Force

--
# Set the HOME environment variable to ensure Homebrew works
export HOME="/var/root"

# Set the PATH for the current session to include Homebrew's location
export PATH="/usr/local/bin:$PATH"
--


# Run this script as Administrator

Write-Host ""
Write-Host "--- Setting Dirty Bit on C: ---"
fsutil dirty set C:

Write-Host ""
Write-Host "--- Scheduling CHKDSK on C: with /f /r /x ---"
echo Y | chkdsk C: /f /r /x

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "--- Verifying Dirty Bit Status ---"
$dirtyStatus = fsutil dirty query C:
Write-Host $dirtyStatus

Write-Host ""
Write-Host "--- Checking if CHKDSK is Scheduled in Registry ---"
$bootExecute = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager").BootExecute
$bootExecuteString = $bootExecute -join " "

if ($bootExecuteString -match "/r \\??\\C:") {
    Write-Host "CHKDSK is scheduled to run on C: at next boot."
} else {
    Write-Host "CHKDSK does NOT appear to be explicitly scheduled in the registry."
}

Write-Host ""
$reboot = Read-Host "Would you like to reboot now to run CHKDSK? (Y/N)"

if ($reboot -match '^[Yy]$') {
    Write-Host "Rebooting now..."
    Restart-Computer
} else {
    Write-Host "Reboot skipped. CHKDSK will not run until the next reboot."
}



$duo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Where-Object { $_.DisplayName -like "Duo Authentication for Windows Logon*" }

if ($duo) {
    Write-Output "Duo is installed. Version: $($duo.DisplayVersion)"
} else {
    Write-Output "Duo is not installed."
}


Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Duo*" }

