$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory((Join-Path $PSScriptRoot 'test-results'))
$exe=Join-Path $PSScriptRoot 'dist\WeTypeCompanion\WeTypeCompanion.exe'
if(!(Test-Path -LiteralPath $exe)){throw '请先运行 Build-App.ps1。'}
$process=Start-Process -FilePath $exe -ArgumentList '--self-test',('"'+$PSScriptRoot+'"') -WindowStyle Hidden -PassThru
try{
 if(!$process.WaitForExit(180000)){$process.Kill();throw 'C# 集成测试超时。'}
 Get-Content -LiteralPath (Join-Path $PSScriptRoot 'test-results\native-tests.txt')
 if($process.ExitCode -ne 0){throw 'C# 集成测试失败。'}
}finally{$process.Dispose()}
