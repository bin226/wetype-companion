using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

// Source priority is determined by load order, not approximate word matching.
public sealed class LocalLexicon {
 public readonly Dictionary<string,string> Meanings = new Dictionary<string,string>(StringComparer.Ordinal);
 public readonly Dictionary<string,string> Sources = new Dictionary<string,string>(StringComparer.Ordinal);
 public readonly HashSet<string> Words = new HashSet<string>(StringComparer.Ordinal);
 public int CedictEntries;
 public int CedictWords;
 public int QingjianWords;
 public int PersonalWords;
 public int VocabularyOnlyWords;
 static readonly Regex CedictLine = new Regex(@"^(\S+) (\S+) \[.+?\] /(.+)/$", RegexOptions.Compiled);
 public void LoadCedict(string path) {
  var entries = new Dictionary<string,List<string>>(StringComparer.Ordinal);
  foreach(string line in File.ReadLines(path, Encoding.UTF8)) {
   if(line.StartsWith("#") || String.IsNullOrWhiteSpace(line)) continue;
   var match = CedictLine.Match(line);
   if(!match.Success) throw new InvalidDataException("Invalid CC-CEDICT entry: " + line);
   CedictEntries++;
   foreach(string word in new[]{match.Groups[1].Value,match.Groups[2].Value}) {
    List<string> definitions;
    if(!entries.TryGetValue(word,out definitions)) {definitions=new List<string>();entries[word]=definitions;}
    foreach(string definition in match.Groups[3].Value.Split('/')) {
     if(definitions.Count<2 && !String.IsNullOrWhiteSpace(definition) && !definitions.Contains(definition)) definitions.Add(definition);
    }
   }
  }
  if(CedictEntries==0) throw new InvalidDataException("CC-CEDICT has no entries.");
  foreach(var pair in entries) {Meanings[pair.Key]=String.Join(" · ",pair.Value);Sources[pair.Key]="CC-CEDICT";Words.Add(pair.Key);}
  CedictWords=entries.Count;
 }
 public void LoadTsv(string path,string source) {
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
  if(source=="Personal") PersonalWords=loaded.Count;
 }
 public void LoadVocabulary(string path) {
  foreach(string line in File.ReadLines(path,Encoding.UTF8)) {
   string word=line.Trim();
   if(word.Length==0 || word.StartsWith("#")) continue;
   if(word.IndexOf('\t')>=0 || word.IndexOf(' ')>=0) throw new InvalidDataException("personal-words.txt expects one word per line");
   if(Words.Add(word)) VocabularyOnlyWords++;
  }
 }
 public string Meaning(string word) {string value;return Meanings.TryGetValue(word,out value)?value:"";}
 public string Source(string word) {string value;return Sources.TryGetValue(word,out value)?value:"";}
 public void ExportWords(string path) {var words=new List<string>(Words);words.Sort(StringComparer.Ordinal);File.WriteAllLines(path,words,new UTF8Encoding(false));}
}
