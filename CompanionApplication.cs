using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

public sealed class DictionaryConfiguration {
 public bool Qingjian {get;set;} public bool Cedict {get;set;}
 public bool Custom {get;set;}
 public static DictionaryConfiguration Default(){return new DictionaryConfiguration{Qingjian=true};}
}
public sealed class ConfigurationStore {
 public readonly string Root,DataDirectory,SettingsPath;
 const string RunKey="Software\\Microsoft\\Windows\\CurrentVersion\\Run";
 public ConfigurationStore(string root,string dataDirectory){Root=root;DataDirectory=dataDirectory;Directory.CreateDirectory(dataDirectory);SettingsPath=Path.Combine(dataDirectory,"settings.json");}
 public DictionaryConfiguration Read(){
  if(!File.Exists(SettingsPath))return DictionaryConfiguration.Default();
  var values=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(SettingsPath));
  foreach(string name in new[]{"Qingjian","Cedict","Custom"})if(values==null || !values.ContainsKey(name) || !(values[name] is bool))throw new InvalidDataException("设置文件格式无效");
  return new DictionaryConfiguration{Qingjian=(bool)values["Qingjian"],Cedict=(bool)values["Cedict"],Custom=(bool)values["Custom"]};
 }
 public LocalLexicon Load(DictionaryConfiguration config,bool compact=false){
  var lexicon=new LocalLexicon();
  if(config.Cedict){string path=Path.Combine(DataDirectory,"cedict.u8");lexicon.LoadCedict(File.Exists(path)?path:Path.Combine(Root,"data\\cedict.u8"));}
  if(config.Qingjian)lexicon.LoadTsv(Path.Combine(Root,"glossary-en.tsv"),"Qingjian");
  if(config.Custom)lexicon.LoadTsv(Path.Combine(DataDirectory,"custom.tsv"),"Custom");
  if(lexicon.Meanings.Count==0)throw new InvalidDataException("请至少选择一个含释义的词库。");
  if(compact)lexicon.Compact();
  return lexicon;
 }
 public string StartupCommand {get{return "\""+Path.Combine(Root,"WeTypeCompanion.exe")+"\" --background";}}
 public bool StartupEnabled {get{using(var key=Registry.CurrentUser.OpenSubKey(RunKey))return key!=null && Equals(key.GetValue("WeTypeCompanion"),StartupCommand);}}
 public void Save(DictionaryConfiguration config,bool startup){
  string temp=SettingsPath+".tmp";
  File.WriteAllText(temp,new JavaScriptSerializer().Serialize(config),new UTF8Encoding(false));
  using(var key=Registry.CurrentUser.CreateSubKey(RunKey)) {
   object old=key.GetValue("WeTypeCompanion");
   try{if(startup)key.SetValue("WeTypeCompanion",StartupCommand);else key.DeleteValue("WeTypeCompanion",false);ReplaceFile(temp,SettingsPath);}
   catch{if(old==null)key.DeleteValue("WeTypeCompanion",false);else key.SetValue("WeTypeCompanion",old);throw;}
   finally{if(File.Exists(temp))File.Delete(temp);}
  }
 }
 public static void ReplaceFile(string temp,string destination){if(File.Exists(destination))File.Replace(temp,destination,destination+".bak");else File.Move(temp,destination);}
 public void Import(string path){
  string temp=Path.Combine(DataDirectory,"custom.tsv.tmp");
  try{File.Copy(path,temp,true);var probe=new LocalLexicon();probe.LoadTsv(temp,"Custom");if(probe.Meanings.Count==0)throw new InvalidDataException("词库为空。");ReplaceFile(temp,Path.Combine(DataDirectory,"custom.tsv"));}
  finally{if(File.Exists(temp))File.Delete(temp);}
 }
 public static void InstallCedict(string temp,string destination){
  ValidateCedict(temp);
  ReplaceFile(temp,destination);
 }
 static LocalLexicon ValidateCedict(string path){var probe=new LocalLexicon();probe.LoadCedict(path);if(probe.CedictEntries<100000)throw new InvalidDataException("下载词库条数异常，原词库保留。");return probe;}
 public async Task UpdateCedict(CancellationToken cancellation){
  const string url="https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz";
  string temp=Path.Combine(DataDirectory,"cedict.download.tmp");
  try {
   ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
   var request=(HttpWebRequest)WebRequest.Create(url);request.Timeout=120000;request.ReadWriteTimeout=120000;
   using(cancellation.Register(request.Abort))using(var response=await request.GetResponseAsync())using(var input=response.GetResponseStream())using(var gzip=new GZipStream(input,CompressionMode.Decompress))using(var output=File.Create(temp))await gzip.CopyToAsync(output,81920,cancellation);
   cancellation.ThrowIfCancellationRequested();
   var probe=ValidateCedict(temp);
   string hash;using(var sha=SHA256.Create())using(var stream=File.OpenRead(temp))hash=BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","");
   var metadata=new {Source="CC-CEDICT",Url=url,License="CC-BY-SA-4.0",DownloadedUtc=DateTime.UtcNow.ToString("o"),Entries=probe.CedictEntries,Sha256=hash};
   cancellation.ThrowIfCancellationRequested();ReplaceFile(temp,Path.Combine(DataDirectory,"cedict.u8"));
   File.WriteAllText(Path.Combine(DataDirectory,"cedict-source.json"),new JavaScriptSerializer().Serialize(metadata),new UTF8Encoding(false));
  }finally{if(File.Exists(temp))File.Delete(temp);}
 }
}
public sealed class OcrResponse {
 public string Id {get;set;} public string Raw {get;set;} public string Word {get;set;}
 public string Engine {get;set;} public string Error {get;set;} public double Confidence {get;set;} public double Milliseconds {get;set;}
 public string AcceptedWord {get{return Confidence>=0.80 ? Word ?? "" : "";}}
}
public sealed class OcrWorker : IDisposable {
 Process process;Task<string> errors;readonly JavaScriptSerializer json=new JavaScriptSerializer();
 internal int ProcessId {get{return process.Id;}}
 public void Start(string root){StartAsync(root).GetAwaiter().GetResult();}
 public async Task StartAsync(string root){
  string python=Path.Combine(root,"runtime\\python.exe");if(!File.Exists(python))python=Path.Combine(root,".venv\\Scripts\\python.exe");
  var info=new ProcessStartInfo(python,"-u \""+Path.Combine(root,"ocr_worker.py")+"\""){WorkingDirectory=root,UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8};
  process=Process.Start(info);errors=process.StandardError.ReadToEndAsync();var ready=process.StandardOutput.ReadLineAsync();
  if(await Task.WhenAny(ready,Task.Delay(60000)).ConfigureAwait(false)!=ready)throw new TimeoutException("OCR 初始化超时。");
  string response=await ready.ConfigureAwait(false);
  if(response==null)throw new IOException("OCR 初始化失败："+await errors.ConfigureAwait(false));
  var handshake=json.Deserialize<Dictionary<string,object>>(response);
  if(!handshake.ContainsKey("Ready") || !Equals(handshake["Ready"],true))throw new IOException("OCR 初始化响应无效。");
 }
 public Task<string> Send(Bitmap image,Rectangle box,string id){
  if(process.HasExited)throw new IOException("OCR 子进程已退出。");
  using(var normalized=CandidateNative.Normalize(image,box))using(var memory=new MemoryStream()){
   normalized.Save(memory,System.Drawing.Imaging.ImageFormat.Png);
   process.StandardInput.WriteLine(json.Serialize(new {Id=id,Png=Convert.ToBase64String(memory.ToArray())}));process.StandardInput.Flush();
  }
  return process.StandardOutput.ReadLineAsync();
 }
 public OcrResponse Parse(string raw,string id){
  if(raw==null)throw new IOException("OCR 响应流已关闭。");var result=json.Deserialize<OcrResponse>(raw);
  if(result.Id!=id)throw new IOException("OCR 响应标识不匹配。");if(!String.IsNullOrEmpty(result.Error))throw new IOException(result.Error);return result;
 }
 public void Dispose(){if(process==null)return;try{if(!process.HasExited){process.StandardInput.Close();if(!process.WaitForExit(1000)){process.Kill();process.WaitForExit(1000);}}}finally{process.Dispose();process=null;}}
}
public sealed class CandidateState {
 public string StableKey="",LastKey="";public int Version;public OcrResponse Result;
 public void Reset(){if(StableKey.Length>0)Version++;StableKey="";LastKey="";Result=null;}
 public bool Observe(string key){if(key==StableKey)return true;Version++;StableKey=key;return false;}
 public bool Accept(string key,int version){return key==StableKey && version==Version;}
}
// Own the OCR lifecycle on the UI thread; initialization itself never blocks it.
public sealed class LazyOcrWorker : IDisposable {
 readonly OcrWorker worker=new OcrWorker();readonly Stopwatch idle=Stopwatch.StartNew();readonly TimeSpan idleTimeout;
 Task startup;public bool Ready {get;private set;}
 internal int ProcessId {get{return worker.ProcessId;}}
 public LazyOcrWorker():this(TimeSpan.FromSeconds(120)){}
 public LazyOcrWorker(TimeSpan timeout){idleTimeout=timeout;}
 public void Touch(){idle.Restart();}
 public void Poll(bool requestPending){
  if(startup!=null && startup.IsCompleted){startup.GetAwaiter().GetResult();startup=null;Ready=true;Touch();}
  if(Ready && !requestPending && idle.Elapsed>=idleTimeout){worker.Dispose();Ready=false;}
 }
 public bool EnsureReady(string root){if(Ready)return true;if(startup==null)startup=worker.StartAsync(root);return false;}
 public Task<string> Send(Bitmap image,Rectangle box,string id){Touch();return worker.Send(image,box,id);}
 public OcrResponse Parse(string response,string id){return worker.Parse(response,id);}
 public void Dispose(){worker.Dispose();Ready=false;if(startup!=null){startup.ContinueWith(t=>{var ignored=t.Exception;},TaskContinuationOptions.OnlyOnFaulted);startup=null;}}
}
public sealed class CompanionApplication : IDisposable {
 readonly ConfigurationStore store;DictionaryConfiguration config;LocalLexicon lexicon;
 readonly CompanionSettingsForm settings=new CompanionSettingsForm();readonly HintWindow hint=new HintWindow();
 readonly Label label=new Label{Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft,Font=new Font("Microsoft YaHei UI",11)};
 readonly NotifyIcon tray=new NotifyIcon();readonly Icon trayIcon=CompanionArtwork.Create(32);
 readonly ContextMenuStrip menu=new ContextMenuStrip();ToolStripItem pauseMenu;
 readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer{Interval=70};
 readonly EventWaitHandle openSignal=new EventWaitHandle(false,EventResetMode.AutoReset,"Local\\WeTypeCompanionOpenSettings");
 readonly EventWaitHandle exitSignal=new EventWaitHandle(false,EventResetMode.AutoReset,"Local\\WeTypeCompanionExit");
 readonly LazyOcrWorker worker=new LazyOcrWorker();readonly CandidateState state=new CandidateState();
 readonly Dictionary<string,OcrResponse> cache=new Dictionary<string,OcrResponse>();
 readonly Stopwatch clock=new Stopwatch();readonly int runSeconds;
 Task<string> pending;string pendingKey;int pendingVersion;Stopwatch pendingWatch;
 Task dictionaryUpdate;CancellationTokenSource updateCancellation;bool paused;
 public CompanionApplication(string root,int seconds,string dataDirectory=null){store=new ConfigurationStore(root,dataDirectory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"WeTypeCompanion"));runSeconds=seconds;}
 public void Run(bool showSettings){
  try{config=store.Read();}catch(Exception e){config=DictionaryConfiguration.Default();MessageBox.Show("无法读取配置，已恢复默认青简词库。"+e.Message,"译词伴侣");}
  try{lexicon=store.Load(config,true);}catch(Exception e){config=DictionaryConfiguration.Default();MessageBox.Show("所选词库无法加载，暂用默认青简词库。"+e.Message,"译词伴侣");lexicon=store.Load(config,true);}
  hint.Controls.Add(label);
  settings.Qingjian.Checked=config.Qingjian;settings.Cedict.Checked=config.Cedict;settings.Custom.Checked=config.Custom;settings.Startup.Checked=store.StartupEnabled;
  UpdateStatus();settings.Save.Click+=(s,e)=>Guard(Apply);settings.Reload.Click+=(s,e)=>Guard(Apply);settings.Pause.Click+=(s,e)=>TogglePause();settings.Import.Click+=(s,e)=>Guard(Import);settings.UpdateDictionary.Click+=(s,e)=>Guard(StartUpdate);
  settings.AddWord.Click+=(s,e)=>Guard(AddWord);
  settings.Activated+=(s,e)=>Reset();
  menu.Items.Add("打开设置").Click+=(s,e)=>settings.Reveal();pauseMenu=menu.Items.Add("暂停识别");pauseMenu.Click+=(s,e)=>TogglePause();menu.Items.Add(new ToolStripSeparator());menu.Items.Add("退出").Click+=(s,e)=>Application.ExitThread();
  tray.Icon=trayIcon;tray.Text="译词伴侣 · 正在运行";tray.ContextMenuStrip=menu;tray.DoubleClick+=(s,e)=>settings.Reveal();tray.Visible=true;
  timer.Tick+=(s,e)=>Tick();GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();clock.Start();timer.Start();if(showSettings)settings.Reveal();Application.Run();
 }
 void Guard(Action action){try{action();}catch(Exception e){MessageBox.Show(settings,e.Message,"操作失败（原词库继续使用）",MessageBoxButtons.OK,MessageBoxIcon.Error);}}
 void UpdateStatus(){settings.LibraryStatus.Text=String.Format("已加载 {0:N0} 个释义 · 青简 {1:N0} · CC-CEDICT {2:N0}",lexicon.Count,lexicon.QingjianWords,lexicon.CedictEntries);}
 void Reset(){state.Reset();hint.Hide();}
 void Apply(){var selected=new DictionaryConfiguration{Qingjian=settings.Qingjian.Checked,Cedict=settings.Cedict.Checked,Custom=settings.Custom.Checked};var replacement=store.Load(selected,true);store.Save(selected,settings.Startup.Checked);config=selected;lexicon=replacement;cache.Clear();Reset();UpdateStatus();settings.Status.Text="已保存并生效";GC.Collect();}
 void AddWord(){
  LocalLexicon.AddGlossaryEntry(Path.Combine(store.Root,"glossary-en.tsv"),settings.ChineseWord.Text,settings.EnglishMeaning.Text);
  settings.ChineseWord.Clear();settings.EnglishMeaning.Clear();
  settings.Status.Text="词条已保存，请启用青简词库";
  if(config.Qingjian){lexicon=store.Load(config,true);cache.Clear();Reset();UpdateStatus();settings.Status.Text="词条已保存并生效";GC.Collect();}
 }
 void Import(){using(var dialog=new OpenFileDialog{Filter="UTF-8 词库 (*.tsv)|*.tsv",Title="导入中文词语 / 英文释义 TSV"}){if(dialog.ShowDialog(settings)!=DialogResult.OK)return;store.Import(dialog.FileName);settings.Custom.Checked=true;settings.Status.Text="已导入，请保存应用";}}
 void TogglePause(){paused=!paused;Reset();settings.Pause.Text=pauseMenu.Text=paused?"恢复识别":"暂停识别";tray.Text=paused?"译词伴侣 · 已暂停":"译词伴侣 · 正在运行";}
 void StartUpdate(){if(dictionaryUpdate!=null)return;updateCancellation=new CancellationTokenSource(TimeSpan.FromMinutes(3));var token=updateCancellation.Token;dictionaryUpdate=Task.Run(()=>store.UpdateCedict(token));settings.UpdateDictionary.Enabled=false;settings.Status.Text="正在下载词库…";}
 void PollUpdate(){if(dictionaryUpdate==null || !dictionaryUpdate.IsCompleted)return;Guard(()=>{dictionaryUpdate.GetAwaiter().GetResult();var replacement=store.Load(config,true);lexicon=replacement;cache.Clear();Reset();UpdateStatus();settings.Status.Text="词库更新完成";GC.Collect();});dictionaryUpdate=null;updateCancellation.Dispose();updateCancellation=null;settings.UpdateDictionary.Enabled=true;}
 void Tick(){
  if(exitSignal.WaitOne(0) || (runSeconds>0 && clock.Elapsed.TotalSeconds>=runSeconds)){Application.ExitThread();return;}
  if(openSignal.WaitOne(0))settings.Reveal();PollUpdate();
  try {
   worker.Poll(pending!=null);
   // Drain requests even while hidden/paused; enforce timeouts independently of frames.
   OcrResponse completed=null;string completedKey=null;int completedVersion=0;
   if(pending!=null){if(pendingWatch.Elapsed.TotalSeconds>3 && !pending.IsCompleted)throw new TimeoutException("OCR 响应超时。");if(pending.IsCompleted){completed=worker.Parse(pending.GetAwaiter().GetResult(),pendingVersion.ToString());completedKey=pendingKey;completedVersion=pendingVersion;pending=null;}}
   // Never display our overlay over our own IME session (including settings dialogs).
   // Drain outstanding OCR above, and invalidate its result before returning to other apps.
   if(paused || settings.ContainsFocus || CandidateNative.IsCurrentProcessForeground()){Reset();return;}
   using(var capture=CandidateNative.Capture()){
    if(capture==null){Reset();return;}Rectangle box=CandidateNative.Highlight(capture.Image);if(box.IsEmpty){Reset();return;}
    worker.Touch();
    string key=capture.Handle.ToInt64()+":"+CandidateNative.Fingerprint(capture.Image,box);if(!state.Observe(key)){hint.Hide();return;}
    if(completed!=null && completedKey==key && state.Accept(completedKey,completedVersion)){state.LastKey=key;state.Result=completed;if(cache.Count>=256)cache.Clear();cache[key]=completed;}
    if(pending!=null){hint.Hide();return;}
    if(key!=state.LastKey){OcrResponse cached;if(cache.TryGetValue(key,out cached)){state.LastKey=key;state.Result=cached;}else{if(!worker.EnsureReady(store.Root)){hint.Hide();return;}pendingVersion=state.Version;pendingKey=key;pendingWatch=Stopwatch.StartNew();pending=worker.Send(capture.Image,box,pendingVersion.ToString());hint.Hide();return;}}
    string meaning=lexicon.Meaning(state.Result.AcceptedWord);if(meaning.Length==0 || !CandidateNative.IsWindowVisible(capture.Handle)){hint.Hide();return;}
    label.Text=meaning;Rectangle area=Screen.FromPoint(new Point(capture.Window.X+box.X,capture.Window.Y+box.Y)).WorkingArea;Size size=TextRenderer.MeasureText(meaning,label.Font);
    int width=Math.Min(Math.Max(220,size.Width+34),Math.Min(680,area.Width)),height=Math.Max(46,size.Height+18),x=Math.Min(Math.Max(area.Left,capture.Window.X+box.Left),area.Right-width);
    Rectangle panel=CandidateNative.Panel(capture.Image,box);int y=capture.Window.Y+panel.Bottom+10;if(y+height>area.Bottom)y=capture.Window.Y+panel.Top-height-10;y=Math.Max(area.Top,y);
    CandidateNative.Position(hint,x,y,width,height);if(!hint.Visible)hint.Show();
   }
  }catch(Exception e){hint.Hide();timer.Stop();tray.Text="译词伴侣 · 识别已停止";settings.Status.Text="识别已停止，请退出重启";MessageBox.Show(e.Message,"识别失败",MessageBoxButtons.OK,MessageBoxIcon.Error);Application.ExitThread();}
 }
 public void Dispose(){timer.Stop();timer.Dispose();tray.Visible=false;tray.Dispose();worker.Dispose();hint.Dispose();label.Font.Dispose();settings.Icon.Dispose();settings.Dispose();trayIcon.Dispose();menu.Dispose();openSignal.Dispose();exitSignal.Dispose();if(updateCancellation!=null){updateCancellation.Cancel();try{dictionaryUpdate.Wait(3000);}catch(AggregateException){}updateCancellation.Dispose();}}
}
