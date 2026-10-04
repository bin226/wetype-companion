using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

// Source priority is determined by load order, not approximate word matching.
public sealed class LocalLexicon {
 public Dictionary<string,string> Meanings {get;private set;}
 public Dictionary<string,string> Sources {get;private set;}
 public HashSet<string> Words {get;private set;}
 public LocalLexicon(){Meanings=new Dictionary<string,string>(StringComparer.Ordinal);Sources=new Dictionary<string,string>(StringComparer.Ordinal);Words=new HashSet<string>(StringComparer.Ordinal);}
 string[] compactWords,compactMeanings,sourceNames,compactExportWords;byte[] compactSources;
 public int Count {get{return compactWords==null?Meanings.Count:compactWords.Length;}}
 // The application only queries loaded dictionaries. Keep one sorted word index
 // and parallel values, releasing all three mutable hash tables after loading.
 public void Compact(){
  if(compactWords!=null)return;
  compactWords=new string[Meanings.Count];Meanings.Keys.CopyTo(compactWords,0);Array.Sort(compactWords,StringComparer.Ordinal);
  compactMeanings=new string[compactWords.Length];compactSources=new byte[compactWords.Length];
  var names=new List<string>();
  for(int i=0;i<compactWords.Length;i++){
   compactMeanings[i]=Meanings[compactWords[i]];string source=Source(compactWords[i]);int id=names.IndexOf(source);
   if(id<0){id=names.Count;names.Add(source);}if(id>255)throw new InvalidOperationException("Too many dictionary sources.");compactSources[i]=(byte)id;
  }
  sourceNames=names.ToArray();
  if(Words.Count!=compactWords.Length){compactExportWords=new string[Words.Count];Words.CopyTo(compactExportWords);Array.Sort(compactExportWords,StringComparer.Ordinal);}
  Meanings=new Dictionary<string,string>(StringComparer.Ordinal);Sources=new Dictionary<string,string>(StringComparer.Ordinal);Words=new HashSet<string>(StringComparer.Ordinal);
 }
 void RequireMutable(){if(compactWords!=null)throw new InvalidOperationException("Reload the dictionary before editing a compact index.");}
 public int CedictEntries;
 public int CedictWords;
 public int QingjianWords;
 public int VocabularyOnlyWords;
 static readonly Regex CedictLine = new Regex(@"^(\S+) (\S+) \[.+?\] /(.+)/$", RegexOptions.Compiled);
 struct Definitions {
  public string First,Second;
  public void Add(string value){if(String.IsNullOrWhiteSpace(value) || value==First || value==Second)return;if(First==null)First=value;else if(Second==null)Second=value;}
  public string Meaning {get{return Second==null?First ?? "":First+" · "+Second;}}
 }
 public void LoadCedict(string path) {
  RequireMutable();
  // Two definitions suffice; inline the pair instead of a List + backing array
  // for every word in the temporary parse map.
  var entries = new Dictionary<string,Definitions>(StringComparer.Ordinal);
  foreach(string line in File.ReadLines(path, Encoding.UTF8)) {
   if(line.StartsWith("#") || String.IsNullOrWhiteSpace(line)) continue;
   var match = CedictLine.Match(line);
   if(!match.Success) throw new InvalidDataException("Invalid CC-CEDICT entry: " + line);
   CedictEntries++;
   string traditional=match.Groups[1].Value,simplified=match.Groups[2].Value;
   string[] meanings=match.Groups[3].Value.Split('/');
   foreach(string word in traditional==simplified?new[]{traditional}:new[]{traditional,simplified}) {
    Definitions definitions;entries.TryGetValue(word,out definitions);
    foreach(string definition in meanings){definitions.Add(definition);if(definitions.Second!=null)break;}
    entries[word]=definitions;
   }
  }
  if(CedictEntries==0) throw new InvalidDataException("CC-CEDICT has no entries.");
  foreach(var pair in entries) {Meanings[pair.Key]=pair.Value.Meaning;Sources[pair.Key]="CC-CEDICT";Words.Add(pair.Key);}
  CedictWords=entries.Count;
 }
 public void LoadTsv(string path,string source) {
  RequireMutable();
  var loaded = new HashSet<string>(StringComparer.Ordinal);
  int number=0;
  foreach(string line in File.ReadLines(path,Encoding.UTF8)) {
   number++;
   if(line.StartsWith("#") || String.IsNullOrWhiteSpace(line)) continue;
   string[] columns=line.Split('\t');
   if(columns.Length<2 || String.IsNullOrWhiteSpace(columns[0]) || String.IsNullOrWhiteSpace(columns[1])) throw new InvalidDataException(path+":"+number+": expected word<TAB>meaning");
   string word=columns[0].Trim();
   Meanings[word]=String.Join(" · ",columns,1,Math.Min(2,columns.Length-1));
   Sources[word]=source;Words.Add(word);loaded.Add(word);
  }
  if(source=="Qingjian") QingjianWords=loaded.Count;
 }
 public void LoadVocabulary(string path) {
  RequireMutable();
  foreach(string line in File.ReadLines(path,Encoding.UTF8)) {
   string word=line.Trim();
   if(word.Length==0 || word.StartsWith("#")) continue;
   if(word.IndexOf('\t')>=0 || word.IndexOf(' ')>=0) throw new InvalidDataException("personal-words.txt expects one word per line");
   if(Words.Add(word)) VocabularyOnlyWords++;
  }
 }
 public string Meaning(string word) {if(compactWords!=null){int i=Array.BinarySearch(compactWords,word,StringComparer.Ordinal);return i<0?"":compactMeanings[i];}string value;return Meanings.TryGetValue(word,out value)?value:"";}
 public static void AddGlossaryEntry(string path,string word,string meaning) {
  word=(word ?? "").Trim();meaning=(meaning ?? "").Trim();
  if(word.Length==0 || meaning.Length==0)throw new InvalidDataException("请填写中文词语和英文释义。");
  if(word.IndexOfAny(new[]{'\t','\r','\n'})>=0 || meaning.IndexOfAny(new[]{'\t','\r','\n'})>=0 || word.StartsWith("#"))throw new InvalidDataException("词语和释义不能包含 Tab 或换行，词语不能以 # 开头。");
  var rows=new SortedDictionary<string,string>(Comparer<string>.Create(CompareCodePoints));
  foreach(string line in File.ReadLines(path,new UTF8Encoding(false,true))) {
   if(String.IsNullOrWhiteSpace(line))continue;
   string[] columns=line.Split('\t');
   if(columns.Length<2 || String.IsNullOrWhiteSpace(columns[0]) || String.IsNullOrWhiteSpace(columns[1]))throw new InvalidDataException("原青简词表格式无效，未写入。");
   if(rows.ContainsKey(columns[0]))throw new InvalidDataException("原青简词表存在重复词语，未写入。");
   rows.Add(columns[0],line);
  }
  if(rows.ContainsKey(word))throw new InvalidDataException("青简词表已包含这个词语，未覆盖原释义。");
  rows.Add(word,word+"\t"+meaning);
  string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
  try {
   using(var writer=new StreamWriter(temp,false,new UTF8Encoding(false))){writer.NewLine="\n";foreach(string row in rows.Values)writer.WriteLine(row);}
   var probe=new LocalLexicon();probe.LoadTsv(temp,"Qingjian");
   File.Replace(temp,path,path+".bak");
  }finally{if(File.Exists(temp))File.Delete(temp);}
 }
 static int CompareCodePoints(string a,string b) {
  int i=0,j=0;while(i<a.Length && j<b.Length){int x=Char.ConvertToUtf32(a,i),y=Char.ConvertToUtf32(b,j);if(x!=y)return x.CompareTo(y);i+=x>0xffff?2:1;j+=y>0xffff?2:1;}return (a.Length-i).CompareTo(b.Length-j);
 }
 public string Source(string word) {if(sourceNames!=null){int i=Array.BinarySearch(compactWords,word,StringComparer.Ordinal);return i<0?"":sourceNames[compactSources[i]];}string value;return Sources.TryGetValue(word,out value)?value:"";}
 public void ExportWords(string path) {if(compactWords!=null){File.WriteAllLines(path,compactExportWords ?? compactWords,new UTF8Encoding(false));return;}var words=new List<string>(Words);words.Sort(StringComparer.Ordinal);File.WriteAllLines(path,words,new UTF8Encoding(false));}
}
