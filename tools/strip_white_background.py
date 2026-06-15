#!/usr/bin/env python3
"""Вырезать белый фон у PNG: flood-fill от краёв + замкнутые чисто-белые карманы + de-fringe.
Использование: python3 tools/strip_white_background.py <glob...>  (правит файлы на месте)."""
import sys,glob
from collections import deque
from PIL import Image
EDGE=225; POCKET=246
def nw(p,t): return p[3]>0 and min(p[0],p[1],p[2])>=t
def process(png):
    im=Image.open(png).convert("RGBA"); w,h=im.size; px=im.load()
    vis=[[False]*w for _ in range(h)]; dq=deque()
    for x in range(w):
        for y in (0,h-1):
            if nw(px[x,y],EDGE) and not vis[y][x]: dq.append((x,y)); vis[y][x]=True
    for y in range(h):
        for x in (0,w-1):
            if nw(px[x,y],EDGE) and not vis[y][x]: dq.append((x,y)); vis[y][x]=True
    while dq:
        x,y=dq.popleft(); r,g,b,a=px[x,y]; px[x,y]=(r,g,b,0)
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx,ny=x+dx,y+dy
            if 0<=nx<w and 0<=ny<h and not vis[ny][nx] and nw(px[nx,ny],EDGE): vis[ny][nx]=True; dq.append((nx,ny))
    for y in range(h):
        for x in range(w):
            if nw(px[x,y],POCKET): px[x,y]=(px[x,y][0],px[x,y][1],px[x,y][2],0)
            r,g,b,a=px[x,y]
            if 0<a<255 and min(r,g,b)>=215: px[x,y]=(r,g,b,int(a*0.4))
    im.save(png)
if __name__=="__main__":
    n=0
    for pat in sys.argv[1:]:
        for f in glob.glob(pat):
            if not f.endswith(".import"): process(f); n+=1
    print("обработано:",n)
