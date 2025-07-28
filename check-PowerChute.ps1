# Still testing
$username = ""                 # Replace with your username
$password = ""      # Replace with your password

$baseUrl = ""
$loginUrl = "$baseUrl/j_security_check"
$eventLogUrl = "$baseUrl/eventlog"

# Ignore SSL cert warnings
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Create a web session (to persist cookies)
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Send the login form POST request
$response = Invoke-WebRequest -Uri $loginUrl -WebSession $session -Method POST -Body @{
    j_username = $username
    j_password = $password
} -ContentType "application/x-www-form-urlencoded" -UseBasicParsing

# Check if login was successful (redirect or event log load)
if ($response.StatusCode -eq 200 -and $response.Content -notmatch "Log On") {
    # Login succeeded, request event log
    $logResponse = Invoke-WebRequest -Uri $eventLogUrl -WebSession $session -UseBasicParsing
    Write-Output $logResponse.Content
} else {
    Write-Error "Login failed. Make sure username and password are correct."
}