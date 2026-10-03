param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
[void][CandidateNative]::SetProcessDPIAware()
$capture=[CandidateNative]::Capture()
if($null -eq $capture){throw 'No visible WeType candidate window'}
try{
 $box=[CandidateNative]::Highlight($capture.Image)
 if($box.IsEmpty){throw 'No green highlighted candidate'}
 $box.Inflate(5,5);$box.Intersect([Drawing.Rectangle]::new(0,0,$capture.Image.Width,$capture.Image.Height))
 $crop=$capture.Image.Clone($box,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 try{
  $full=[IO.Path]::GetFullPath($OutputPath)
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full))
  $crop.Save($full,[Drawing.Imaging.ImageFormat]::Png)
  [pscustomobject]@{Path=$full;Crop=$box.ToString();Window=$capture.Handle.ToInt64()}|ConvertTo-Json
 }finally{$crop.Dispose()}
}finally{$capture.Dispose()}
