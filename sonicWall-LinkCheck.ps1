# Replace with your credentials
$sonicIP = ""
$username = ""
$password = ''

# Ignore SSL errors (if using self-signed cert)
add-type @"
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

# Prepare auth headers
$authInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username : $password"))
$headers = @{
    "Authorization" = "Basic $authInfo"
    "Content-Type" = "application/json"
}

# Query a system endpoint (example: interface info)
$response = Invoke-RestMethod -Uri "$sonicIP/api/sonicos/interfaces" -Headers $headers -Method GET

# Display interface details
$response.interfaces
