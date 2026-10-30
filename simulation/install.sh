#!/usr/bin/env bash
#
# Install the UOB SkyDrop simulation files into a PX4-Autopilot checkout:
#   - Gazebo models  -> Tools/simulation/gz/models/
#   - Gazebo worlds  -> Tools/simulation/gz/worlds/
#   - PX4 airframe   -> ROMFS/px4fmu_common/init.d-posix/airframes/
#     and its name added to that folder's CMakeLists.txt
#
# Anything already there that differs is moved to ~/.skydrop-backups/<time>/
# first. Safe to re-run after every change in this repo.
#
# Usage: ./simulation/install.sh
# Override the PX4 location with PX4_DIR=/path/to/PX4-Autopilot if needed.

set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"
PINNED_PX4_COMMIT="fe87271f9cb918b12adb8608372e53f8d3e074f0"

GZ_DIR="$PX4_DIR/Tools/simulation/gz"
AIRFRAME_DIR="$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes"
CMAKE_LIST="$AIRFRAME_DIR/CMakeLists.txt"
BACKUP_DIR="$HOME/.skydrop-backups/$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$GZ_DIR/models" ] || [ ! -f "$CMAKE_LIST" ]; then
    echo "ERROR: no PX4-Autopilot checkout at $PX4_DIR (set PX4_DIR)." >&2
    exit 1
fi

head_commit="$(git -C "$PX4_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
if [ "$head_commit" != "$PINNED_PX4_COMMIT" ]; then
    echo "WARNING: PX4 is at $head_commit."
    echo "         This project was validated at $PINNED_PX4_COMMIT."
fi

changed_airframe=0
backed_up=0

backup() {  # backup <path>
    local rel="${1#"$PX4_DIR"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$1" "$BACKUP_DIR/$rel"
    backed_up=1
    echo "  backed up $rel"
}

install_item() {  # install_item <source> <destination folder>
    local src="$1" dest="$2/$(basename "$1")"
    if [ -e "$dest" ] && diff -rq "$src" "$dest" >/dev/null 2>&1; then
        echo "  unchanged $(basename "$src")"
        return 1
    fi
    [ -e "$dest" ] && backup "$dest"
    cp -r "$src" "$dest"
    echo "  installed $(basename "$src")"
    return 0
}

echo "Models:"
for model in "$SIM_DIR"/models/*/; do
    install_item "${model%/}" "$GZ_DIR/models" || true
done

echo "Worlds:"
for world in "$SIM_DIR"/worlds/*.sdf; do
    install_item "$world" "$GZ_DIR/worlds" || true
done

echo "Airframes:"
for airframe in "$SIM_DIR"/airframes/*; do
    name="$(basename "$airframe")"
    number="${name%%_*}"

    # Refuse if another airframe already uses this number (PX4 would load
    # whichever it finds first - this once loaded a tiltrotor instead).
    for other in "$AIRFRAME_DIR/${number}"_*; do
        if [ -e "$other" ] && [ "$(basename "$other")" != "$name" ]; then
            echo "ERROR: airframe number $number is already used by $(basename "$other")." >&2
            exit 1
        fi
    done

    if install_item "$airframe" "$AIRFRAME_DIR"; then
        changed_airframe=1
    fi

    # PX4 only builds airframes listed by name in CMakeLists.txt.
    if ! grep -Eq "^[[:space:]]*${name}[[:space:]]*$" "$CMAKE_LIST"; then
        mkdir -p "$BACKUP_DIR/ROMFS/px4fmu_common/init.d-posix/airframes"
        cp "$CMAKE_LIST" "$BACKUP_DIR/ROMFS/px4fmu_common/init.d-posix/airframes/CMakeLists.txt"
        backed_up=1
        if grep -q "Reserve for custom models" "$CMAKE_LIST"; then
            awk -v n="$name" '{print} /Reserve for custom models/ && !d {print "\t" n; d=1}' \
                "$CMAKE_LIST" > "$CMAKE_LIST.tmp"
        else
            last_paren="$(grep -n '^)' "$CMAKE_LIST" | tail -1 | cut -d: -f1)"
            awk -v n="$name" -v l="$last_paren" 'NR==l {print "\t" n} {print}' \
                "$CMAKE_LIST" > "$CMAKE_LIST.tmp"
        fi
        mv "$CMAKE_LIST.tmp" "$CMAKE_LIST"
        echo "  registered $name in CMakeLists.txt"
        changed_airframe=1
    fi
done

echo
if [ "$backed_up" -eq 1 ]; then
    echo "Previous versions saved in $BACKUP_DIR"
fi
if [ "$changed_airframe" -eq 1 ]; then
    echo "Airframe changed: rebuild PX4 before launching (airframes are built in):"
    echo "  cd $PX4_DIR && rm -rf build/px4_sitl_default && make px4_sitl"
else
    echo "No rebuild needed. Launch with: ./simulation/run_x650_v2.sh"
fi
