$iloIP = ""         
$username = ""      
$password = ""      

$pair    = "$username`:$password"
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $encoded" }
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

function Get-LogEntries {
    param (
        [string]$basePath,
        [string]$label
    )

    $uri = "https://$iloIP$basePath/Entries/?`$top=10"
    Write-Host "`n=== $label (Latest 10 Entries) ===`n"

    try {
        $entries = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -UseBasicParsing

        if (-not $entries.Members) {
            Write-Warning "No entries found for $label"
            return
        }

        foreach ($e in $entries.Members) {
            $entryUri = "https://$iloIP$($e.'@odata.id')"
            try {
                $d = Invoke-RestMethod -Uri $entryUri -Headers $headers -Method GET -UseBasicParsing

                $timestamp = $d.Created
                $severity  = $d.Severity
                $message   = $d.Message

                $color = switch ($severity) {
                    "OK"       { "Green" }
                    "Warning"  { "Yellow" }
                    "Critical" { "Red" }
                    default    { "White" }
                }

                Write-Host ("[{0}] {1,-8} - {2}" -f $timestamp, $severity, $message) -ForegroundColor $color
            } catch {
                Write-Warning "Failed to retrieve entry at $entryUri"
            }
        }
    }
    catch {
        Write-Warning "Failed to fetch $label from $uri. $_"
    }
}



# IEL
Get-LogEntries -basePath "/redfish/v1/Managers/1/LogServices/IEL" -label "iLO Event Log (IEL)"

#IML
Get-LogEntries -basePath "/redfish/v1/Systems/1/LogServices/IML" -label "Integrated Management Log (IML)"

#Security Log
Get-LogEntries -basePath "/redfish/v1/Systems/1/LogServices/SL" -label "Security Log (SL)"