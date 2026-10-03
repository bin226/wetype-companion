function Start-RapidWorker {
 $python=Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
 if(!(Test-Path -LiteralPath $python)){throw 'Run Setup-Ocr.ps1 to install the project OCR environment.'}
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=$python;$info.Arguments='-u "'+(Join-Path $PSScriptRoot 'ocr_worker.py')+'"'
 $info.WorkingDirectory=$PSScriptRoot;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $info.RedirectStandardInput=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.StandardOutputEncoding=[Text.Encoding]::UTF8;$info.StandardErrorEncoding=[Text.Encoding]::UTF8
 $script:worker=[Diagnostics.Process]::new();$script:worker.StartInfo=$info
 [void]$script:worker.Start()
 $script:workerErrors=$script:worker.StandardError.ReadToEndAsync()
 $ready=$script:worker.StandardOutput.ReadLineAsync()
 if(!$ready.Wait(60000)){Stop-RapidWorker;throw 'OCR worker initialization timed out.'}
 if(!$ready.Result){$errorText=$script:workerErrors.Result;Stop-RapidWorker;throw ('OCR worker failed: '+$errorText)}
 if(!($ready.Result|ConvertFrom-Json).Ready){Stop-RapidWorker;throw 'Invalid OCR worker handshake.'}
}
function Stop-RapidWorker {
 if($script:worker){
  try{if(!$script:worker.HasExited){$script:worker.StandardInput.Close();if(!$script:worker.WaitForExit(1000)){$script:worker.Kill()}}}finally{$script:worker.Dispose();$script:worker=$null}
 }
}
function Send-RapidImage($Bitmap,$Box,[string]$Id) {
 if($script:worker.HasExited){throw 'OCR worker exited unexpectedly.'}
 $normalized=[CandidateNative]::Normalize($Bitmap,$Box);$memory=[IO.MemoryStream]::new()
 try{
  $normalized.Save($memory,[Drawing.Imaging.ImageFormat]::Png)
  $request=@{Id=$Id;Png=[Convert]::ToBase64String($memory.ToArray())}|ConvertTo-Json -Compress
  $request=[regex]::Replace($request,'[^\u0000-\u007f]',{param($match) '\u'+([int][char]$match.Value).ToString('x4')})
  $script:worker.StandardInput.WriteLine($request);$script:worker.StandardInput.Flush()
  return $script:worker.StandardOutput.ReadLineAsync()
 }finally{$normalized.Dispose();$memory.Dispose()}
}
function Convert-RapidResult([string]$Json) {
 if(!$Json){throw 'OCR worker closed its response stream.'}
 $result=$Json|ConvertFrom-Json
 if($result.Error){throw $result.Error}
 $word=$result.Word
 if($result.Confidence -lt 0.80){$word=''}
 $meaning=$script:lexicon.Meaning($word)
 [pscustomobject]@{Raw=$result.Raw;Word=$word;Meaning=$meaning;Attempts=1;Source=$script:lexicon.Source($word);InWordlist=$script:lexicon.Words.Contains($word);Confidence=$result.Confidence;Engine=$result.Engine;RecognitionMilliseconds=$result.Milliseconds;Status=$(if($meaning){'matched'}elseif($word){'no-translation'}else{'ocr-empty'})}
}
