## ZCode bridge

`zcode` in this directory is a byte-identical, version-controlled copy of the
QA-certified pipeline bridge installed at `/usr/local/bin/zcode`
(sha256 `3a52eaa994c8b0256c2956115843f97e0036a9a0f897f88e4c5a2642bf45ee07`,
accepted FAN-2906). It translates the Claude stream-json protocol to the real
ZCode CLI. **Do not edit its behaviour here** — this is a preservation copy,
not a new implementation; behaviour changes go through their own
FAN issue and re-certification.

The real ZCode CLI binary was moved to `/usr/local/bin/zcode.real`
(sha256 `460736edc0458cd6f02507e7fc7e02c2775548053cca918b5f96299064d389c9`) so
the bridge could take over the standard `zcode` install path. `install.sh`
never touches `zcode.real`.

### Silent overwrite risk

The bridge occupies ZCode's normal install location. **When the ZCode CLI
itself updates, its installer will silently overwrite the bridge** — no
error, no warning. The pipeline will quietly go back to raw `zcode.real`
behaviour (including the pre-FAN-2894 30-minute timeout truncation) and
nothing will point at the update as the cause.

After every ZCode CLI update, run:

```
tools/zcode_bridge/install.sh --check
```

If it reports a mismatch, reinstall the bridge:

```
tools/zcode_bridge/install.sh
```

### Usage

- `tools/zcode_bridge/install.sh` — install the bridge to
  `/usr/local/bin/zcode`, preserving the executable bit. Idempotent: running
  it again when the installed file already matches does nothing and says so.
- `tools/zcode_bridge/install.sh --check` — compare the installed file's
  sha256 against the certified one; exits non-zero and prints both sums on
  mismatch.
