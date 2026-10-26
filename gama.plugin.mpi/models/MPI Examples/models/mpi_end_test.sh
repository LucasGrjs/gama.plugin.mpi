#!/bin/bash
# Test of the end of a distributed run (mpi_end.gaml): end modes sleep, abort, micro on 2, 4 and 8 ranks.
# Per run: exit code, steps written by every rank (20), ABORT line of every rank (abort mode), errors.
#
# Usage: mpi_end_test.sh <gama dir> [repeats, default 1] [modes, default "sleep abort micro"]
#   <gama dir>  headless GAMA folder with plugins/ (as for run_mpi.sh); output in ./mpi_end_test/
# Exit code: 0 every run clean, 1 otherwise.
set -u
if [ $# -lt 1 ]; then sed -n '2,8p' "$0"; exit 2; fi
G=$1; REPEATS=${2:-1}; MODES=${3:-"sleep abort micro"}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(realpath -m mpi_end_test); mkdir -p "$OUT"
total=0; ok=0
for mode in $MODES; do
  plan="$OUT/mpi_end_$mode.xml"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<Experiment_plan>\n  <Simulation id="0" sourcePath="%s" experiment="mpi_end" finalStep="20">\n    <Parameters>\n      <Parameter name="end_mode" type="STRING" value="%s" var="end_mode"/>\n    </Parameters>\n  </Simulation>\n</Experiment_plan>\n' \
    "$HERE/mpi_end.gaml" "$mode" > "$plan"
  for np in 2 4 8; do
    for k in $(seq 1 "$REPEATS"); do
      d="$OUT/${mode}_np${np}_$k"; rm -rf "$d"
      timeout 240 bash "$HERE/run_mpi.sh" "$G" "$plan" "$np" "$d" > "$d.log" 2>&1
      rc=$?
      steps=$(for r in $(seq 0 $((np - 1))); do grep -a -c '^STEP ' "$d/rank_$r/output.txt" 2>/dev/null || echo 0; done | sort -u | tr '\n' ' ')
      # writes from abort go to the rank's console-outputs-<rank>.txt; "ABORT <rank> <n-1>": every other rank answered
      aborts=$(for r in $(seq 0 $((np - 1))); do cat "$d/rank_$r/output.txt" "$d/rank_$r"/console-outputs-*.txt 2>/dev/null | grep -a -q "^\.*ABORT $r $((np - 1))$" && echo x; done | wc -l)
      want=$([ "$mode" = abort ] && echo "$np" || echo 0)
      errs=$(grep -a -h -o -E 'Exception[^ ]*|SIGSEGV|exited on signal [0-9]+|core dumped|abnormally' "$d"/rank_*/output.txt "$d.log" 2>/dev/null | sort | uniq -c | tr '\n' ';')
      total=$((total + 1))
      if [ "$rc" = 0 ] && [ "$steps" = "20 " ] && [ "$aborts" = "$want" ] && [ -z "$errs" ]; then ok=$((ok + 1)); v=OK; else v=FAIL; fi
      echo "$mode np=$np run=$k exit=$rc steps=[$steps] abort lines=$aborts/$want errors=[$errs] $v"
    done
  done
done
echo "== $ok/$total clean"
[ "$ok" = "$total" ]
