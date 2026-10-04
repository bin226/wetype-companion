# This shared loader also works without initializing OCR or a window.
if (-not ('LocalLexicon' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Lexicon.cs') }
function Get-LocalLexicon {
 param([string]$Root=$PSScriptRoot,[switch]$IncludeSupplementary,$Configuration=$null,[string]$DataDirectory='')
 $lexicon=New-Object LocalLexicon
 if($null -ne $Configuration){
  $cedict=Join-Path $Root 'data\cedict.u8'
  if($DataDirectory -and (Test-Path -LiteralPath (Join-Path $DataDirectory 'cedict.u8'))){$cedict=Join-Path $DataDirectory 'cedict.u8'}
  if($Configuration.Cedict){$lexicon.LoadCedict($cedict)}
  if($Configuration.Qingjian){$lexicon.LoadTsv((Join-Path $Root 'glossary-en.tsv'),'Qingjian')}
  if($Configuration.Custom){$lexicon.LoadTsv((Join-Path $DataDirectory 'custom.tsv'),'Custom')}
  if($lexicon.Meanings.Count -eq 0){throw '请至少选择一个含释义的词库。'}
  return $lexicon
 }
 $cedict=Join-Path $Root 'data\cedict.u8'
 if($IncludeSupplementary -and (Test-Path -LiteralPath $cedict)){$lexicon.LoadCedict($cedict)}
 $lexicon.LoadTsv((Join-Path $Root 'glossary-en.tsv'),'Qingjian')
 $words=Join-Path $Root 'personal-words.txt'
 if($IncludeSupplementary -and (Test-Path -LiteralPath $words)){$lexicon.LoadVocabulary($words)}
 return $lexicon
}
