param([string]$TestImage='', [int]$RunSeconds=0, [switch]$Diagnostics, [ValidateSet('RapidOCR','Windows')][string]$Engine='RapidOCR', [switch]$NoCorrections)
if($Engine -eq 'RapidOCR'){ & (Join-Path $PSScriptRoot 'companion-rapid.ps1') -TestImage $TestImage -RunSeconds $RunSeconds -Diagnostics:$Diagnostics; exit }
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing,System.Windows.Forms,System.Runtime.WindowsRuntime
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
[void][CandidateNative]::SetProcessDPIAware()
$null=[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
$null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
$null=[Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
$null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
$null=[Windows.Media.Ocr.OcrResult,Windows.Foundation,ContentType=WindowsRuntime]
$script:awaitMethod=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'} | Select-Object -First 1
function Await-WinRT($Operation,$ResultType){$task=$script:awaitMethod.MakeGenericMethod($ResultType).Invoke($null,@($Operation));$task.Wait();$task.Result}
$script:engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if($null -eq $engine){throw 'Install a Chinese Windows OCR language pack first.'}
. (Join-Path $PSScriptRoot 'lexicon.ps1')
$script:lexicon=Get-LocalLexicon
$script:glossary=$script:lexicon.Meanings
$script:corrections=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
if(Test-Path (Join-Path $PSScriptRoot 'ocr-corrections.tsv')){foreach($line in [IO.File]::ReadLines((Join-Path $PSScriptRoot 'ocr-corrections.tsv'),[Text.Encoding]::UTF8)){$cols=$line.Split("`t");if($cols.Length -ge 2 -and !$line.StartsWith('#')){$script:corrections[$cols[0]]=$cols[1]}}}
function Read-Word($Bitmap,$Box){
 $normalized=[CandidateNative]::Normalize($Bitmap,$Box)
 try{
  $attempts=@();$word='';$meaning=''
  for($pass=0;$pass -lt 2;$pass++){
   $image=$normalized;if($pass -eq 1){$image=[CandidateNative]::Invert($normalized)}
   $mem=[IO.MemoryStream]::new()
   try{
    $image.Save($mem,[Drawing.Imaging.ImageFormat]::Png);$mem.Position=0
    $stream=[System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($mem)
    $decoder=Await-WinRT ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $software=Await-WinRT ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    try{$result=Await-WinRT ($script:engine.RecognizeAsync($software)) ([Windows.Media.Ocr.OcrResult]);$raw=$result.Text}finally{$software.Dispose();$stream.Dispose()}
    $attempts+=$raw
    $word=($raw.Normalize([Text.NormalizationForm]::FormKC) -replace '\s','') -replace '^\d+[.、]?',''
    if($word -notmatch '^[\p{IsCJKUnifiedIdeographs}\p{IsCJKUnifiedIdeographsExtensionA}]{1,30}$'){$word=''}
    if(!$NoCorrections -and $word -and !$script:glossary.ContainsKey($word) -and $script:corrections.ContainsKey($word)){$word=$script:corrections[$word]}
    if($word -and $script:glossary.ContainsKey($word)){$meaning=$script:glossary[$word];break}
   }finally{$mem.Dispose();if($pass -eq 1){$image.Dispose()}}
  }
  [pscustomobject]@{Raw=$attempts -join ' / ';Word=$word;Meaning=$meaning;Attempts=$attempts.Count;Source=$script:lexicon.Source($word);InWordlist=$script:lexicon.Words.Contains($word);Status=$(if($meaning){'matched'}elseif($word){'no-translation'}else{'ocr-empty'})}
 }finally{$normalized.Dispose()}
}
if($TestImage){
 $bmp=[Drawing.Bitmap]::new($TestImage);$watch=[Diagnostics.Stopwatch]::StartNew()
 try{$box=[CandidateNative]::Highlight($bmp);if($box.IsEmpty){throw 'No candidate highlight found'};$result=Read-Word $bmp $box;$result | Add-Member Milliseconds $watch.Elapsed.TotalMilliseconds;$result | Add-Member Highlight $box.ToString();$result|ConvertTo-Json}finally{$bmp.Dispose()}
 exit
}
$script:mutex=[Threading.Mutex]::new($false,'Local\WeTypeLocalGlossCompanion')
if(!$script:mutex.WaitOne(0,$false)){throw 'Companion is already running.'}
$script:hint=[HintWindow]::new();$script:label=[Windows.Forms.Label]::new();$script:label.Dock='Fill';$script:label.TextAlign='MiddleLeft';$script:label.Font=[Drawing.Font]::new('Microsoft YaHei UI',11);$script:hint.Controls.Add($script:label)
$script:tray=[Windows.Forms.NotifyIcon]::new();$script:tray.Icon=[Drawing.SystemIcons]::Information;$script:tray.Text='WeType local translation';$script:tray.Visible=$true
$menu=[Windows.Forms.ContextMenuStrip]::new();$exit=$menu.Items.Add('Exit');$exit.add_Click({[Windows.Forms.Application]::ExitThread()});$script:tray.ContextMenuStrip=$menu
$script:clock=[Diagnostics.Stopwatch]::StartNew();$script:lastHash='';$script:stableHash='';$script:lastResult=$null
$script:timer=[Windows.Forms.Timer]::new();$script:timer.Interval=140
$script:timer.add_Tick({
 $capture=$null
 try{
  if($RunSeconds -gt 0 -and $script:clock.Elapsed.TotalSeconds -ge $RunSeconds){[Windows.Forms.Application]::ExitThread();return}
  $capture=[CandidateNative]::Capture()
  if($null -eq $capture){
   if($Diagnostics -and $script:hint.Visible){'{"Hidden":true}'|Add-Content -LiteralPath (Join-Path $PSScriptRoot 'live-results.jsonl') -Encoding UTF8}
   $script:hint.Hide();$script:lastHash='';$script:stableHash='';$script:lastResult=$null;return
  }
  $box=[CandidateNative]::Highlight($capture.Image)
  if($box.IsEmpty){$script:hint.Hide();$script:lastHash='';$script:stableHash='';$script:lastResult=$null;return}
  $hash=[CandidateNative]::Fingerprint($capture.Image,$box)
  if($hash -ne $script:stableHash){$script:stableHash=$hash;$script:hint.Hide();return}
  if($hash -ne $script:lastHash){
   $watch=[Diagnostics.Stopwatch]::StartNew();$result=Read-Word $capture.Image $box
   $script:lastHash=$hash;$script:lastResult=$result
   if($Diagnostics){[pscustomobject]@{Elapsed=$script:clock.Elapsed.TotalSeconds;Raw=$result.Raw;Attempts=$result.Attempts;Word=$result.Word;Meaning=$result.Meaning;Source=$result.Source;InWordlist=$result.InWordlist;Status=$result.Status;Milliseconds=$watch.Elapsed.TotalMilliseconds;Foreground=[CandidateNative]::GetForegroundWindow().ToInt64()}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $PSScriptRoot 'live-results.jsonl') -Encoding UTF8}
  }
  $result=$script:lastResult
  if(!$result.Word -or !$result.Meaning){$script:hint.Hide();return}
  # OCR can finish after the composition closes: never show a stale hint.
  if(![CandidateNative]::IsWindowVisible($capture.Handle)){$script:hint.Hide();return}
  $script:label.Text=$result.Meaning
  $area=[Windows.Forms.Screen]::FromPoint([Drawing.Point]::new($capture.Window.X+$box.X,$capture.Window.Y+$box.Y)).WorkingArea
  $size=[Windows.Forms.TextRenderer]::MeasureText($script:label.Text,$script:label.Font)
  $width=[Math]::Min([Math]::Max(220,$size.Width+34),[Math]::Min(680,$area.Width));$height=[Math]::Max(46,$size.Height+18)
  $x=[Math]::Min([Math]::Max($area.Left,$capture.Window.X+$box.Left),$area.Right-$width)
  $panel=[CandidateNative]::Panel($capture.Image,$box)
  $y=$capture.Window.Y+$panel.Bottom+10
  if($y+$height -gt $area.Bottom){$y=$capture.Window.Y+$panel.Top-$height-10}
  $y=[Math]::Max($area.Top,$y)
  [CandidateNative]::Position($script:hint,$x,$y,$width,$height)
  if(!$script:hint.Visible){
   $before=[CandidateNative]::GetForegroundWindow().ToInt64();$script:hint.Show()
   if($Diagnostics){[pscustomobject]@{Shown=$true;ForegroundBefore=$before;ForegroundAfter=[CandidateNative]::GetForegroundWindow().ToInt64();OverlayHandle=$script:hint.Handle.ToInt64();X=$x;Y=$y;Width=$width;Height=$height}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $PSScriptRoot 'live-results.jsonl') -Encoding UTF8}
  }
 }catch{
  $script:hint.Hide();$script:lastHash=''
  if($Diagnostics){[pscustomobject]@{Error=$_.Exception.Message}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $PSScriptRoot 'live-results.jsonl') -Encoding UTF8}
 }finally{if($null -ne $capture){$capture.Dispose()}}
})
try{$script:timer.Start();[Windows.Forms.Application]::Run()}finally{$script:timer.Dispose();$script:tray.Visible=$false;$script:tray.Dispose();$script:hint.Dispose();$script:mutex.ReleaseMutex();$script:mutex.Dispose()}
