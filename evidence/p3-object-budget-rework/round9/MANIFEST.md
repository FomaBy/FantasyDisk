# FAN-3934 round-9 SHA-256 manifest (evidence completion + preservation artifacts)

- source `4d57ff43c68d6984ea606f5935b181111bb9e250` tree `f4befaf0f96c4666dea1e203c5e1a430d71af2a8` at generation time; the published successor adds only this manifest refresh and the control-provenance corrections

## round-9 additions
- FOURTH-FAILURE-REMEDIATION.md `3ccfdc587d9affdf8bf01c0fd28373e2390130f8b757588ac8aa6064db3305ae`
- dev-control-p3.log `fae1493a3ccfacb40f1ebc493a60c39b70fd8257e46d32cb7354b763249b0d81`
- dev-control-verbose.log `23251beef8932187970c8157b8ab52faff2842f3b87142d50361c71636357d45`
- engineer-windowed-header.txt `0f554a1152e943c0c8d8ef50a31f0279ff6a318abbd144a171a279b7e0c347ba`
- engineer-windowed.log `d5b26fbac92ce29826742ed5398a81710574c4122e6d4a79b095366000138008`
- vsync_measure.gd `443d41ff56697bcb0bd75bab385baf7dd667788fec21b2b81b2228c7b3829662`
- vsync_measure.gd.uid `a25d2c2e54cdd549f2dcab0623b1df76231d0378a89bcb1d2e22bf7d191f2df6`

## preservation artifacts
- raw-baseline/extracted/candidate-identity.txt.orig.gz `ecb5314f3fe31d08e75bfd31e4cf5955cc2f167e02ac640ef1b57ae956b14886`
- raw-baseline/extracted/candidate-identity.txt `2eb379ef325d7cbe98f04bf9799ad64603130420cf741a62f893c48738968af7`
- raw-baseline/WHITESPACE-NOTE.md `9aa4cf38d1c1e492b3a5c37ad64dbdbfb35030e5fda229f63d3db6b6a441fe64`
- round8/MANIFEST.md `6bf1101ae069e178b9dcb7456a8fab60bed6df2d9ccec7ac1bf4faad4e62c699`
- ROUND8-PACKAGE.md `1f36983896d94044c1379b51c1619eb04a758dfdb18024e692fd61bfc88b601f`
- ROUND9-EVIDENCE.md `86c66e8986ba4238952f940eb384f15177f57fd4e9fc132dd9f1d547c94d351d`

Original identity bytes (decompressed from candidate-identity.txt.orig.gz):
sha256 0e7be085cdeba0c85f7ab128b5df1719dc86499c07ea0d305c0cacb4a6a84963 — byte-identical to the pre-normalization file.

Provenance: `dev-control-p3.log` is a failed author control (aborted before sampling);
the completed matched leak control is the reviewer's clean-dev reproduction in QA report
`01a09657-2503-7815-9d10-b770df0d7b22`. `dev-control-verbose.log` is the completed
owner-identification control. A manifest need not hash itself.
