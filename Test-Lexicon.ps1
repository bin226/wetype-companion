$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lexicon.ps1')
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('wetype-lexicon-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'data'))
$encoding=[Text.UTF8Encoding]::new($false)
try{
 [IO.File]::WriteAllText((Join-Path $fixture 'data\cedict.u8'),"# fixture`n測試 测试 [ce4 shi4] /dictionary/test/`n測試 测试 [ce4 shi4] /test/another/`n補充 补充 [bu3 chong1] /supplement/`n",$encoding)
 [IO.File]::WriteAllText((Join-Path $fixture 'glossary-en.tsv'),"测试`tqingjian`n覆盖`tqingjian`n",$encoding)
 [IO.File]::WriteAllText((Join-Path $fixture 'personal.tsv'),"# comment`n覆盖`tpersonal`n",$encoding)
 [IO.File]::WriteAllText((Join-Path $fixture 'personal-words.txt'),"# comment`n仅词表`n测试`n",$encoding)
 $lexicon=Get-LocalLexicon -Root $fixture -IncludeSupplementary
 Assert ($lexicon.Meaning('测试') -eq 'qingjian') 'Qingjian must override CC-CEDICT'
 Assert ($lexicon.Meaning('覆盖') -eq 'qingjian') 'Legacy personal file must not override Qingjian'
 Assert ($lexicon.Source('覆盖') -eq 'Qingjian') 'Source tracking failed'
 Assert ($lexicon.Meaning('補充') -eq 'supplement' -and $lexicon.Meaning('补充') -eq 'supplement') 'Traditional/simplified lookup failed'
 Assert ($lexicon.Meaning('測試') -eq 'dictionary · test') 'Duplicate definitions must merge'
 Assert ($lexicon.Words.Contains('仅词表') -and !$lexicon.Meaning('仅词表')) 'Vocabulary-only word must not invent a translation'
 Assert (!$lexicon.Words.Contains('不存在') -and !$lexicon.Meaning('不存在')) 'Unknown word must stay unknown'
 $export=Join-Path $fixture 'words.txt';$lexicon.ExportWords($export)
 Assert ([IO.File]::ReadAllLines($export).Length -eq $lexicon.Words.Count) 'Export count mismatch'
 [IO.File]::WriteAllText((Join-Path $fixture 'glossary-en.tsv'),'invalid row',$encoding)
 $rejected=$false;try{$null=Get-LocalLexicon -Root $fixture -IncludeSupplementary}catch{$rejected=$true}
 Assert $rejected 'Malformed Qingjian dictionary must report an error'
 $actual=Get-LocalLexicon
 Assert ($actual.CedictEntries -eq 0 -and $actual.QingjianWords -eq 232213 -and $actual.Words.Count -eq 232213) 'Runtime must load only Qingjian'
 foreach($word in @('微信','违心','弯折')){Assert ($actual.Meaning($word).Length -gt 0) ('Missing regression word: '+$word)}
 Assert (!$actual.Meaning('微信输入法')) 'Supplementary personal terms must remain disabled'
 'PASS: priority, source, traditional/simplified lookup, duplicates, vocabulary-only/unknown words, export, invalid input and production data.'
}finally{
 foreach($name in @('data\cedict.u8','glossary-en.tsv','personal.tsv','personal-words.txt','words.txt')){
  $path=Join-Path $fixture $name;if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}
 }
 Remove-Item -LiteralPath (Join-Path $fixture 'data')
 Remove-Item -LiteralPath $fixture
}
