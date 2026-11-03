from pathlib import Path
import struct
root=Path(__file__).resolve().parent
relative=Path('ProjectPBZ/Content/Localization/Game/zh-Hans/Game.locres')
b=(root/'text-original'/relative).read_bytes()
assert b[16]==3
pos=struct.unpack_from('<q',b,17)[0];start=pos
count=struct.unpack_from('<i',b,pos)[0];pos+=4
out=bytearray(b[:pos]);changed=0
for i in range(count):
 begin=pos;length=struct.unpack_from('<i',b,pos)[0];pos+=4
 width=2 if length<0 else 1;size=abs(length)*width
 s=b[pos:pos+size-width].decode('utf-16-le' if width==2 else 'utf-8');pos+=size
 refs=b[pos:pos+4];pos+=4
 if all(x in s for x in ['完美格挡','完美闪避','<Tutorial_Body_Blue>蓝光技能</>','<Tutorial_Body_Red>红光技能</>']):
  s=s.replace('<Tutorial_Body_Red>红光技能</>','<Tutorial_Body_Yellow>黄光技能</>').replace('<Tutorial_Body_Blue>蓝光技能</>','<Tutorial_Body_Red>红光技能</>')
  encoded=s.encode('utf-16-le')+b'\0\0';out+=struct.pack('<i',-len(encoded)//2)+encoded+refs;changed+=1
 else:out+=b[begin:pos]
assert pos==len(b) and changed==1,(pos,len(b),changed)
assert out[:start]==b[:start],'namespace/key/hash metadata must remain identical'
target=root/'text-patched'/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(out)
print('PASS: one tutorial text updated; all other localization entries unchanged')
