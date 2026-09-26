import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
#!/usr/bin/env python3
"""List resource paths in a Godot 4 PCK, including one embedded in a Windows exe.
Reads only the pack directory, never file data. Derived from evidence/FAN-3966/list_pck_paths.py."""
import struct, sys, os, hashlib
def find_pck_start(f):
    f.seek(0); magic=f.read(4)
    if magic==b"GDPC": return 0
    size=os.path.getsize(f.name)
    f.seek(size-12); pck_size,=struct.unpack("<Q",f.read(8)); tail=f.read(4)
    if tail!=b"GDPC": raise SystemExit("no embedded pck trailer")
    start=size-12-pck_size
    f.seek(start)
    if f.read(4)!=b"GDPC": raise SystemExit(f"embedded pck magic not found at {start}")
    return start
def read_paths(path):
    with open(path,"rb") as f:
        base=find_pck_start(f); f.seek(base+4)
        version,major,minor,patch=struct.unpack("<4I",f.read(16))
        flags,file_base=struct.unpack("<IQ",f.read(12))
        if flags&1: raise SystemExit("encrypted directory")
        if version>=3:
            dir_offset,=struct.unpack("<Q",f.read(8)); f.seek(base+dir_offset)
        else: f.read(64)
        count,=struct.unpack("<I",f.read(4)); paths=[]
        for _ in range(count):
            ln,=struct.unpack("<I",f.read(4)); raw=f.read(ln); f.read(8+8+16+4)
            paths.append(raw.rstrip(b"\0").decode("utf-8","replace"))
        return base,(version,major,minor,patch),paths
def main(a):
    base,(v,ma,mi,pa),paths=read_paths(a[1])
    prefix=a[2] if len(a)>2 else ""
    m=[p for p in paths if p.startswith(prefix)] if prefix else paths
    for p in m: print(p.encode("utf-8","replace").decode("utf-8"))
    print(f"# pck_offset {base}; pack_format {v}; engine {ma}.{mi}.{pa}; packed files {len(paths)}; matching '{prefix}': {len(m)}")
if __name__=="__main__": main(sys.argv)
