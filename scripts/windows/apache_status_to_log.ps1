# Script for determining selected monitoring parameters and integration into NX-Log and Graylog
# Tested on Microsoft Windows 2016, 2019 and 2022 and Apache 2.4
# (C) Michael Schmidt
# Version 0.1 (01.12.2023)

$apacheServerIpAddress = "1.1.1.1"
$apacheStatusFile = "D:\Logs\httpd\apache_httpd_status.tmp"
$logFilePath = "D:\Logs\httpd\apache_httpd_status.json"

$short_message="Apache http server status message"
$full_message="Apache http server status message"

$idleWorkers = 0
$busyWorkers = 0
$freeWorkers = 0

$loop = 0 

# Bypasses for the certificate issues.
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
# End Bypasses for the certificate issues.

# get Apache status from url
Invoke-WebRequest -Uri https://$apacheServerIpAddress/server-status?auto -OutFile $apacheStatusFile

# load content from temp status file
$fileContent = Get-Content $apacheStatusFile

$jsonString = "{"

# create json from Apache status
foreach ($line in $fileContent) {
	$lineArray = $line.Split(":")
	$value = $lineArray[1]
	if ($value -ne '' -or $value -ne $null) {
		switch($loop){            
			0 {
				echo $value
			}            
			1 {
				$jsonString = $jsonString + '"' + "ApacheVersion" + '" : "' + $value.Trim() + '", '
			}            
			9 {
				$jsonString = $jsonString + '"' + "ApacheUptime" + '" : "' + $value.Trim() + '", '
			} 
			13 {
				$jsonString = $jsonString + '"' + "ApacheTotalAccesses" + '" : "' + $value.Trim() + '", '
			} 
			20 {
				$jsonString = $jsonString + '"' + "ApacheDurationPerReq" + '" : "' + $value.Trim() + '", '
			}  
			21 {
				$busyWorkers = $value.Trim();
				$jsonString = $jsonString + '"' + "ApacheBusyWorkers" + '" : "' + $busyWorkers + '", '
			}
			23 {
				$idleWorkers = $value.Trim();
				$jsonString = $jsonString + '"' + "ApacheIdleWorkers" + '" : "' + $idleWorkers + '"'
			}                       
		}
	}
	$loop = $loop + 1
}

# calculate free workers
if($idleWorkers -match "^\d+$" -And $busyWorkers -match "^\d+$")
{
	$freeWorkers = [int]$idleWorkers - [int]$busyWorkers
	$jsonString = $jsonString + ', "' + "ApacheFreeWorkers" + '" : "' + $freeWorkers + '"'
}

$jsonString = $jsonString + ', "' + "short_message" + '" : "' + $short_message + '"' + ', "' + "full_message" + '" : "' + $full_message + '"'
$jsonString = $jsonString + " }"

Write-Output $jsonString | Out-File -Encoding utf8 -Append -FilePath $logFilePath

# delete temp file
Remove-Item -Path $apacheStatusFile