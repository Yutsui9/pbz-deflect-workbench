"""Read only source containers; stage selected encrypted blocks in a sparse UCAS.
retoc 0.1.5 seeks absolute offsets in one file and cannot read this game's 66 partitions.
The staged file preserves original offsets without copying 140 GB of unrelated assets.
"""
from pathlib import Path
import struct,sys,json,ctypes,msvcrt,shutil,re
ROOT=Path(__file__).resolve().parent
GAME=next((p for p in ROOT.parents if (p/'platform/steam/PBZ.exe').is_file()),None)
if GAME is None: raise RuntimeError('Place this source below the PBZ game root before extracting resources')
sys.path.insert(0,str(ROOT/'tools/python-deps'))
from Crypto.Cipher import AES
source=GAME/'ProjectPBZ/Content/Paks'
data=(source/'ProjectPBZ-Windows.utoc').read_bytes()
u32=lambda o:struct.unpack_from('<I',data,o)[0]
count=u32(24);bs=u32(44);partsize=struct.unpack_from('<Q',data,88)[0]
blockpos=u32(20)+count*22+(u32(84)+u32(96))*4
pos=blockpos+u32(28)*u32(32)+u32(36)*u32(40)
assert not data[80]&4,'signed containers need signature table handling'
key=bytes.fromhex((ROOT/'tools/local-aes.txt').read_text().strip())
buf=AES.new(key,AES.MODE_ECB).decrypt(data[pos:pos+u32(48)])
pos=0
def integer():
 global pos
 n=struct.unpack_from('<i',buf,pos)[0];pos+=4;return n
def string():
 global pos
 n=integer()
 if n<0:
  size=-n*2;s=buf[pos:pos+size-2].decode('utf-16-le');pos+=size;return s
 s=buf[pos:pos+n-1].decode('utf-8');pos+=n;return s
mount=string()
def array(fmt,size):
 global pos
 n=integer();out=[struct.unpack_from(fmt,buf,pos+i*size) for i in range(n)];pos+=n*size;return out
dirs=array('<IIII',16);files=array('<III',12);strings=[string() for _ in range(integer())]
paths={}
def walk(i,parent):
 name,child,sibling,file=dirs[i];path=parent+('/'+strings[name] if name!=0xffffffff else '')
 while file!=0xffffffff:
  name,nxt,index=files[file];paths[index]=path+'/'+strings[name];file=nxt
 while child!=0xffffffff:
  walk(child,path);child=dirs[child][2]
walk(0,'')
(ROOT/'asset-index.json').write_text(json.dumps(paths,ensure_ascii=False),encoding='utf-8')
pattern=sys.argv[1] if len(sys.argv)>1 else 'NS_AttackAlert'
selected={i for i,p in paths.items() if re.search(pattern,p)}
selected.update(i for i in range(count) if data[144+i*12+11]==6)

# Resolve transitive package headers; conversion needs imports as well as target bytes.
def package_name(path):
 if '/Content/' not in path: return ''
 left,right=path.rsplit('/Content/',1)
 prefix='Game' if left=='/ProjectPBZ' else left.rsplit('/',1)[-1]
 return '/'+prefix+'/'+right.rsplit('.',1)[0]
byname={package_name(p).lower():i for i,p in paths.items() if p.endswith('.uasset')}
oodle=ctypes.CDLL(str(ROOT/'tools/retoc-verified/oo2core_9_win64.dll'))
dec=oodle.OodleLZ_Decompress
dec.restype=ctypes.c_longlong
dec.argtypes=[ctypes.c_void_p,ctypes.c_longlong,ctypes.c_void_p,ctypes.c_longlong]+[ctypes.c_longlong]*10

def readblock(i):
 off=blockpos+i*12
 absolute=int.from_bytes(data[off:off+5],'little');size=int.from_bytes(data[off+5:off+8],'little');rawsize=int.from_bytes(data[off+8:off+11],'little');method=data[off+11]
 part,local=divmod(absolute,partsize)
 name='ProjectPBZ-Windows'+('_s'+str(part) if part else '')+'.ucas'
 with (source/name).open('rb') as f:
  f.seek(local);chunk=f.read((size+15)//16*16)
 chunk=AES.new(key,AES.MODE_ECB).decrypt(chunk)[:size]
 if method==0: return chunk
 out=ctypes.create_string_buffer(rawsize)
 result=dec(chunk,len(chunk),out,rawsize,1,0,0,0,0,0,0,0,0,3)
 assert result==rawsize,(i,result,rawsize)
 return out.raw

def bounds(i):
 off=144+count*12+i*10
 return int.from_bytes(data[off:off+5],'big'),int.from_bytes(data[off+5:off+10],'big')
def header(i):
 start,size=bounds(i);block=readblock(start//bs);offset=start%bs
 first=block[offset:];headsize=struct.unpack_from('<I',first,4)[0]
 assert 52<=headsize<=size,(i,headsize,size)
 for b in range(start//bs+1,(start+headsize+bs-1)//bs): first+=readblock(b)
 return first[:headsize]
def imports(h):
 off=struct.unpack_from('<I',h,48)[0]
 n=struct.unpack_from('<I',h,off)[0]
 if not n:return []
 assert struct.unpack_from('<Q',h,off+8)[0]==0xc1640000
 lengths=struct.unpack_from('>'+str(n)+'H',h,off+16+n*8)
 pos=off+16+n*10;result=[]
 for length in lengths:
  wide=bool(length&0x8000);size=(length&0x7fff)*(2 if wide else 1)
  result.append(h[pos:pos+size].decode('utf-16-le' if wide else 'utf-8'));pos+=size
 nums=struct.unpack_from('<'+str(n)+'i',h,pos)
 return [name+('_'+str(num-1) if num else '') for name,num in zip(result,nums)]
queue=[i for i in selected if i in paths];done=set();headblocks=set()
while queue:
 i=queue.pop()
 if i in done:continue
 done.add(i);assert len(done)<4000,'unexpected dependency expansion'
 h=header(i);start,size=bounds(i)
 headblocks.update(range(start//bs,(start+len(h)+bs-1)//bs))
 for name in imports(h):
  dep=byname.get(name.lower())
  if dep is not None and dep not in done:queue.append(dep)
blocks=set(headblocks)

for i in selected:
 off=144+count*12+i*10
 start=int.from_bytes(data[off:off+5],'big');size=int.from_bytes(data[off+5:off+10],'big')
 blocks.update(range(start//bs,(start+size+bs-1)//bs))
stage=ROOT/'staged';stage.mkdir(exist_ok=True)
shutil.copy2(source/'ProjectPBZ-Windows.utoc',stage)
for ext in ['utoc','ucas']: shutil.copy2(source/('global.'+ext),stage)
target=stage/'ProjectPBZ-Windows.ucas'
with target.open('a+b') as out:
 handle=msvcrt.get_osfhandle(out.fileno());returned=ctypes.c_ulong()
 fn=ctypes.windll.kernel32.DeviceIoControl
 fn.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_void_p,ctypes.c_ulong,ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(ctypes.c_ulong),ctypes.c_void_p]
 assert fn(handle,0x900c4,None,0,None,0,ctypes.byref(returned),None),'FSCTL_SET_SPARSE failed'
# Reopen without append: all writes must honor source offsets.
with target.open('r+b') as out:
 total=0
 for i in sorted(blocks):
  off=blockpos+i*12
  absolute=int.from_bytes(data[off:off+5],'little');size=int.from_bytes(data[off+5:off+8],'little');size=(size+15)//16*16
  part,local=divmod(absolute,partsize)
  name='ProjectPBZ-Windows'+('_s'+str(part) if part else '')+'.ucas'
  with (source/name).open('rb') as src:
   src.seek(local);chunk=src.read(size);assert len(chunk)==size,(name,local,size)
  out.seek(absolute);out.write(chunk);total+=size
print('Staged',len(selected),'chunks,',len(blocks),'blocks,',total,'physical bytes')
for i in sorted(selected):
 if i in paths: print(paths[i])
