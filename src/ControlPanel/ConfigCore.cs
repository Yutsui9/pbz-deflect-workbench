using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace PBZGuardPanel {
    public sealed class GuardConfig {
        public bool Enabled=true, StrongParryAnimation=true, ParryTapFX=true, ParryTapSound=true, Debug=false;
        public string GuardKey="G", ParryKey="RightMouseButton";
        public decimal ParryCostPercent=.03m, WindowSeconds=.250m, SpamRecoverySeconds=.400m;
        public decimal[] SpamMultipliers={1m,1m,1m,1m};
        public decimal ParryRaiseSpeed=1.70m, BladeFlashStrength=.16m, BladeFlashDuration=.18m, BladeFlashMinInterval=.32m;
        public decimal ParryLowerSpeed=1.50m, PerfectParryRefundPercent=.10m, PerfectParryPoisePercent=.10m;
        public bool SuccessChainEnabled=true;
        public bool ParryTapShake=true;
        public bool WarningColorsEnabled=false;
        public decimal SuccessChainTimeout=6m, SuccessChainMaxStacks=3m, SuccessChainRefundStep=.02m, SuccessChainPoiseStep=.02m;
        public decimal ParryTapSoundVolume=.24m, GuardDrainMultiplier=1.15m, GuardDrainStartDelay=.20m;
        public decimal NormalUltimateMultiplier=.80m, PerfectUltimateMultiplier=1.10m;
        static readonly CultureInfo Inv=CultureInfo.InvariantCulture;
        public static readonly string[] Keys=BuildKeys();
        static string[] BuildKeys() {
            var a=new List<string>{"RightMouseButton","MiddleMouseButton","XButton1","XButton2","LeftMouseButton"};
            for(char c='A';c<='Z';c++) a.Add(c.ToString());
            a.AddRange(new[]{"LeftShift","LeftControl","SpaceBar","Tab"});
            for(int i=1;i<=12;i++) if(i!=5 && i!=6 && i!=7) a.Add("F"+i);
            return a.ToArray();
        }
        static void Range(decimal v,decimal min,decimal max,string label) {
            if(v<min || v>max) throw new InvalidDataException(label+"必须在 "+min+" 到 "+max+" 之间。");
        }
        public void Validate() {
            if(Array.IndexOf(Keys,GuardKey)<0 || Array.IndexOf(Keys,ParryKey)<0) throw new InvalidDataException("按键名称不受支持，请从列表选择。");
            if(GuardKey==ParryKey) throw new InvalidDataException("防御键与招架键不能相同。");
            Range(ParryCostPercent,0,.25m,"点按耗气比例"); Range(WindowSeconds,.05m,.6m,"精防窗口（秒）");
            Range(SpamRecoverySeconds,.1m,2,"连按恢复间隔（秒）");
            Range(SuccessChainTimeout,1,15,"连续成功衔接时间");Range(SuccessChainMaxStacks,1,5,"连续成功奖励层数");
            if(SuccessChainMaxStacks!=decimal.Truncate(SuccessChainMaxStacks))throw new InvalidDataException("奖励层数必须为整数。");
            Range(SuccessChainRefundStep,0,.05m,"每层额外回气");Range(SuccessChainPoiseStep,0,.05m,"每层额外削韧");
            if(SpamMultipliers==null || SpamMultipliers.Length!=4) throw new InvalidDataException("连按倍率必须有四项。");
            foreach(var v in SpamMultipliers) Range(v,0,1,"连按窗口倍率");
            Range(ParryRaiseSpeed,1,2.5m,"举刀起手速度"); Range(BladeFlashStrength,0,1,"剑光强度");
            Range(ParryLowerSpeed,1,2.5m,"收刀速度");Range(PerfectParryRefundPercent,0,.25m,"成功精防回杀气比例");Range(PerfectParryPoisePercent,0,.25m,"成功精防即时削韧比例");
            Range(BladeFlashDuration,.04m,.4m,"剑光时长（秒）"); Range(BladeFlashMinInterval,.10m,2,"剑光最小间隔（秒）");
            if(BladeFlashMinInterval<BladeFlashDuration+.06m) throw new InvalidDataException("剑光最小间隔需比时长至少多 60 毫秒，以免连成常亮。");
            Range(ParryTapSoundVolume,0,1,"音量"); Range(GuardDrainMultiplier,0,5,"持续防御耗气倍率");
            Range(GuardDrainStartDelay,0,2,"防御耗气延迟（秒）");
            Range(NormalUltimateMultiplier,0,5,"普通防御收益倍率");Range(PerfectUltimateMultiplier,0,5,"精防收益倍率");
        }
        static string Value(string source,string key) {
            var m=Regex.Match(source,@"(?m)^\s*"+Regex.Escape(key)+@"\s*=\s*(\{[^\r\n}]*\}|""[^""\r\n]*""|true\b|false\b|[-+]?\d+(?:\.\d+)?)\s*[,;]?");
            return m.Success?m.Groups[1].Value:null;
        }
        public static GuardConfig Parse(string source) {
            var c=new GuardConfig();
            foreach(var f in typeof(GuardConfig).GetFields(System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public)) {
                var raw=Value(source,f.Name);if(raw==null)continue;
                if(f.FieldType==typeof(bool)) f.SetValue(c,raw=="true");
                else if(f.FieldType==typeof(string)) f.SetValue(c,raw.Trim('"'));
                else if(f.FieldType==typeof(decimal)) f.SetValue(c,decimal.Parse(raw,Inv));
                else if(f.FieldType==typeof(decimal[])) {
                    var parts=raw.Trim('{','}').Split(',');var a=new decimal[parts.Length];
                    for(int i=0;i<a.Length;i++)a[i]=decimal.Parse(parts[i].Trim(),Inv);f.SetValue(c,a);
                }
            }
            c.Validate();return c;
        }
        static string N(decimal v) {return v.ToString("0.######",Inv);}
        public string Serialize() {
            Validate();var s=new StringBuilder("-- Managed by the PBZ guard configuration panel. F5 reloads this file.\r\nreturn {\r\n");
            foreach(var f in typeof(GuardConfig).GetFields(System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public)) {
                object v=f.GetValue(this);string raw;
                if(v is bool) raw=(bool)v?"true":"false";
                else if(v is string) raw="\""+(string)v+"\"";
                else if(v is decimal[]) {var a=(decimal[])v;var p=new string[a.Length];for(int i=0;i<a.Length;i++)p[i]=N(a[i]);raw="{"+string.Join(", ",p)+"}";}
                else raw=N((decimal)v);
                s.Append("    ").Append(f.Name).Append(" = ").Append(raw).Append(",\r\n");
            }
            return s.Append("}\r\n").ToString();
        }
    }
    public sealed class ConfigStore {
        public readonly string Root,ConfigPath,ScriptsPath,BackupPath;
        public static readonly UTF8Encoding Utf8=new UTF8Encoding(false);
        public ConfigStore(string root) {
            Root=Path.GetFullPath(root);ScriptsPath=Path.Combine(Root,@"platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts");
            ConfigPath=Path.Combine(ScriptsPath,"config.lua");BackupPath=Path.Combine(Root,@"_ModWork\YanyunGuard\PanelBackups");
        }
        public GuardConfig Load() {return GuardConfig.Parse(File.ReadAllText(ConfigPath,Encoding.UTF8));}
        static string NewId() {return DateTime.UtcNow.Ticks.ToString(CultureInfo.InvariantCulture)+Guid.NewGuid().ToString("N").Substring(0,6);}
        static void AtomicWrite(string path,string content) {
            string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
            try {File.WriteAllText(temp,content,Utf8);if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}
            finally {if(File.Exists(temp))File.Delete(temp);}
        }
        public string Apply(GuardConfig c) {
            c.Enabled=true;c.Validate();return Save(c,"APPLY");
        }
        public string RestoreVanilla() {
            // Preserve the user's last saved tuning while persisting the disabled state.
            var c=Load();c.Enabled=false;return Save(c,"RESTORE");
        }
        string Save(GuardConfig c,string action) {
            Directory.CreateDirectory(BackupPath);
            string id=NewId();File.Copy(ConfigPath,Path.Combine(BackupPath,"config-"+id+".lua"));
            AtomicWrite(ConfigPath,c.Serialize());
            string mod=Directory.GetParent(ScriptsPath).FullName;
            if(!File.Exists(Path.Combine(mod,"enabled.txt")) && File.Exists(Path.Combine(mod,"disabled.txt"))) File.Move(Path.Combine(mod,"disabled.txt"),Path.Combine(mod,"enabled.txt"));
            AtomicWrite(Path.Combine(ScriptsPath,"control.request"),id+"\n"+action+"\n");return id;
        }
        public Dictionary<string,string> ReadStatus() {
            string path=Path.Combine(ScriptsPath,"control.status");var d=new Dictionary<string,string>();
            if(!File.Exists(path) || (DateTime.UtcNow-File.GetLastWriteTimeUtc(path)).TotalSeconds>4) return d;
            foreach(string line in File.ReadAllLines(path,Encoding.UTF8)) {int n=line.IndexOf('=');if(n>0)d[line.Substring(0,n)]=line.Substring(n+1);}
            return d;
        }
        public string RestoreBackup(string path) {
            string full=Path.GetFullPath(path);
            if(!full.StartsWith(BackupPath+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("请选择本面板生成的备份。");
            var c=GuardConfig.Parse(File.ReadAllText(full,Encoding.UTF8));
            return c.Enabled?Apply(c):Save(c,"RESTORE");
        }
    }
}
