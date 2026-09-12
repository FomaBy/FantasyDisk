# Note on candidate-identity.txt normalization (FAN-3934 CI recovery)

`raw-baseline/extracted/candidate-identity.txt` is part of the extracted FAN-3877
evidence archive copy. It shipped with a trailing blank line at EOF, which the CI
range check (`git diff --check`) rejected in run 34429832208. The original bytes are
preserved immutably beside it as `candidate-identity.txt.orig`
(sha256 recorded below); the live file is byte-identical except for the removed
trailing blank line. No measured value or source identity changed.
sha256 original: 0e7be085cdeba0c85f7ab128b5df1719dc86499c07ea0d305c0cacb4a6a84963
