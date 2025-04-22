param(
    [string]$svc = 'W3SVC'
)

function Get-ExitCodeExplanation {
    param([int]$code)

    $map = @{
        0     = "No error"
        1     = "Incorrect function"
        2     = "File not found"
        3     = "Path not found"
        5     = "Access denied"
        1067  = "Process terminated unexpectedly"
        1053  = "Service did not respond to the start/control request in time"
        1054  = "Service did not respond to a start request"
        1068  = "Dependency service or group failed to start"
        1075  = "Dependency service does not exist or is marked for deletion"
        1077  = "The service has never been started"
    }

    if ($map.ContainsKey($code)) {
		return $map[$code]
	} else {
		return "Unknown"
	}

}

function Start-ServiceWithDependencies {
    param (
        [string]$serviceName,
        [System.Collections.Generic.HashSet[string]]$visited = $(New-Object "System.Collections.Generic.HashSet[string]")
    )

    if ($visited.Contains($serviceName)) {
        return
    }
    $visited.Add($serviceName) | Out-Null

    $svcInfo = Get-WmiObject Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
    if ($null -eq $svcInfo) {
        Write-Warning "Service '$serviceName' not found."
        return
    }

    if ($svcInfo.StartMode -eq "Disabled") {
        Write-Warning "Service '$serviceName' is disabled. Skipping start."
        return
    }

    $status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $status) {
        Write-Warning "Service '$serviceName' status could not be retrieved."
        return
    }

    if ($status.Status -eq "Running") {
        Write-Output "Service '$serviceName' is already running."
        return
    }

    # Check dependencies first
    $deps = Get-WmiObject Win32_DependentService | Where-Object { $_.Dependent -like "*Name=`"$serviceName`"" }
    foreach ($dep in $deps) {
        $depName = ($dep.Antecedent -split '"')[1]
        Write-Output "Processing dependency: $depName"
        Start-ServiceWithDependencies -serviceName $depName -visited $visited
    }

    Write-Output "`n--- Attempting to start: $serviceName ---"
    try {
        Start-Service $serviceName -ErrorAction Stop
        Write-Output "Successfully started '$serviceName'."
    } catch {
        Write-Error "Failed to start '$serviceName'."

        # Exit code explanation
        $exitCode = $svcInfo.ExitCode
        $meaning = Get-ExitCodeExplanation -code $exitCode
        Write-Output "Exit Code: $exitCode - $meaning"

        # Check executable path
        $exePath = $svcInfo.PathName -replace '"','' -replace ' -.*$',''
        if (-Not (Test-Path $exePath)) {
            Write-Warning "Executable not found at '$exePath'"
        } else {
            Write-Output "Executable Path: $exePath"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($svc)) {
    Write-Warning "No service name provided. Use the -svc parameter."
    return
}

$mainStatus = Get-Service -Name $svc -ErrorAction SilentlyContinue
if ($null -eq $mainStatus) {
    Write-Warning "Service '$svc' not found."
    return
}

if ($mainStatus.Status -eq 'Running') {
    Write-Output "Service '$svc' is already running. Exiting."
    return
}

Start-ServiceWithDependencies -serviceName $svc

Write-Output "`nRecent related system event logs:"
Get-WinEvent -LogName System -MaxEvents 50 |
    Where-Object { $_.Message -like "*$svc*" } |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Format-List
