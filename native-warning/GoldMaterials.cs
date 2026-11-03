using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UAssetAPI;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;
using UAssetAPI.ExportTypes;
using UAssetAPI.PropertyTypes.Objects;
using UAssetAPI.PropertyTypes.Structs;
public static class GoldMaterials {
 static FName N(UAsset a,string n)=>new FName(a,n,0);
 static PropertyData P(IEnumerable<PropertyData> p,string n)=>p.FirstOrDefault(x=>x.Name.ToString()==n);
 static StructPropertyData S(UAsset a,string n,string t,params PropertyData[] p)=>new StructPropertyData(N(a,n),N(a,t)){Value=p.ToList()};
 static void Set(UAsset a,NormalExport e,string name,float r,float g,float b) {
  var arr=P(e.Data,"VectorParameterValues") as ArrayPropertyData;
  if(arr==null){arr=new ArrayPropertyData(N(a,"VectorParameterValues")){ArrayType=N(a,"StructProperty"),Value=new PropertyData[0]};e.Data.Add(arr);}
  var item=arr.Value.Cast<StructPropertyData>().FirstOrDefault(v=>((NamePropertyData)P(((StructPropertyData)P(v.Value,"ParameterInfo")).Value,"Name")).Value.ToString()==name);
  var col=S(a,"ParameterValue","LinearColor",new LinearColorPropertyData(N(a,"ParameterValue")){Value=new FLinearColor(r,g,b,.75f)});
  if(item!=null){var old=(LinearColorPropertyData)((StructPropertyData)P(item.Value,"ParameterValue")).Value[0];col.Value[0]=new LinearColorPropertyData(N(a,"ParameterValue")){Value=new FLinearColor(r,g,b,old.Value.A)};item.Value[item.Value.FindIndex(x=>x.Name.ToString()=="ParameterValue")]=col;item.IsZero=false;}
  else {
   var info=S(a,"ParameterInfo","MaterialParameterInfo",new NamePropertyData(N(a,"Name")){Value=N(a,name)},new EnumPropertyData(N(a,"Association")){EnumType=N(a,"EMaterialParameterAssociation"),InnerType=N(a,"ByteProperty"),Value=N(a,"GlobalParameter")},new IntPropertyData(N(a,"Index")){Value=-1});
   item=S(a,arr.Value.Length.ToString(),"VectorParameterValue",info,col,S(a,"ExpressionGUID","Guid",new GuidPropertyData(N(a,"ExpressionGUID")){Value=Guid.Empty}));
   arr.Value=arr.Value.Concat(new PropertyData[]{item}).ToArray();
  }arr.IsZero=false;
 }
 public static void Verify(string source,string destination,string mapping){
  var a=new UAsset(source,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
  var b=new UAsset(destination,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
  if(a.Exports.Count!=b.Exports.Count||a.Imports.Count!=b.Imports.Count)throw new Exception("Material structure changed");
  for(int i=0;i<a.Imports.Count;i++)if(a.SerializeJsonObject(a.Imports[i],false)!=b.SerializeJsonObject(b.Imports[i],false))throw new Exception("Material parent/dependency changed");
  for(int i=0;i<a.Exports.Count;i++){
   var x=(NormalExport)a.Exports[i];var y=(NormalExport)b.Exports[i];
   foreach(var prop in x.Data.Where(p=>p.Name.ToString()!="VectorParameterValues"))if(a.SerializeJsonObject(prop,false)!=b.SerializeJsonObject(P(y.Data,prop.Name.ToString()),false))throw new Exception("Non-color material property changed: "+prop.Name);
   var old=P(x.Data,"VectorParameterValues") as ArrayPropertyData;
   var updated=(ArrayPropertyData)P(y.Data,"VectorParameterValues");
   if(old!=null)foreach(var prop in old.Value.Cast<StructPropertyData>()){
    string key=((NamePropertyData)P(((StructPropertyData)P(prop.Value,"ParameterInfo")).Value,"Name")).Value.ToString();
    if(new[]{"Main_Color_0","Main_Color_1","Main_Color_2","Color"}.Contains(key))continue;
    var actual=updated.Value.Cast<StructPropertyData>().Single(v=>((NamePropertyData)P(((StructPropertyData)P(v.Value,"ParameterInfo")).Value,"Name")).Value.ToString()==key);
    if(a.SerializeJsonObject(prop,false)!=b.SerializeJsonObject(actual,false))throw new Exception("Non-color vector changed: "+key);
   }
  }
 }
 public static void Run(string warning,string originals,string output,string mapping){
  var a=new UAsset(warning,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
  var used=a.Exports.Cast<NormalExport>().Where(e=>e.ObjectName.ToString().StartsWith("NiagaraSpriteRendererProperties")).Select(e=>P(e.Data,"Material") as ObjectPropertyData).Where(p=>p!=null&&p.Value.Index<0).Select(p=>-p.Value.Index-1).Distinct().ToArray();
  foreach(int idx in used){
   var imp=a.Imports[idx];if(imp.ClassName.ToString()!="MaterialInstanceConstant")throw new Exception("Unexpected material class");
   var pkg=a.Imports[-imp.OuterIndex.Index-1];string path=pkg.ObjectName.ToString(), name=imp.ObjectName.ToString();
   string rel="ProjectPBZ/Plugins/PBZVFXPack/Content/"+path.Substring("/PBZVFXPack/".Length)+".uasset";
   string src=Path.Combine(originals,rel), dst=Path.Combine(output,rel.Replace(".uasset","_PBZGold.uasset"));
   var m=new UAsset(src,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
   Directory.CreateDirectory(Path.GetDirectoryName(dst));
   string baseline=Path.Combine(Path.GetDirectoryName(originals),"baselines",name+".material.uasset");m.Write(baseline);
   if(!File.ReadAllBytes(Path.ChangeExtension(src,".uexp")).SequenceEqual(File.ReadAllBytes(Path.ChangeExtension(baseline,".uexp"))))throw new Exception("Material baseline differs: "+src);
   var e=m.Exports.OfType<NormalExport>().Single(x=>x.ObjectName.ToString()==name);
   bool smoke=name.Contains("Smoke");
   Set(m,e,"Main_Color_0",1f,.65f,.03f);Set(m,e,"Main_Color_1",smoke?.45f:1.17f,smoke?.28f:.76f,smoke?.07f:.035f);Set(m,e,"Main_Color_2",.234f,.1183f,.008f);Set(m,e,"Color",1.17f,.76f,.035f);
   // Rename only this copy; original shared material packages stay untouched.
   for(int i=0;i<m.GetNameMapIndexList().Count;i++){string n=m.GetNameReference(i).ToString();if(n==name||n==path)m.SetNameReference(i,new FString(n+"_PBZGold"));}
   m.Write(dst);
   Verify(src,dst,mapping);
   var check=new UAsset(dst,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
   var ce=check.Exports.OfType<NormalExport>().Single(x=>x.ObjectName.ToString()==name+"_PBZGold");
   var cv=(ArrayPropertyData)P(ce.Data,"VectorParameterValues");
   foreach(string key in new[]{"Main_Color_0","Main_Color_1","Main_Color_2","Color"}){
    var entry=cv.Value.Cast<StructPropertyData>().Single(v=>((NamePropertyData)P(((StructPropertyData)P(v.Value,"ParameterInfo")).Value,"Name")).Value.ToString()==key);
    var color=((LinearColorPropertyData)((StructPropertyData)P(entry.Value,"ParameterValue")).Value[0]).Value;
    if(!(color.R>color.G&&color.G>color.B))throw new Exception("Gold parameter not preserved");
   }
   pkg.ObjectName=N(a,path+"_PBZGold");imp.ObjectName=N(a,name+"_PBZGold");
  }
  a.Write(warning);Console.WriteLine("Gold material imports verified: "+used.Length+" in "+Path.GetFileName(warning));
 }
}
