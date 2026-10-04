param([switch]$Background,[int]$RunSeconds=0)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
try { & (Join-Path $PSScriptRoot 'companion-rapid.ps1') -ShowSettings:(!$Background) -RunSeconds $RunSeconds }
catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'译词伴侣启动失败','OK','Error');exit 1 }
