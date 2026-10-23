#!/bin/bash
# Runs a GAMA experiment plan on several MPI processes, one headless GAMA per rank, then prints
# what each rank's model wrote.
#
# Usage: run_mpi.sh <gama dir> <experiment plan .xml> <number of processes> [output dir]
#   <gama dir>  headless GAMA folder containing plugins/ and configuration/
#   output dir  default: ./mpi_output. One folder per rank: <output dir>/rank_<r>/ holds the rank's
#               full output (output.txt), its GAMA outputs and its display pictures (snapshot/).
# Environment:
#   MPI_JAVA_LIB  folder of libmpi_java.so (default /usr/local/lib)
#   GAMA_XMX      Java heap per rank (default 3g)
#   MPI_DEBUG=1   also print the MPI plugin's progress messages
#
# Example: bash run_mpi.sh ~/gama mpi_hello.xml 4
set -euo pipefail
if [ $# -lt 3 ]; then sed -n '2,15p' "$0"; exit 1; fi
GAMA=$(realpath "$1"); PLAN=$(realpath "$2"); NP=$3; OUT=$(realpath -m "${4:-mpi_output}")
export GAMA PLAN OUT
export MPI_JAVA_LIB=${MPI_JAVA_LIB:-/usr/local/lib} GAMA_XMX=${GAMA_XMX:-3g}
export DEBUG_FLAG=$([ "${MPI_DEBUG:-0}" = 1 ] && echo "-Dgama.mpi.debug=true" || echo "-Dgama.mpi.debug=false")
export PMIX_MCA_pcompress_base_silence_warning=1

# created before mpirun: ranks creating snapshot/ at the same time make GAMA abort
for r in $(seq 0 $((NP - 1))); do mkdir -p "$OUT/rank_$r/snapshot"; done

set +e
mpirun -np "$NP" bash -c '
  R=$OMPI_COMM_WORLD_RANK
  # one workspace and one empty OSGi configuration per rank: ranks starting together must not
  # write the same bundle cache. GAMA then reads $GAMA/configuration as a read-only base, so
  # nothing is written into the GAMA folder.
  WS=/tmp/gama_ws_mpi_$R; rm -rf "$WS"; mkdir -p "$WS/configuration"
  exec java -cp "$(ls "$GAMA"/plugins/org.eclipse.equinox.launcher_*.jar | head -1)" \
    -Xmx"$GAMA_XMX" -Djava.awt.headless=true -Djava.library.path="$MPI_JAVA_LIB" "$DEBUG_FLAG" \
    --add-modules jdk.incubator.vector --enable-preview --sun-misc-unsafe-memory-access=allow \
    --enable-native-access=ALL-UNNAMED \
    --add-exports=java.base/java.lang=ALL-UNNAMED --add-exports=java.desktop/sun.awt=ALL-UNNAMED \
    --add-exports=java.desktop/sun.java2d=ALL-UNNAMED --add-exports=java.desktop/sun.awt.image=ALL-UNNAMED \
    --add-exports=java.base/java.math=ALL-UNNAMED --add-exports=java.base/sun.nio.ch=ALL-UNNAMED \
    --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
    --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.math=ALL-UNNAMED \
    --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
    --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED \
    --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.security=ALL-UNNAMED \
    --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED \
    --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.lang.ref=ALL-UNNAMED \
    --add-opens=java.desktop/java.awt=ALL-UNNAMED --add-opens=java.sql/java.sql=ALL-UNNAMED \
    org.eclipse.equinox.launcher.Main -configuration "$WS/configuration" \
    -application gama.headless.product -data "$WS" -v "$PLAN" "$OUT/rank_$R" \
    > "$OUT/rank_$R/output.txt" 2>&1
'
rc=$?
set -e

# what each rank's model wrote: its output without GAMA's start-up messages (last 20 lines)
NOISE='^> |^[[:space:]]*$|^\[[A-Za-z_]+\.[A-Za-z_]+\] |^WARNING: Using incubator modules|^Log active$|^GAMA configuring and loading|^Refreshing Edges|^Listeners found|^Image Display Surface created'
for r in $(seq 0 $((NP - 1))); do
  echo "── rank $r ── full output: $OUT/rank_$r/output.txt"
  grep -a -v -E "$NOISE" "$OUT/rank_$r/output.txt" 2>/dev/null | tail -n 20 | sed 's/^\.//; s/^/   /'
done
[ $rc -eq 0 ] || echo "mpirun exit code $rc"
exit $rc
