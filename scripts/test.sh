#!/usr/bin/env bash
# Runs the GUT suite headless. Extra arguments are passed to GUT
# (e.g. -gselect=test_project_data -gunit_test_name=test_wall_length).
set -euo pipefail

cd "$(dirname "$0")/.."

# Refresh Godot's global class cache so newly added `class_name` scripts resolve.
godot --headless --path . --import > /dev/null

godot --headless --path . -s addons/gut/gut_cmdln.gd "$@"
