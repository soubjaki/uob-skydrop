#!/bin/bash

cd ~/PX4-Autopilot || exit 1

export GZ_SIM_RESOURCE_PATH=$HOME/PX4-Autopilot/Tools/simulation/gz/models:$GZ_SIM_RESOURCE_PATH

PX4_HOME_LAT=34.36628 \
PX4_HOME_LON=35.78218 \
PX4_HOME_ALT=262 \
PX4_GZ_WORLD=uob_training \
PX4_SYS_AUTOSTART=4001 \
PX4_SIM_MODEL=gz_x650_skydrop_v2 \
./build/px4_sitl_default/bin/px4
