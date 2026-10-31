using System;
using System.IO;
using System.Text;
namespace PBZGuardPanel {
    static class SelfTest {
        static void Check(bool ok,string label){if(!ok)throw new Exception(label);}
        public static int Run(string root) {
            string area=Path.Combine(root,@"_ModWork\YanyunGuard\ControlPanel\Tests",Guid.NewGuid().ToString("N"));
            string report=Path.Combine(root,@"_ModWork\YanyunGuard\ControlPanel\self-test.txt");
            try {
                var store=new ConfigStore(area);Directory.CreateDirectory(store.ScriptsPath);
                var c=new GuardConfig();c.ParryKey="H";c.ParryCostPercent=.075m;c.Enabled=false;
                string text=c.Serialize();var parsed=GuardConfig.Parse(text);
                Check(parsed.Serialize()==text,"Full schema round-trip, including disabled state");
                Check(parsed.SuccessChainEnabled && parsed.SuccessChainMaxStacks==3 && parsed.SuccessChainRefundStep==.02m,"Chain defaults round-trip");
                bool chainRejected=false;c.SuccessChainMaxStacks=2.5m;try{c.Validate();}catch(InvalidDataException){chainRejected=true;}Check(chainRejected,"Reject fractional chain stacks");c.SuccessChainMaxStacks=3;
                chainRejected=false;c.SuccessChainPoiseStep=.06m;try{c.Validate();}catch(InvalidDataException){chainRejected=true;}Check(chainRejected,"Reject excessive chain step");c.SuccessChainPoiseStep=.02m;
                bool rejected=false;c.GuardKey="H";try{c.Validate();}catch(InvalidDataException){rejected=true;}Check(rejected,"Reject duplicate bindings");c.GuardKey="G";
                rejected=false;c.BladeFlashMinInterval=.20m;try{c.Validate();}catch(InvalidDataException){rejected=true;}Check(rejected,"Reject continuous-light settings");c.BladeFlashMinInterval=.32m;
                File.WriteAllText(store.ConfigPath,c.Serialize(),ConfigStore.Utf8);
                string first=store.Apply(c);Check(store.Load().Enabled,"Apply persists enabled");
                Check(File.ReadAllText(Path.Combine(store.ScriptsPath,"control.request")).Contains(first+"\nAPPLY"),"Apply queues correct request");
                string second=store.RestoreVanilla();var off=store.Load();
                Check(!off.Enabled && off.ParryKey=="H" && off.ParryCostPercent==.075m,"Vanilla restore preserves user tuning");
                Check(second!=first && File.ReadAllText(Path.Combine(store.ScriptsPath,"control.request")).Contains("RESTORE"),"Restore queues fresh request");
                string before=File.ReadAllText(store.ConfigPath);c.ParryKey="F7";rejected=false;try{store.Apply(c);}catch(InvalidDataException){rejected=true;}
                Check(rejected && File.ReadAllText(store.ConfigPath)==before,"Invalid input cannot partially save");
                string[] backups=Directory.GetFiles(store.BackupPath,"*.lua");Check(backups.Length==2,"Every valid mutation creates backup");
                string selected=null;foreach(string b in backups)if(GuardConfig.Parse(File.ReadAllText(b)).Enabled)selected=b;
                Check(selected!=null,"Enabled backup available");store.RestoreBackup(selected);Check(store.Load().Enabled,"Restore config backup including state");
                File.WriteAllText(Path.Combine(store.ScriptsPath,"control.status"),"enabled=1\nrequest=test\nresult=ok\n");Check(store.ReadStatus()["enabled"]=="1","Read runtime acknowledgement");
                Check(GuardConfig.Parse("return {\n GuardKey = \"G\",\n ParryKey = \"RightMouseButton\",\n}\n").Enabled,"Legacy configs default to enabled");
                File.WriteAllText(report,"PASS: schema round-trip, binding validation, flash gap validation, atomic apply/restore, preserved tuning, request protocol, backup recovery, runtime acknowledgement, legacy config.\r\nTest data: "+area,Encoding.UTF8);return 0;
            }catch(Exception e){Directory.CreateDirectory(Path.GetDirectoryName(report));File.WriteAllText(report,"FAIL: "+e,Encoding.UTF8);return 1;}
        }
    }
}
