param([Parameter(Mandatory=$true)][string[]]$Word)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lexicon.ps1')
$lexicon=Get-LocalLexicon
foreach($value in $Word){
 [pscustomobject]@{Word=$value;InWordlist=$lexicon.Words.Contains($value);Meaning=$lexicon.Meaning($value);Source=$lexicon.Source($value)}
}
