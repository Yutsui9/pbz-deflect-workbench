using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace PBZGuardPanel {
    sealed class KeyChoice {
        public string Code,Label;
        public override string ToString(){return Label;}
    }
    sealed class NumberBinding { public NumericUpDown Control;public decimal Scale; }
    public sealed class PanelForm:Form {
        readonly ConfigStore store;
        readonly Dictionary<string,Control> fields=new Dictionary<string,Control>();
        readonly Dictionary<string,NumberBinding> numbers=new Dictionary<string,NumberBinding>();
        readonly Label connection=new Label(),message=new Label(),configState=new Label();
        readonly Timer timer=new Timer();
        readonly Color background=Color.FromArgb(20,25,33), surface=Color.FromArgb(29,36,46), ink=Color.FromArgb(233,239,245),muted=Color.FromArgb(155,170,188);
        GuardConfig loaded;string pending="";
        public PanelForm(ConfigStore s) {
            store=s;Text="影之刃零 · 卸势调校台";StartPosition=FormStartPosition.CenterScreen;
            Size=new Size(1060,820);MinimumSize=new Size(920,680);BackColor=background;ForeColor=ink;
            Font=new Font("Microsoft YaHei UI",9.5f);AutoScaleMode=AutoScaleMode.Dpi;AutoScaleDimensions=new SizeF(96,96);
            var shell=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=4,Padding=new Padding(22,16,22,14),BackColor=background};
            shell.RowStyles.Add(new RowStyle(SizeType.Absolute,112));shell.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            shell.RowStyles.Add(new RowStyle(SizeType.Absolute,36));shell.RowStyles.Add(new RowStyle(SizeType.Absolute,58));Controls.Add(shell);
            var header=new Panel{Dock=DockStyle.Fill};shell.Controls.Add(header,0,0);
            header.Controls.Add(new Label{Text="卸势调校台",Font=new Font(Font.FontFamily,22,FontStyle.Bold),ForeColor=ink,AutoSize=true,Location=new Point(0,0)});
            header.Controls.Add(new Label{Text="影之刃零  /  本地面板 · 0.2.11",ForeColor=muted,AutoSize=true,Location=new Point(3,47)});
            connection.AutoSize=true;connection.Location=new Point(3,78);connection.ForeColor=Color.FromArgb(111,214,195);header.Controls.Add(connection);
            configState.AutoSize=true;configState.Anchor=AnchorStyles.Right|AnchorStyles.Top;configState.TextAlign=ContentAlignment.MiddleRight;configState.Location=new Point(625,18);header.Controls.Add(configState);
            var tabs=new TabControl{Dock=DockStyle.Fill,Padding=new Point(20,9),DrawMode=TabDrawMode.OwnerDrawFixed};
            tabs.DrawItem+=(o,e)=>{var selected=e.Index==tabs.SelectedIndex;using(var b=new SolidBrush(selected?surface:background))e.Graphics.FillRectangle(b,e.Bounds);TextRenderer.DrawText(e.Graphics,tabs.TabPages[e.Index].Text,Font,e.Bounds,selected?ink:muted,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);};
            shell.Controls.Add(tabs,0,1);
            var modes=Page(tabs,"功能开关");
            AddCheck(modes,"启用卸势调校","独立键鼠输入、窗口、耗气、奖励与动作反馈。","Enabled");
            AddCheck(modes,"启用预警换色（试验）","闪避黄光、卸势红光；不要求开启卸势调校。","WarningColorsEnabled");
            AddNote(modes,"两个开关独立生效：仅换色 / 仅卸势 / 同时开启 / 全部关闭。\n勾选后点击应用设置；还原游戏原版会关闭两个功能并保留调参。");
            var keys=Page(tabs,"按键与招架");
            AddKey(keys,"持续防御键","长按保持防御，松开结束。","GuardKey");
            AddKey(keys,"点按招架键","每次按下触发一次招架，长按不会连发。","ParryKey");
            AddNumber(keys,"精防窗口","第一次点按的判定时长，与动画和剑光独立。","WindowSeconds",50,600,10,0,1000,"毫秒");
            AddNumber(keys,"连按惩罚恢复","停止连按多久后，窗口恢复到第一次的长度。","SpamRecoverySeconds",100,2000,10,0,1000,"毫秒");
            AddNumber(keys,"每次点按耗气","占气条上限的比例；成功回气与连胜奖励在其他页签调整。","ParryCostPercent",0,25,.5m,1,100,"%");
            AddSpam(keys);
            AddNote(keys,"请避开游戏已有动作键。F5 / F6 / F7 与内部占位键不供绑定。\n切换两个按键时可同时修改，点击下方“应用设置”后一起生效。");
            var feedback=Page(tabs,"动作、剑光与声音");
            AddNumber(feedback,"举刀起手速度","仅加速点按招架的入防动作，1.00 为原速。","ParryRaiseSpeed",1,2.5m,.05m,2,1,"倍");
            AddNumber(feedback,"收刀速度","仅加速点按招架结束时的退防动作，1.00 为原速。","ParryLowerSpeed",1,2.5m,.05m,2,1,"倍");
            AddCheck(feedback,"使用强招架动作","招架期间使用原生强招架动画。","StrongParryAnimation");
            AddCheck(feedback,"点按抖刀反馈","播放当前武器上半身举刀片段；成功卸势、受击和进退防动作优先。","ParryTapShake");
            AddCheck(feedback,"启用起手反馈","控制刀面反光和附加音效；关闭后仍可正常招架。","ParryTapFX");
            AddNumber(feedback,"剑光强度","刀面局部反光的强弱，0 为不发光。","BladeFlashStrength",0,1,.02m,2,1,"");
            AddNumber(feedback,"剑光持续时间","一闪后逐渐变暗，连续点按不会延长本次闪光。","BladeFlashDuration",40,400,10,0,1000,"毫秒");
            AddNumber(feedback,"剑光最小间隔","两次闪光起点之间的间隔，需比时长至少多 60 毫秒。","BladeFlashMinInterval",100,2000,10,0,1000,"毫秒");
            AddCheck(feedback,"启用轻金属音效","每次有效点按播放，长按防御不会持续播放。","ParryTapSound");
            AddNumber(feedback,"附加音效音量","相对这段原生音效的输出增益，0 为静音。","ParryTapSoundVolume",0,100,1,0,100,"%");
            var warning=Page(tabs,"出招预警");
            AddNote(warning,"请在“功能开关”页独立开启预警换色。仅换色时保留原版战斗。 ");
            AddNote(warning,"保留原来的提示时机与招式判定；关闭可恢复原配色。\n教学提示同步为格挡红光、闪避黄光；处于试验阶段。");
            var streak=Page(tabs,"连续卸势奖励");
            AddCheck(streak,"启用连续成功奖励","成功清除已积累的连按惩罚；从第二次成功起叠加奖励。","SuccessChainEnabled");
            AddNumber(streak,"成功衔接时间","在此时间内再次成功可续连胜；空按落空或普通防御清空。","SuccessChainTimeout",1,15,.5m,1,1,"秒");
            AddNumber(streak,"最多奖励层数","第二次成功为一层，之后逐次增加，达到上限后维持。","SuccessChainMaxStacks",1,5,1,0,1,"层");
            AddNumber(streak,"每层额外回杀气","在成功精防基础回气之上增加，占自身杀气上限。","SuccessChainRefundStep",0,5,.5m,1,100,"%");
            AddNumber(streak,"每层额外削韧","在成功精防基础削韧之上增加，占敌方韧性上限。","SuccessChainPoiseStep",0,5,.5m,1,100,"%");
            AddNote(streak,"成功后保留剩余窗口；同一次点按对应多个命中也只提升一次连胜。\n回气封顶自身上限，敌方韧性最低为零；应用参数或还原原版会清空连胜。");
            var balance=Page(tabs,"防御与收益");
            AddNumber(balance,"成功精防回杀气","额外恢复气条上限的比例，仅右键成功精防触发。","PerfectParryRefundPercent",0,25,.5m,1,100,"%");
            AddNumber(balance,"成功精防即时削韧","精防成立时额外扣敌方韧性上限的比例，无需追加攻击。","PerfectParryPoisePercent",0,25,.5m,1,100,"%");
            AddNumber(balance,"持续防御耗气","相对于原版持续防御耗气量。","GuardDrainMultiplier",0,5,.05m,2,1,"倍");
            AddNumber(balance,"防御耗气延迟","持续防御开始多久后进入耗气阶段。","GuardDrainStartDelay",0,2000,10,0,1000,"毫秒");
            AddNumber(balance,"普通防御大招收益","相对于原版普通防御的大招充能收益。","NormalUltimateMultiplier",0,5,.05m,2,1,"倍");
            AddNumber(balance,"精防大招收益","相对于原版成功精防的大招充能收益。","PerfectUltimateMultiplier",0,5,.05m,2,1,"倍");
            AddCheck(balance,"详细调试日志","排查问题时开启，平时可关闭。","Debug");
            AddNote(balance,"“还原游戏原版”会关闭本模组的按键、战斗数值、动作加速、剑光和声音。\n已保存的调参和存档隔离会保留，之后可以再次启用。");
            tabs.SelectedIndexChanged+=(o,e)=>BeginInvoke((Action)(()=>{if(tabs.SelectedTab!=null)tabs.SelectedTab.AutoScrollPosition=Point.Empty;}));
            message.Dock=DockStyle.Fill;message.ForeColor=muted;message.TextAlign=ContentAlignment.MiddleLeft;message.AutoEllipsis=true;shell.Controls.Add(message,0,2);
            var footer=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.RightToLeft,WrapContents=false,Padding=new Padding(0,5,0,0)};shell.Controls.Add(footer,0,3);
            Button apply=Button("应用设置",Color.FromArgb(33,129,116),()=>Apply());footer.Controls.Add(apply);
            footer.Controls.Add(Button("还原游戏原版",Color.FromArgb(113,64,62),()=>RestoreVanilla()));
            footer.Controls.Add(Button("载入推荐参数",surface,()=>{var preset=new GuardConfig();preset.Enabled=loaded.Enabled;preset.WarningColorsEnabled=loaded.WarningColorsEnabled;Fill(preset);message.Text="已载入当前推荐值，点击“应用设置”后生效。";}));
            footer.Controls.Add(Button("重新读取",surface,()=>Reload()));
            footer.Controls.Add(Button("配置备份",surface,()=>RestoreBackup()));
            footer.Controls.Add(Button("使用说明",surface,()=>Process.Start(new ProcessStartInfo(Path.Combine(store.Root,@"_ModWork\YanyunGuard\使用说明.txt")){UseShellExecute=true})));
            AcceptButton=apply;
            Reload();timer.Interval=800;timer.Tick+=(o,e)=>RefreshStatus();timer.Start();RefreshStatus();
            FormClosed+=(o,e)=>timer.Dispose();
        }
        Button Button(string text,Color color,Action action) {
            var b=new Button{Text=text,BackColor=color,ForeColor=ink,FlatStyle=FlatStyle.Flat,Height=40,Width=text.Length>5?138:116,Margin=new Padding(7,0,0,0),Cursor=Cursors.Hand};b.FlatAppearance.BorderSize=0;
            b.Click+=(o,e)=>{try{action();}catch(Exception ex){MessageBox.Show(this,ex.Message,"操作未完成",MessageBoxButtons.OK,MessageBoxIcon.Warning);}};return b;
        }
        TableLayoutPanel Page(TabControl tabs,string title) {
            var p=new TabPage(title){BackColor=surface,Padding=new Padding(18,12,18,10),AutoScroll=true};tabs.TabPages.Add(p);
            var t=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=2,BackColor=surface,Padding=new Padding(3,5,3,10)};
            t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,56));t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,44));p.Controls.Add(t);return t;
        }
        int Row(TableLayoutPanel t,string title,string desc,int height) {
            int row=t.RowCount++;t.RowStyles.Add(new RowStyle(SizeType.Absolute,height));
            var panel=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0,0,8,0)};
            panel.Controls.Add(new Label{Text=title,AutoSize=true,ForeColor=ink,Location=new Point(0,4),Font=new Font(Font,FontStyle.Bold)});
            panel.Controls.Add(new Label{Text=desc,ForeColor=muted,AutoSize=false,Height=36,Dock=DockStyle.Bottom});t.Controls.Add(panel,0,row);return row;
        }
        void AddKey(TableLayoutPanel t,string title,string desc,string key) {
            int row=Row(t,title,desc,67);var c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=285,BackColor=background,ForeColor=ink,FlatStyle=FlatStyle.Flat,Margin=new Padding(0,12,0,0)};
            foreach(string code in GuardConfig.Keys)c.Items.Add(new KeyChoice{Code=code,Label=KeyLabel(code)});fields[key]=c;t.Controls.Add(c,1,row);
        }
        static string KeyLabel(string code) {
            switch(code){case "RightMouseButton":return "鼠标右键";case "LeftMouseButton":return "鼠标左键（通常用于攻击）";case "MiddleMouseButton":return "鼠标中键";case "XButton1":return "鼠标侧键 1";case "XButton2":return "鼠标侧键 2";case "LeftShift":return "左 Shift";case "LeftControl":return "左 Ctrl";case "SpaceBar":return "空格";default:return code;}
        }
        void AddNumber(TableLayoutPanel t,string title,string desc,string key,decimal min,decimal max,decimal step,int places,decimal scale,string unit) {
            int row=Row(t,title,desc,67);var p=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=false,Padding=new Padding(0,10,0,0)};
            var n=new NumericUpDown{Minimum=min,Maximum=max,Increment=step,DecimalPlaces=places,Width=158,BackColor=background,ForeColor=ink,BorderStyle=BorderStyle.FixedSingle,ThousandsSeparator=false};
            numbers[key]=new NumberBinding{Control=n,Scale=scale};p.Controls.Add(n);p.Controls.Add(new Label{Text=unit,ForeColor=muted,AutoSize=true,Margin=new Padding(10,4,0,0)});t.Controls.Add(p,1,row);
        }
        void AddCheck(TableLayoutPanel t,string title,string desc,string key) {
            int row=Row(t,title,desc,67);var c=new CheckBox{Text="开启",ForeColor=ink,AutoSize=true,Margin=new Padding(0,13,0,0)};fields[key]=c;t.Controls.Add(c,1,row);
        }
        void AddSpam(TableLayoutPanel t) {
            int row=Row(t,"连续点按窗口倍率","第 1 / 2 / 3 / 4 次及以后，按顺序填写百分比。",78);
            var p=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=false,Padding=new Padding(0,10,0,0)};
            for(int i=0;i<4;i++) {var n=new NumericUpDown{Minimum=0,Maximum=100,DecimalPlaces=0,Width=70,Increment=5,BackColor=background,ForeColor=ink,Margin=new Padding(0,0,7,0)};numbers["SpamMultipliers."+i]=new NumberBinding{Control=n,Scale=100};p.Controls.Add(n);}t.Controls.Add(p,1,row);
        }
        void AddNote(TableLayoutPanel t,string text) {int row=t.RowCount++;t.RowStyles.Add(new RowStyle(SizeType.Absolute,80));var l=new Label{Text=text,ForeColor=muted,Dock=DockStyle.Fill,Padding=new Padding(0,12,0,0)};t.Controls.Add(l,0,row);t.SetColumnSpan(l,2);}
        static object GetValue(GuardConfig c,string key) {
            if(key.StartsWith("SpamMultipliers."))return c.SpamMultipliers[int.Parse(key.Substring(key.Length-1))];
            return typeof(GuardConfig).GetField(key).GetValue(c);
        }
        void Fill(GuardConfig c) {
            loaded=c;
            foreach(var pair in fields) {
                object v=GetValue(c,pair.Key);var cb=pair.Value as CheckBox;if(cb!=null){cb.Checked=(bool)v;continue;}
                var combo=(ComboBox)pair.Value;foreach(KeyChoice item in combo.Items)if(item.Code==(string)v){combo.SelectedItem=item;break;}
            }
            foreach(var p in numbers)p.Value.Control.Value=(decimal)GetValue(c,p.Key)*p.Value.Scale;
            configState.Text="已保存：卸势"+(c.Enabled?"开":"关")+" / 换色"+(c.WarningColorsEnabled?"开":"关");
        }
        GuardConfig ReadForm() {
            var c=new GuardConfig();c.Enabled=loaded.Enabled;
            foreach(var pair in fields) {
                object v=pair.Value is CheckBox?(object)((CheckBox)pair.Value).Checked:((KeyChoice)((ComboBox)pair.Value).SelectedItem).Code;
                typeof(GuardConfig).GetField(pair.Key).SetValue(c,v);
            }
            foreach(var p in numbers) {
                decimal v=p.Value.Control.Value/p.Value.Scale;
                if(p.Key.StartsWith("SpamMultipliers."))c.SpamMultipliers[int.Parse(p.Key.Substring(p.Key.Length-1))]=v;
                else typeof(GuardConfig).GetField(p.Key).SetValue(c,v);
            }
            c.Validate();return c;
        }
        void Reload(){Fill(store.Load());message.Text="表单修改在点击“应用设置”后生效。每次保存会自动备份。";}
        void Apply(){var c=ReadForm();pending=store.Apply(c);Fill(c);message.Text="已保存，等待游戏接收；未连接时将在下次启动自动应用。";RefreshStatus();}
        void RestoreVanilla(){pending=store.RestoreVanilla();Fill(store.Load());message.Text="已保存原版状态，调好的参数和隔离存档均保留。";RefreshStatus();}
        void RestoreBackup() {
            Directory.CreateDirectory(store.BackupPath);
            using(var d=new OpenFileDialog{Title="选择要恢复的配置备份",InitialDirectory=store.BackupPath,Filter="本面板的配置备份 (*.lua)|*.lua",CheckFileExists=true}) {
                if(d.ShowDialog(this)!=DialogResult.OK)return;
                pending=store.RestoreBackup(d.FileName);Fill(store.Load());message.Text="已恢复所选配置备份，等待游戏接收。";RefreshStatus();
            }
        }
        void RefreshStatus() {
            try {
                var s=store.ReadStatus();
                if(s.Count==0){
                    var processes=Process.GetProcessesByName("PBZ");bool running=processes.Length>0;foreach(var p in processes)p.Dispose();
                    connection.Text=running?"● 等待游戏刷新 · 保存后切回游戏自动应用":"● 未连接游戏 · 启动游戏后自动应用已保存设置";
                    connection.ForeColor=muted;return;
                }
                bool enabled=s.ContainsKey("enabled")&&s["enabled"]=="1";
                bool warningEnabled=s.ContainsKey("warning_enabled")&&s["warning_enabled"]=="1";
                connection.Text="● 游戏已连接 · 卸势"+(enabled?"开":"关")+" / 换色"+(warningEnabled?"开":"关");connection.ForeColor=enabled?Color.FromArgb(111,214,195):Color.FromArgb(232,193,122);
                if(pending!="" && s.ContainsKey("request") && s["request"]==pending) {
                    message.Text=s.ContainsKey("result")&&s["result"]=="error"?"游戏应用失败："+(s.ContainsKey("message")?s["message"]:""):"游戏已应用当前设置。";pending="";
                }
            }catch(IOException){}catch(UnauthorizedAccessException){}
        }
    }
    static class Program {
        [STAThread]static int Main(string[] args) {
            string root=AppDomain.CurrentDomain.BaseDirectory;
            if(args.Length>0 && args[0]=="--self-test")return SelfTest.Run(root);
            try {Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new PanelForm(new ConfigStore(root)));return 0;}
            catch(Exception e){MessageBox.Show(e.Message,"配置面板启动失败",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
        }
    }
}
