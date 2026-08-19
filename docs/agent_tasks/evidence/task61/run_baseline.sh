#!/bin/bash
# Runs every combat/tests + growth/tests run_*.gd headlessly (excluding
# run_global_instakill_tests.gd per protection rules) and records a
# summary.txt with exit code + PASS/FAIL detection + 5-marker log scan.
set -u
GODOT="/c/Users/heliashi/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
PROJECT="c:/Users/heliashi/Documents/元素地牢-4.7"
OUTDIR="$1"
mkdir -p "$OUTDIR"
SUMMARY="$OUTDIR/summary.txt"
> "$SUMMARY"

for f in $(find "$PROJECT/combat/tests" "$PROJECT/growth/tests" -maxdepth 1 -name 'run_*.gd' | sort); do
  base=$(basename "$f")
  if [ "$base" == "run_global_instakill_tests.gd" ]; then
    continue
  fi
  rel="res://${f#$PROJECT/}"
  logfile="$OUTDIR/${base%.gd}.log"
  "$GODOT" --headless --path "$PROJECT" --script "$rel" > "$logfile" 2>&1
  code=$?
  markers=$(grep -c -E "SCRIPT ERROR|Parse Error|ERROR:|WARNING:|CrashHandlerException" "$logfile")
  passfail="UNKNOWN"
  if grep -q -E "\bFAIL\b" "$logfile"; then passfail="HAS_FAIL_TEXT"; fi
  if grep -qE "^(PASS|ALL TESTS PASSED|All tests passed)" "$logfile"; then passfail="PASS_TEXT"; fi
  echo "$base | exit=$code | markers=$markers | $passfail" >> "$SUMMARY"
done
echo "DONE" >> "$SUMMARY"
