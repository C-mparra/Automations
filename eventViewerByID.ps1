Get-WinEvent -FilterHashtable @{
    LogName = 'System';
    Id = 7;
    ProviderName = 'disk'
} | Select-Object TimeCreated, Message | Sort-Object TimeCreated -Descending
