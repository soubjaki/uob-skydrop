# Setup on a new machine

These steps set up the full simulation on **native Ubuntu 24.04** (the team's laptop setup). Ubuntu 22.04 also works. Avoid newer releases such as 26.04: PX4's setup script did not install Gazebo there (see the [progress record](progress-record.md)).

Internet is needed for the installs and the first launch, which downloads Gazebo assets. After that, everything runs offline.

## 1. PX4 at the validated commit

```bash
git clone --recursive https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot
cd ~/PX4-Autopilot
git checkout fe87271f9cb918b12adb8608372e53f8d3e074f0
git submodule update --init --recursive
bash ./Tools/setup/ubuntu.sh
```

Reboot when the script finishes. Then check that Gazebo is installed:

```bash
gz sim --version     # should print 8.x (Gazebo Harmonic)
```

## 2. Project files and build

```bash
git clone https://github.com/soubjaki/uob-skydrop.git ~/uob-skydrop
~/uob-skydrop/simulation/install.sh
cd ~/PX4-Autopilot && make px4_sitl
```

`install.sh` copies the models, worlds and airframe into PX4 and registers airframe 22001 in PX4's airframe list. The first build takes 10–20 minutes. `make px4_sitl` only compiles; it does not open anything.

## 3. QGroundControl

From [QGroundControl's install guide](https://docs.qgroundcontrol.com/master/en/qgc-user-guide/getting_started/download_and_install.html):

```bash
sudo usermod -aG dialout "$(id -un)"
sudo systemctl mask --now ModemManager.service
sudo apt install -y libfuse2t64 libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor0
```

On Ubuntu 22.04 the first package is `libfuse2` instead. Log out and back in once, then download the Linux AppImage from qgroundcontrol.com and run it:

```bash
chmod +x ~/Downloads/QGroundControl*.AppImage
~/Downloads/QGroundControl*.AppImage
```

In QGC's Application Settings, set the preferred firmware to PX4.

## 4. Launch

```bash
~/uob-skydrop/simulation/run_x650_v2.sh
```

Wait for the Gazebo window with the X650 and the `pxh>` prompt, then start QGroundControl. It connects by itself. Check:

- `param show CA_ROTOR0_PX` at `pxh>` reads **0.2298** (the X650's arm position).
- QGC's top bar says **Ready To Fly** and the vehicle type is a multirotor, not "MR(vtol)".

To stop, type `shutdown` at `pxh>` or close the Gazebo window. Both close everything.

## 5. Flight scripts

```bash
sudo apt install -y python3-venv
python3 -m venv ~/skydrop-venv
source ~/skydrop-venv/bin/activate
pip install -r ~/uob-skydrop/scripts/requirements.txt
cd ~/uob-skydrop && python scripts/basic_flight.py
```

Install from `requirements.txt`, not `pip install mavsdk`. Since v4, the `mavsdk` package is a different API and these scripts fail with it.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `gz: command not found` | PX4's setup script did not install Gazebo (unsupported Ubuntu release) | Use Ubuntu 24.04 or 22.04 |
| `make px4_sitl` opens nothing | It only compiles | Launch with `simulation/run_x650_v2.sh` |
| `no autostart file found ... 22001_*` | Airframe not built in | Run `install.sh`, then `rm -rf build/px4_sitl_default && make px4_sitl` |
| `CA_ROTOR0_PX` is not 0.2298, or QGC shows "MR(vtol)" | Wrong airframe loaded | Check `SYS_AUTOSTART` is 22001 and no other airframe file starts with `22001_` |
| Arming denied: "system power unavailable" | Simulated power reading missing | At `pxh>`: `param set CBRK_SUPPLY_CHK 894281` (simulation only, never on hardware) |
| Arming denied: "No connection to the GCS" | QGroundControl not running | Start QGC |
| Gazebo runs but no window | PX4 starts Gazebo headless | Use the run script; it opens the viewer |

More background on each problem is in the [progress record](progress-record.md).
