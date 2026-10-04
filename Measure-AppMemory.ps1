param([string]$Label='current',[string]$Exe=(Join-Path $PSScriptRoot 'dist\WeTypeCompanion\WeTypeCompanion.exe'))
$ErrorActionPreference='Stop'
$results=@()
foreach($dictionary in @('Qingjian','Cedict')){
 $directory=Join-Path $PSScriptRoot ('test-results\memory-config-'+$dictionary)
 [void][IO.Directory]::CreateDirectory($directory)
 @{Qingjian=($dictionary -eq 'Qingjian');Cedict=($dictionary -eq 'Cedict');Custom=$false}|ConvertTo-Json|Set-Content (Join-Path $directory 'settings.json') -Encoding UTF8
 $process=Start-Process -FilePath $Exe -ArgumentList '--background','--run-seconds','16','--data-directory',('"'+$directory+'"') -WindowStyle Hidden -PassThru
 try{
  Start-Sleep -Seconds 10
  if($process.HasExited){throw 'Benchmark process exited early (another instance may be running).'}
  $children=@(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)")
  foreach($id in @($process.Id)+@($children | ForEach-Object {$_.ProcessId})){
   $sample=Get-Process -Id $id
   $results += [pscustomobject]@{Label=$Label;Dictionary=$dictionary;Process=$sample.ProcessName;WorkingSetMB=[math]::Round($sample.WorkingSet64/1MB,2);PrivateMB=[math]::Round($sample.PrivateMemorySize64/1MB,2)}
  }
  if(!$process.WaitForExit(30000)){throw 'Benchmark exit timed out.'}
  if($process.ExitCode -ne 0){throw 'Benchmark failed.'}
 }finally{if(!$process.HasExited){$process.Kill()};$process.Dispose()}
}
$results|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot ('test-results\memory-'+$Label+'.json')) -Encoding UTF8
$results|Format-Table
