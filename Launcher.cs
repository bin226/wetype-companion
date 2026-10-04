using System;
using System.Threading;
using System.Windows.Forms;
static class Launcher {
 [STAThread] static int Main(string[] args) {
  try {
   string root=AppDomain.CurrentDomain.BaseDirectory;
   if(Array.IndexOf(args,"--self-test")>=0){NativeTests.Run(root,args);return 0;}
   bool exit=Array.IndexOf(args,"--exit")>=0;
   try{using(var signal=EventWaitHandle.OpenExisting(exit?"Local\\WeTypeCompanionExit":"Local\\WeTypeCompanionOpenSettings")){signal.Set();return 0;}}catch(WaitHandleCannotBeOpenedException){if(exit)return 0;}
   using(var mutex=new Mutex(false,"Local\\WeTypeLocalGlossCompanion")) {
    if(!mutex.WaitOne(0,false)) throw new Exception("伴侣正在启动或旧版仍在运行，请稍后重试。");
    try {
     CandidateNative.SetProcessDPIAware();Application.EnableVisualStyles();
     int seconds=0,index=Array.IndexOf(args,"--run-seconds");
     if(index>=0 && index+1<args.Length) seconds=Int32.Parse(args[index+1]);
     string dataDirectory=null;index=Array.IndexOf(args,"--data-directory");
     if(index>=0 && index+1<args.Length)dataDirectory=System.IO.Path.GetFullPath(args[index+1]);
     using(var app=new CompanionApplication(root,seconds,dataDirectory)) app.Run(Array.IndexOf(args,"--background")<0);
    } finally{mutex.ReleaseMutex();}
   }
   return 0;
  } catch(Exception e){if(Array.IndexOf(args,"--self-test")<0)MessageBox.Show(e.Message,"译词伴侣启动失败",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
 }
}
