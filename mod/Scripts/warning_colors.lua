-- Recolour only native attack-alert colour curves. No combat timing changes.
local M={}
local saved={}
local texts={}
local rendererColors={}
local gpuGlows={}
local last=-10
local failed=false
local root='/PBZVFXPack/VFX/BattleFX/'
local systems={
 ['Common/NS_AttackAlert_Blue_001']='deflect',
 ['Common/NS_AttackAlert_Blue_002']='deflect',
 ['Common/NS_AttackAlert_Red_001']='dodge',
 ['Common/NS_AttackAlert_Red_004']='dodge',
 ['Hun/NS_AttackAlertHun_Blue_001']='deflect',
 ['Hun/NS_AttackAlertHun_Red_001']='dodge',
}
local function valid(o) return o and o:IsValid() end
local function kind(name)
 for path,k in pairs(systems) do
  local asset=path:match('([^/]+)$')
  if name:find(root..path..'.'..asset..':',1,true) then return k end
 end
end
local function values(array)
 local t={}
 array:ForEach(function(i,v) t[i]=v:get() end)
 return t
end
local function write(array,t)
 array:ForEach(function(i,v) if t[i]~=nil then v:set(t[i]) end end)
end
local colorParameters={Main_Color_0=true,Main_Color_1=true,Main_Color_2=true,EdgeColor=true}
local goldPalette={
 Main_Color_0={1,0.86,0.48}, Main_Color_1={0.82,0.54,0.13},
 Main_Color_2={0.46,0.25,0.07}, EdgeColor={1,0.88,0.55},
}
local function patchRendererColors()
 local changed=0
 for _,class in ipairs({'NiagaraSpriteRendererProperties','NiagaraMeshRendererProperties','NiagaraRibbonRendererProperties'}) do
  for _,o in ipairs(FindAllOf(class) or {}) do
   local name=o:GetFullName()
   local k=kind(name)
   local key=tostring(o:GetAddress())
   if k and not rendererColors[key] then
    local snapshot={object=o,name=name,parameters={}}
    local smoke=k=='dodge' and class=='NiagaraSpriteRendererProperties' and valid(o.Material) and o.Material:GetFullName():find('Smoke',1,true)
    o.MaterialParameters.VectorParameters:ForEach(function(i,param)
     local p=param:get();local pname=p.MaterialParameterName:ToString()
     if colorParameters[pname] then
      local v=p.Value;local peak=math.max(v.R,v.G,v.B)
      if peak>0 and ((smoke and pname=='Main_Color_1') or peak-math.min(v.R,v.G,v.B)>peak*0.05) then
       snapshot.parameters[i]={name=pname,R=v.R,G=v.G,B=v.B,A=v.A}
       local hue=smoke and {0.5625,0.35,0.0875} or (k=='dodge' and goldPalette[pname] or {1,0.035,0.012})
       if smoke then v.A=v.A*0.45 end
       -- Keep the hue/alpha; soften the main ring HDR edge and hot core.
       local gain=not smoke and k=='dodge' and pname=='Main_Color_1' and 1.12 or 1
       if k=='dodge' and not smoke then
        if pname=='EdgeColor' then gain=0.4
        elseif pname=='Main_Color_0' then gain=0.6 end
       end
       v.R=peak*hue[1]*gain;v.G=peak*hue[2]*gain;v.B=peak*hue[3]*gain
       changed=changed+1
      end
     end
    end)
    -- The main warning quad has an additional particle-red multiplier.
    -- Its dissolve/texture shader still supplies the shape and fade.
    if k=='dodge' and class=='NiagaraMeshRendererProperties' then
     local main=false
     for _,old in pairs(snapshot.parameters) do if old.name=='EdgeColor' then main=true end end
     if main then
      local b=o.ColorBinding
      snapshot.binding={root=b.RootName:ToString(),param=b.ParamMapVariable.Name:ToString(),dataset=b.DataSetName:ToString(),exists=b.bBindingExistsOnSource}
      b.RootName=FName('PBZWarningGoldCore')
      b.ParamMapVariable.Name=FName('Particles.PBZWarningGoldCore')
      b.DataSetName=FName('PBZWarningGoldCore')
      b.bBindingExistsOnSource=false
     end
    end
    rendererColors[key]=snapshot
   end
  end
 end
 if changed>0 then print('[YanyunGuard] Warning layered renderer colours: parameters='..changed..'\n') end
end
local function restoreBinding(o,old)
 local b=o.ColorBinding
 b.RootName=FName(old.root);b.ParamMapVariable.Name=FName(old.param);b.DataSetName=FName(old.dataset);b.bBindingExistsOnSource=old.exists
end
local function patchDodgeLayers()
 local count=0
 for _,o in ipairs(FindAllOf('NiagaraSpriteRendererProperties') or {}) do
  local name=o:GetFullName();local key=tostring(o:GetAddress())
  if kind(name)=='dodge' and not gpuGlows[key] then
   if valid(o.Material) then
    local parent=o.Material
    local smoke=parent:GetFullName():find('Smoke',1,true)~=nil
    local b=o.ColorBinding
    local snapshot={object=o,name=name,material=parent}
    gpuGlows[key]=snapshot
    local pc=require('UEHelpers').GetPlayerController()
    local lib=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
    local mid=lib:CreateDynamicMaterialInstance(pc,parent,FName('None'),0)
    assert(valid(mid),'Cannot create gold warning material')
    snapshot.mid=mid
    snapshot.binding={root=b.RootName:ToString(),param=b.ParamMapVariable.Name:ToString(),dataset=b.DataSetName:ToString(),exists=b.bBindingExistsOnSource}
    b.RootName=FName('PBZWarningGoldGlow');b.ParamMapVariable.Name=FName('Particles.PBZWarningGoldGlow');b.DataSetName=FName('PBZWarningGoldGlow');b.bBindingExistsOnSource=false
    if smoke then
     local col=parent:K2_GetVectorParameterValue(FName('Main_Color_1'))
     mid:SetVectorParameterValue(FName('Main_Color_1'),{R=0.45,G=0.28,B=0.07,A=col.A*0.45})
    else
     local spark=name:find('Star',1,true)~=nil
     local core=snapshot.binding.dataset=='PP_GlowCol'
     if not spark then
      -- Tighten the existing glow texture, with warm highlights and brass shadows.
      local power=1
      pcall(function() local v=parent:K2_GetScalarParameterValue(FName('Tex_Color_Pow'));if v>0 then power=v end end)
      mid:SetScalarParameterValue(FName('Tex_Color_Pow'),math.max(0.7,math.min(3,power*1.2)))
     end
     for _,parameter in ipairs({'Main_Color_1','Main_Color_2','Color'}) do
      local a=1
      pcall(function() local v=parent:K2_GetVectorParameterValue(FName(parameter));if v.A>0 then a=v.A end end)
      local primary=parameter~='Main_Color_2'
      local r,g,blue=1.8,1.3,0.22
      if core then r,g,blue=2,1.75,0.95 elseif spark then r,g,blue=1.4,0.82,0.035 end
      if not spark then r,g,blue=r*0.65,g*0.65,blue*0.65 end
      if not primary then r,g,blue=r*0.2,g*0.14,blue*0.22 end
      mid:SetVectorParameterValue(FName(parameter),{R=r,G=g,B=blue,A=a*0.75})
     end
    end
    o.Material=mid;count=count+1
   end
  end
 end
 if count>0 then print('[YanyunGuard] Gold warning sprite layers='..count..' (native textures, softened smoke)\n') end
end
local function patchText()
 for _,o in ipairs(FindAllOf('PBZCommonLocRichText') or {}) do
  if not o:GetFullName():find('Default__',1,true) then
   local original=o:GetText()
   local raw=original:ToString()
   if raw:find('完美格挡',1,true) and raw:find('完美闪避',1,true)
    and raw:find('<Tutorial_Body_Blue>蓝光技能</>',1,true)
    and raw:find('<Tutorial_Body_Red>红光技能</>',1,true) then
    -- Replace complete spans in one pass; never reswap a replacement.
    local edited=raw:gsub('<Tutorial_Body_(%a+)>(.-)</>',function(style,word)
     if style=='Blue' and word=='蓝光技能' then return '<Tutorial_Body_Red>红光技能</>' end
     if style=='Red' and word=='红光技能' then return '<Tutorial_Body_Yellow>黄光技能</>' end
     return '<Tutorial_Body_'..style..'>'..word..'</>'
    end)
    local key=tostring(o:GetAddress())
    texts[key]={object=o,name=o:GetFullName(),original=original,edited=edited}
    o:SetText(FText(edited))
    print('[YanyunGuard] Warning tutorial text: deflect=red dodge=yellow\n')
   end
  end
 end
end
function M.clear()
 local pendingGPU={}
 for key,s in pairs(gpuGlows) do
  if valid(s.object) and s.object:GetFullName()==s.name then
   local ok=pcall(function()
    if s.binding then restoreBinding(s.object,s.binding) end
    if valid(s.mid) and s.object.Material:GetAddress()==s.mid:GetAddress() then s.object.Material=s.material end
   end)
   if not ok then pendingGPU[key]=s end
  end
 end
 gpuGlows=pendingGPU
 local pendingRenderers={}
 for key,s in pairs(rendererColors) do
  if valid(s.object) and s.object:GetFullName()==s.name then
   local ok=pcall(function()
    if s.binding then
     local b=s.object.ColorBinding;local old=s.binding
     b.RootName=FName(old.root);b.ParamMapVariable.Name=FName(old.param);b.DataSetName=FName(old.dataset);b.bBindingExistsOnSource=old.exists
    end
    s.object.MaterialParameters.VectorParameters:ForEach(function(i,param)
     local old=s.parameters[i];local p=param:get()
     if old and p.MaterialParameterName:ToString()==old.name then
      p.Value.R=old.R;p.Value.G=old.G;p.Value.B=old.B;p.Value.A=old.A
     end
    end)
   end)
   if not ok then pendingRenderers[key]=s end
  end
 end
 rendererColors=pendingRenderers
 local pending={}
 for key,s in pairs(saved) do
  if valid(s.object) and s.object:GetFullName()==s.name then
   local ok=pcall(function() write(s.object.ShaderLUT,s.original) end)
   if not ok then pending[key]=s end
  end
 end
 local pendingTexts={}
 for key,s in pairs(texts) do
  if valid(s.object) and s.object:GetFullName()==s.name then
   local ok=pcall(function()
    if s.object:GetText():ToString()==s.edited then s.object:SetText(s.original) end
   end)
   if not ok then pendingTexts[key]=s end
  end
 end
 texts=pendingTexts
 saved=pending;last=-10;failed=false
end
function M.tick(c,now)
 if not c.WarningColorsEnabled then if next(saved) or next(texts) or next(rendererColors) or next(gpuGlows) then M.clear() end;return end
 if failed or (now>=last and now-last<1) then return end
 last=now
 local ok,err=pcall(function()
  for key,snapshot in pairs(saved) do
   if not valid(snapshot.object) or snapshot.object:GetFullName()~=snapshot.name then saved[key]=nil end
  end
  for key,snapshot in pairs(texts) do
   if not valid(snapshot.object) or snapshot.object:GetFullName()~=snapshot.name then texts[key]=nil end
  end
  for key,snapshot in pairs(rendererColors) do
   if not valid(snapshot.object) or snapshot.object:GetFullName()~=snapshot.name then rendererColors[key]=nil end
  end
  for key,snapshot in pairs(gpuGlows) do
   if not valid(snapshot.object) or snapshot.object:GetFullName()~=snapshot.name then gpuGlows[key]=nil end
  end
  patchText()
  patchRendererColors()
  patchDodgeLayers()
  local count=0
  for _,o in ipairs(FindAllOf('NiagaraDataInterfaceColorCurve') or {}) do
   local name=o:GetFullName()
   local k=kind(name)
   local key=tostring(o:GetAddress())
   if k and not saved[key] and o.bUseLUT then
    local original=values(o.ShaderLUT)
    if #original>0 and #original%4==0 then
     local edited={}
     for i,v in ipairs(original) do edited[i]=v end
     local changed=false
     for i=1,#original,4 do
      local r,g,b=original[i],original[i+1],original[i+2]
      local peak=math.max(r,g,b)
      -- Preserve white flashes, intensity envelopes and alpha exactly.
      if peak>0 and peak-math.min(r,g,b)>peak*0.05 then
       edited[i]=peak
       edited[i+1]=peak*(k=='dodge' and 0.78 or 0.025)
       edited[i+2]=peak*(k=='dodge' and 0.025 or 0.01)
       changed=true
      end
     end
     if changed then
      saved[key]={object=o,name=name,original=original}
      write(o.ShaderLUT,edited);count=count+1
     end
    end
   end
  end
  if count>0 then print('[YanyunGuard] Warning colours: dodge=yellow deflect=red; curves='..count..'\n') end
 end)
 if not ok then
  M.clear();failed=true
  print('[YanyunGuard] Warning colours restored after error: '..tostring(err)..'\n')
 end
end
return M
