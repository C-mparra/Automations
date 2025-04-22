function Get-LoggedInUser {
    $user = (Get-WmiObject -Class Win32_ComputerSystem).UserName
    return $user
}