import argparse, subprocess, json, pathlib
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
 best=(0,0,0);gold=0
 for y in range(90,250):
  run=0;start=0
  for x in range(160,550):
   i=(y*w+x)*3;r,g,b=data[i:i+3];mx=max(r,g,b);mn=min(r,g,b)
   above=data[i-6*w*3:i-6*w*3+3];below=data[i+6*w*3:i+6*w*3+3]
   contrast=(r+g+b)/3-(sum(above)+sum(below))/6
   hit=mn>=140 and mx-mn<mx*.22 and contrast>25
   if hit:
    if not run:start=x
    run+=1
    if run>best[0]:best=(run,start,y)
   else:run=0
   if r>100 and .35*r<g<.9*r and b<.45*r and contrast>20:gold+=1
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
