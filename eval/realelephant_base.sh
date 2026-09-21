#!/bin/bash
set -eo pipefail

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
BASELINE=19bbc81
WT=/tmp/598ape-baseline
RUNS="1 2 3 4 5"

log(){ printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

sudo -v

log "creating baseline worktree ($BASELINE)"
git -C "$SCRIPTDIR/.." worktree remove --force "$WT" 2>/dev/null || true
git -C "$SCRIPTDIR/.." worktree add -q "$WT" "$BASELINE"



log "building baseline"
pushd "$WT" > /dev/null
make -s > /dev/null 2>&1
mkdir -p output

for i in $RUNS; do
  log "recording run $i"
  sudo perf record -e cpu-cycles -F 4000 -g -o "$SCRIPTDIR"/realelephant_base_run$i.data -- ./main.exe -i "$SCRIPTDIR"/../inputs/realelephant.ray --ppm  -a inputs/elephant.animate --no-movie -F 2 -W 4 -H 4
  sudo chown "$USER" "$SCRIPTDIR"/realelephant_base_run$i.data
  log "run $i recorded ($(du -h "$SCRIPTDIR"/realelephant_base_run$i.data | cut -f1))"
done
popd > /dev/null

for i in $RUNS; do
  log "folding run $i"
  perf script -i "$SCRIPTDIR"/realelephant_base_run$i.data -F -period | "$SCRIPTDIR"/FlameGraph/stackcollapse-perf.pl > "$SCRIPTDIR"/realelephant_base$i.perf-folded
  log "folded run $i"
done
wait
log "all folds complete"

log "building flame graph"
cat "$SCRIPTDIR"/realelephant_base*.perf-folded | "$SCRIPTDIR"/FlameGraph/flamegraph.pl > "$SCRIPTDIR"/realelephant_base_flamegraph.svg
log "done -> $SCRIPTDIR/realelephant_base_flamegraph.svg"
