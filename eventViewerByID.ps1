Get-WinEvent -FilterHashtable @{
    LogName = 'System';
    Id = 55;
    ProviderName = 'NTFS'
} | Select-Object TimeCreated, Message | Sort-Object TimeCreated -Descending
