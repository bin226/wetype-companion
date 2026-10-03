$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lexicon.ps1')
$lexicon=Get-LocalLexicon
$data=Join-Path $PSScriptRoot 'data'
[void][IO.Directory]::CreateDirectory($data)
$lexicon.ExportWords((Join-Path $data 'wordlist.txt'))
$stats=[ordered]@{
 CedictEntries=$lexicon.CedictEntries;CedictWords=$lexicon.CedictWords
 QingjianWords=$lexicon.QingjianWords;PersonalWords=$lexicon.PersonalWords
 VocabularyOnlyWords=$lexicon.VocabularyOnlyWords
 TranslatedWords=$lexicon.Meanings.Count;TotalWords=$lexicon.Words.Count
 Priority=@('Qingjian')
}
$json=$stats | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $data 'wordlist-stats.json'),$json,[Text.UTF8Encoding]::new($false))
$json
