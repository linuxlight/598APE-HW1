#!/bin/bash
set -eo pipefail

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
RUNS="1 2 3 4 5"

log(){ printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

sudo -v

pushd "$SCRIPTDIR/.." > /dev/null
for i in $RUNS; do
  log "recording run $i"
  sudo perf record -e cpu-cycles -F 4000 -g -o "$SCRIPTDIR"/realelephant_run$i.data -- ./main.exe -i inputs/realelephant.ray --ppm  -a inputs/elephant.animate --no-movie -F 24 -W 100 -H 100 
  sudo chown "$USER" "$SCRIPTDIR"/realelephant_run$i.data
  log "run $i recorded ($(du -h "$SCRIPTDIR"/realelephant_run$i.data | cut -f1))"
done
popd > /dev/null

for i in $RUNS; do
  ( log "folding run $i"
    perf script -i "$SCRIPTDIR"/realelephant_run$i.data -F -period | "$SCRIPTDIR"/FlameGraph/stackcollapse-perf.pl > "$SCRIPTDIR"/realelephant$i.perf-folded
    log "folded run $i" ) &
done
wait
log "all folds complete"

log "building flame graph"
cat "$SCRIPTDIR"/realelephant*.perf-folded | "$SCRIPTDIR"/FlameGraph/flamegraph.pl > "$SCRIPTDIR"/realelephant_flamegraph.svg
log "done -> $SCRIPTDIR/realelephant_flamegraph.svg"
