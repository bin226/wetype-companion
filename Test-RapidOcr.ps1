$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
. (Join-Path $PSScriptRoot 'lexicon.ps1')
. (Join-Path $PSScriptRoot 'rapid-ocr.ps1')
$script:lexicon=Get-LocalLexicon
$fixtures=Join-Path $PSScriptRoot 'test-fixtures\live-v1'
$samples=Get-Content (Join-Path $fixtures 'manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
try{
 Start-RapidWorker
 foreach($sample in $samples){
  $path=Join-Path $fixtures $sample.File
  if((Get-FileHash -LiteralPath $path).Hash -ne $sample.Sha256){throw ('Fixture changed: '+$sample.File)}
  $bitmap=[Drawing.Bitmap]::new($path)
  try{
   $box=[CandidateNative]::Highlight($bitmap)
   if($box.IsEmpty){throw ('Highlight missing: '+$sample.File)}
   $requestId=$sample.Expected;$response=Send-RapidImage $bitmap $box $requestId
   if(!$response.Wait(10000)){throw 'OCR response timed out'}
   if(!$response.Result){throw ('Worker closed stream: '+$script:workerErrors.Result)}
   if(($response.Result|ConvertFrom-Json).Id -cne $requestId){throw 'Response identifier mismatch'}
   $result=Convert-RapidResult $response.Result
   if($result.Word -cne $sample.Expected -or !$result.Meaning -or $result.Source -ne 'Qingjian'){throw ('Recognition or lookup mismatch: '+$sample.File)}
  }finally{$bitmap.Dispose()}
 }
 'PASS: '+$samples.Count+' real candidate fixtures, persistent worker protocol, confidence gate and Qingjian lookup.'
}finally{Stop-RapidWorker}
