# Retained-release preservation (recursive SHA-256 of every regular file under $local_root/releases except .DS_Store; symlinks are not followed)
before build: 706269 files, manifest sha256 d6352ac5f40070f6bdbafa4ce59d0fa9dc8ce77bea8865cc76a2db2fb69fc491
after build (excluding the new v0.3.1.2/): 706269 files, manifest sha256 d6352ac5f40070f6bdbafa4ce59d0fa9dc8ce77bea8865cc76a2db2fb69fc491
diff before/after: 0 bytes (0 = byte-identical)

per-package file counts and per-package manifest sha256 (before / after):
  .gdignore: 1 files, c04a2f634421604dee3a2edfe2a8a101e3187a690679bdcdac945680b61ab5a5 / c04a2f634421604dee3a2edfe2a8a101e3187a690679bdcdac945680b61ab5a5
  archive/v0.3.1-attempt1-448a0cc1: 114341 files, 74f48f8746f8b8d3972dbb4c5ad60b1d9c30316d93f26578537581085d37e80d / 74f48f8746f8b8d3972dbb4c5ad60b1d9c30316d93f26578537581085d37e80d
  archive/v0.3.1-attempt2-165f14aa: 115269 files, 7da5ed5a5fde2c790cb165514691e5a6abd4670b773916e99baacfb101552783 / 7da5ed5a5fde2c790cb165514691e5a6abd4670b773916e99baacfb101552783
  v0.3.0: 43165 files, e2f2b7e3e8cf3d80d53a52e0dd14d4ebb91d81623cb7e2b1bec07c5ffef43b7e / e2f2b7e3e8cf3d80d53a52e0dd14d4ebb91d81623cb7e2b1bec07c5ffef43b7e
  v0.3.0-godot-registration-20260908T0537Z: 3 files, 00c17611ff1437ebccd3d4eae8ee6a55129218c10cbbe4b609617de2986dc169 / 00c17611ff1437ebccd3d4eae8ee6a55129218c10cbbe4b609617de2986dc169
  v0.3.0-rejected-7f35f010: 43154 files, 202f38b66744a564991db82be9523c5b947b8e2233806eadfd72a853432080e8 / 202f38b66744a564991db82be9523c5b947b8e2233806eadfd72a853432080e8
  v0.3.0-snapshot-quarantine-20260907T0358Z: 2 files, a799c5c059913fe428f47e4e7d501d2cdb93142f5861353d3d908375086b8261 / a799c5c059913fe428f47e4e7d501d2cdb93142f5861353d3d908375086b8261
  v0.3.1: 160112 files, 3a71d0b66ebc6e6ec7b8390224458ca1b849700dd3722c9da3870777430191bc / 3a71d0b66ebc6e6ec7b8390224458ca1b849700dd3722c9da3870777430191bc
  v0.3.1.1: 115769 files, 8ffbc8d80b36c4971cf2aa04f0e1c867a961f68d64965f6f909d6b5882c36aa2 / 8ffbc8d80b36c4971cf2aa04f0e1c867a961f68d64965f6f909d6b5882c36aa2
  v0.3.2: 114453 files, 5f290ece9735d7f13c2ff03b7ce15042d24348e6130a024913782868e44a7274 / 5f290ece9735d7f13c2ff03b7ce15042d24348e6130a024913782868e44a7274

current-project pointer: before build -> v0.3.1.1/godot-project; after build -> v0.3.1.2/godot-project (the only intended change under releases/ besides the new v0.3.1.2/ directory; .gdignore touched with unchanged empty content)
