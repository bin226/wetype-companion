param([switch]$SkipRuntime,[switch]$Zip,[string]$OutputDirectory='')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$output=Join-Path $root 'dist\WeTypeCompanion'
if($OutputDirectory){$output=[IO.Path]::GetFullPath($OutputDirectory)}
[void][IO.Directory]::CreateDirectory($output)
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
if(-not ('CompanionArtwork' -as [type])){Add-Type -Path (Join-Path $root 'AppUI.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms}
$iconPath=Join-Path $output 'companion.ico'
$icon=[CompanionArtwork]::Create(64);$stream=[IO.File]::Create($iconPath)
try{$icon.Save($stream)}finally{$stream.Dispose();$icon.Dispose()}
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(!(Test-Path -LiteralPath $compiler)){throw '需要 Windows .NET Framework 4.x 编译器。'}

& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/win32icon:$iconPath" "/out:$output\WeTypeCompanion.exe" (Join-Path $root 'Launcher.cs') (Join-Path $root 'Native.cs') (Join-Path $root 'Lexicon.cs') (Join-Path $root 'AppUI.cs') (Join-Path $root 'CompanionApplication.cs') (Join-Path $root 'NativeTests.cs')
if($LASTEXITCODE -ne 0){throw '可执行程序编译失败。'}
$files=@('App.ps1','AppUI.cs','settings.ps1','companion-rapid.ps1','Native.cs','Lexicon.cs','lexicon.ps1','rapid-ocr.ps1','ocr_worker.py','Update-Cedict.ps1','glossary-en.tsv','glossary-source.md','qingjian-revision.txt','ocr-model-source.json','requirements.txt','requirements-lock.txt','THIRD-PARTY-NOTICES.md','LICENSE','README.md','Launcher.cs','CompanionApplication.cs','NativeTests.cs','Build-App.ps1')
foreach($file in $files){Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $output $file) -Force}
$legacyPersonal=Join-Path $output 'personal.tsv'
if(Test-Path -LiteralPath $legacyPersonal -PathType Leaf){Remove-Item -LiteralPath $legacyPersonal}
[void][IO.Directory]::CreateDirectory((Join-Path $output 'data'))
foreach($file in @('cedict.u8','cedict-source.json','README.md')){Copy-Item -LiteralPath (Join-Path $root ('data\'+$file)) -Destination (Join-Path $output ('data\'+$file)) -Force}
Copy-Item -LiteralPath (Join-Path $root 'licenses') -Destination $output -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'docs') -Destination $output -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'models') -Destination $output -Recurse -Force
if(!$SkipRuntime){
 $cfg=[IO.File]::ReadAllText((Join-Path $root '.venv\pyvenv.cfg'))
 $pythonHome=[regex]::Match($cfg,'(?m)^home = (.+)\r?$').Groups[1].Value.Trim()
 if(!(Test-Path -LiteralPath (Join-Path $pythonHome 'python.exe'))){throw '无法定位 Python 基础运行时。'}
 $runtime=Join-Path $output 'runtime';[void][IO.Directory]::CreateDirectory($runtime)
 foreach($file in Get-ChildItem -LiteralPath $pythonHome -File){Copy-Item -LiteralPath $file.FullName -Destination $runtime -Force}
 Copy-Item -LiteralPath (Join-Path $pythonHome 'DLLs') -Destination $runtime -Recurse -Force
 # Do not ship unrelated packages from the host's bundled Python.
 & robocopy (Join-Path $pythonHome 'Lib') (Join-Path $runtime 'Lib') /E /XD site-packages __pycache__ /XF '*.pyc' /NFL /NDL /NJH /NJS /NP | Out-Null
 if($LASTEXITCODE -ge 8){throw '复制 Python 标准库失败。'}
 & robocopy (Join-Path $root '.venv\Lib\site-packages') (Join-Path $runtime 'Lib\site-packages') /E /XD __pycache__ /XF '*.pyc' /NFL /NDL /NJH /NJS /NP | Out-Null
 if($LASTEXITCODE -ge 8){throw '复制 OCR 依赖失败。'}
 # Isolate from PYTHONHOME/PYTHONPATH and the user's installed Python packages.
 [IO.File]::WriteAllText((Join-Path $runtime 'python312._pth'),".\nLib\nDLLs\nLib\site-packages\nimport site\n".Replace('\n',"`r`n"),[Text.UTF8Encoding]::new($false))
}
if($Zip){
 $archive=Join-Path $root 'dist\WeTypeCompanion-win-x64.zip'
 # Package explicitly so stale local backups/configuration never enter a Release.
 Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
 $stream=[IO.File]::Open($archive,[IO.FileMode]::Create)
 $archiveWriter=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
 try{
  $prefix=$output.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
  foreach($file in Get-ChildItem -LiteralPath $output -Recurse -File){
   $relative=$file.FullName.Substring($prefix.Length).Replace('\','/')
   if($relative -match '(^|/)(personal\.tsv|personal-words\.txt|settings\.json|custom\.tsv|live-results\.jsonl|live-preview\.png|\.env[^/]*|\.venv|\.git)(/|$)|\.(bak|log|tmp)$'){continue}
   [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archiveWriter,$file.FullName,('WeTypeCompanion/'+$relative),[IO.Compression.CompressionLevel]::Optimal)
  }
 }finally{$archiveWriter.Dispose();$stream.Dispose()}
 $hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
 [IO.File]::WriteAllText(($archive+'.sha256'),($hash+'  '+[IO.Path]::GetFileName($archive)+"`n"),[Text.UTF8Encoding]::new($false))
}
# Robocopy uses 1-7 for successful copies; do not leak these to a CI caller.
$global:LASTEXITCODE=0
Write-Output "已生成：$output\WeTypeCompanion.exe"
