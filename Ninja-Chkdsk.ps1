# for ninja one, asks for a drive letter, will reboot
param (
    [string]$DriveLetter = $env:drive
)

if (-not $DriveLetter) {
    Write-Output "ERROR: No drive letter specified. Please set the 'drive' environment variable (e.g., C:)."
    exit 1
}

$Drive = $DriveLetter.TrimEnd('\') + ":"
$RebootRequired = $Drive -eq "C:"

Write-Output "Starting CHKDSK scan for drive $Drive"
Write-Output "CHKDSK mode: /r (check for bad sectors)"

if ($RebootRequired) {
    Write-Output "System drive detected. Scheduling CHKDSK at next boot..."

    try {
        # Schedule CHKDSK and mark volume as dirty
        cmd.exe /c "chkntfs /c $Drive" | Out-Null
        fsutil dirty set $Drive | Out-Null

        Write-Output "CHKDSK has been scheduled for next boot. Please reboot the system to complete the scan."
    } catch {
        Write-Output "Failed to schedule CHKDSK: $_"
    }
} else {
    try {
        Write-Output "Running CHKDSK directly on $Drive (no reboot required)..."
        Start-Process -FilePath "chkdsk.exe" -ArgumentList "$Drive /r /f /x" -NoNewWindow -Wait
        Write-Output "CHKDSK completed."
    } catch {
        Write-Output "CHKDSK failed: $_"
    }
}
