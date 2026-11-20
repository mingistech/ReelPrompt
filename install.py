#!/usr/bin/env python3
"""Build ReelPrompt locally for this Mac. Requires Python 3.12 and Apple developer tools."""
import argparse,json,os,pathlib,plistlib,shutil,subprocess,sys,tempfile,venv

def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,default=pathlib.Path.home()/'Library/Application Support/ReelPrompt');p.add_argument('--app-dir',type=pathlib.Path,default=pathlib.Path.home()/'Applications');p.add_argument('--skip-dependencies',action='store_true',help=argparse.SUPPRESS);a=p.parse_args()
 if sys.version_info[:2] != (3,12): raise SystemExit('Run this installer with Python 3.12.')
 if os.uname().machine != 'arm64': raise SystemExit('ReelPrompt requires an Apple Silicon Mac.')
 src=pathlib.Path(__file__).resolve().parent;root=a.root.expanduser().resolve();app=a.app_dir.expanduser().resolve()/'ReelPrompt.app';resources=app/'Contents/Resources';binary=app/'Contents/MacOS';root.mkdir(parents=True,exist_ok=True);resources.mkdir(parents=True,exist_ok=True);binary.mkdir(parents=True,exist_ok=True)
 runtime=root/'venv'
 if not (runtime/'bin/python').exists(): venv.create(runtime,with_pip=True)
 python=runtime/'bin/python'
 if not a.skip_dependencies: subprocess.run([str(python),'-m','pip','install','-r',str(src/'requirements-lock.txt')],check=True)
 shutil.copy2(src/'Sources/analyze.py',root/'analyze.py')
 with tempfile.TemporaryDirectory(prefix='reelprompt-icon-') as tmp:
  t=pathlib.Path(tmp);png=t/'clapper.png';iconset=t/'Clapper.iconset';iconset.mkdir()
  subprocess.run(['xcrun','swift',str(src/'Resources/make-icon.swift'),str(png)],check=True)
  for size in (16,32,128,256,512):
   for scale in (1,2):
    name=f'icon_{size}x{size}'+('@2x' if scale==2 else '')+'.png'
    subprocess.run(['sips','-z',str(size*scale),str(size*scale),str(png),'--out',str(iconset/name)],check=True,stdout=subprocess.DEVNULL)
  subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(resources/'Clapper.icns')],check=True)
 subprocess.run(['xcrun','swiftc',str(src/'Sources/ReelPrompt.swift'),'-o',str(binary/'VideoPromptLocal'),'-framework','Cocoa'],check=True)
 config={'python':str(python),'script':str(root/'analyze.py'),'model':str(root/'Models/Huihui-Qwen3-VL-32B-Instruct-abliterated-4bit-mlx'),'output':str(root/'Results')}
 (resources/'config.json').write_text(json.dumps(config,indent=2));(root/'Models').mkdir(exist_ok=True)
 info={'CFBundleExecutable':'VideoPromptLocal','CFBundleIdentifier':'com.mingistech.reelprompt','CFBundleName':'ReelPrompt','CFBundleDisplayName':'ReelPrompt','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','CFBundlePackageType':'APPL','CFBundleIconFile':'Clapper','NSHighResolutionCapable':True,'LSMinimumSystemVersion':'14.0','NSPrincipalClass':'NSApplication'}
 (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info));subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
 print(f'Built {app}. Open Settings and choose Download Model (about 19.6 GB). This local build is not notarized.')
if __name__=='__main__': main()
