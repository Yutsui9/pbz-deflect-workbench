using System;
using System.Linq;
using System.IO;
using System.Collections.Generic;
using UAssetAPI;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;
using UAssetAPI.ExportTypes;
using UAssetAPI.PropertyTypes.Objects;
using UAssetAPI.PropertyTypes.Structs;
public static class PatchWarnings {
 static FName N(UAsset a,string n){return new FName(a,n,0);}
 static PropertyData P(IEnumerable<PropertyData> list,string n){return list.FirstOrDefault(p=>p.Name.ToString()==n);}
 static StructPropertyData S(UAsset a,string name,string type,params PropertyData[] values){return new StructPropertyData(N(a,name),N(a,type)){Value=values.ToList()};}
 static NamePropertyData Name(UAsset a,string n,string v){return new NamePropertyData(N(a,n)){Value=N(a,v)};}
 static void Put(List<PropertyData> list,PropertyData p){int i=list.FindIndex(x=>x.Name.ToString()==p.Name.ToString());if(i<0)list.Add(p);else list[i]=p;}
 static ArrayPropertyData Array(UAsset a,StructPropertyData s,string name){var p=P(s.Value,name) as ArrayPropertyData;if(p==null){p=new ArrayPropertyData(N(a,name)){ArrayType=N(a,"StructProperty"),Value=new PropertyData[0]};s.Value.Add(p);}return p;}
 static StructPropertyData Parameters(UAsset a,NormalExport e){var p=P(e.Data,"MaterialParameters") as StructPropertyData;if(p==null){p=S(a,"MaterialParameters","NiagaraRendererMaterialParameters");e.Data.Add(p);}return p;}
 static LinearColorPropertyData Color(StructPropertyData entry){return (LinearColorPropertyData)((StructPropertyData)P(entry.Value,"Value")).Value[0];}
 static void Vector(UAsset a,StructPropertyData parameters,string name,float r,float g,float b,float alpha){
  var arr=Array(a,parameters,"VectorParameters");
  var entry=arr.Value.Cast<StructPropertyData>().FirstOrDefault(x=>((NamePropertyData)P(x.Value,"MaterialParameterName")).Value.ToString()==name);
  if(entry!=null)return; // existing renderer override has precedence over parent material
  var color=new LinearColorPropertyData(N(a,"Value")){Value=new FLinearColor(r,g,b,alpha)};
  entry=S(a,arr.Value.Length.ToString(),"NiagaraRendererMaterialVectorParameter",Name(a,"MaterialParameterName",name),S(a,"Value","LinearColor",color));
  arr.Value=arr.Value.Concat(new PropertyData[]{entry}).ToArray();arr.IsZero=false;
 }
 static void Scalar(UAsset a,StructPropertyData parameters,string name,float value){
  var arr=Array(a,parameters,"ScalarParameters");
  var entry=arr.Value.Cast<StructPropertyData>().FirstOrDefault(x=>((NamePropertyData)P(x.Value,"MaterialParameterName")).Value.ToString()==name);
  if(entry!=null)return;
  entry=S(a,arr.Value.Length.ToString(),"NiagaraRendererMaterialScalarParameter",Name(a,"MaterialParameterName",name),new FloatPropertyData(N(a,"Value")){Value=value});
  arr.Value=arr.Value.Concat(new PropertyData[]{entry}).ToArray();arr.IsZero=false;
 }
 static void Unbind(UAsset a,NormalExport e,StructPropertyData variableTemplate){
  var binding=(StructPropertyData)P(e.Data,"ColorBinding");
  if(binding==null)throw new Exception("No colour binding");
  Put(binding.Value,Name(a,"RootName","PBZWarningGold"));Put(binding.Value,Name(a,"DataSetName","PBZWarningGold"));
  var variable=P(binding.Value,"ParamMapVariable") as StructPropertyData;
  if(variable!=null)((NiagaraVariableBasePropertyData)variable.Value[0]).VariableName=N(a,"Particles.PBZWarningGold");
  Put(binding.Value,new BoolPropertyData(N(a,"bBindingExistsOnSource")){Value=false});binding.IsZero=false;
 }

 public static void Verify(string source,string destination,string mapping){
  var x=new UAsset(source,EngineVersion.VER_UE5_6,null,CustomSerializationFlags.None);
  var y=new UAsset(destination,EngineVersion.VER_UE5_6,null,CustomSerializationFlags.None);
  if(x.Exports.Count!=y.Exports.Count)throw new Exception("Export count changed");
  int changed=0;
  for(int i=0;i<x.Exports.Count;i++){
   var left=(RawExport)x.Exports[i];var right=(RawExport)y.Exports[i];
   if(left.ObjectName.ToString()!=right.ObjectName.ToString())throw new Exception("Export order changed");
   if(!left.Data.SequenceEqual(right.Data)){
    string n=left.ObjectName.ToString();
    if(!n.StartsWith("NiagaraDataInterfaceColorCurve")&&!n.StartsWith("NiagaraSpriteRendererProperties")&&!n.StartsWith("NiagaraMeshRendererProperties")&&!n.StartsWith("NiagaraRibbonRendererProperties"))throw new Exception("Nonvisual export changed: "+n);
    changed++;
   }
  }
  if(changed==0)throw new Exception("No changes");
  var a=new UAsset(source,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
  var b=new UAsset(destination,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
  for(int i=0;i<a.Exports.Count;i++){
   var left=(NormalExport)a.Exports[i];var right=b.Exports[i] as NormalExport;if(right==null)throw new Exception("Patched export cannot parse");
   if(!left.ObjectName.ToString().StartsWith("NiagaraDataInterfaceColorCurve"))continue;
   var l=P(left.Data,"ShaderLUT") as ArrayPropertyData;var r=P(right.Data,"ShaderLUT") as ArrayPropertyData;if(l==null)continue;
   if(r==null||l.Value.Length!=r.Value.Length)throw new Exception("LUT length changed");
   for(int j=0;j<l.Value.Length;j+=4){
    var lc=l.Value.Skip(j).Take(4).Cast<FloatPropertyData>().Select(v=>v.Value).ToArray();var rc=r.Value.Skip(j).Take(4).Cast<FloatPropertyData>().Select(v=>v.Value).ToArray();
    if(lc[3]!=rc[3])throw new Exception("Particle alpha changed");float max=lc.Take(3).Max(),min=lc.Take(3).Min();
    if((max<=0||max-min<=max*.05f)&&!lc.SequenceEqual(rc))throw new Exception("White flash changed");
   }
  }
 }
 public static string Run(string source,string destination,string mapping){
  var a=new UAsset(source,EngineVersion.VER_UE5_6,new Usmap(mapping),CustomSerializationFlags.None);
  if(a.Exports.Any(e=>!(e is NormalExport)))throw new Exception("Unparsed export in "+source);
  // Caller validates this untouched round-trip byte-for-byte before using patched output.
  Directory.CreateDirectory(Path.GetDirectoryName(destination));
  a.Write(destination+".baseline.uasset");
  bool gold=Path.GetFileName(source).Contains("_Red_");int curves=0,colors=0,glows=0;
  StructPropertyData template=null;
  foreach(var e in a.Exports.Cast<NormalExport>()){
   var binding=P(e.Data,"ColorBinding") as StructPropertyData;
   if(binding!=null && P(binding.Value,"ParamMapVariable") is StructPropertyData v){template=v;break;}
  }
  foreach(var e in a.Exports.Cast<NormalExport>()){
   string name=e.ObjectName.ToString();
   if(name.StartsWith("NiagaraDataInterfaceColorCurve")){
    var lut=P(e.Data,"ShaderLUT") as ArrayPropertyData;if(lut==null)continue;
    var use=P(e.Data,"bUseLUT") as BoolPropertyData;if(use!=null&&!use.Value)continue;
    if(lut.Value.Length%4!=0)throw new Exception("Invalid LUT");bool changed=false;
    for(int i=0;i<lut.Value.Length;i+=4){var p=lut.Value.Skip(i).Take(4).Cast<FloatPropertyData>().ToArray();float peak=Math.Max(p[0].Value,Math.Max(p[1].Value,p[2].Value));
     if(peak>0 && peak-Math.Min(p[0].Value,Math.Min(p[1].Value,p[2].Value))>peak*.05f){p[0].Value=peak;p[1].Value=peak*(gold?.78f:.025f);p[2].Value=peak*(gold?.025f:.01f);for(int n=0;n<3;n++)p[n].IsZero=false;changed=true;}
    }if(changed){curves++;lut.IsZero=false;}
   }
   bool sprite=name.StartsWith("NiagaraSpriteRendererProperties"),mesh=name.StartsWith("NiagaraMeshRendererProperties"),ribbon=name.StartsWith("NiagaraRibbonRendererProperties");
   if(!sprite&&!mesh&&!ribbon)continue;
   var mat=P(e.Data,"Material") as ObjectPropertyData;
   string material=mat!=null && mat.Value.Index<0?a.Imports[-mat.Value.Index-1].ObjectName.ToString():"";
   bool smoke=gold&&sprite&&material.Contains("Smoke"),main=false;
   var parameters=Parameters(a,e);var vectors=P(parameters.Value,"VectorParameters") as ArrayPropertyData;
   if(vectors!=null)foreach(var entry in vectors.Value.Cast<StructPropertyData>()){
    string parameter=((NamePropertyData)P(entry.Value,"MaterialParameterName")).Value.ToString();
    if(!new[]{"Main_Color_0","Main_Color_1","Main_Color_2","EdgeColor"}.Contains(parameter))continue;
    var c=Color(entry);float peak=Math.Max(c.Value.R,Math.Max(c.Value.G,c.Value.B));
    if(peak<=0||(!(smoke&&parameter=="Main_Color_1")&&peak-Math.Min(c.Value.R,Math.Min(c.Value.G,c.Value.B))<=peak*.05f))continue;
    float[] hue=smoke?new[]{.5625f,.35f,.0875f}:new[]{1f,.035f,.012f};float gain=1;
    if(gold&&!smoke){switch(parameter){case "Main_Color_0":hue=new[]{1f,.86f,.48f};gain=.6f;break;case "Main_Color_1":hue=new[]{.82f,.54f,.13f};gain=1.12f;break;case "Main_Color_2":hue=new[]{.46f,.25f,.07f};break;case "EdgeColor":hue=new[]{1f,.88f,.55f};gain=.4f;break;}}
    c.Value=new FLinearColor(peak*hue[0]*gain,peak*hue[1]*gain,peak*hue[2]*gain,c.Value.A*(smoke?.45f:1f));c.IsZero=false;colors++;if(parameter=="EdgeColor")main=true;
   }
   if(gold&&mesh&&main){Unbind(a,e,template);}
   if(gold&&sprite&&mat!=null){
    var binding=(StructPropertyData)P(e.Data,"ColorBinding");var dataset=P(binding.Value,"DataSetName") as NamePropertyData;
    bool core=dataset!=null&&dataset.Value.ToString()=="PP_GlowCol";
    string outer=e.OuterIndex.Index>0?a.Exports[e.OuterIndex.Index-1].ObjectName.ToString():"";bool spark=outer.Contains("Star");
    Unbind(a,e,template);
    if(smoke)Vector(a,parameters,"Main_Color_1",.45f,.28f,.07f,.45f);
    else{
     float r=core?2:spark?1.4f:1.8f,g=core?1.75f:spark?.82f:1.3f,b=core?.95f:spark?.035f:.22f;
     if(!spark){r*=.65f;g*=.65f;b*=.65f;Scalar(a,parameters,"Tex_Color_Pow",1.2f);}
     Vector(a,parameters,"Main_Color_1",r,g,b,.75f);Vector(a,parameters,"Color",r,g,b,.75f);Vector(a,parameters,"Main_Color_2",r*.2f,g*.14f,b*.22f,.75f);
    }glows++;
   }
  }
  if(curves==0)throw new Exception("No target curves patched");
  a.Write(destination);
  return Path.GetFileName(source)+": curves="+curves+", renderer colours="+colors+", gold layers="+glows;
 }
}
