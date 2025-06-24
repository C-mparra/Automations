Set-ExecutionPolicy RemoteSigned -Scope Process -Force
Import-Module PSWindowsUpdate -Force
Get-WindowsUpdate -MicrosoftUpdate -IsInstalled:$false


Get-ChildItem -Path "D:\" -Recurse -Filter "SentinelOne-win32_windows_legacy_v2_1_0_86.exe" -ErrorAction SilentlyContinue

Get-Process -Name powershell | ForEach-Object { $_.Kill() }

Expand-Archive -Path "C:\Temp\FirefoxPortable.zip" -DestinationPath "C:\Temp\Firefox" -Force

--
# Set the HOME environment variable to ensure Homebrew works
export HOME="/var/root"

# Set the PATH for the current session to include Homebrew's location
export PATH="/usr/local/bin:$PATH"
--