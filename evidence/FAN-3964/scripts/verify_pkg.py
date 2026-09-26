import hashlib, os, sys, datetime
def now(): return datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda: f.read(1<<20), b''): h.update(b)
    return h.hexdigest()
print(now(),'verify parts start')
exp={}
for line in open('PARTS.sha256',encoding='utf-8'):
    line=line.strip()
    if line: d,n=line.split(None,1); exp[n.strip()]=d
ok=True
parts=sorted(exp)
for n in parts:
    s=os.path.getsize(n); d=sha(n); m=(d==exp[n])
    ok&=m
    print(f'{n} bytes={s} sha256={d} match={m}')
print(now(),'parts_all_match',ok)
if not ok: sys.exit(2)
out='FantasyDisk-0.3.1-windows-setup.exe'
with open(out,'wb') as o:
    for n in parts:
        with open(n,'rb') as f:
            while True:
                b=f.read(1<<22)
                if not b: break
                o.write(b)
print(now(),'concatenated order', parts)
S=os.path.getsize(out); D=sha(out)
print(f'{out} bytes={S} sha256={D}')
print('whole_match', S==535974634 and D=='375c5290040ac349a1e75cd2e09e3ddd520216b3ddeadfab758d413fb12dafed')
for n,e in [('SHA256SUMS.txt','a1cc64e84dad49e7f4267e98167326cd0ece5a8c230d60673e11e0427c0f5206'),('update-manifest.json','a81d1149044c9ce8371f4260d8449829df52de5358cfb66378174a924fc1e1f6')]:
    d=sha(n); print(f'{n} bytes={os.path.getsize(n)} sha256={d} match={d==e}')
print(now(),'verify end')
