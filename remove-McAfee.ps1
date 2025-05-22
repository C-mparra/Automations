#for manual removal
#1
$mcKey = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" |
    Where-Object { ($_ | Get-ItemProperty).DisplayName -like "*mcafee*" }

if (-not $mcKey) {
    Write-Output "No McAfee uninstall entries found in the registry."
} else {
    Write-Output "Found McAfee registry entry:"
    $mcKey | ForEach-Object {
        $props = Get-ItemProperty $_.PsPath
        Write-Output "- DisplayName: $($props.DisplayName)"
        Write-Output "- UninstallString: $($props.UninstallString)"
    }

    # 2 this launches a prompt worked in background mode
    Write-Output "`nLaunching uninstaller — this may show a visible prompt. Follow it manually if it appears."
    try {
        Start-Process -FilePath "$($props.UninstallString -split ' ')[0]" -ArgumentList "/uninstall" -ErrorAction Stop
    } catch {
        Write-Output "Failed to start uninstaller: $_"
    }

    Write-Output "Waiting 30 seconds for any GUI interactions..."
    Start-Sleep -Seconds 30
}

# 3
Write-Output "`nChecking for leftover McAfee processes..."
Get-Process | Where-Object { $_.Path -like "*mcafee*" } | ForEach-Object {
    Write-Output "- Stopping process: $($_.Name)"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# 4
$mcPaths = @(
    "C:\Program Files\McAfee",
    "C:\Program Files (x86)\McAfee"
)

foreach ($path in $mcPaths) {
    if (Test-Path $path) {
        Write-Output "`nRemoving leftover folder: $path"
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Output "- Removed: $path"
        } catch {
            Write-Output "- Failed to remove $path: $_"
        }
    } else {
        Write-Output "- Path not found: $path"
    }
}

# 5
if ($mcKey) {
    Write-Output "`nRemoving registry uninstall entry..."
    try {
        Remove-Item -Path $mcKey.PSPath -Force -ErrorAction Stop
        Write-Output "- Registry key removed"
    } catch {
        Write-Output "- Failed to remove registry key: $_"
    }
}

Write-Output "`nFinal check:"
Write-Output "- Registry: Should be no McAfee uninstall keys"
Write-Output "- Folders: Should be no Program Files\McAfee"
Write-Output "- Processes: Should be no McAfee services running"

Write-Output "`nManual removal complete. You may now proceed with Defender repair or re-enable."
