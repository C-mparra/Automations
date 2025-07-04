$amcAccounts = @("amcadmin")

$logonUIKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"

$localUsers = Get-LocalUser | Where-Object {
    $_.Enabled -eq $true -and
    $_.Name -ne "Administrator" -and
    $_.Name -notin $amcAccounts
}

$validUser = $localUsers | Sort-Object LastLogon -Descending | Select-Object -First 1

if ($validUser) {
    $fullUser = ".\$($validUser.Name)" 
    Write-Output "Restoring last customer user to login screen: $fullUser"

    Set-ItemProperty -Path $logonUIKey -Name "LastLoggedOnUser" -Value $fullUser
    Set-ItemProperty -Path $logonUIKey -Name "LastLoggedOnDisplayName" -Value $validUser.Name
} else {
    Write-Output "No suitable user found to set on login screen."
}

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0"

foreach ($acct in $amcAccounts) {
    if (Get-LocalUser -Name $acct -ErrorAction SilentlyContinue) {
        try {
            Remove-LocalUser -Name $acct -ErrorAction Stop
            Write-Output "Removed local admin account: $acct"
        } catch {
            Write-Warning "Failed to remove account: $acct - $_"
        }
    }
}
