Get-WinEvent -FilterHashtable @{
    LogName = 'System';
    Id = 51;
    ProviderName = 'disk'
} | Select-Object TimeCreated, Message | Sort-Object TimeCreated -Descending
