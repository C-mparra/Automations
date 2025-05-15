Get-WinEvent -FilterHashtable @{
    LogName = 'System';
    Id = 7;
    ProviderName = 'Disk'
} | Select-Object TimeCreated, Message | Sort-Object TimeCreated -Descending
