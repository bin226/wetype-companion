param([Parameter(Mandatory=$true)][string]$Image,[Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
$bitmap=[Drawing.Bitmap]::new([IO.Path]::GetFullPath($Image))
try{
 $box=[CandidateNative]::Highlight($bitmap)
 if($box.IsEmpty){throw 'No highlight'}
 $normalized=[CandidateNative]::Normalize($bitmap,$box)
 try{$normalized.Save([IO.Path]::GetFullPath($OutputPath),[Drawing.Imaging.ImageFormat]::Png)}finally{$normalized.Dispose()}
}finally{$bitmap.Dispose()}
