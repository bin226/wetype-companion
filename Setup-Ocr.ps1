param([Parameter(Mandatory=$true)][string]$Python,[string]$IndexUrl='https://pypi.org/simple')
$ErrorActionPreference='Stop'
& $Python -m venv (Join-Path $PSScriptRoot '.venv')
if($LASTEXITCODE){throw 'Cannot create Python environment'}
$localPython=Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
& $localPython -m pip install --index-url $IndexUrl -r (Join-Path $PSScriptRoot 'requirements.txt')
if($LASTEXITCODE){throw 'OCR dependency installation failed'}
Push-Location $PSScriptRoot
try{& $localPython -c "from ocr_worker import create_recognizer; create_recognizer(allow_download=True)";if($LASTEXITCODE){throw 'Model setup failed'}}finally{Pop-Location}
