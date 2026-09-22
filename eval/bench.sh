#!/usr/bin/env bash
# CS598APE HW1 - VM measurement script.
# Lives in eval/; runs from any cwd. On the VM, inside tmux (expect ~60-80 min):
#   chmod +x eval/bench.sh && eval/bench.sh 2>&1 | tee bench.log
# Sections run in priority order, so if time runs out, send whatever finished.
# Send back bench.log (bench_out/*.txt only if I ask).
set -u
SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
pushd "$SCRIPTDIR/.." > /dev/null || exit 1   # repo root, as in eval/*.sh

BASE=19bbc81
FINAL=c5d6565
MIDDLE=(8c6b259 f193627 e2e6c3a 66fd713 c1c40fc de0e21f 79cdff5 c936c54 b12f292 381e77e)
OUT=$PWD/bench_out
mkdir -p "$OUT"
ORIG=$(git rev-parse --abbrev-ref HEAD)

# Commands from README.md. --no-movie so FFmpeg time isn't counted by perf.
# "sphere" = inputs/elephant.ray (3168-tri sphere); real elephant = realelephant.ray.
PIANO="./main.exe -i inputs/pianoroom.ray --ppm -o output/pianoroom.ppm -H 500 -W 500"
GLOBE="./main.exe -i inputs/globe.ray --ppm -a inputs/globe.animate --no-movie -F 24"
SPHERE="./main.exe -i inputs/elephant.ray --ppm -a inputs/elephant.animate --no-movie -W 100 -H 100"
# realelephant.ray is not in the baseline commit, so keep a copy outside the tree.
git show "$FINAL:inputs/realelephant.ray" > "$OUT/realelephant.ray" || { echo "cannot extract realelephant.ray"; exit 1; }
ELE="./main.exe -i $OUT/realelephant.ray --ppm -a inputs/elephant.animate --no-movie"

build() {
  echo "#### build $1"
  git checkout -q "$1" || { echo "checkout $1 FAILED"; return 1; }
  make clean >"$OUT/build_$1.log" 2>&1
  make >>"$OUT/build_$1.log" 2>&1 || { echo "BUILD FAILED at $1"; tail -15 "$OUT/build_$1.log"; return 1; }
  mkdir -p output
}

# run <name> <reps> <cmd...>
run() {
  local name=$1 reps=$2; shift 2
  echo "== $name"
  perf stat -r "$reps" -e cycles,instructions -o "$OUT/$name.txt" -- "$@" >"$OUT/$name.stdout" 2>&1
  grep -E "elapsed|instructions|cycles" "$OUT/$name.txt"
  grep "Total time" "$OUT/$name.stdout"
}

lscpu | grep -E "Model name|^CPU\(s\)|L3" ; g++ --version | head -1
git log --oneline "$BASE^..$FINAL"

# ---- 1. Final build: all four test cases ----
if build "$FINAL"; then
  run piano_final 5 $PIANO; cp output/pianoroom.ppm "$OUT/piano_final.ppm"
  run globe_final 5 $GLOBE
  run sphere_final_F1  3 $SPHERE -F 1
  run sphere_final_F24 3 $SPHERE -F 24
  run ele_final_F1  3 $ELE -F 1 -W 100 -H 100
  run ele_final_F24 1 $ELE -F 24 -W 100 -H 100
  for n in 2 3 4; do run "ele_final_${n}x${n}" 3 $ELE -F 1 -W $n -H $n; done
  # thread scaling: NCPU comes from sched_getaffinity, so taskset sets the thread count
  for cpus in 0 0-1 0-2 0-3; do run "globe_cpus_$cpus" 3 taskset -c $cpus $GLOBE; done
  echo "== divider (elephant IPC question)"
  perf stat -e cycles,instructions,arith.divider_active -- $ELE -F 1 -W 100 -H 100 2>&1 >/dev/null \
    | grep -E "cycles|instructions|divider"
fi

# ---- 2. Baseline ----
# Sphere and elephant baseline cost is hit-independent (every ray copies+sorts
# all shapes), so 1 frame is measured and scaled; validated against final F1 vs F24.
if build "$BASE"; then
  run piano_base 5 $PIANO; cp output/pianoroom.ppm "$OUT/piano_base.ppm"
  run globe_base 1 $GLOBE
  run sphere_base_F1 1 $SPHERE -F 1
  for n in 2 3 4; do run "ele_base_${n}x${n}" 1 $ELE -F 1 -W $n -H $n; done
fi

# ---- 3. Per-commit series (the cumulative speedup graph) ----
for c in "${MIDDLE[@]}"; do
  build "$c" || continue
  run "piano_$c" 5 $PIANO; cp output/pianoroom.ppm "$OUT/piano_$c.ppm"
  run "globe_$c" 1 $GLOBE
done
echo "== correctness vs baseline (pianoroom)"
for f in "$OUT"/piano_*.ppm; do
  cmp -s "$OUT/piano_base.ppm" "$f" && echo "$(basename $f) identical" || echo "$(basename $f) DIFFERS"
done

# ---- 4. Denom cache (failed optimization 6b) ----
if build f0389f0~1; then run piano_predenom 5 $PIANO; run globe_predenom 3 $GLOBE; fi
if build f0389f0;   then run piano_denom 5 $PIANO;    run globe_denom 3 $GLOBE; fi

git checkout -q "$ORIG"; make clean >/dev/null 2>&1; make >/dev/null 2>&1
popd > /dev/null
echo "DONE"
