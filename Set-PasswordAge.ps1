## Parameters are for NinjaOne
param(
    [ValidateSet("90", "180", "365")]
    [string]$PasswordMaxAge = "90"
)

function Test-IsDomainController {
    $role = (Get-WmiObject Win32_ComputerSystem).DomainRole
    return ($role -eq 4 -or $role -eq 5)
}

function Get-GPOOrCreate {
    param ([string]$GPOName)
    $existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (!$existingGPO) {
        Write-Output "Creating GPO: $GPOName"
        $existingGPO = New-GPO -Name $GPOName
    }
    return $existingGPO
}

function Set-GPOLink {
    param ([string]$GPOName)
    $domain = (Get-ADDomain).DistinguishedName
    Write-Output "Linking GPO: $GPOName to domain: $domain"
    New-GPLink -Name $GPOName -Target $domain -LinkEnabled Yes -Enforced No
}

function Set-GPOAccess {
    param ([string]$GPOName)
    Write-Output "Setting GPO permissions for Domain Computers"
    Set-GPPermission -Name $GPOName -TargetName "Domain Computers" -TargetType Group -PermissionLevel GpoApply
}

function Set-GPORegistryValue {
    param (
        [string]$GPOName,
        [string]$RegistryKey,
        [string]$ValueName,
        [string]$ValueType,
        [object]$ValueData
    )
    Write-Output "Setting Registry Value: $RegistryKey\$ValueName = $ValueData"
    Set-GPRegistryValue -Name $GPOName -Key $RegistryKey -ValueName $ValueName -Type $ValueType -Value $ValueData
}

if (-not (Test-IsDomainController)) {
    Write-Output "Not a Domain Controller. Exiting."
    exit 0
}

Import-Module GroupPolicy

$GPOName = "AMC - Password Age Policy"
Get-GPOOrCreate -GPOName $GPOName

Set-GPORegistryValue -GPOName $GPOName `
    -RegistryKey "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "MaximumPasswordAge" `
    -ValueType "DWORD" `
    -ValueData $PasswordMaxAge

Set-GPOLink -GPOName $GPOName
Set-GPOAccess -GPOName $GPOName

Write-Output "Password Age GPO configuration complete."
exit 0
