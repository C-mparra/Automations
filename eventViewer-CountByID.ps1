$daysBack = 3
$eventID = 7
$logName = 'System'

try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = $logName
        ID = $eventID
        StartTime = (Get-Date).AddDays(-$daysBack)
    }

    $count = $events.Count
    Write-Output "Event ID $eventID has occurred $count times in the last $daysBack days."
} catch {
    Write-Output "Failed to query event log: $_"
}
