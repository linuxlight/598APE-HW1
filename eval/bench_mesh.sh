#!/usr/bin/env bash
# CS598APE HW1 - per-commit series for the mesh scenes (~20-25 min on the VM).
# Lives in eval/; runs from any cwd:
#   eval/bench_mesh.sh 2>&1 | tee bench_mesh.log
set -u
SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
pushd "$SCRIPTDIR/.." > /dev/null || exit 1   # repo root, as in eval/*.sh

REPS=${REPS:-1}
FINAL=c5d6565
# Sphere: every commit (baseline 1 frame already measured in bench.log).
SPHERE_COMMITS=(8c6b259 f193627 e2e6c3a 66fd713 c1c40fc de0e21f 79cdff5 c936c54 b12f292 381e77e)
# Elephant: only from #6 (de0e21f) on; earlier commits need ~62 h per frame.
ELE_COMMITS=(de0e21f 79cdff5 c936c54 b12f292 381e77e)
OUT=$PWD/bench_out
mkdir -p "$OUT"
ORIG=$(git rev-parse --abbrev-ref HEAD)

SPHERE="./main.exe -i inputs/elephant.ray --ppm -a inputs/elephant.animate --no-movie -W 100 -H 100 -F 1"
git show "$FINAL:inputs/realelephant.ray" > "$OUT/realelephant.ray" || exit 1
ELE="./main.exe -i $OUT/realelephant.ray --ppm -a inputs/elephant.animate --no-movie -W 100 -H 100 -F 1"

if ! perf stat -e cycles,instructions -- true >/dev/null 2>&1; then
  echo "perf stat cannot count events. Run: sudo sysctl kernel.perf_event_paranoid=1"; exit 1
fi

build() {
  echo "#### build $1"
  git checkout -q "$1" || { echo "checkout $1 FAILED"; return 1; }
  make clean >"$OUT/build_$1.log" 2>&1
  make >>"$OUT/build_$1.log" 2>&1 || { echo "BUILD FAILED at $1"; tail -15 "$OUT/build_$1.log"; return 1; }
  mkdir -p output
}
run() {
  local name=$1 reps=$2; shift 2
  echo "== $name"
  perf stat -r "$reps" -e cycles,instructions -o "$OUT/$name.txt" -- "$@" >"$OUT/$name.stdout" 2>&1
  grep -E "elapsed|instructions|cycles" "$OUT/$name.txt"
  grep "Total time" "$OUT/$name.stdout"
}

for c in "${SPHERE_COMMITS[@]}"; do
  build "$c" || continue
  run "sphere_${c}_F1" $REPS $SPHERE
  for e in "${ELE_COMMITS[@]}"; do
    [ "$c" = "$e" ] && run "ele_${c}_F1" $REPS $ELE
  done
done

git checkout -q "$ORIG"; make clean >/dev/null 2>&1; make >/dev/null 2>&1
popd > /dev/null
echo "DONE"
