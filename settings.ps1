# UI configuration stays in the current user's profile, never in the release folder.
if(-not ('CompanionSettingsForm' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'AppUI.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms}
$script:settingsDirectory=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'WeTypeCompanion'
[void][IO.Directory]::CreateDirectory($script:settingsDirectory)
$script:settingsPath=Join-Path $script:settingsDirectory 'settings.json'
$script:configuration=[pscustomobject]@{Qingjian=$true;Cedict=$false;Custom=$false}
if(Test-Path -LiteralPath $script:settingsPath){
 try{
  $loaded=[IO.File]::ReadAllText($script:settingsPath)|ConvertFrom-Json
  foreach($name in @('Qingjian','Cedict','Custom')){
   if($loaded.$name -isnot [bool]){throw '设置文件格式无效'}
   $script:configuration.$name=$loaded.$name
  }
 }catch{
  $script:configuration=[pscustomobject]@{Qingjian=$true;Cedict=$false;Custom=$false}
  [void][Windows.Forms.MessageBox]::Show('无法读取配置，已恢复默认青简词库。可在设置中重新保存。','译词伴侣')
 }
}
function Get-StartupCommand {
 $exe=Join-Path $PSScriptRoot 'WeTypeCompanion.exe'
 if(Test-Path -LiteralPath $exe){return '"'+$exe+'" --background'}
 return '"'+(Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')+'" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $PSScriptRoot 'App.ps1')+'" -Background'
}
function Get-StartupEnabled {
 $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
 try{return ($null -ne $key -and $key.GetValue('WeTypeCompanion') -eq (Get-StartupCommand))}finally{if($key){$key.Dispose()}}
}
function Set-StartupEnabled([bool]$Enabled) {
 $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
 try{if($Enabled){$key.SetValue('WeTypeCompanion',(Get-StartupCommand))}else{$key.DeleteValue('WeTypeCompanion',$false)}}finally{$key.Dispose()}
}
function Get-SelectedConfiguration {
 return [pscustomobject]@{Qingjian=$script:settingsForm.Qingjian.Checked;Cedict=$script:settingsForm.Cedict.Checked;Custom=$script:settingsForm.Custom.Checked}
}
function Update-LibraryStatus {
 $script:settingsForm.LibraryStatus.Text=('已加载 {0:N0} 个释义 · 青简 {1:N0} · CC-CEDICT {2:N0}' -f $script:lexicon.Meanings.Count,$script:lexicon.QingjianWords,$script:lexicon.CedictEntries)
}
function Apply-SelectedSettings {
 # Build and validate first. Keep the old live dictionary and disk settings on failure.
 $selected=Get-SelectedConfiguration
 $replacement=Get-LocalLexicon -Configuration $selected -DataDirectory $script:settingsDirectory
 $temporary=$script:settingsPath+'.tmp'
 [IO.File]::WriteAllText($temporary,($selected|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
 $oldStartup=$key.GetValue('WeTypeCompanion')
 try{
  Set-StartupEnabled $script:settingsForm.Startup.Checked
  if(Test-Path -LiteralPath $script:settingsPath){[IO.File]::Replace($temporary,$script:settingsPath,$script:settingsPath+'.bak')}else{[IO.File]::Move($temporary,$script:settingsPath)}
 }catch{
  if($null -ne $oldStartup){$key.SetValue('WeTypeCompanion',$oldStartup)}else{$key.DeleteValue('WeTypeCompanion',$false)}
  throw
 }finally{$key.Dispose();if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary}}
 $script:configuration=$selected;$script:lexicon=$replacement
 $script:cache.Clear();Reset-Candidate
 Update-LibraryStatus;$script:settingsForm.Status.Text='已保存并生效'
}
function Show-SettingsError($ErrorRecord){[void][Windows.Forms.MessageBox]::Show($ErrorRecord.Exception.Message,'操作失败（原词库继续使用）','OK','Error')}
function Initialize-SettingsUI {
 $script:settingsForm=[CompanionSettingsForm]::new()
 foreach($name in @('Qingjian','Cedict','Custom')){$script:settingsForm.$name.Checked=$script:configuration.$name}
 $script:settingsForm.Startup.Checked=Get-StartupEnabled
 Update-LibraryStatus
 $script:settingsForm.Save.add_Click({try{Apply-SelectedSettings}catch{Show-SettingsError $_}})
 $script:settingsForm.Reload.add_Click({try{Apply-SelectedSettings}catch{Show-SettingsError $_}})
 $script:settingsForm.AddWord.add_Click({
  try{
   [LocalLexicon]::AddGlossaryEntry((Join-Path $PSScriptRoot 'glossary-en.tsv'),$script:settingsForm.ChineseWord.Text,$script:settingsForm.EnglishMeaning.Text)
   $script:settingsForm.ChineseWord.Clear();$script:settingsForm.EnglishMeaning.Clear()
   $script:settingsForm.Status.Text='词条已保存，请启用青简词库'
   if($script:configuration.Qingjian){
    $script:lexicon=Get-LocalLexicon -Configuration $script:configuration -DataDirectory $script:settingsDirectory
    $script:cache.Clear();Reset-Candidate;Update-LibraryStatus;$script:settingsForm.Status.Text='词条已保存并生效'
   }
  }catch{Show-SettingsError $_}
 })
 $script:settingsForm.Pause.add_Click({Switch-Recognition})
 $script:settingsForm.Import.add_Click({
  $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Filter='UTF-8 词库 (*.tsv)|*.tsv';$dialog.Title='导入中文词语 / 英文释义 TSV'
  try{
   if($dialog.ShowDialog($script:settingsForm) -ne 'OK'){return}
   $stage=Join-Path $script:settingsDirectory 'custom.tsv.tmp'
   try{
    [IO.File]::Copy($dialog.FileName,$stage,$true)
    $probe=New-Object LocalLexicon;$probe.LoadTsv($stage,'Custom')
    if($probe.Meanings.Count -eq 0){throw '词库为空。'}
    $destination=Join-Path $script:settingsDirectory 'custom.tsv'
    if(Test-Path -LiteralPath $destination){[IO.File]::Replace($stage,$destination,$destination+'.bak')}else{[IO.File]::Move($stage,$destination)}
    $script:settingsForm.Custom.Checked=$true
    $script:settingsForm.Status.Text='已导入，请保存应用'
   }finally{if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage}}
  }catch{Show-SettingsError $_}finally{$dialog.Dispose()}
 })
 $script:settingsForm.UpdateDictionary.add_Click({
  try{
   if($script:dictionaryUpdate){return}
   $info=[Diagnostics.ProcessStartInfo]::new()
   $info.FileName=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
   $info.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Update-Cedict.ps1')+'" -DataDirectory "'+$script:settingsDirectory+'"'
   $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
   $script:dictionaryUpdate=[Diagnostics.Process]::Start($info)
   $script:updateOutput=$script:dictionaryUpdate.StandardOutput.ReadToEndAsync();$script:updateErrors=$script:dictionaryUpdate.StandardError.ReadToEndAsync()
   $script:updateWatch=[Diagnostics.Stopwatch]::StartNew()
   $script:settingsForm.UpdateDictionary.Enabled=$false;$script:settingsForm.Status.Text='正在下载词库…'
  }catch{Show-SettingsError $_}
 })
}
function Switch-Recognition {
 $script:paused=!$script:paused;Reset-Candidate
 $text=if($script:paused){'恢复识别'}else{'暂停识别'}
 $script:settingsForm.Pause.Text=$text;$script:pauseMenu.Text=$text
 $script:tray.Text=if($script:paused){'译词伴侣 · 已暂停'}else{'译词伴侣 · 正在运行'}
}
function Poll-Settings {
 if($script:openSettingsSignal.WaitOne(0)){$script:settingsForm.Reveal()}
 if($script:dictionaryUpdate){
  if($script:updateWatch.Elapsed.TotalMinutes -gt 3 -and !$script:dictionaryUpdate.HasExited){$script:dictionaryUpdate.Kill()}
  if($script:dictionaryUpdate.HasExited){
   try{
    if($script:dictionaryUpdate.ExitCode -ne 0){throw ('词库更新失败，原词库保留。'+$script:updateErrors.Result)}
    $replacement=Get-LocalLexicon -Configuration $script:configuration -DataDirectory $script:settingsDirectory
    $script:lexicon=$replacement;$script:cache.Clear();Reset-Candidate;Update-LibraryStatus
    $script:settingsForm.Status.Text='词库更新完成'
   }catch{Show-SettingsError $_}finally{$script:dictionaryUpdate.Dispose();$script:dictionaryUpdate=$null;$script:settingsForm.UpdateDictionary.Enabled=$true}
  }
 }
}
