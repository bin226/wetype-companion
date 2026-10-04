using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class CompanionArtwork {
 [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr handle);
 public static Icon Create(int size) {
  using(var b=new Bitmap(size,size)) using(var g=Graphics.FromImage(b)) {
   g.SmoothingMode=SmoothingMode.AntiAlias; g.ScaleTransform(size/64f,size/64f);
   using(var brush=new LinearGradientBrush(new Rectangle(0,0,64,64),Color.FromArgb(20,184,166),Color.FromArgb(37,99,235),45f)) {
    using(var shape=new GraphicsPath()) {
     shape.AddArc(2,2,24,24,180,90);shape.AddArc(38,2,24,24,270,90);
     shape.AddArc(38,38,24,24,0,90);shape.AddArc(2,38,24,24,90,90);shape.CloseFigure();g.FillPath(brush,shape);
    }
   }
   using(var p=new Pen(Color.White,4)) {p.StartCap=LineCap.Round;p.EndCap=LineCap.Round;
    g.DrawLine(p,15,20,15,39);g.DrawLine(p,15,39,23,31);g.DrawLine(p,23,31,31,39);g.DrawLine(p,31,39,31,20);
    g.DrawLine(p,39,23,51,23);g.DrawLine(p,45,23,45,39);
   }
   using(var p=new Pen(Color.FromArgb(180,255,255,255),3)){g.DrawLine(p,19,49,45,49);}
   IntPtr h=b.GetHicon();try{return (Icon)Icon.FromHandle(h).Clone();}finally{DestroyIcon(h);}
  }
 }
}
public sealed class CompanionSettingsForm : Form {
 public CheckBox Startup=new CheckBox(), Qingjian=new CheckBox(), Cedict=new CheckBox(), Custom=new CheckBox();
 public TextBox ChineseWord=new TextBox(), EnglishMeaning=new TextBox();
 public Button AddWord=new Button();
 public Button Save=new Button(), Reload=new Button(), Import=new Button(), UpdateDictionary=new Button(), Pause=new Button();
 public Label Status=new Label(), LibraryStatus=new Label();
 public CompanionSettingsForm() {
  Text="微信输入法 · 译词伴侣";ClientSize=new Size(710,690);MinimumSize=new Size(730,730);
  StartPosition=FormStartPosition.CenterScreen;AutoScaleMode=AutoScaleMode.Dpi;
  Font=new Font("Microsoft YaHei UI",10);BackColor=Color.FromArgb(245,247,251);Icon=CompanionArtwork.Create(64);
  var scroll=new Panel{Dock=DockStyle.Fill,AutoScroll=true};Controls.Add(scroll);
  var layout=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,Padding=new Padding(28),ColumnCount=1,RowCount=9};
  layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
  for(int row=0;row<9;row++)layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));scroll.Controls.Add(layout);
  var title=new Label{Text="译词伴侣",AutoSize=true,Font=new Font(Font.FontFamily,23,FontStyle.Bold),Dock=DockStyle.Top,Margin=new Padding(3,3,3,12),ForeColor=Color.FromArgb(20,80,110)};layout.Controls.Add(title);
  Startup.Text="登录 Windows 时自动启动（后台托盘运行）";Startup.AutoSize=true;Startup.Dock=DockStyle.Top;Startup.Margin=new Padding(3,3,3,10);layout.Controls.Add(Startup);
  layout.Controls.Add(new Label{Text="词库选择 · 后加载的词库优先覆盖释义",AutoSize=true,Dock=DockStyle.Top});
  var choices=new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,FlowDirection=FlowDirection.TopDown,WrapContents=false};
  Qingjian.Text="青简英文词库（默认）";Cedict.Text="CC-CEDICT 中英词典";Custom.Text="导入的自定义词库（优先级最高）";
  foreach(var c in new[]{Qingjian,Cedict,Custom}){c.AutoSize=true;c.Margin=new Padding(3,3,3,5);choices.Controls.Add(c);}layout.Controls.Add(choices);
  var tools=new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink};Import.Text="导入 TSV…";UpdateDictionary.Text="更新 CC-CEDICT";Reload.Text="重载本地词库";
  foreach(var b in new[]{Import,UpdateDictionary,Reload}){StyleButton(b,false);tools.Controls.Add(b);}layout.Controls.Add(tools);
  LibraryStatus.AutoSize=true;LibraryStatus.Dock=DockStyle.Top;LibraryStatus.Margin=new Padding(3,3,3,16);LibraryStatus.ForeColor=Color.FromArgb(75,85,100);layout.Controls.Add(LibraryStatus);
  var entry=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,ColumnCount=3,RowCount=3};
  entry.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));entry.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));entry.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
  for(int row=0;row<3;row++)entry.RowStyles.Add(new RowStyle(SizeType.AutoSize));
  var heading=new Label{Text="补充青简词库 · 按词表顺序保存",AutoSize=true,Dock=DockStyle.Top,Margin=new Padding(0,3,0,10)};entry.Controls.Add(heading,0,0);entry.SetColumnSpan(heading,3);
  entry.Controls.Add(new Label{Text="中文词语",AutoSize=true,Margin=new Padding(0,6,0,0)},0,1);ChineseWord.Dock=DockStyle.Fill;entry.Controls.Add(ChineseWord,1,1);entry.SetColumnSpan(ChineseWord,2);
  entry.Controls.Add(new Label{Text="英文释义",AutoSize=true,Margin=new Padding(0,6,0,0)},0,2);EnglishMeaning.Dock=DockStyle.Fill;entry.Controls.Add(EnglishMeaning,1,2);
  AddWord.Text="保存词条";StyleButton(AddWord,true);entry.Controls.Add(AddWord,2,2);layout.Controls.Add(entry);
  layout.Controls.Add(new Label{Text="新词写入程序目录 glossary-en.tsv，青简启用时立即生效。\n已有词语不会覆盖；保存前自动备份为 glossary-en.tsv.bak。\n更新或替换词表前，请保留自己补充的词条。\n关闭此窗口后继续在托盘运行；右键托盘可退出。",AutoSize=true,Dock=DockStyle.Top,Margin=new Padding(3,10,3,8),ForeColor=Color.FromArgb(95,105,120)});
  var footer=new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink};Save.Text="保存并应用";Pause.Text="暂停识别";StyleButton(Save,true);StyleButton(Pause,false);footer.Controls.Add(Save);footer.Controls.Add(Pause);
  Status.AutoSize=true;Status.Margin=new Padding(8,10,0,0);footer.Controls.Add(Status);layout.Controls.Add(footer);
  FormClosing+=(s,e)=>{if(e.CloseReason==CloseReason.UserClosing){e.Cancel=true;Hide();}};
 }
 static void StyleButton(Button b,bool primary){b.AutoSize=true;b.Height=34;b.Padding=new Padding(8,3,8,3);b.FlatStyle=FlatStyle.Flat;b.FlatAppearance.BorderSize=0;b.BackColor=primary?Color.FromArgb(15,118,110):Color.FromArgb(225,232,242);b.ForeColor=primary?Color.White:Color.FromArgb(35,55,75);b.Cursor=Cursors.Hand;}
 public void Reveal(){Show();WindowState=FormWindowState.Normal;Activate();BringToFront();}
}
