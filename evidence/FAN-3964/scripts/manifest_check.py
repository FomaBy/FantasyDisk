import json, re, hashlib, os, datetime
W=os.path.dirname(os.path.abspath(__file__)); P=os.path.join(W,'pkg')
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda: f.read(1<<20), b''): h.update(b)
    return h.hexdigest()
print('## update-manifest consistency', datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))
m=json.load(open(os.path.join(P,'update-manifest.json'),encoding='utf-8'))
ok=True
def chk(name,cond,detail=''):
    global ok; ok&=bool(cond); print(f"  [{'PASS' if cond else 'FAIL'}] {name} {detail}")
ver=re.compile(r'^\d+\.\d+\.\d+(\.\d+)?$')
chk('schema_version==1', m.get('schema_version')==1, str(m.get('schema_version')))
chk('version format', ver.match(str(m.get('version',''))), m.get('version'))
chk('version==0.3.1 (project.godot config/version at tag)', m.get('version')=='0.3.1')
chk('minimum_supported_version format', ver.match(str(m.get('minimum_supported_version',''))), m.get('minimum_supported_version'))
def parts(v): return [int(x) for x in v.split('.')]
chk('minimum_supported<=version', parts(m['minimum_supported_version'])<=parts(m['version']))
chk('release_url', m.get('release_url')==f"https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v{m['version']}", m.get('release_url'))
w=m['assets']['windows']; mac=m['assets']['macos']
chk('windows.name', w['name']==f"FantasyDisk-{m['version']}-windows-setup.exe", w['name'])
chk('windows.url trusted download path', w['url']==f"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v{m['version']}/{w['name']}", w['url'])
setup=os.path.join(P,'FantasyDisk-0.3.1-windows-setup.exe'); S=os.path.getsize(setup); D=sha(setup)
chk('windows.size == reassembled installer bytes', w['size']==S, f"{w['size']} vs {S}")
chk('windows.sha256 == reassembled installer sha256', w['sha256'].lower()==D, f"{w['sha256']} vs {D}")
chk('windows.size <= 1 GiB download limit', w['size']<=1024**3)
sums={}
for line in open(os.path.join(P,'SHA256SUMS.txt'),encoding='utf-8'):
    line=line.strip()
    if line: d,n=line.split(None,1); sums[n.strip()]=d.lower()
chk('SHA256SUMS windows entry == manifest', sums.get(w['name'])==w['sha256'].lower(), sums.get(w['name']))
chk('SHA256SUMS macos entry == manifest', sums.get(mac['name'])==mac['sha256'].lower(), sums.get(mac['name']))
chk('macos.name', mac['name']==f"FantasyDisk-{m['version']}-macos.dmg", mac['name'])
chk('macos.url trusted', mac['url']==f"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v{m['version']}/{mac['name']}")
print('  note: the macOS DMG bytes are not on this host; only name/URL/hash-list agreement is checked here.')
print('  note: the installed client checks .../releases/latest/download/update-manifest.json on startup; v0.3.1 is unpublished, so the live check cannot see this manifest yet.')
print('RESULT', 'PASS' if ok else 'FAIL')
