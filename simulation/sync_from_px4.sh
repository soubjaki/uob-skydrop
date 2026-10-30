#!/usr/bin/env bash
#
# Copy the project's files back from a PX4-Autopilot checkout into this repo,
# for when someone edited them directly inside PX4 (for example on the
# teammate's PC). Only files this repo already tracks are copied, so `git diff`
# shows exactly what changed. It then lists every other custom change in PX4
# so nothing is missed.
#
# Usage: ./simulation/sync_from_px4.sh && git diff --stat
# Override the PX4 location with PX4_DIR=/path/to/PX4-Autopilot if needed.

set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"
GZ_DIR="$PX4_DIR/Tools/simulation/gz"
AIRFRAME_DIR="$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes"

[ -d "$GZ_DIR/models" ] || { echo "ERROR: no PX4-Autopilot checkout at $PX4_DIR" >&2; exit 1; }

copied=0
sync_tree() {  # sync_tree <repo folder> <px4 folder>
    local repo_root="$1" px4_root="$2"
    while IFS= read -r -d '' file; do
        local rel="${file#"$repo_root"/}"
        local src="$px4_root/$rel"
        if [ -f "$src" ] && ! cmp -s "$src" "$file"; then
            cp "$src" "$file"
            echo "  updated ${repo_root#"$SIM_DIR"/}/$rel"
            copied=$((copied + 1))
        fi
    done < <(find "$repo_root" -type f -print0)
}

echo "Copying changed files from $PX4_DIR:"
sync_tree "$SIM_DIR/models" "$GZ_DIR/models"
sync_tree "$SIM_DIR/worlds" "$GZ_DIR/worlds"
sync_tree "$SIM_DIR/airframes" "$AIRFRAME_DIR"
echo "  $copied file(s) updated"

echo
echo "Other custom changes in PX4 (copy anything new into this repo by hand):"
echo "--- Gazebo models/worlds (Tools/simulation/gz):"
git -C "$GZ_DIR" status --short 2>/dev/null || echo "  (not a git checkout)"
echo "--- PX4 itself:"
git -C "$PX4_DIR" status --short --ignore-submodules=all 2>/dev/null || echo "  (not a git checkout)"
