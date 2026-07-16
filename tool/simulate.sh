#!/usr/bin/env bash
# Convenience wrapper for the MaxHype training simulator.
#
#   bash tool/simulate.sh [--weeks=8] [--days=3] [--duration=90]
#        [--experience=advanced] [--out=build/sim] [--no-rotation] [--seed=1000]
#
# Passes all args through to the Dart simulator (which runs under the Flutter
# test runner). Writes <out>_sessions.csv and <out>_variety.csv.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter test tool/simulate_training.dart --dart-define=SIM_ARGS="$*"
