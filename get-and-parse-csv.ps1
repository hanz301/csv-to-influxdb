Set-Variable -Name compArr  -Value @("Hostnames")  
Set-Variable -Name IdArr -Value @("ALL") #Set to ALL if every EventID should be shown.
Set-Variable -Name LogNames -Value @("Application", "System")  # Checking app and system logs
Set-Variable -Name EventTypes -Value @("Error", "Warning")  # Loading only Errors and Warnings
Set-Variable -Name ExportFolder -Value "C:\LOGS" #change to own leisure, all csv files will reside here

$el_c = @()   #consolidated error log

$now=(Get-Date).AddMinutes(-60) ## create param ##
#$startdate=$now
$ExportFile= "el_$comp" + $now.ToString("yyyy-MM-dd---hh-mm-ss") + ".csv"  ## we cannot use standard delimiters like ":"

echo "now: $now"
#echo "EventAge: $EventAgeDays"
#echo "stardate: $startdate"

foreach($comp in $compArr) 
{ 
$tp = Test-Path -PathType Container "$ExportFolder\$comp"

if ($tp -eq $false) ##If $tp is false, then create folder corresponding to $comp
  {
  New-Item -ItemType Directory -Force -Path $ExportFolder\$comp | Out-Null
  echo "creating dir for $comp"
  }
  else {
  echo "dir was found for $comp"
  }

  foreach($log in $LogNames) 
  {
    if ($IdArr -ne "ALL") 
    {
        foreach($id in $IdArr) 
        {
        Write-Host Processing $comp\$log
        $el = get-eventlog -ComputerName $comp -log $log -After $now -EntryType $EventTypes | Where-Object {$_.EventID -eq $id} 
        $el_c += $el  #consolidating
        }
    }
    else 
    {
        Write-Host Processing $comp\$log
        $el = get-eventlog -ComputerName $comp -log $log -After $now -EntryType $EventTypes
        $el_c += $el  #consolidating
    }

  }
$el_sorted = $el_c | Sort-Object TimeGenerated    #sort by time
$el_finale = $el_sorted|Select EntryType, TimeGenerated, Source, EventID, MachineName, Message | ConvertTo-Csv -NoTypeInformation
$ExportFile= "el_$comp" + "_" + $now.ToString("yyyy-MM-dd hh-mm-ss") + ".csv"  # we cannot use standard delimiters like ":"

$el_finale | Out-File $ExportFolder\$comp\$ExportFile -Encoding utf8
#Invoke-WebRequest -UseBasicParsing $inpipipfluxURL -ContentType "text/csv" -Method POST -Body $el_finale
}
#Calling the Python script, make sure to have installed dependendacies (It will complain about which modules are missing, so np) 
python.exe .\csv-to-influxdb.py `
--input $ExportFolder\$comp\$ExportFile `
--server 'Hostname:Port' ` #InfluxDB 
--metricname 'el_$comp' `
--dbname 'EventLogs' `
--timeformat '%d-%m-%Y %H:%M:%S' `
--timecolumn 'TimeGenerated' `
--tagcolumns 'MachineName','EventID' `
--fieldcolumns 'Message','Source','EntryType'  `
--timezone UTC

Write-Host Done!
Remove-Variable -Name CompArr, IdArr, LogNames, EventTypes, ExportFolder, el_c, now
