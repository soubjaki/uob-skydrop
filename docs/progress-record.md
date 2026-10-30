# UOB SkyDrop — Simulation Progress Record

Oct 29, 2026 · @Omar

## Where we stand

The simulation baseline is finished and verified: the X650 model runs in Gazebo on the teammate's PC, QGroundControl shows **Ready To Fly**, and the next step is Phase 3, scripted flight with MAVSDK-Python.

From 29 Oct, Omar carries the simulation on his own laptop, now dual-booted with native Ubuntu 24.04. The teammate is designing and 3D-printing the gripper and getting the campus building plans from the university.

On the drone itself, only the airframe, the battery (as a weight), the motors and propellers, and the four basic flight sensors are modeled. **The Jetson, the depth camera, and the gripper are not attached to the simulated drone yet.** Section 2 has the full list.

Checks passed on the current setup:

- `param show CA_ROTOR0_PX` reads 0.2298 m, so PX4 uses the X650's arm geometry instead of the x500's 0.174 m.
- QGC shows a plain multirotor and Ready To Fly. The "MR(vtol)" label and "Airspeed invalid" warnings are gone.
- One Gazebo window opens, and typing `shutdown` at `pxh>` or closing the window kills every Gazebo and PX4 process.
- No takeoff has been logged here with the corrected airframe yet. The first Phase 3 script is that test.

| Phase | Status |
| --- | --- |
| 0. Machine setup | Done on the teammate's PC (native Ubuntu 22.04); to redo on Omar's laptop (native Ubuntu 24.04) |
| 1. PX4 + Gazebo running | Done |
| 2. QGC connected, manual control | Done |
| X650 model and airframe config | Done and verified |
| 3. Scripted flight (MAVSDK-Python) | **Next.** Scripts in the repo, test-flown on PX4's built-in simulator (30 Oct); first run on the X650 model pending |
| 4–10. ROS 2 through hardware-in-the-loop | Not started. A placeholder campus world already exists (part of Phase 8). |

## What is attached to the simulated drone

The Jetson, depth camera, gripper and package are **not** on the simulated drone yet. What flies today is the bare X650: frame, battery weight, four motors with propellers, and the flight sensors. Total simulated mass is 3.226 kg (frame 1.912 + battery 1.226 + 4 × 0.022 propellers).

| Component | Status | In the simulation now | Real part (report) |
| --- | --- | --- | --- |
| NVIDIA Jetson | Not attached yet | Nothing on the model, not even its weight. Its job (ROS 2, vision code) will run on the PC from Phase 4. | Jetson companion computer |
| Depth camera | Not attached yet | No camera sensor on the model. Added in Phase 5. | Intel RealSense D455 |
| Gripper | Not attached yet | Not modeled. Added in Phase 7. | 3D-printed claw gripper, being designed and printed by the teammate |
| Package (payload) | Not attached yet | Not modeled. Added in Phase 7. | Up to 1 kg (report's limit) |
| Flight controller | Software stand-in | PX4 runs as software on the PC (SITL). The board on the frame is a cosmetic decal from the x500 model. | Pixhawk running PX4 |
| Telemetry radio | Software stand-in | Replaced by a UDP link on the same PC; QGC listens on port 14550. | Telemetry radio pair |
| RC transmitter | Software stand-in | Replaced by QGC's virtual joystick and `pxh>` commands. | RC transmitter |
| Frame | In the model | 650 mm wheelbase, arms at ±0.2298 m. Frame and electronics lumped into one 1.912 kg body. Its look reuses the x500 mesh. | Holybro X650 carbon frame |
| Motors and ESCs | In the model | Four motor plugins: max 628.3 rad/s, motor constant 4.83e-05. ESCs are not modeled separately. | T-Motor MN4014, 45 A ESCs |
| Propellers | In the model | Four rotors, 0.022 kg each, using a scaled x500 propeller shape. | Gemfan 1555 (15 in) |
| Battery | In the model | A fixed 1.226 kg block, 165 × 64 × 63 mm, under the frame. Weight only: the charge % in QGC comes from PX4's battery simulator. | 10000 mAh pack (chosen 29 Oct) |
| GPS | In the model | `navsat` sensor at 30 Hz. | M10 GPS |
| IMU, barometer, magnetometer | In the model | On the frame with realistic noise: IMU 250 Hz, barometer 50 Hz, magnetometer 100 Hz. | Inside the Pixhawk |
| Motor-failure plugin | In the model | Included, for failure tests in Phase 9. | Simulation only |

Source: the teammate's model files (`x650_skydrop_v2`, `x650_skydrop_v2_base`) from his 23 Sep archive, matched against the boot logs. If he changed the model after that, this lists what is really on it:

```
grep -nE "<link name|<sensor name|<mass>" ~/PX4-Autopilot/Tools/simulation/gz/models/x650_skydrop_v2_base/model.sdf
```

## Software environment

Omar now continues the work on his laptop, dual-booted with native Ubuntu 24.04 (no WSL). The verified setup in this table is still on the teammate's PC and has to be moved over. The earlier WSL2 / Ubuntu 26.04 install only got as far as flying the stock x500.

| Item | Value |
| --- | --- |
| Machine | Teammate's PC, user `kot`, host `braic1-eng` |
| OS | Ubuntu 22.04 (native, not WSL) |
| PX4-Autopilot | v1.18.0-beta1-697, commit `fe87271f9c` on `main` |
| Gazebo | Harmonic (gz-sim 8.15.0) |
| Ground station | QGroundControl (Linux AppImage) |
| Toolchain | GCC 11.4, Python 3.12.13 at `/usr/local/bin/python3`, OpenCV 4.5.4, GStreamer 1.20 |
| Drone model | `x650_skydrop_v2` + `x650_skydrop_v2_base` (meshes come from `x650_skydrop_base`), in `~/PX4-Autopilot/Tools/simulation/gz/models/` |
| World | `uob_training.sdf`, which loads the `uob_training_campus` placeholder model |
| Airframe config | `22001_gz_x650_skydrop`, in `ROMFS/px4fmu_common/init.d-posix/airframes/` and listed in that folder's `CMakeLists.txt` |
| Key airframe values | Rotor positions ±0.22981 m (`CA_ROTOR0–3_PX/PY`), hover throttle 0.644 (`MPC_THR_HOVER`) |
| Home position | Lat 34.36628, lon 35.78218, alt 262 m (UOB campus) |
| Launch script | `~/run_x650_v2.sh` |
| Saved parameters | `~/PX4-Autopilot/build/px4_sitl_default/rootfs/fs/parameters.bson` |

Correction to earlier notes: the Gazebo installed on the laptop was version 10.5, which is Gazebo **Jetty**, not Harmonic as the earlier guide said. The teammate's PC runs Harmonic, which is what PX4 targets.

## What we did, step by step

The work went from a stock x500 on the laptop to a verified X650 on the teammate's PC in about five weeks.

| Step | When | What was done | Result |
| --- | --- | --- | --- |
| 1 | Early Sep | Read the Senior I report and chose the stack: PX4 SITL, Gazebo, QGroundControl, later ROS 2 | Roadmap v1 (Phases 0–9) |
| 2 | Early Sep | Installed WSL2 and Ubuntu 26.04 on the laptop, cloned PX4, ran PX4's setup script | Script did not install Gazebo on 26.04 |
| 3 | 11 Sep | Installed the Gazebo packages by hand, plus OpenCV and OpenGL headers, and rebuilt PX4 | `make px4_sitl gz_x500` opened Gazebo with an x500 and a `pxh>` prompt (Phase 1) |
| 4 | Mid Sep | Installed QGroundControl, set the home position to UOB, bypassed the power check | QGC connected to the simulated drone (Phase 2) |
| 5 | Mid Sep | Wrote Roadmap v2, a from-zero guide for teammates (WSL install, Ubuntu 24.04 advice) | Shared with the team |
| 6 | 23–28 Sep | Teammate built the X650 model and the `uob_training` world on his PC and exported an archive plus an engineering record | Model checked: masses, arm length and propellers match the X650 |
| 7 | 1 Oct | Moved the work to the teammate's PC and wrote a dedicated X650 airframe file | Rotor positions 0.22981 m, hover throttle 0.644 |
| 8 | 5 Oct | Debugged three faults: rotor parameter stuck at 0.1515, VTOL label in QGC, Gazebo with no window | All three traced to root causes (next section) |
| 9 | Early Oct | Renumbered the airframe to 22001, registered it in `CMakeLists.txt`, rebuilt from scratch | `CA_ROTOR0_PX` = 0.2298, QGC Ready To Fly |
| 10 | Early Oct | Rewrote `run_x650_v2.sh` with a duplicate-window guard and full cleanup on exit | One window; nothing left running after shutdown |
| 11 | 29 Oct | Wrote this record and the next-steps roadmap | Phase 3 is next |
| 12 | 30 Oct | Put the project in a GitHub repo (models, worlds, airframe, install and launch scripts, docs) and wrote the Phase 3 flight scripts | Both scripts flew end to end on PX4's built-in simulator at the pinned commit |

## Problems hit and how each was fixed

Eight problems came up. The costliest was an airframe number collision that made PX4 load a stock tiltrotor config instead of the X650's.

| Problem | Root cause | Fix |
| --- | --- | --- |
| `gz: command not found` (laptop) | PX4's setup script does not support Ubuntu 26.04 and skipped Gazebo | Installed the Gazebo packages by hand, plus `libopencv-dev` and the OpenGL headers, then rebuilt from a clean `build` folder |
| `make px4_sitl` opened nothing | That command only compiles. Running `./px4` alone starts PX4's built-in SIH simulator, which has no graphics | Launch with `make px4_sitl gz_x500` (laptop) or the run script (teammate's PC) |
| Arming denied: "system power unavailable", "No connection to the GCS" | The simulated power reading was missing; no ground station was running | `param set CBRK_SUPPLY_CHK 894281` (simulation only), and start QGC |
| `CA_ROTOR0_PX` stuck at 0.1515; QGC showed "MR(vtol)" and "Airspeed invalid" | Airframe number 4020 was already taken by PX4's `4020_gz_tiltrotor`, which loaded instead of ours. Deleting saved parameters did not help | Gave our airframe its own number |
| Renumbered airframe "not found" at boot | PX4 only builds airframes listed by name in the folder's `CMakeLists.txt`. Numbers 22000–22999 are reserved for custom models | Renamed to `22001_gz_x650_skydrop`, added it to the list, rebuilt from scratch |
| Gazebo ran with no window | PX4 starts the Gazebo server headless (`gz sim -s`) | The run script starts the viewer with `gz sim -g` |
| Two Gazebo windows | A second viewer attached to the same server, most likely the one PX4 tries to open itself | The script's watchdog kills any extra viewer within a second |
| Processes left running after closing | PX4 and the server were not tied to the window | The script kills PX4 when the window closes, and every Gazebo process when PX4 exits |

Tricks that found these: `gz sim --version` to confirm Gazebo exists, `make -n px4_sitl` to see what a command really runs, running a launcher directly to see errors `make` hides, and `ls <airframes folder> | grep <number>` before picking an airframe number.

## Daily startup and shutdown routine

One script starts everything, and one command stops everything.

**Start**

1. Terminal 1: run `~/run_x650_v2.sh`. Wait for the Gazebo window with the X650 and the `pxh>` prompt.
2. Open QGroundControl the way it is installed on this PC. It connects by itself; the top bar should say Ready To Fly.
3. Optional check at `pxh>`: `param show CA_ROTOR0_PX` should read 0.2298.
4. Only if arming is refused with a power warning: `param set CBRK_SUPPLY_CHK 894281`.

**Stop**

1. If the drone is flying: `commander land` and wait for it to disarm.
2. Type `shutdown` at `pxh>`, or close the Gazebo window. Both close everything.
3. Close QGroundControl.
4. Confirm nothing is left: `ps aux | grep -E "gz sim|bin/px4" | grep -v grep` should print nothing.

**After editing files**

- Changed an airframe file: rebuild with `rm -rf build/px4_sitl_default && make px4_sitl` from `~/PX4-Autopilot`. Airframes are packed in at build time.
- Changed a model or world file: no rebuild. Restart the script.

## Open items and things to confirm

The battery is now chosen (10000 mAh) and the parachute is dropped. What remains: weigh the pack, move the setup to Omar's laptop, and add real building heights to the campus.

- [ ] **Battery chosen.** The model assumes a 6S 10000 mAh pack weighing 1.226 kg. Decided 29 Oct: the drone flies a 10000 mAh pack, not the 4S 5000 mAh in the report's Fig. 3.6. Weigh the real pack and confirm its cell count, since weight sets hover throttle and flight time.
- [ ] **First takeoff with the corrected airframe.** Not done yet; the first Phase 3 script covers it.
- [ ] **Placeholder campus.** The `uob_training_campus` buildings were generated by ChatGPT, not taken from real UOB plans. The teammate is getting the real plans from the university's construction department. They are 2D only, so each building's height has to be added by hand (Phase 8).
- [ ] **Two home positions.** The laptop used 34.365812, 35.782627; the teammate's PC uses 34.36628, 35.78218. Keep one and use it everywhere.
- [x] **Setup backed up.** The models, worlds, airframe, run script and flight scripts are in the project repo [soubjaki/uob-skydrop](https://github.com/soubjaki/uob-skydrop), with `simulation/install.sh` to put them into any PX4 checkout (30 Oct).
- [ ] **Possibly redundant viewer.** PX4 already tries to open a Gazebo viewer itself, and the script opens another. The watchdog removes the duplicate, so this works; it can be simplified later.
