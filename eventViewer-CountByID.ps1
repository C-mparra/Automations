$daysBack = 1
$eventID = 55
$logName = 'System'
$providerName = 'Ntfs'

try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName     = $logName
        ID          = $eventID
        StartTime   = (Get-Date).AddDays(-$daysBack)
        ProviderName= $providerName
    }

    $count = $events.Count
    Write-Output "Event ID $eventID from provider '$providerName' has occurred $count times in the last $daysBack days."
} catch {
    Write-Output "Failed to query event log: $_"
}
