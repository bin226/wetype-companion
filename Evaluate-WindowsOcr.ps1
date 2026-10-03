param([string]$Images=(Join-Path $PSScriptRoot 'test-fixtures\live-v1'),[int]$Repeats=5)
$ErrorActionPreference='Stop'
$Engine='Windows';$NoCorrections=$true
# Reuse the actual Windows OCR initialization and Read-Word function without
# running the companion UI or initializing a second mutex.
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'companion.ps1'))
$start=$source.IndexOf("`$ErrorActionPreference='Stop'")
$end=$source.IndexOf('if($TestImage){')
$initialization=$source.Substring($start,$end-$start).Replace('$PSScriptRoot',("'"+$PSScriptRoot.Replace("'","''")+"'"))
. ([ScriptBlock]::Create($initialization))
$results=@()
foreach($file in Get-ChildItem -LiteralPath $Images -Filter *.png | Where-Object {$_.BaseName -notlike '*-normalized'}){
 $bitmap=[Drawing.Bitmap]::new($file.FullName)
 try{
  $box=[CandidateNative]::Highlight($bitmap);if($box.IsEmpty){throw ('No highlight: '+$file.Name)}
  $normalized=[CandidateNative]::Normalize($bitmap,$box)
  try{$normalized.Save((Join-Path $Images ($file.BaseName+'-normalized.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$normalized.Dispose()}
  $null=Read-Word $bitmap $box
  $times=@();$outputs=@()
  for($iteration=0;$iteration -lt $Repeats;$iteration++){
   $watch=[Diagnostics.Stopwatch]::StartNew();$result=Read-Word $bitmap $box;$times+=$watch.Elapsed.TotalMilliseconds;$outputs+=$result.Word
  }
  $ordered=@($times|Sort-Object)
  $results+=[pscustomobject]@{Expected=$file.BaseName;Raw=$result.Raw;Word=$result.Word;Correct=($result.Word -ceq $file.BaseName);MedianMilliseconds=$ordered[[int][Math]::Floor($ordered.Count/2)];Outputs=$outputs;CorrectionsEnabled=$false}
 }finally{$bitmap.Dispose()}
}
$json=$results|ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'test-results\windows-baseline.json'),$json,[Text.UTF8Encoding]::new($false))
$json
