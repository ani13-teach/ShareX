import pathlib, shutil, json, hashlib, zipfile
w=pathlib.Path(__file__).parent
p=w/'package'; data=p/'data'
root=pathlib.Path('C:/Users/WJZN/ShareX-21.0.0-portable-x64')
if not (root/'ShareX.exe').exists(): root=pathlib.Path('C:/Users/WJZN/Downloads/ShareX-21.0.0-portable-x64')
exec(compile((w/'make_map.py').read_text(encoding='utf-8'),str(w/'make_map.py'),'exec'),{'__file__':str(w/'make_map.py')})
shutil.copy2(w/'patch-entries.json',data/'patch-entries.json')
shutil.copy2('C:/Users/WJZN/.nuget/packages/mono.cecil/0.11.6/lib/net40/Mono.Cecil.dll',data/'Mono.Cecil.dll')
old=p/'汉化.ps1'
if old.exists():old.rename(p/'Patch.ps1')
for f in [p/'Patch.ps1',data/'PatchEngine.cs']:
    s=f.read_text(encoding='utf-8-sig');f.write_text(s,encoding='utf-8-sig')
for name,action in [('安装汉化.cmd','Install'),('恢复原版.cmd','Restore')]:
    (p/name).write_bytes(('@echo off\r\npowershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action '+action+' %*\r\nexit /b %errorlevel%\r\n').encode('ascii'))
h=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
original_editor=root/'ShareX.ImageEditor.dll'
if (root/'.sharex-zh-backup/ShareX.ImageEditor.dll').exists(): original_editor=root/'.sharex-zh-backup/ShareX.ImageEditor.dll'
m={'Version':'21.0.0','MainHash':h(root/'ShareX.dll'),'EditorHash':h(original_editor),'CecilHash':h(data/'Mono.Cecil.dll'),'EngineHash':h(data/'PatchEngine.cs'),'EntriesHash':h(data/'patch-entries.json'),'EntryCount':len(json.loads((data/'patch-entries.json').read_text(encoding='utf-8'))),'Resources':[{'Name':f.name,'Hash':h(f)} for f in sorted((root/'Languages/zh-CN').glob('*.dll'))]}
(data/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
sandbox=w/'test-app'
if not sandbox.exists():
    shutil.copytree(root,sandbox,ignore=shutil.ignore_patterns('ShareX','.sharex-zh-backup'))
    (sandbox/'ShareX').mkdir(exist_ok=True)
    (sandbox/'ShareX/ApplicationConfig.json').write_text(json.dumps({'Language':'English','ShowAfterCaptureWindow':False,'TestMarker':'preserved'},indent=2),encoding='utf-8')
print('Package entries',m['EntryCount'],'sandbox ready',sandbox)
