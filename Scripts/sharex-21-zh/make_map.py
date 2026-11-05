import json,pathlib,re,collections
w=pathlib.Path(__file__).parent
translations={}
for fn in ['translations.tsv','effects1.tsv','effects2.tsv','extra.tsv','final.tsv']:
 p=w/fn
 if not p.exists():continue
 for line in p.read_text(encoding='utf-8').splitlines():
  if not line:continue
  a,b=line.split('\t',1);a=a.replace('\\n','\n');b=b.replace('\\n','\n')
  if a in translations and translations[a]!=b:raise ValueError(a)
  translations[a]=b
rows=json.loads((w/'ShareX.ImageEditor.strings.json').read_text(encoding='utf-8'))
# Apply only to display sites, not identifiers, binding paths or serialized values.
def eligible(r):
 t,m,n=r['type'],r['method'],r['next'] or ''
 if t.startswith(('CompiledAvaloniaXaml.','!')) or 'INotifyProperty' in t:return False
 if m=='.cctor' and 'ToolbarCustomizationItemViewModel' not in t:return False
 if r['text']=='Auto' and not any(x in n for x in ['::set_Text(','::set_Header(','::set_DisplayName(','::set_Content(']):return False
 if m.startswith(('set_','On')) and not any(x in n for x in ['::set_Text(','::set_Header(','::SetTip(']):return False
 if any(x in n for x in ['ReflectionBindingExtension','PropertyChangedEventArgs','PropertyChangingEventArgs','::FindControl','::FindName','::set_Name(','::set_Key(','::set_Id(','::op_Equality','::op_Inequality','::Parse(','::set_StrokeColor(']):return False
 if m in ['get_Name','get_Description','get_Parameters','get_ActiveToolName','GetWindowTitle','get_ToggleToolbarsMenuHeader','get_ContinueButtonText','get_Title']:return True
 if any(x in n for x in ['::set_Text(','::set_Header(','::SetTip(','::set_Watermark(','::set_Title(','::set_DisplayName(','::set_StatusText(','::set_NotificationMessage(']):return True
 if '.Presentation.Converters.' in t:return True
 if '.Presentation.ViewModels.' in t and not m.startswith(('get_','set_','On','Normalize','Parse','ToString','PrintMembers','GetHashCode','Equals')):return True
 if '.Presentation.Views.' in t and not m.startswith(('Initialize','MapConfiguredTheme','GetBackground','CreateNamespaces')):return True
 if '.Presentation.Controls.' in t and ('Xaml' in m or 'XamlClosure' in t or m in ['.ctor','UpdateSearchWatermark'] or 'Tooltip' in m):return True
 return False
manifest={};audit=[];untranslated=collections.OrderedDict()
for r in rows:
 if not eligible(r):continue
 s=r['text']
 if s in translations:
  k=f"{r['token']}:{r['offset']}";manifest[k]=translations[s];audit.append({**r,'translation':translations[s]})
 elif re.search('[A-Za-z]',s) and len(s)<500:
  if any(x in s for x in ['://','ShareX.','Command','Property','Avalonia.','#']):continue
  if re.fullmatch('[a-z][a-zA-Z0-9_]*',s) or re.fullmatch('[A-Z][a-z]+(?:[A-Z][a-zA-Z0-9]*)+',s):continue
  if s.startswith(('.',"*.","Failed ","IL_")) or re.fullmatch('[A-Z0-9]{1,3}',s):continue
  untranslated.setdefault(s,[]).append(r)
(w/'patch-map.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
patch_entries=[{'key':k,'source':r['text'],'translation':r['translation']} for k,r in zip(manifest,audit)]
for r in rows:
 if r['type']=='ShareX.ImageEditor.Presentation.ViewModels.MainViewModel' and r['method']=='.cctor' and r['text'] in ['Dark','Light']:
  patch_entries.append({'key':f"{r['token']}:{r['offset']}",'source':r['text'],'translation':{'Dark':'深色','Light':'浅色'}[r['text']]})
(w/'patch-entries.json').write_text(json.dumps(patch_entries,ensure_ascii=False,indent=2),encoding='utf-8')
(w/'patch-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
(w/'remaining.txt').write_text('\n'.join(json.dumps(s,ensure_ascii=False)+' | '+r[0]['type'].split('.')[-1]+'.'+r[0]['method'] for s,r in untranslated.items()),encoding='utf-8')
print('Translation dictionary:',len(translations),'Patch sites:',len(manifest),'Unique applied:',len(set(r['text'] for r in audit)),'Remaining candidates:',len(untranslated))
