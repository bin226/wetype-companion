param([string]$TestImage='', [int]$RunSeconds=0, [switch]$Diagnostics)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
[void][CandidateNative]::SetProcessDPIAware()
. (Join-Path $PSScriptRoot 'lexicon.ps1')
. (Join-Path $PSScriptRoot 'rapid-ocr.ps1')
$script:lexicon=Get-LocalLexicon
if($TestImage){
 $bitmap=[Drawing.Bitmap]::new([IO.Path]::GetFullPath($TestImage))
 try{
  $box=[CandidateNative]::Highlight($bitmap);if($box.IsEmpty){throw 'No candidate highlight found'}
  Start-RapidWorker;$watch=[Diagnostics.Stopwatch]::StartNew()
  $response=Send-RapidImage $bitmap $box 'test'
  if(!$response.Wait(10000)){throw 'OCR request timed out'}
  $result=Convert-RapidResult $response.Result
  $result|Add-Member Milliseconds $watch.Elapsed.TotalMilliseconds
  $result|Add-Member Highlight $box.ToString();$result|ConvertTo-Json
 }finally{$bitmap.Dispose();Stop-RapidWorker}
 return
}
$script:mutex=[Threading.Mutex]::new($false,'Local\WeTypeLocalGlossCompanion')
if(!$script:mutex.WaitOne(0,$false)){$script:mutex.Dispose();throw 'Companion is already running.'}
try{Start-RapidWorker}catch{$script:mutex.ReleaseMutex();$script:mutex.Dispose();throw}
$script:hint=[HintWindow]::new()
$script:label=[Windows.Forms.Label]::new();$script:label.Dock='Fill';$script:label.TextAlign='MiddleLeft'
$script:label.Font=[Drawing.Font]::new('Microsoft YaHei UI',11);$script:hint.Controls.Add($script:label)
$script:tray=[Windows.Forms.NotifyIcon]::new();$script:tray.Icon=[Drawing.SystemIcons]::Information
$script:tray.Text='WeType PP-OCRv5';$script:tray.Visible=$true
$menu=[Windows.Forms.ContextMenuStrip]::new();$exit=$menu.Items.Add('Exit')
$exit.add_Click({[Windows.Forms.Application]::ExitThread()});$script:tray.ContextMenuStrip=$menu
$script:clock=[Diagnostics.Stopwatch]::StartNew()
$script:stableKey='';$script:version=0;$script:lastKey='';$script:lastResult=$null;$script:pending=$null
$script:cache=[Collections.Generic.Dictionary[string,object]]::new()
function Reset-Candidate {
 if($script:stableKey){$script:version++}
 $script:stableKey='';$script:lastKey='';$script:lastResult=$null;$script:hint.Hide()
}
function Write-Diagnostic($Value){if($Diagnostics){$Value|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $PSScriptRoot 'live-results.jsonl') -Encoding UTF8}}
$script:timer=[Windows.Forms.Timer]::new();$script:timer.Interval=70
$script:timer.add_Tick({
 $capture=$null
 try{
  if($RunSeconds -gt 0 -and $script:clock.Elapsed.TotalSeconds -ge $RunSeconds){[Windows.Forms.Application]::ExitThread();return}
  $capture=[CandidateNative]::Capture()
  if($null -eq $capture){if($script:hint.Visible){Write-Diagnostic @{Hidden=$true}};Reset-Candidate;return}
  $box=[CandidateNative]::Highlight($capture.Image)
  if($box.IsEmpty){Reset-Candidate;return}
  $key=$capture.Handle.ToInt64().ToString()+':'+[CandidateNative]::Fingerprint($capture.Image,$box)
  if($key -ne $script:stableKey){$script:version++;$script:stableKey=$key;$script:hint.Hide();return}
  if($script:pending){
   if(!$script:pending.Task.IsCompleted){
    if($script:pending.Watch.Elapsed.TotalSeconds -gt 3){throw 'OCR response timed out; restart companion.'}
    $script:hint.Hide();return
   }
   $pending=$script:pending;$script:pending=$null
   $raw=$pending.Task.Result
   if(($raw|ConvertFrom-Json).Id -ne $pending.Version.ToString()){throw 'OCR response identifier mismatch'}
   $completed=Convert-RapidResult $raw
   if($pending.Key -eq $key -and $pending.Version -eq $script:version){
    $script:lastKey=$key;$script:lastResult=$completed
    if($script:cache.Count -ge 256){$script:cache.Clear()};$script:cache[$key]=$completed
    Write-Diagnostic @{Raw=$completed.Raw;Word=$completed.Word;Meaning=$completed.Meaning;Confidence=$completed.Confidence;Engine=$completed.Engine;RecognitionMilliseconds=$completed.RecognitionMilliseconds;ResultMilliseconds=$pending.Watch.Elapsed.TotalMilliseconds;Source=$completed.Source;Status=$completed.Status;Version=$pending.Version}
   }else{Write-Diagnostic @{DiscardedStale=$true;RequestVersion=$pending.Version;CurrentVersion=$script:version}}
  }
  if($key -ne $script:lastKey){
   if($script:cache.ContainsKey($key)){$script:lastKey=$key;$script:lastResult=$script:cache[$key]}
   else{
    $watch=[Diagnostics.Stopwatch]::StartNew();$task=Send-RapidImage $capture.Image $box ($script:version.ToString())
    $script:pending=[pscustomobject]@{Task=$task;Key=$key;Version=$script:version;Watch=$watch}
    $script:hint.Hide();return
   }
  }
  $result=$script:lastResult
  if(!$result.Meaning -or ![CandidateNative]::IsWindowVisible($capture.Handle)){$script:hint.Hide();return}
  $script:label.Text=$result.Meaning
  $area=[Windows.Forms.Screen]::FromPoint([Drawing.Point]::new($capture.Window.X+$box.X,$capture.Window.Y+$box.Y)).WorkingArea
  $size=[Windows.Forms.TextRenderer]::MeasureText($script:label.Text,$script:label.Font)
  $width=[Math]::Min([Math]::Max(220,$size.Width+34),[Math]::Min(680,$area.Width));$height=[Math]::Max(46,$size.Height+18)
  $x=[Math]::Min([Math]::Max($area.Left,$capture.Window.X+$box.Left),$area.Right-$width)
  $panel=[CandidateNative]::Panel($capture.Image,$box);$y=$capture.Window.Y+$panel.Bottom+10
  if($y+$height -gt $area.Bottom){$y=$capture.Window.Y+$panel.Top-$height-10};$y=[Math]::Max($area.Top,$y)
  [CandidateNative]::Position($script:hint,$x,$y,$width,$height)
  if(!$script:hint.Visible){
   $before=[CandidateNative]::GetForegroundWindow().ToInt64();$script:hint.Show()
   Write-Diagnostic @{Shown=$true;Word=$result.Word;ForegroundBefore=$before;ForegroundAfter=[CandidateNative]::GetForegroundWindow().ToInt64()}
  }
 }catch{
  $script:hint.Hide();$script:lastKey='';Write-Diagnostic @{Error=$_.Exception.Message}
  # Stop a broken worker instead of accumulating requests or stale results.
  if($script:pending -and $script:pending.Watch.Elapsed.TotalSeconds -gt 3){[Windows.Forms.Application]::ExitThread()}
 }finally{if($capture){$capture.Dispose()}}
})
try{$script:timer.Start();[Windows.Forms.Application]::Run()}finally{
 $script:timer.Dispose();$script:tray.Visible=$false;$script:tray.Dispose();$script:hint.Dispose()
 Stop-RapidWorker;$script:mutex.ReleaseMutex();$script:mutex.Dispose()
}
