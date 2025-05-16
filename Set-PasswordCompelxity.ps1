function Test-IsDomainController {
    $role = (Get-WmiObject Win32_ComputerSystem).DomainRole
    return ($role -eq 4 -or $role -eq 5)
}

function Get-GPOCreate {
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

function Set-GPOPermissions {
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

function main {
    param($EnableComplexity = $true)

    if (-not (Test-IsDomainController)) {
        Write-Output "Not a Domain Controller. Exiting."
        return
    }

    Import-Module GroupPolicy

    if ($null -eq $EnableComplexity) {
        Write-Error "EnableComplexity parameter is null. Exiting script."
        return
    }

    $ComplexityValue = if ($EnableComplexity -eq $true) { 1 } elseif ($EnableComplexity -eq $false) { 0 } else {
        Write-Error "Invalid value passed for EnableComplexity: $EnableComplexity"
        return
    }

    $GPOName = "Password Complexity Policy"

    Get-GPOCreate -GPOName $GPOName

    Set-GPORegistryValue -GPOName $GPOName `
        -RegistryKey "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
        -ValueName "PasswordComplexity" `
        -ValueType "DWORD" `
        -ValueData $ComplexityValue

    Set-GPOLink -GPOName $GPOName
    Set-GPOPermissions -GPOName $GPOName

    Write-Output "Password Complexity GPO configuration complete."
}
