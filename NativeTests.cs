using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

static class NativeTests {
 static void Check(bool condition,string message){if(!condition)throw new Exception(message);}
 static void Reject(Action action,string message){bool rejected=false;try{action();}catch{rejected=true;}Check(rejected,message);}
 static void CheckLayout(Control parent){
  foreach(Control child in parent.Controls){
   Check(child.Top>=0 && child.Bottom<=parent.ClientSize.Height,"Clipped control: "+child.Text);
   if(child is CheckBox)Check(child.Height>=child.GetPreferredSize(Size.Empty).Height,"Clipped checkbox text: "+child.Text);
   foreach(Control other in parent.Controls)if(child!=other)Check(!child.Bounds.IntersectsWith(other.Bounds),"Overlapping controls: "+child.Text+" / "+other.Text);
   CheckLayout(child);
  }
 }
 public static void Run(string root,string[] args){
  int index=Array.IndexOf(args,"--self-test");string source=index+1<args.Length?Path.GetFullPath(args[index+1]):root;
  index=Array.IndexOf(args,"--memory-probe");if(index>=0){Measure(root,source,args[index+1]);return;}
  string report=Path.Combine(source,"test-results\\native-tests.txt");string temp=Path.Combine(Path.GetTempPath(),"wetype-native-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(temp);
  try{
   var store=new ConfigurationStore(root,temp);Check(store.Read().Qingjian,"Default configuration");
   var config=DictionaryConfiguration.Default();var lexicon=store.Load(config);Check(lexicon.QingjianWords==232213,"Qingjian count");
   string editing=Path.Combine(temp,"glossary-en.tsv");
   string original="一\tone\tfirst\n末\tlast\n\ue000\tprivate\n\U00020000\tsupplementary\n";
   File.WriteAllText(editing,original,new UTF8Encoding(false));
   LocalLexicon.AddGlossaryEntry(editing," 中 "," middle ");
   Check(File.ReadAllText(editing)=="一\tone\tfirst\n中\tmiddle\n末\tlast\n\ue000\tprivate\n\U00020000\tsupplementary\n","Sorted insertion or original columns changed");
   Check(File.ReadAllText(editing+".bak")==original,"Glossary backup");
   byte[] bytes=File.ReadAllBytes(editing);Check(!(bytes[0]==0xef && bytes[1]==0xbb && bytes[2]==0xbf) && File.ReadAllText(editing).IndexOf('\r')<0,"UTF-8 no BOM / LF");
   var edited=new ConfigurationStore(temp,Path.Combine(temp,"edit-settings"));Check(edited.Load(DictionaryConfiguration.Default()).Meaning("中")=="middle","Saved entry reload");
   string saved=File.ReadAllText(editing);
   Reject(()=>LocalLexicon.AddGlossaryEntry(editing,"中","overwrite"),"Duplicate accepted");
   Reject(()=>LocalLexicon.AddGlossaryEntry(editing," ","blank"),"Blank word accepted");
   Reject(()=>LocalLexicon.AddGlossaryEntry(editing,"新","x\ty"),"Tab accepted");
   Reject(()=>LocalLexicon.AddGlossaryEntry(editing,"新\n词","new"),"Newline accepted");
   Check(File.ReadAllText(editing)==saved,"Rejected entry changed glossary");
   File.Delete(editing+".bak");Directory.CreateDirectory(editing+".bak");Reject(()=>LocalLexicon.AddGlossaryEntry(editing,"新","new"),"Failed replacement accepted");Check(File.ReadAllText(editing)==saved,"Failed replacement changed glossary");Directory.Delete(editing+".bak");
   File.WriteAllText(editing,"invalid");Reject(()=>LocalLexicon.AddGlossaryEntry(editing,"新","new"),"Malformed glossary accepted");Check(File.ReadAllText(editing)=="invalid","Malformed glossary changed");
   File.WriteAllText(edited.SettingsPath,"{\"Qingjian\":true,\"Cedict\":false,\"Personal\":true,\"Custom\":false}");Check(edited.Read().Qingjian,"Legacy personal settings compatibility");File.Delete(edited.SettingsPath);Directory.Delete(edited.DataDirectory);
   config.Cedict=true;lexicon=store.Load(config);Check(lexicon.CedictEntries>100000,"Dictionary selection");Check(lexicon.Source("速度")=="Qingjian","Priority");
   string custom=Path.Combine(temp,"input.tsv");File.WriteAllText(custom,"速度\tcustom speed\n",new UTF8Encoding(false));store.Import(custom);config.Custom=true;Check(store.Load(config).Meaning("速度")=="custom speed","Custom priority");
   File.WriteAllText(custom,"invalid");Reject(()=>store.Import(custom),"Invalid import accepted");Check(store.Load(config).Meaning("速度")=="custom speed","Invalid import replaced dictionary");
   Reject(()=>store.Load(new DictionaryConfiguration()),"Empty selection accepted");
   var mutable=store.Load(config);var compact=store.Load(config,true);Check(mutable.Count==compact.Count,"Compact dictionary count");
   foreach(var pair in mutable.Meanings)Check(compact.Meaning(pair.Key)==pair.Value && compact.Source(pair.Key)==mutable.Source(pair.Key),"Compact lookup mismatch: "+pair.Key);
   Check(compact.Meaning("不存在的测试词语")=="" && compact.Source("不存在的测试词语")=="","Compact missing lookup");
   Reject(()=>compact.LoadTsv(custom,"Custom"),"Compact index allowed mutation");
   string vocabulary=Path.Combine(temp,"vocabulary.txt");File.WriteAllText(vocabulary,"无释义测试词\n");mutable.LoadVocabulary(vocabulary);mutable.Compact();mutable.ExportWords(vocabulary);Check(Array.IndexOf(File.ReadAllLines(vocabulary),"无释义测试词")>=0,"Compact export lost vocabulary-only word");
   using(var key=Registry.CurrentUser.CreateSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Run")){
    object old=key.GetValue("WeTypeCompanion");
    try{store.Save(config,true);Check(store.StartupEnabled,"Startup enable");Check(store.Read().Custom && store.Read().Cedict,"Configuration round trip");store.Save(config,false);Check(!store.StartupEnabled,"Startup disable");
     string disk=File.ReadAllText(store.SettingsPath);File.Delete(store.SettingsPath+".bak");Directory.CreateDirectory(store.SettingsPath+".bak");Reject(()=>store.Save(config,true),"Failed save accepted");Check(!store.StartupEnabled && File.ReadAllText(store.SettingsPath)==disk,"Save failure rollback");Directory.Delete(store.SettingsPath+".bak");
    }finally{if(old==null)key.DeleteValue("WeTypeCompanion",false);else key.SetValue("WeTypeCompanion",old);}
   }
   File.WriteAllText(store.SettingsPath,"{}");Reject(()=>store.Read(),"Malformed settings accepted");
   string download=Path.Combine(temp,"download.tmp"),destination=Path.Combine(temp,"cedict.u8");File.WriteAllText(destination,"original");File.WriteAllText(download,"測試 测试 [ce4 shi4] /test/\n");Reject(()=>ConfigurationStore.InstallCedict(download,destination),"Small download accepted");Check(File.ReadAllText(destination)=="original","Download failure rollback");
   var state=new CandidateState();Check(!state.Observe("a") && state.Observe("a"),"Two-frame stability");int version=state.Version;Check(state.Accept("a",version),"Current response");state.Observe("b");state.Observe("a");Check(!state.Accept("a",version),"ABA stale response accepted");version=state.Version;state.Reset();Check(!state.Accept("a",version),"Closed candidate response accepted");
   Check(new OcrResponse{Word="速度",Confidence=0.79}.AcceptedWord=="","Confidence gate");
   var json=new JavaScriptSerializer();var samples=json.Deserialize<List<Dictionary<string,object>>>(File.ReadAllText(Path.Combine(source,"test-fixtures\\live-v1\\manifest.json")));
   var glossary=store.Load(DictionaryConfiguration.Default());using(var worker=new OcrWorker()){
    var startup=worker.StartAsync(root);Check(startup.Wait(60000),"Async worker startup timeout");startup.GetAwaiter().GetResult();int n=0;
    for(int round=0;round<2;round++){
     if(round==1){worker.Dispose();worker.Start(root);}
     foreach(var sample in samples){using(var image=new Bitmap(Path.Combine(source,"test-fixtures\\live-v1",(string)sample["File"]))){var box=CandidateNative.Highlight(image);Check(!box.IsEmpty,"Highlight missing");string id=(n++).ToString();var task=worker.Send(image,box,id);Check(task.Wait(10000),"OCR timeout");var result=worker.Parse(task.Result,id);Check(result.AcceptedWord==(string)sample["Expected"] && glossary.Meaning(result.AcceptedWord).Length>0,"Recognition/lookup: "+sample["File"]);}}
    }
    using(var blank=new Bitmap(90,35))Check(CandidateNative.Highlight(blank).IsEmpty,"Reusable highlight buffer retained previous frame");
    Reject(()=>worker.Parse("{\"Id\":\"wrong\"}","expected"),"Mismatched response accepted");
   }
   var coldStarts=new List<double>();
   using(var lazy=new LazyOcrWorker(TimeSpan.FromMilliseconds(30))){
    Check(!lazy.Ready,"OCR initialized eagerly");
    for(int cycle=0;cycle<2;cycle++){
     var watch=Stopwatch.StartNew();Check(!lazy.EnsureReady(root),"Cold worker already ready");
     while(!lazy.Ready && watch.Elapsed.TotalSeconds<60){lazy.Poll(false);Thread.Sleep(5);}Check(lazy.Ready,"Lazy OCR startup failed");coldStarts.Add(watch.Elapsed.TotalMilliseconds);
     var sample=samples[0];using(var image=new Bitmap(Path.Combine(source,"test-fixtures\\live-v1",(string)sample["File"]))){string id="lazy-"+cycle;var task=lazy.Send(image,CandidateNative.Highlight(image),id);Thread.Sleep(50);lazy.Poll(true);Check(lazy.Ready,"Pending request released worker");Check(task.Wait(10000),"Lazy OCR response timeout");Check(lazy.Parse(task.Result,id).AcceptedWord==(string)sample["Expected"],"Lazy OCR restart changed recognition");}
     lazy.Poll(false);Check(!lazy.Ready,"Idle worker was not released");
    }
   }
   File.WriteAllText(Path.Combine(source,"test-results\\ocr-cold-start.json"),json.Serialize(coldStarts));
   Application.EnableVisualStyles();
   foreach(float scale in new[]{1f,1.25f,1.5f,2f})using(var form=new CompanionSettingsForm()){
    form.Font=new Font("Microsoft YaHei UI",10*scale);
    form.LibraryStatus.Text="已加载 365,071 个释义 · 青简 232,214 · CC-CEDICT 125,173";
    form.Reveal();form.ChineseWord.Focus();Application.DoEvents();
    Check(form.ContainsFocus,"Settings input focus");
    if(CandidateNative.GetForegroundWindow()==form.Handle)Check(CandidateNative.IsCurrentProcessForeground(),"Settings foreground process detection");
    // The scroll viewport may be shorter than its content; every content row must remain intact.
    CheckLayout(form.Controls[0].Controls[0]);
    using(var image=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(image,new Rectangle(0,0,image.Width,image.Height));image.Save(Path.Combine(source,"test-results\\native-settings-ui-"+(scale*100).ToString("0")+".png"));}
    form.Close();Check(!form.Visible && !form.IsDisposed,"Close must hide settings");form.Icon.Dispose();
   }
   File.WriteAllText(report,"PASS: full compact/mutable dictionary lookup and source equivalence, missing words, vocabulary export; asynchronous lazy OCR startup, idle release, pending request protection and restart; reusable highlight buffers across sizes; sorted glossary insertion, preserved columns, Unicode code points, UTF-8/LF, backup, duplicate/invalid input and write failure rollback, reload and legacy settings; native configuration, startup and save rollback, dictionary selection/priority/import rollback, invalid data, download validation, stale ABA/closed candidate rejection, confidence gate, 10 real OCR fixtures before and after worker restart, protocol, settings input focus and foreground detection, no clipped/overlapping rows at 100/125/150/200 percent text size, settings rendering.\n",new UTF8Encoding(false));
  }catch(Exception e){File.WriteAllText(report,"FAIL: "+e.ToString());throw;}
  finally{foreach(string path in Directory.GetFiles(temp))File.Delete(path);Directory.Delete(temp);}
 }
 static void Measure(string root,string source,string dictionary){
  string directory=Path.Combine(source,"test-results\\memory-config-"+dictionary);
  string report=Path.Combine(source,"test-results\\memory-after-active-"+dictionary+".json");bool sampled=false;
  CandidateNative.SetProcessDPIAware();Application.EnableVisualStyles();
  using(var app=new CompanionApplication(root,16,directory))using(var timer=new System.Windows.Forms.Timer{Interval=20}){
   var worker=(LazyOcrWorker)typeof(CompanionApplication).GetField("worker",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(app);
   var watch=Stopwatch.StartNew();
   timer.Tick+=(s,e)=>{
    worker.Touch();worker.EnsureReady(root);
    if(!sampled && worker.Ready && watch.Elapsed.TotalSeconds>=10){
     var rows=new List<object>();
     foreach(int id in new[]{Process.GetCurrentProcess().Id,worker.ProcessId})using(var process=Process.GetProcessById(id)){process.Refresh();rows.Add(new{Dictionary=dictionary,Process=process.ProcessName,WorkingSetMB=Math.Round(process.WorkingSet64/1048576.0,2),PrivateMB=Math.Round(process.PrivateMemorySize64/1048576.0,2)});}
     File.WriteAllText(report,new JavaScriptSerializer().Serialize(rows));sampled=true;
    }
   };
   timer.Start();app.Run(false);
  }
  Check(sampled,"Active memory probe did not complete");
 }
}
