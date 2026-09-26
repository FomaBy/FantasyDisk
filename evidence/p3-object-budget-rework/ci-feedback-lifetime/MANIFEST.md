# FAN-3934 ci-feedback-lifetime SHA-256 manifest

- measured source `23ff00a03233192231f49c664531ed2f5ab4bb11` tree `407b2b3797fd9fecf2baeaac198b9eb29b906e49`; probe sha256 `57d817d2effc2627f5d5b115b8094ebdb6bda541e5a3640fab2a9f7f03eaa6f5`

- DIAGNOSIS.md `5f7ebb46abcee77ec3f0c40e0fd1697cadccbac3c0a38b917aa2d72a38fc0863`
- ci-suite-fail-before-fix.log `b9a5412b729bbfa126530623bfafa849181a8d6629688d97a2501c4a0cc53e98`
- driver-header.txt `e0ac0c6665a2e134175ea32627ceda54d58f7e5ecf72f949abe2c48759dae859`
- env-final.txt `76780742735ebd1a482ca432177069dadc011035c4c18c5337664d2938f5cbf6`
- env-matrix-p1.txt `ae9664fd6c03387736ac0d74c44e12c16d836113bee75930f297ba61c7f588f1`
- env-matrix-p2.txt `6e3b3d161a985a8c9a703667164de328cc82d76d303e8cd3973acf5e18f1a6c5`
- env-matrix-p3-run1.txt `0055965df7fe2924d7441e433add91b8366deb5a4b2217a24c0a301be09af16c`
- env-matrix-p3-run2.txt `51212224c0d5c8618e53cde1d2672d1c41cc85632a6b299ac379826fde3d7765`
- env-suite-berserk.txt `0d2a27a977c881a8368659726277c93edb1f371411c079f2f019cddf45c7a539`
- env-suite-feedback.txt `04ac482afaff5557cf8599d71dbae331a7097282b3ddf0622d6f25ea7f743809`
- env-suite-hazard.txt `d2b71690381425be759f44ee4941cd7ba4635c12ce883a753a719374e566f4db`
- env-suite-hazardsmoke.txt `588dfb87f2f3a204e4f51d80f791c722473caa062445fdebf6be9f3bcc4633fc`
- env-suite-residency.txt `f8035917011ab175ff7760bb558e8d285543c2b6a64c81898c880729300ae16b`
- env-suite-summon.txt `29ffc6b93e79283c63fd0086d39bfe4a919a721cf9222df6d52aec3a4bf5ef1c`
- file-hashes.txt `35c6f7862f26a2774a4c0df726be6e8cbadce663a29dfd1dec70ed788d5067e9`
- log-matrix-p1.txt `8f2e7874f60e0deea28e9a8c91be642935d3ce007fa465f0840bb38a1f4a91cf`
- log-matrix-p2.txt `b18e88ee1c132f88e1e3a90fdcfe586daf7df2be41ed782e7cdc6c228330b13b`
- log-matrix-p3-run1.txt `75e3449dea3cee10d9c1e5afd325389a0e95cf454dc2587e36fd0e1bfc07682d`
- log-matrix-p3-run2.txt `2ead221375b118144de27dc650bc8e6a590692a048489c2b29ba64c047e187f8`
- log-suite-berserk.txt `dbf91a35b62cdd42d3da3e9165163d3384be11f9c9f1e800f99404942450edfe`
- log-suite-feedback.txt `25c31e92a082ea3f9bc295c798fc4725a7718bc13b7eefac8b347b75d417d5fe`
- log-suite-hazard.txt `9fe36fc030a424293d742a1666c23853f9ba7776e31bb86453482aaa3b9aa3b5`
- log-suite-hazardsmoke.txt `9af2e8a8f13d464c0ce16a4162cedd97dfcb4d31034b00b4afe08476b0bd584d`
- log-suite-residency.txt `7327e7ea6b3f1d37cfe099f7e29e27ecad5462f108c4a71b4350ad8172920baa`
- log-suite-summon.txt `7a57f44b3e2f27d8dfd577fa1935fff557003109947dbd7e6b715cb028830147`
- perf-p1.csv `63ce8fde9fbf4e7e2c45e78ae6238b22802de47fa252844358673f00c24af904`
- perf-p1.json `c672f1a5ea4f804795f44768754c1c2c0abea9e113ff37104d57b07607660309`
- perf-p2.csv `e723193189657f8e35556d06e023ef1122cdd5dfaeff6d99a4f701a81e22eba9`
- perf-p2.json `3ebd0b4f7d35aa8d66f3ef00582ee08714e929b90b615aaef6ece7967a7759e5`
- perf-p3-run1.csv `5f280823f6301425d4245ddd36e13b9c3510e97d349a1d4c48a54c5dafcc9e5a`
- perf-p3-run1.json `f33e703d2f6001928596cfa59cf8b785f3e7b1aec318393a0a30bf2a956d9e86`
- perf-p3-run2.csv `4b63173e17d9754aa0ae37b625a8340a51c7a16cfec788c5b09ae09c4ed8cecd`
- perf-p3-run2.json `96be35037234d4cffeca4d184dcbb826b8815073389032e667fff3844ad62857`
- pfa-after.log `d283d04be1da042665b1e0016cb0ccc821630110016a60b65f2598ef2c59a24b`
- pfa-before.log `179f7b340db533dc8509aa1f4f5667b29b1bcca8e3b6ee0b836891f08202b01d`
- run_observed.py `57140c98d8a18cf0839e13d7bbd42252a3c442393056d682738166d07163b065`
- tdcr-after.log `87e432a7bdc923627b4ad8943e4e98e90196d2e43f14b07cce0e7b41a2205914`

Every matrix/suite run was driven by `run_observed.py` (argv/env/own-pid, verbatim ps
before/during/after; strict overlap check: no foreign Godot process live in any window).
