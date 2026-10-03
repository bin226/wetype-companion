# This shared loader also works without initializing OCR or a window.
if (-not ('LocalLexicon' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Lexicon.cs') }
function Get-LocalLexicon {
 param([string]$Root=$PSScriptRoot,[switch]$IncludeSupplementary)
 $lexicon=New-Object LocalLexicon
 $cedict=Join-Path $Root 'data\cedict.u8'
 if($IncludeSupplementary -and (Test-Path -LiteralPath $cedict)){$lexicon.LoadCedict($cedict)}
 $lexicon.LoadTsv((Join-Path $Root 'glossary-en.tsv'),'Qingjian')
 $personal=Join-Path $Root 'personal.tsv'
 if($IncludeSupplementary -and (Test-Path -LiteralPath $personal)){$lexicon.LoadTsv($personal,'Personal')}
 $words=Join-Path $Root 'personal-words.txt'
 if($IncludeSupplementary -and (Test-Path -LiteralPath $words)){$lexicon.LoadVocabulary($words)}
 return $lexicon
}
