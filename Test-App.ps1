$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'lexicon.ps1')
. (Join-Path $PSScriptRoot 'settings.ps1')
function Assert($condition,$message){if(!$condition){throw $message}}
function Reset-Candidate {}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('wetype-app-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$script:settingsDirectory=$fixture;$script:settingsPath=Join-Path $fixture 'settings.json'
$script:lexicon=Get-LocalLexicon
$script:cache=[Collections.Generic.Dictionary[string,object]]::new()
$key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
$previous=$key.GetValue('WeTypeCompanion')
try{
 Initialize-SettingsUI
 $script:settingsForm.Qingjian.Checked=$true
 foreach($name in @('Cedict','Custom')){$script:settingsForm.$name.Checked=$false}
 $script:settingsForm.Startup.Checked=$false
 Apply-SelectedSettings
 Assert (([IO.File]::ReadAllText($script:settingsPath)|ConvertFrom-Json).Qingjian) 'Settings did not persist'
 Set-StartupEnabled $true
 Assert (Get-StartupEnabled) 'Startup command or quoting failed'
 Set-StartupEnabled $false
 Assert (!(Get-StartupEnabled)) 'Startup entry was not removed'
 $script:settingsForm.Qingjian.Checked=$false;$script:settingsForm.Cedict.Checked=$true
 Apply-SelectedSettings
 Assert ($script:lexicon.CedictEntries -gt 100000 -and $script:lexicon.QingjianWords -eq 0) 'CC-CEDICT selection failed'
 $script:settingsForm.Qingjian.Checked=$true
 Apply-SelectedSettings
 Assert ($script:lexicon.Source('速度') -eq 'Qingjian') 'Dictionary priority failed'
 [IO.File]::WriteAllText((Join-Path $fixture 'custom.tsv'),"速度`tcustom speed`n",[Text.UTF8Encoding]::new($false))
 $script:settingsForm.Custom.Checked=$true;Apply-SelectedSettings
 Assert ($script:lexicon.Meaning('速度') -eq 'custom speed') 'Custom dictionary priority failed'
 $old=$script:lexicon;$oldDisk=[IO.File]::ReadAllText($script:settingsPath)
 [IO.File]::WriteAllText((Join-Path $fixture 'custom.tsv'),'invalid row')
 $rejected=$false;try{Apply-SelectedSettings}catch{$rejected=$true}
 Assert ($rejected -and [Object]::ReferenceEquals($old,$script:lexicon) -and $oldDisk -eq [IO.File]::ReadAllText($script:settingsPath)) 'Invalid data replaced active dictionary or settings'
 foreach($name in @('Qingjian','Cedict','Custom')){$script:settingsForm.$name.Checked=$false}
 $rejected=$false;try{Apply-SelectedSettings}catch{$rejected=$true}
 Assert $rejected 'Empty selection must be rejected'
 $script:configuration=[pscustomobject]@{Qingjian=$true;Cedict=$false;Custom=$false}
 $script:lexicon=Get-LocalLexicon;Update-LibraryStatus
 $script:settingsForm.Qingjian.Checked=$true;$script:settingsForm.Status.Text='运行正常'
 $script:settingsForm.Show();[Windows.Forms.Application]::DoEvents();$script:settingsForm.PerformLayout()
 $bitmap=[Drawing.Bitmap]::new($script:settingsForm.Width,$script:settingsForm.Height)
 try{$script:settingsForm.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$bitmap.Width,$bitmap.Height));$bitmap.Save((Join-Path $PSScriptRoot 'test-results\settings-ui.png'))}finally{$bitmap.Dispose()}
 'PASS: settings persistence, startup enable/disable, dictionary selection and priority, invalid data rollback, empty selection and UI rendering.'
}finally{
 if($null -ne $previous){$key.SetValue('WeTypeCompanion',$previous)}else{$key.DeleteValue('WeTypeCompanion',$false)}
 $key.Dispose();if($script:settingsForm){$script:settingsForm.Dispose()}
 foreach($file in Get-ChildItem -LiteralPath $fixture -File){Remove-Item -LiteralPath $file.FullName}
 Remove-Item -LiteralPath $fixture
}
