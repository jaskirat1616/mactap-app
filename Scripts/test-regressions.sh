#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
test_dir="$(mktemp -d "$PWD/build/regressions.XXXXXX")"

# Optional arguments are forwarded to swiftc (for example -sdk).
swiftc "$@" MacTap/Sources/TapDetector.swift Tests/TapDetectorRegression.swift \
    -o "$test_dir/detector-regression"
"$test_dir/detector-regression"

sources=()
for source in MacTap/Sources/*.swift; do
    if [[ "$source" != MacTap/Sources/MacTapApp.swift ]]; then
        sources+=("$source")
    fi
done
swiftc "$@" -parse-as-library "${sources[@]}" Tests/CalibrationRegression.swift \
    -o "$test_dir/calibration-regression"
"$test_dir/calibration-regression"
