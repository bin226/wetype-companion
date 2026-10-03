using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

public sealed class HintWindow : Form {
 public HintWindow() { FormBorderStyle=FormBorderStyle.None; ShowInTaskbar=false; TopMost=true; BackColor=Color.FromArgb(30,34,40); ForeColor=Color.White; Padding=new Padding(14,8,14,8); }
 protected override bool ShowWithoutActivation { get { return true; } }
 protected override CreateParams CreateParams { get { var p=base.CreateParams; p.ExStyle |= 0x08000000 | 0x00000080 | 0x00000020; return p; } }
 protected override void WndProc(ref Message m) { if(m.Msg==0x0084) {m.Result=(IntPtr)(-1); return;} if(m.Msg==0x0021){m.Result=(IntPtr)3;return;} base.WndProc(ref m); }
}
public class CaptureResult : IDisposable {
 public Bitmap Image; public Rectangle Window; public IntPtr Handle;
 public void Dispose(){if(Image!=null)Image.Dispose();}
}
public static class CandidateNative {
 public delegate bool EnumProc(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb,IntPtr p);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags);
 struct Rect {public int Left,Top,Right,Bottom;}
 public static void Position(Form f,int x,int y,int w,int h){SetWindowPos(f.Handle,new IntPtr(-1),x,y,w,h,0x0010);}
 public static CaptureResult Capture(){
  IntPtr found=IntPtr.Zero; Rectangle bounds=Rectangle.Empty;
  EnumWindows((h,p)=>{
   if(!IsWindowVisible(h)) return true;
   var s=new StringBuilder(128);GetWindowText(h,s,128);if(s.ToString()!="wetype_candidate")return true;
   uint id; GetWindowThreadProcessId(h,out id);
   try{if(Process.GetProcessById((int)id).ProcessName!="wetype_renderer")return true;}catch{return true;}
   Rect r;if(!GetWindowRect(h,out r))return true;
   bounds=Rectangle.Intersect(Rectangle.FromLTRB(r.Left,r.Top,r.Right,r.Bottom),SystemInformation.VirtualScreen);
   if(bounds.Width<=0 || bounds.Height<=0 || bounds.Width>2400 || bounds.Height>1600)return true;
   found=h;return false;
  },IntPtr.Zero);
  if(found==IntPtr.Zero)return null;
  var b=new Bitmap(bounds.Width,bounds.Height,PixelFormat.Format32bppArgb);
  try{using(var g=Graphics.FromImage(b))g.CopyFromScreen(bounds.Location,Point.Empty,bounds.Size);return new CaptureResult{Image=b,Window=bounds,Handle=found};}catch{b.Dispose();return null;}
 }
 static byte[] Pixels(Bitmap b){var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);try{var a=new byte[d.Stride*b.Height];Marshal.Copy(d.Scan0,a,0,a.Length);return a;}finally{b.UnlockBits(d);}}
 static bool Green(byte[] a,int i){return a[i+1]>95 && a[i+2]<110 && a[i]>55 && a[i+1]-a[i+2]>55 && a[i+1]-a[i]>15;}
 public static Rectangle Highlight(Bitmap b){
  var a=Pixels(b);int w=b.Width,h=b.Height;var seen=new bool[w*h];Rectangle best=Rectangle.Empty;int score=0;
  var q=new Queue<int>();
  for(int k=0;k<seen.Length;k++){
   if(seen[k] || !Green(a,k*4))continue;
   seen[k]=true;q.Enqueue(k);int minX=w,maxX=0,minY=h,maxY=0,count=0;
   while(q.Count>0){int n=q.Dequeue(),x=n%w,y=n/w;count++;minX=Math.Min(minX,x);maxX=Math.Max(maxX,x);minY=Math.Min(minY,y);maxY=Math.Max(maxY,y);
    int[] ns={x>0?n-1:-1,x<w-1?n+1:-1,y>0?n-w:-1,y<h-1?n+w:-1};foreach(int m in ns){if(m>=0&&!seen[m]&&Green(a,m*4)){seen[m]=true;q.Enqueue(m);}}
   }
   int rw=maxX-minX+1,rh=maxY-minY+1;
   if(count>400 && rw>=30 && rw<=900 && rh>=18 && rh<=160 && rw>rh && count>score){score=count;best=new Rectangle(minX,minY,rw,rh);}
  }
  return best;
 }
 public static Bitmap Normalize(Bitmap source,Rectangle box){
  box.Inflate(3,3);box.Intersect(new Rectangle(0,0,source.Width,source.Height));
  using(var crop=source.Clone(box,PixelFormat.Format32bppArgb)){
   var d=crop.LockBits(new Rectangle(0,0,crop.Width,crop.Height),ImageLockMode.ReadWrite,PixelFormat.Format32bppArgb);
   try{var a=new byte[d.Stride*crop.Height];Marshal.Copy(d.Scan0,a,0,a.Length);for(int i=0;i<a.Length;i+=4){if(Green(a,i)){a[i]=a[i+1]=a[i+2]=20;}a[i+3]=255;}Marshal.Copy(a,0,d.Scan0,a.Length);}finally{crop.UnlockBits(d);}
   var scaled=new Bitmap(crop.Width*2+24,crop.Height*2+24);using(var g=Graphics.FromImage(scaled)){g.Clear(Color.FromArgb(20,20,20));g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;g.DrawImage(crop,12,12,crop.Width*2,crop.Height*2);}return scaled;
  }
 }
 public static string Fingerprint(Bitmap b,Rectangle box){using(var c=b.Clone(box,PixelFormat.Format32bppArgb)){using(var md=System.Security.Cryptography.MD5.Create())return Convert.ToBase64String(md.ComputeHash(Pixels(c)));}}
 public static Rectangle Panel(Bitmap b,Rectangle box){
  int x=Math.Max(0,box.Left-5),mid=box.Top+box.Height/2;Color seed=b.GetPixel(x,mid);int top=mid,bottom=mid;
  while(top>0){Color c=b.GetPixel(x,top-1);if(Math.Abs(c.R-seed.R)>6||Math.Abs(c.G-seed.G)>6||Math.Abs(c.B-seed.B)>6)break;top--;}
  while(bottom<b.Height-1){Color c=b.GetPixel(x,bottom+1);if(Math.Abs(c.R-seed.R)>6||Math.Abs(c.G-seed.G)>6||Math.Abs(c.B-seed.B)>6)break;bottom++;}
  if(bottom-top>1000)return box;
  return new Rectangle(box.Left,top,box.Width,bottom-top+1);
 }
 public static Bitmap Invert(Bitmap source){
  var result=new Bitmap(source.Width,source.Height);
  using(var g=Graphics.FromImage(result))using(var attrs=new ImageAttributes()){
   attrs.SetColorMatrix(new ColorMatrix(new float[][]{
    new float[]{-1,0,0,0,0},new float[]{0,-1,0,0,0},new float[]{0,0,-1,0,0},new float[]{0,0,0,1,0},new float[]{1,1,1,0,1}}));
   g.DrawImage(source,new Rectangle(0,0,result.Width,result.Height),0,0,source.Width,source.Height,GraphicsUnit.Pixel,attrs);
  }
  return result;
 }
}
