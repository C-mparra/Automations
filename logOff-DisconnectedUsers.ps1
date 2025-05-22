function Get-DisconnectedSessions {
    $sessions = @()
    $raw = query session
    if (-not $raw) { return $sessions }

    $header = $raw | Where-Object { $_ -like "*USERNAME*" }
    $headerProps = @{
        "SessionName" = $header.IndexOf("SESSIONNAME")
        "Username"    = $header.IndexOf("USERNAME")
        "ID"          = $header.IndexOf("ID")
        "State"       = $header.IndexOf("STATE")
        "Type"        = $header.IndexOf("TYPE")
        "Device"      = $header.IndexOf("DEVICE")
    }

    foreach ($line in $raw) {
        if ($line -like "*USERNAME*") { continue }
        try {
            $session = New-Object PSObject -Property @{
                SessionName = $line.Substring(0, $headerProps["Username"]).Trim(" >")
                Username    = $line.Substring($headerProps["Username"], $headerProps["ID"] - $headerProps["Username"]).Trim()
                ID          = $line.Substring($headerProps["ID"], $headerProps["State"] - $headerProps["ID"]).Trim()
                State       = $line.Substring($headerProps["State"], $headerProps["Type"] - $headerProps["State"]).Trim()
                Type        = $line.Substring($headerProps["Type"], $headerProps["Device"] - $headerProps["Type"]).Trim()
                Device      = $line.Substring($headerProps["Device"]).Trim()
            }

            if ($session.State -eq "Disc" -and $session.Username) {
                $sessions += $session
            }
        } catch {
            Write-Output "Error parsing session line: $line"
        }
    }

    return $sessions
}

$disconnected = Get-DisconnectedSessions

if ($disconnected.Count -eq 0) {
    Write-Output "No disconnected sessions found."
} else {
    foreach ($session in $disconnected) {
        Write-Output "Logging off user: $($session.Username) | Session ID: $($session.ID)"
        try {
            logoff $session.ID /V
        } catch {
            Write-Output "Failed to log off Session ID: $($session.ID) - $_"
        }
    }
}