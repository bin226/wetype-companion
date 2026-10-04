param([Parameter(Mandatory=$true)][string]$Python,[string]$IndexUrl='https://pypi.org/simple')
$ErrorActionPreference='Stop'
& $Python -c "import sys, struct; assert sys.version_info[:2] == (3, 12) and struct.calcsize('P') == 8, 'Python 3.12 x64 is required'"
if($LASTEXITCODE){throw 'Python 3.12 x64 is required'}
& $Python -m venv (Join-Path $PSScriptRoot '.venv')
if($LASTEXITCODE){throw 'Cannot create Python environment'}
$localPython=Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
& $localPython -m pip install --index-url $IndexUrl -r (Join-Path $PSScriptRoot 'requirements.txt') -c (Join-Path $PSScriptRoot 'requirements-lock.txt')
if($LASTEXITCODE){throw 'OCR dependency installation failed'}
Push-Location $PSScriptRoot
try{& $localPython -c "from ocr_worker import create_recognizer; create_recognizer(allow_download=True)";if($LASTEXITCODE){throw 'Model setup failed'}}finally{Pop-Location}

$metadata=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ocr-model-source.json') -Raw | ConvertFrom-Json
$model=Join-Path $PSScriptRoot ('models\'+$metadata.Model)
if((Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash -ne $metadata.Sha256){throw 'Downloaded OCR model SHA-256 does not match ocr-model-source.json'}
