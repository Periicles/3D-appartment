#!/usr/bin/env bash
# Runs the GUT suite headless. Extra arguments are passed to GUT
# (e.g. -gselect=test_project_data -gunit_test_name=test_wall_length).
set -euo pipefail

cd "$(dirname "$0")/.."

# Refresh Godot's global class cache so newly added `class_name` scripts resolve.
import_log="$(mktemp)"
output_file="$(mktemp)"
trap 'rm -f "$import_log" "$output_file"' EXIT

import_status=0
godot --headless --path . --import > "$import_log" 2>&1 || import_status=$?
if [ "$import_status" -ne 0 ]; then
	cat "$import_log" >&2
	exit "$import_status"
fi

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
