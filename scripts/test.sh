#!/usr/bin/env bash
# Runs the GUT suite headless. Extra arguments are passed to GUT
# (e.g. -gselect=test_project_data -gunit_test_name=test_wall_length).
set -euo pipefail

cd "$(dirname "$0")/.."

# Refresh Godot's global class cache so newly added `class_name` scripts resolve.
godot --headless --path . --import > /dev/null

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

# GUT exits 0 when a test script fails to parse ("Nothing was run"), so scan its output too.
set +e
godot --headless --path . -s addons/gut/gut_cmdln.gd "$@" 2>&1 | tee "$output_file"
status=${PIPESTATUS[0]}
set -e

if grep -qE "SCRIPT ERROR|Parse Error|Nothing was run" "$output_file"; then
	echo "Test run failed: script errors or no tests run (see output above)." >&2
	exit 1
fi
exit "$status"
