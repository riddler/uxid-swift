#!/usr/bin/env bash
# Fails when the library's line coverage is under the floor.
#
# Run after `swift test --enable-code-coverage`. It reads the coverage data
# that run wrote (the profile beside the JSON report `swift test
# --show-codecov-path` names), exports it as LCOV with `llvm-cov export`, and
# counts the lines of the files under Sources/Uxid/ only: test files and
# generated runner files are not the library and do not count.
#
# A file with no executable line (a constant, a type with no body) has no
# line in the report. While no library file has one, there is nothing to
# measure and the floor passes, saying so; the first executable line under
# Sources/Uxid/ puts every library line under the floor. The report must
# hold a file under Tests/UxidTests/ by the same path prefix, so a run without
# coverage data, or a report whose paths do not start at this checkout, never
# passes.
#
# Usage: scripts/coverage-floor.sh [floor-percent]   (default 90)
set -euo pipefail

floor="${1:-90}"
root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"

codecov_json="$(swift test --show-codecov-path)"
codecov_dir="$(dirname "$codecov_json")"
profdata="$codecov_dir/default.profdata"
bin_dir="$(dirname "$codecov_dir")"

if [[ ! -f "$profdata" ]]; then
  echo "coverage-floor: no coverage profile at $profdata;" \
    "run swift test --enable-code-coverage first" >&2
  exit 1
fi

if [[ -f "$bin_dir/uxidPackageTests.xctest/Contents/MacOS/uxidPackageTests" ]]; then
  test_binary="$bin_dir/uxidPackageTests.xctest/Contents/MacOS/uxidPackageTests"
elif [[ -f "$bin_dir/uxidPackageTests.xctest" ]]; then
  test_binary="$bin_dir/uxidPackageTests.xctest"
else
  echo "coverage-floor: no test binary under $bin_dir" >&2
  exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
  llvm_cov=(xcrun llvm-cov)
else
  llvm_cov=(llvm-cov)
fi

lcov="$("${llvm_cov[@]}" export -format=lcov -summary-only \
  -instr-profile "$profdata" "$test_binary")"

# "<test files in the report> <library lines> <library lines covered>"
read -r test_files lines covered < <(
  printf '%s\n' "$lcov" | awk -v lib="$root/Sources/Uxid/" -v tests="$root/Tests/UxidTests/" '
    /^SF:/ {
      file = substr($0, 4)
      in_lib = (index(file, lib) == 1)
      if (index(file, tests) == 1) test_files++
      next
    }
    /^LF:/ { if (in_lib) lines += substr($0, 4); next }
    /^LH:/ { if (in_lib) covered += substr($0, 4); next }
    END { printf "%d %d %d\n", test_files, lines, covered }
  '
)

if (( test_files == 0 )); then
  echo "coverage-floor: the coverage report holds no file under" \
    "$root/Tests/UxidTests/; no coverage data, or its paths start elsewhere" >&2
  exit 1
fi

if (( lines == 0 )); then
  echo "coverage-floor: no executable line under Sources/Uxid/ yet;" \
    "the ${floor}% floor applies from the first one"
  exit 0
fi

percent="$(awk -v c="$covered" -v l="$lines" 'BEGIN { printf "%.2f", 100 * c / l }')"
if (( covered * 100 < floor * lines )); then
  echo "coverage-floor: Sources/Uxid/ lines ${covered}/${lines} (${percent}%)" \
    "is under the ${floor}% floor" >&2
  exit 1
fi

echo "coverage-floor: Sources/Uxid/ lines ${covered}/${lines} (${percent}%)," \
  "floor ${floor}%"
