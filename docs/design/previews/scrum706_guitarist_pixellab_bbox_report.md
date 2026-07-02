# SCRUM-706 Guitarist PixelLab BBox Report

- Production PixelLab source: `704fd67b-da81-4804-acd2-07e75fefd9de` (`FantasyDisk SCRUM-706 Sonic Bard empty palms 240`)
- Runtime policy: per-frame alpha crop -> 245px visible height, centered X, bottom padding 112px on 512x512 transparent canvas.
- Primary south idle runtime bbox: `{'x0': 150, 'y0': 155, 'x1': 361, 'y1': 400, 'width': 211, 'height': 245}`
- Runtime visible height range: `245..245 px`
- Runtime visible width range: `87..224 px`
- Height strict pass 240..250: `True`
- Height broad pass 230..260: `True`
- Primary width target 240..250: `False` (source is intentionally open-palmed; silhouette width may be narrower/wider than height depending on direction).
- Rejected sources: `f41e1d57-f720-4ae1-a739-8873d935163b` (failed/listed 128x128), `d278e753-9885-4550-82ff-81ee3bef297d` (baked held instrument).
