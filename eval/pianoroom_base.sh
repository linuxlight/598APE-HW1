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
  sudo perf record -e cpu-cycles -F 4000 -g -o "$SCRIPTDIR"/pianoroom_base_run$i.data -- ./main.exe -i inputs/pianoroom.ray --ppm -o output/pianoroom.ppm -H 500 -W 500
  sudo chown "$USER" "$SCRIPTDIR/pianoroom_base_run$i.data"
  log "run $i recorded ($(du -h "$SCRIPTDIR/pianoroom_base_run$i.data" | cut -f1))"
done
popd > /dev/null

for i in $RUNS; do
  log "folding run $i"
  perf script -i "$SCRIPTDIR"/pianoroom_base_run$i.data -F -period | "$SCRIPTDIR"/FlameGraph/stackcollapse-perf.pl > "$SCRIPTDIR"/pianoroom_base$i.perf-folded
  log "folded run $i"
done
wait
log "all folds complete"

log "building flame graph"
cat "$SCRIPTDIR"/pianoroom_base*.perf-folded | "$SCRIPTDIR"/FlameGraph/flamegraph.pl > "$SCRIPTDIR"/pianoroom_base_flamegraph.svg
log "done -> $SCRIPTDIR/pianoroom_base_flamegraph.svg"
