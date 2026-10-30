#!/bin/bash
#
# Launch the UOB SkyDrop X650 in Gazebo with PX4 SITL.
#
# - One Gazebo window: PX4 starts the Gazebo server headless, so this script
#   opens the viewer itself and kills any duplicate viewer that appears.
# - Clean shutdown: typing `shutdown` at pxh>, pressing Ctrl+C, or closing the
#   Gazebo window stops PX4 and every Gazebo process.
#
# Usage: ./simulation/run_x650_v2.sh
# Override the PX4 location with PX4_DIR=/path/to/PX4-Autopilot if needed.

PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"
cd "$PX4_DIR" || { echo "PX4-Autopilot not found at $PX4_DIR (set PX4_DIR)"; exit 1; }

if [ ! -x ./build/px4_sitl_default/bin/px4 ]; then
    echo "PX4 is not built yet. Run: cd $PX4_DIR && make px4_sitl"
    exit 1
fi

# Start clean: kill leftovers from earlier runs or manual tests.
pkill -9 -f "gz sim" 2>/dev/null
pkill -9 -f "build/px4_sitl_default/bin/px4" 2>/dev/null
sleep 1

export GZ_SIM_RESOURCE_PATH="$PX4_DIR/Tools/simulation/gz/models:$GZ_SIM_RESOURCE_PATH"

gz sim -g &
GUI_PID=$!

# Watchdog: keep exactly one viewer, and stop PX4 if the window is closed.
( while kill -0 "$GUI_PID" 2>/dev/null; do
    for pid in $(pgrep -f "gz sim -g"); do
      [ "$pid" != "$GUI_PID" ] && kill -9 "$pid" 2>/dev/null
    done
    sleep 1
  done
  pkill -9 -f "build/px4_sitl_default/bin/px4" 2>/dev/null
) &
WATCHDOG_PID=$!

# PX4 runs in the foreground so the pxh> shell stays interactive.
PX4_HOME_LAT=34.36628 \
PX4_HOME_LON=35.78218 \
PX4_HOME_ALT=262 \
PX4_GZ_WORLD=uob_training \
PX4_SYS_AUTOSTART=22001 \
PX4_SIM_MODEL=gz_x650_skydrop_v2 \
./build/px4_sitl_default/bin/px4

# PX4 exited: close the viewer, the watchdog and any Gazebo process left over.
kill "$GUI_PID" "$WATCHDOG_PID" 2>/dev/null
pkill -9 -f "gz sim" 2>/dev/null
