import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

TAB = '1498889840'
PRIVATE = Path('private-proofs')
JS = "JSON.stringify({url:location.href,state:document.readyState,text:document.body.innerText,radios:Array.from(document.querySelectorAll('input[type=radio]')).map(x=>({value:x.value,checked:x.checked})),links:Array.from(document.querySelectorAll('a[href]')).filter(a=>a.innerText.trim()==='Configure').map(a=>({text:a.innerText.trim(),href:a.href}))})"

def browser(url):
    script = '''on run argv
tell application "Google Chrome"
 repeat with w in windows
  repeat with t in tabs of w
   if (id of t as text) is item 1 of argv then
    if item 2 of argv is not "" then set URL of t to item 2 of argv
    return execute t javascript (item 3 of argv)
   end if
  end repeat
 end repeat
end tell
error "Task browser tab unavailable"
end run'''
    subprocess.check_output(['osascript','-e',script,TAB,url,JS], text=True)
    for _ in range(80):
        time.sleep(.25)
        raw = subprocess.check_output(['osascript','-e',script,TAB,'',JS], text=True)
        data = json.loads(raw)
        if any(s in data['text'] for s in ['Confirm access','Enter the verification code','Sign in to GitHub']):
            raise RuntimeError('GitHub requires reauthentication; stop without entering credentials')
        if data['url'] == url and data['state'] == 'complete' and 'Footer' in data['text']:
            if 'SF (FomaBy)' not in data['text']:
                raise RuntimeError('Cannot prove signed-in FomaBy account')
            return data
    raise RuntimeError('Complete live page unreadable')

stage=sys.argv[1]
captures=[]
def capture(url,name):
    data=browser(url)
    raw=json.dumps(data,ensure_ascii=False,indent=2).encode()
    (PRIVATE/f'{stage}-{name}.json').write_bytes(raw)
    captures.append({'page':name,'observed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sha256':hashlib.sha256(raw).hexdigest()})
    return data

index=capture('https://github.com/settings/installations','installed-apps')
assert 'Installed GitHub Apps' in index['text']
assert not re.search(r'\bNext\b|\bPrevious\b',index['text']), 'Unproved pagination'
urls=[x['href'] for x in index['links']]
assert len(urls)==len(set(urls)) and len(urls)<100
installations=[]
summary=[]
mapping={'checks':'checks','commit statuses':'statuses','metadata':'metadata','actions':'actions','code':'contents','issues':'issues','pull requests':'pull_requests','workflows':'workflows','administration':'administration'}
for url in urls:
    installation_id=int(url.rsplit('/',1)[1])
    data=capture(url,str(installation_id))
    text=data['text']
    name=text.split('Developer settings\n',1)[1].split('\n Installed',1)[0].strip()
    slug={'ChatGPT Codex Connector':'chatgpt-codex-connector','Multica AI':'multica-ai'}[name]
    section=text.split('Permissions\n',1)[1].split('Repository access',1)[0]
    permissions={}
    for line in section.strip().splitlines():
        line=line.strip()
        match=re.fullmatch(r'(Read|Read and write) access to (.*)',line)
        assert match, 'Unreadable permission line'
        level='read' if match[1]=='Read' else 'write'
        for permission in re.split(r',\s*(?:and\s+)?|\s+and\s+',match[2]):
            permissions[mapping[permission]]=level
    checked=[x['value'] for x in data['radios'] if x['checked']]
    assert len(checked)==1 and checked[0] in ['all','selected']
    selection=checked[0]
    repositories=None
    covers=True
    if selection=='selected':
        match=re.search(r'Selected (\d+) repositories\.\n(.*?)\nSave',text,re.S)
        assert match
        names=match[2].strip().splitlines()
        assert len(names)==int(match[1]) and len(names)==len(set(names))
        assert all(re.fullmatch(r'FomaBy/[^\s/]+',n) for n in names)
        repositories={'total_count':len(names),'repositories':[{'full_name':n} for n in names]}
        covers='FomaBy/FantasyDisk-Releases' in names
    assert not(covers and any(v=='write' for v in permissions.values())), 'Foreign App writer covers release repository'
    installations.append({'id':installation_id,'app_slug':slug,'permissions':permissions,'repository_selection':selection,'repositories':repositories})
    summary.append({'name':name,'id':installation_id,'permissions':permissions,'repository_selection':selection,'covers_release_repository':covers,'selected_repository_count':None if repositories is None else repositories['total_count']})
observed=datetime.datetime.now(datetime.timezone.utc).isoformat()
proof={'schema_version':1,'source':'github-account-applications-settings','account':'FomaBy','repository':'FomaBy/FantasyDisk-Releases','complete':True,'observed_at':observed,'installations':installations}
(PRIVATE/f'{stage}-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
sanitized={'stage':stage,'observed_at':observed,'method':'Agent live Chrome DOM reads through AppleScript under owner delegation; owner personal observation not claimed','captures':captures,'apps':summary}
Path(f'saved-evidence/{stage}-inventory-summary.json').write_text(json.dumps(sanitized,indent=2)+'\n')
print(json.dumps(sanitized,indent=2))
