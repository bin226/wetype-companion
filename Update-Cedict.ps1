param([string]$DownloadUrl='https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lexicon.ps1')
$data=Join-Path $PSScriptRoot 'data'
[void][IO.Directory]::CreateDirectory($data)
$gzipPath=Join-Path $data 'cedict.gz'
$tempPath=Join-Path $data 'cedict.tmp'
try{
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 Invoke-WebRequest -Uri $DownloadUrl -OutFile $gzipPath -UseBasicParsing
 $inputFile=[IO.File]::OpenRead($gzipPath)
 try{
  $gzip=[IO.Compression.GZipStream]::new($inputFile,[IO.Compression.CompressionMode]::Decompress)
  try{
   $outputFile=[IO.File]::Create($tempPath)
   try{$gzip.CopyTo($outputFile)}finally{$outputFile.Dispose()}
  }finally{$gzip.Dispose()}
 }finally{$inputFile.Dispose()}
 # Validate before replacing the working dictionary; failures preserve it.
 $probe=New-Object LocalLexicon
 $probe.LoadCedict($tempPath)
 if($probe.CedictEntries -lt 100000){throw 'Downloaded dictionary unexpectedly small; old dictionary retained.'}
 $metadata=[ordered]@{Source='CC-CEDICT';Url=$DownloadUrl;License='CC-BY-SA-4.0';DownloadedUtc=[DateTime]::UtcNow.ToString('o');Entries=$probe.CedictEntries;Sha256=(Get-FileHash -LiteralPath $tempPath -Algorithm SHA256).Hash}
 Move-Item -LiteralPath $tempPath -Destination (Join-Path $data 'cedict.u8') -Force
 [IO.File]::WriteAllText((Join-Path $data 'cedict-source.json'),($metadata|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 & (Join-Path $PSScriptRoot 'Build-Wordlist.ps1')
}finally{
 if(Test-Path -LiteralPath $gzipPath){Remove-Item -LiteralPath $gzipPath}
 if(Test-Path -LiteralPath $tempPath){Remove-Item -LiteralPath $tempPath}
}
