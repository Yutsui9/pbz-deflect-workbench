import argparse, subprocess, json, pathlib
import numpy as np
p=argparse.ArgumentParser();p.add_argument('video');p.add_argument('--seconds',type=float,default=5);p.add_argument('--out',required=True);a=p.parse_args()
root=pathlib.Path(__file__).resolve().parent
ff=root.parent/'VideoIntro/.python/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
w,h=640,360
cmd=[str(ff),'-v','error','-sseof',str(-a.seconds),'-i',a.video,'-vf',f'fps=60,scale={w}:{h}','-an','-f','rawvideo','-pix_fmt','rgb24','-']
proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
results=[];frame_no=0;peak=None
while True:
 data=proc.stdout.read(w*h*3)
 if not data:break
 if len(data)!=w*h*3:raise RuntimeError('Incomplete frame')
 arr=np.frombuffer(data,dtype=np.uint8).reshape(h,w,3).astype(np.float32)
 roi=arr[90:250,160:550];mx=roi.max(2);mn=roi.min(2)
 contrast=roi.mean(2)-(arr[84:244,160:550].mean(2)+arr[96:256,160:550].mean(2))/2
 mask=(mn>=140)&((mx-mn)<mx*.22)&(contrast>25)
 run=np.zeros(mask.shape[0],dtype=np.int32);best=(0,0,0)
 for x in range(mask.shape[1]):
  run=(run+1)*mask[:,x];y=int(run.argmax());length=int(run[y])
  if length>best[0]:best=(length,160+x-length+1,90+y)
 r,g,b=roi[:,:,0],roi[:,:,1],roi[:,:,2]
 gold=int(((r>100)&(g>.35*r)&(g<.9*r)&(b<.45*r)&(contrast>20)).sum())

 rec={'frame':frame_no,'seconds_from_segment_start':round(frame_no/60,4),'white_horizontal_run_px':best[0],'line_x':best[1],'line_y':best[2],'gold_contrast_pixels':gold}
 results.append(rec)
 if peak is None or best[0]>peak[0]:peak=(best[0],data,rec)
 frame_no+=1
stderr=proc.stderr.read().decode(errors='replace')
if proc.wait():raise RuntimeError(stderr)
if not results:raise RuntimeError('No frames')
out=pathlib.Path(a.out);out.mkdir(parents=True,exist_ok=True)
report={'video':a.video,'frames':frame_no,'fps':60,'scope':'central ROI; heuristic streak detector, not semantic effect identification','status':'white_streak_candidate' if peak[0]>=12 else 'inconclusive_not_a_pass','peak':peak[2],'candidate_frames':sum(r['white_horizontal_run_px']>=12 for r in results),'measurements':results}
(out/'metrics.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'peak.ppm').write_bytes(f'P6\n{w} {h}\n255\n'.encode()+peak[1])
print(json.dumps({k:v for k,v in report.items() if k!='measurements'},ensure_ascii=False))
