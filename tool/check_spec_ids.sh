#!/usr/bin/env bash
# Traceability gate between the QA spec and the test suite.
#
# Every case the spec marks [A] (automated) must exist as a test whose name
# carries the spec ID — so a claimed-but-missing test fails the build instead
# of surviving until a human audit (that is exactly how NAV-05 and TTS-13
# shipped falsely marked [A] once). Extend the list whenever the spec
# promotes a case to [A].
set -euo pipefail
cd "$(dirname "$0")/.."

ids=(
  NAV-05
  TTS-13
  # TTS-14 retired 2026-08-18: the progress bar it covered was removed in
  # favour of the read marker (v0.2) — the MRK ids below took its place.
  TTS-15 TTS-16 TTS-17 TTS-18 TTS-19
  FTR-01 FTR-02 END-01 END-02 HDR-01 MRK-16 SCR-01
  MRK-01 MRK-02 MRK-03 MRK-04 MRK-05 MRK-06 MRK-07 MRK-08 MRK-09
  SPD-01 SPD-02
  MRK-10 MRK-11 MRK-13 MRK-14
  BMK-01 BMK-02
  EXP-01
  CTL-01 CTL-02 CTL-03
  SWP-11
  CHR-01 CHR-02 CHR-03 CHR-04 CHR-05
  SWP-10
  EDG-01 EDG-02 EDG-03 EDG-04 EDG-05 EDG-06 EDG-07 EDG-08
  ACC-01
  LAY-06
  TOC-07
  RTL-06
  KEY-01 KEY-02
)

missing=0
for id in "${ids[@]}"; do
  if ! grep -rq "$id" test/; then
    echo "MISSING spec-ID test: $id"
    missing=1
  fi
done

if [ "$missing" -eq 0 ]; then
  echo "traceability OK: all ${#ids[@]} spec-ID tests present"
fi
exit "$missing"
