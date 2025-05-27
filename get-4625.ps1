$events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} | Sort-Object TimeCreated -Descending
"Total 4625 Events: $($events.Count)"
$events | Select-Object -First 5 | Format-List TimeCreated, Message
