Import-Module ActiveDirectory

function New-RandomString($length) {
    -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $length | ForEach-Object { [char]$_ })
}

# Generate random credentials
$secureUsername = "user_" + (New-RandomString -length 6)
$securePasswordPlain = New-RandomString -length 16
$securePassword = ConvertTo-SecureString $securePasswordPlain -AsPlainText -Force

# Define user properties
$userParams = @{
    Name                 = $secureUsername
    SamAccountName       = $secureUsername
    UserPrincipalName    = "$secureUsername@athensmicro.com"
    AccountPassword      = $securePassword
    Enabled              = $true
    Path                 = "CN=Users,DC=athensmicro,DC=com"
    PasswordNeverExpires = $true
}

# Create the domain user
try {
    New-ADUser @userParams
    Write-Output "User created successfully."
} catch {
    Write-Output "Failed to create user: $_"
}

# Add the user to Domain Admins group
try {
    Add-ADGroupMember -Identity "Domain Admins" -Members $secureUsername
    Write-Output "User '$secureUsername' added to 'Domain Admins' group."
} catch {
    Write-Output "Failed to add user to group: $_"
}

# Output credentials
Write-Output "Username: $secureUsername"
Write-Output "Password: $securePasswordPlain"
