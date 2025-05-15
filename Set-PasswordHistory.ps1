# uses dropdown variables in Ninja One
[int]$passwordHistory = [int]$env:passwordHistory
Write-Output "[DEBUG] passwordHistory = '$passwordHistory'"

function Test-IsDomainController {
    $role = (Get-WmiObject Win32_ComputerSystem).DomainRole
    return ($role -eq 4 -or $role -eq 5)
}

function Set-PasswordHistory {
    param(
        [int]$passwordHistory
    )

    if (-not (Test-IsDomainController)) {
        Write-Output "Not a Domain Controller. Exiting."
        return
    }

    Import-Module ActiveDirectory

    try {
        $domain = Get-ADDomain
        Write-Output "Setting PasswordHistoryCount to $passwordHistory for domain: $($domain.DNSRoot)"
        Set-ADDefaultDomainPasswordPolicy -Identity $domain.DistinguishedName -PasswordHistoryCount $passwordHistory
        Write-Output "Password History policy updated successfully."
    } catch {
        Write-Error "Failed to update Password History policy: $_"
    }
}

Set-PasswordHistory -passwordHistory $passwordHistory
