# UOB SkyDrop — Simulation Roadmap: Next Steps

Oct 29, 2026 · @Omar

## Starting point

The plan starts from the verified X650 on the teammate's PC, moves it to Omar's laptop (native Ubuntu 24.04), where all further work happens, and adds the drone's attachments one phase at a time: the Jetson's software role in Phase 4, the depth camera in Phase 5, a landing camera in Phase 6, and the gripper, package and Jetson weight in Phase 7. The parachute has been dropped from the design.

Phases 3–6 keep their earlier numbers. A new Phase 7 covers the payload hardware, so the campus world moves to Phase 8, integration to Phase 9, and hardware-in-the-loop to Phase 10.

Each phase ends with a check that must pass before the next one starts:

1. **Phase 3, scripted flight.** A Python script flies takeoff, waypoint, return and landing with no hands on the controls.
2. **Phase 4, ROS 2.** A ROS 2 node flies the same mission.
3. **Phase 5, depth camera and avoidance.** The drone stops at least 2 m before a box in its path, every time.
4. **Phase 6, precision landing.** It lands within 0.3 m of the marker center in 9 of 10 runs (suggested target).
5. **Phase 7, payload hardware.** The fully loaded model hovers steadily and drops the package only on command.
6. **Phase 8, campus world.** Missions fly over the real campus layout, and leaving the geofence triggers a return.
7. **Phase 9, integration.** Ten full deliveries in a row, and every failure test ends safely.
8. **Phase 10, hardware.** The real Pixhawk and Jetson run the same software, and the real drone hovers like the model.

Before Phase 3, move the setup to Omar's laptop (next section) and keep it in a team Git repo.

## Before Phase 3: set up Omar's laptop from the project repo

Everything the simulation needs now lives in the project repo, [soubjaki/uob-skydrop](https://github.com/soubjaki/uob-skydrop): the X650 models, the worlds, the 22001 airframe, the launch script and the flight scripts. On the laptop (native Ubuntu 24.04), install PX4 at the same commit as the teammate's PC, then let the repo's install script put the files in place. That PX4 commit was test-built on Ubuntu 24.04 on 30 Oct.

1. Install PX4 at the pinned commit and its dependencies, then reboot:

```bash
git clone --recursive https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot
cd ~/PX4-Autopilot && git checkout fe87271f9c && git submodule update --init --recursive
bash ./Tools/setup/ubuntu.sh
```

2. Clone the repo, install the project files and build:

```bash
git clone https://github.com/soubjaki/uob-skydrop.git ~/uob-skydrop
~/uob-skydrop/simulation/install.sh
cd ~/PX4-Autopilot && make px4_sitl
```

3. Install QGroundControl (steps in the repo's `docs/setup.md`) and launch with `~/uob-skydrop/simulation/run_x650_v2.sh`.
4. Optional, on the teammate's PC: if anything was edited there after the 23 Sep archive, clone the repo there, run `simulation/sync_from_px4.sh`, and push the changes.

Done when: on the laptop, `param show CA_ROTOR0_PX` reads 0.2298 and QGC shows Ready To Fly. From then on, edit models, worlds and the airframe in the repo, run `install.sh`, and commit.

## Phase 3: scripted flight with MAVSDK-Python

Phase 3 replaces your hands with a Python script: first a takeoff and landing, then a flight to a drop point and back. Simulator in terminal 1, script in terminal 2.

**3.1 Create a Python environment.** Ubuntu 24.04 blocks pip installs into the system Python 3.12, so use a venv.

```bash
sudo apt install -y python3-venv
python3 -m venv ~/skydrop-venv
```

**3.2 Install MAVSDK** (needs internet once) from the repo's `requirements.txt`, which uses `mavsdk-grpc`. Do not run `pip install mavsdk`: since v4 that package is a different API and the scripts fail with it.

```bash
source ~/skydrop-venv/bin/activate
pip install -r ~/uob-skydrop/scripts/requirements.txt
```

**3.3 First flight: take off, hover, land.** Start `~/uob-skydrop/simulation/run_x650_v2.sh` and QGroundControl, then in a second terminal:

```bash
source ~/skydrop-venv/bin/activate
cd ~/uob-skydrop && python scripts/basic_flight.py
```

The X650 should climb to 10 m, hold still for 10 s, land and disarm. This is the first flight of the corrected airframe, so watch for drift or wobble.

**3.4 Delivery mission.** `python scripts/mission.py` takes off to 20 m, flies 50 m north, hovers 10 s as a stand-in for the release, then returns home and lands. Change the drop point and altitude at the top of the file. If the drop point is not reached within 120 s, it returns home instead.

Both scripts were test-flown on 30 Oct against PX4 at the pinned commit, using PX4's built-in quad simulator (SIH) at the UOB home position: about 45 s and 95 s. Running them on the X650 Gazebo model is the remaining check.

**3.5 Read the flight log.** Every flight writes a `.ulg` file under `~/PX4-Autopilot/build/px4_sitl_default/rootfs/fs/log/`. Upload it to PX4 Flight Review (review.px4.io) and check that altitude follows the setpoint and hover throttle sits near 0.64.

**Done when:** `mission.py` completes three runs in a row on the X650 model with no manual input.

## Phase 4: ROS 2 and the PX4 bridge

Phase 4 builds the Jetson's software side: ROS 2 nodes that talk to PX4. In simulation they run on the PC; on the real drone the same nodes run on the Jetson. The Jetson is never a physical part in the simulator, only its job.

**4.1 Install ROS 2** Jazzy, the version for Ubuntu 24.04, following the official ROS 2 apt instructions, then:

```bash
sudo apt install -y ros-jazzy-desktop ros-dev-tools
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
```

Jazzy uses Ubuntu 24.04's own Python 3.12, so no PATH fix is needed. Never build ROS inside the Phase 3 venv; deactivate it in ROS terminals.

**4.2 Build the Micro XRCE-DDS Agent**, the bridge between PX4 and ROS 2. PX4's ROS 2 guide pins a specific agent version (v2.4.x as far as I know); clone the tag it names.

```bash
cd ~ && git clone -b v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent && mkdir build && cd build
cmake .. && make && sudo make install && sudo ldconfig /usr/local/lib/
```

**4.3 Create the workspace.** `px4_msgs` must match the PX4 version. The laptop runs the same PX4 commit as the teammate's PC (main, v1.18 beta), so use the `main` branch.

```bash
mkdir -p ~/skydrop_ws/src && cd ~/skydrop_ws/src
git clone https://github.com/PX4/px4_msgs.git
git clone https://github.com/PX4/px4_ros_com.git
cd ~/skydrop_ws && colcon build
```

**4.4 Run the three pieces.** PX4 already starts its side of the bridge on UDP port 8888 at boot.

1. Terminal 1: `~/uob-skydrop/simulation/run_x650_v2.sh`
2. Terminal 2: `MicroXRCEAgent udp4 -p 8888`
3. Terminal 3: `source ~/skydrop_ws/install/setup.bash && ros2 topic list`

You should see topics such as `/fmu/out/vehicle_odometry` and `/fmu/in/vehicle_command`. If topics appear but nodes crash or values look wrong, a `px4_msgs` version mismatch is the usual cause.

**4.5 Fly the stock offboard example:** `ros2 run px4_ros_com offboard_control`. It arms, switches to offboard mode and holds a point above home.

**4.6 Port the Phase 3 mission to a ROS 2 Python node.** It publishes `OffboardControlMode` and `TrajectorySetpoint` at least 10 times a second and sends `VehicleCommand` to arm, change mode and land. This node grows into the mission controller in Phase 9.

**Done when:** your own ROS 2 node flies takeoff, waypoint and landing. Reference: [PX4 ROS 2 user guide](https://docs.px4.io/v1.18/en/ros2/user_guide).

## Phase 5: depth camera and obstacle avoidance

Phase 5 mounts a simulated RealSense D455 on the X650 and writes the node that stops the drone before obstacles. The D455 sees 87° × 58° and works best from 0.6 m to 6 m ([Intel](https://store.intelrealsense.com/buy-intel-realsense-depth-camera-d455.html)).

**5.1 Copy the model** so the working one stays untouched.

```bash
cd ~/uob-skydrop/simulation/models
cp -r x650_skydrop_v2 x650_skydrop_v2_depth
```

In the copy, rename the model to `x650_skydrop_v2_depth` in both `model.sdf` and `model.config`.

**5.2 Add the camera.** Inside `<model>` in the copy's `model.sdf`, after the `<include>`, add:

```xml
<link name="d455_link">
  <pose>0.12 0 0.03 0 0 0</pose>  <!-- move to your real mount point -->
  <inertial>
    <mass>0.1</mass>  <!-- placeholder: put your weighed D455 + mount here -->
    <inertia><ixx>1e-4</ixx><iyy>1e-4</iyy><izz>1e-4</izz></inertia>
  </inertial>
  <sensor name="d455_depth" type="depth_camera">
    <always_on>1</always_on>
    <update_rate>30</update_rate>
    <topic>d455/depth</topic>
    <camera>
      <horizontal_fov>1.518</horizontal_fov>  <!-- 87 degrees -->
      <image><width>848</width><height>480</height><format>R_FLOAT32</format></image>
      <clip><near>0.6</near><far>6.0</far></clip>
    </camera>
  </sensor>
</link>
<joint name="d455_joint" type="fixed">
  <parent>base_link</parent>
  <child>d455_link</child>
</joint>
```

At 848 × 480 the vertical view works out to about 57°, close to the real 58°.

**5.3 Launch the camera model.** Copy the run script to `simulation/run_x650_depth.sh` and change one line to `PX4_SIM_MODEL=gz_x650_skydrop_v2_depth`. Run install.sh so PX4 gets the new model. The 22001 airframe still fits, since the rotors did not move.

**5.4 Check the image exists:** `gz topic -l | grep d455`. If nothing appears, look at the world: `uob_training.sdf` has no plugins of its own and relies on PX4's default server config to load the sensors system that renders cameras. If that is missing, add the `gz-sim-sensors-system` plugin (ogre2 renderer) to the world.

**5.5 Bring the image into ROS 2.** Install the ROS 2–Gazebo bridge (on Jazzy it pairs with Gazebo Harmonic), then bridge and view:

```bash
sudo apt install -y ros-jazzy-ros-gz
ros2 run ros_gz_bridge parameter_bridge /d455/depth@sensor_msgs/msg/Image[gz.msgs.Image
ros2 run rqt_image_view rqt_image_view
```

**5.6 Write the avoidance node.**

1. Version 1, stop: read the central part of the depth image; if the nearest point is under 3 m while moving forward, send a hold setpoint until the path clears.
2. Version 2, go around: climb or sidestep, then rejoin the route.
3. Alternative: convert the depth image to an `ObstacleDistance` message on `/fmu/in/obstacle_distance` and let PX4's built-in collision prevention (`CP_DIST`) do the stopping in Position mode.

**5.7 Test it.** Place boxes on the route with Gazebo's box tool and fly the mission at 3 m/s, then 5 m/s.

Speed limit to note for the report: the camera sees 6 m ahead, and at the report's 10 m/s target that is 0.6 s of warning, too short to stop. Either cruise above obstacles or cap speed at about 3–4 m/s while avoidance is active.

**Done when:** the drone stops at least 2 m before a box, every run, at 3 and 5 m/s.

## Phase 6: precision landing with markers

Phase 6 makes the drone land on a marker pad instead of a GPS point, using the report's two-stage plan: GPS to within 2 m, then camera-guided descent.

**6.1 Decide the landing camera.** The D455 faces forward, so it cannot see a pad below the drone. Either add a small down-facing camera (keeps forward avoidance) or tilt the D455 (loses it). Adding one is the usual choice, and it adds a part to the bill of materials. In the simulator, copy the down-facing camera block from PX4's stock `x500_mono_cam_down` model into your X650 copy.

**6.2 Make the marker.** In the Phase 3 venv:

```bash
pip install opencv-contrib-python
python -c "import cv2; d=cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50); cv2.imwrite('marker0.png', cv2.aruco.generateImageMarker(d, 0, 800))"
```

The report sets a 20 cm minimum marker size. Start at 0.5 m so it is easy to see from 8 m up, then test at 20 cm.

**6.3 Put a pad in the world.** Create a model `landing_pad_0`: a static box 0.5 × 0.5 × 0.01 m with `marker0.png` as its top texture. Add it to a copy of `uob_training.sdf` at a delivery spot with an `<include>`.

**6.4 Detection node.** A ROS 2 node reads the down camera's image and `camera_info`, finds the marker with `cv2.aruco.ArucoDetector`, and computes the drone's offset from the pad in meters with `cv2.solvePnP`.

**6.5 Landing logic.**

1. Fly to the pad's GPS position at 8 m.
2. Once the marker is seen, descend while correcting sideways; slow down below 2 m.
3. If the marker is lost for more than 2 s, climb back and retry, up to 3 times, then return to base (the report's mitigation).

Alternative: this PX4 build has a vision target estimator and a precision-land mode (both appear in the boot log and build). Feeding them your marker detections can replace hand-written descent logic; check PX4's precision landing docs for the message they expect.

**6.6 Stand in for QR verification.** The real recipient scans a QR code before release. For now, a test script answers "verified" or "rejected", and release (Phase 7) waits for it.

**6.7 Measure.** Compare the drone's final pose with the pad's pose from Gazebo over 10 landings.

**Done when:** 9 of 10 landings end within 0.3 m of the marker center with the 20 cm marker (suggested target; set your own if the report needs one).

## Phase 7: payload hardware and delivery logic

Phase 7 makes the model carry everything the real drone will carry: Jetson weight, gripper and package, so hover and flight-time numbers become honest.

**7.1 Weigh the real parts** (or use datasheet values, labeled as estimates): Jetson with case and cables, D455 with mount, printed gripper with servo (the teammate is designing and printing it), and the 10000 mAh battery.

**7.2 Add the Jetson as a weight.** A fixed box link on the top plate with the weighed mass. No sensor; its computing is not simulated, only its weight.

**7.3 Add the gripper and a package.** The gripper is a fixed link under the frame. The package is a separate box model, at most 1 kg (the report's cap), held by Gazebo's detachable-joint system:

```xml
<plugin filename="gz-sim-detachable-joint-system" name="gz::sim::systems::DetachableJoint">
  <parent_link>gripper_link</parent_link>
  <child_model>package</child_model>
  <child_link>package_link</child_link>
  <detach_topic>/skydrop/release</detach_topic>
</plugin>
```

Release by hand to test it:

```bash
gz topic -t /skydrop/release -m gz.msgs.Empty -p 'unused: true'
```

From ROS 2, bridge it with `/skydrop/release@std_msgs/msg/Empty]gz.msgs.Empty`. On the real drone the gripper servo can be wired to the Pixhawk and driven through PX4's gripper support instead.

**7.4 Release rules** (from the report's design). The node releases only when all three hold:

1. PX4 reports the drone landed.
2. The landing position matches the pad (marker seen and centered).
3. QR verification passed (the Phase 6 stand-in for now).

**7.5 Weight check before takeoff.** Refuse to arm if the package exceeds 1 kg (report risk 22). In simulation, read the mass from the mission config; on the real drone it comes from a load cell.

**7.6 Recheck hover and flight time.** The extra weight raises hover throttle. Read the settled value from PX4's hover thrust estimate in Flight Review; if it is far from 0.644, update `MPC_THR_HOVER` in the 22001 airframe file and rebuild. The simulator's battery drains on a fixed timer, not by physics, so estimate flight time separately from hover thrust and motor data.

**Done when:** the fully loaded model hovers steadily and the package drops only when all three release rules hold.

## Phase 8: realistic UOB campus world and geofence

Phase 8 swaps the ChatGPT-generated placeholder campus for UOB's real buildings and terrain, then fences the drone inside campus.

**8.1 Get real geometry**, best source first:

1. The university's building plans, which the teammate is getting from the construction department. They are 2D only, so add each building's height by hand: floors × about 3 m, or measured on site.
2. OpenStreetMap building footprints, imported into Blender with the BlenderGIS add-on.
3. Boxes drawn from the satellite map: measured footprints, height of about 3 m per floor.

**8.2 Add the terrain.** UOB sits on a hillside, and a flat ground plane hides that. "20 m above home" can be much less above the ground on the uphill side. BlenderGIS can also pull elevation data to build a terrain mesh.

**8.3 Prepare the model in Blender. Trace each 2D plan's outline and extrude it to that building's height.** Export the buildings as `.dae` or `.obj` for looks; the cameras see this mesh. Add simple box collisions per building for physics; detailed meshes make slow, buggy collisions.

**8.4 Build the world.** Package it as a model `uob_campus` and make `uob_campus.sdf` from a copy of `uob_training.sdf`. Keep its origin (lat 34.36628, lon 35.78218, alt 262 m) and line the model up with that point.

**8.5 Place delivery pads** (the Phase 6 pad model) at the real stops the team picks, such as the cafeteria and faculty buildings named in the report's stakeholder list.

**8.6 Set the geofence.** In QGC's Plan view, draw the campus boundary on the Geofence tab and upload it. Set the breach action (`GF_ACTION`) to Return. Test it with a waypoint outside the fence.

**8.7 Pick cruise altitude.** The report requires at least 10 m above pedestrian areas. Fly at least 10 m above the tallest roof on each route, measured from the terrain, not from home.

**Done when:** missions fly over the real campus layout and terrain, and crossing the fence makes the drone return.

## Phase 9: full mission integration and failure testing

Phase 9 joins the pieces into one delivery controller, then breaks things on purpose to prove the drone fails safe. The results become the testing chapter of the final report.

**9.1 Mission controller node.** Grow the Phase 4 node into a state machine that runs these states in order:

1. Idle
2. Preflight checks
3. Takeoff
4. Cruise, with avoidance on
5. Approach pad
6. Precision landing
7. Verify recipient
8. Release package
9. Takeoff and return
10. Land and idle

Abort rules, active in every state: low battery, geofence breach or lost link means return to base; marker not found after 3 tries means return with the package; a blocked path means hold, then return.

**9.2 Preflight checks** from the report: enough battery for the round trip plus a 30% reserve, wind at most 8 m/s, package at most 1 kg, GPS fix, geofence loaded.

**9.3 Battery failsafe.** In QGC, Vehicle Configuration, Safety page: set the low-battery level to 30% and its action to Return.

**9.4 Wind.** Add Gazebo's wind effects system and a `<wind>` element to the campus world. Test at 4 m/s and 8 m/s.

**9.5 Failure tests.** Enable injection once with `param set SYS_FAILURE_EN 1`, then run each test from `pxh>` or the setup shown:

| Test | How to cause it | Expected result | Report risk |
| --- | --- | --- | --- |
| GPS loss | `failure gps off` | Holds or lands safely, no flyaway | 8 |
| Telemetry loss | Close QGroundControl mid-flight | Returns home (`NAV_DLL_ACT` = 2) | 5 |
| Low battery | Shorten the simulated battery (`SIM_BAT_DRAIN`) | Returns at 30% | 21 |
| Motor failure | `failure motor off -i 1` | Drone goes down; with no parachute there is no recovery, so log it as an accepted risk | 1, 15 |
| High wind | Wind at 8 m/s | Holds track, or refuses to start | 18 |
| Overweight package | 1.2 kg package | Refuses to arm | 22 |
| Wrong delivery point | Wrong coordinates in the mission | No pad found, returns, no release | 20 |
| Obstacle on route | Box on the path | Stops or goes around | 7 |

**9.6 Record results.** For each run log time, distance, landing error, battery used and events, from the Flight Review logs.

Not simulated: the battery-swap station (ground equipment) and noise.

**Done when:** ten full deliveries in a row succeed, and every failure test ends with the drone safe.

## Phase 10: hardware-in-the-loop and handoff to the real drone

Phase 10 moves the same software onto the real Pixhawk and Jetson, one piece at a time, before anything flies.

**10.1 Flash the same firmware.** Build PX4 commit `fe87271f9c` for your board; the report's photo shows a Pixhawk 6X, so `make px4_fmu-v6x_default` (confirm the board first). Flash it from QGC's Firmware page using a custom file.

**10.2 Set up a hardware airframe.** The 22001 file is for simulation only and does not go on the board. Start from PX4's closest stock quadrotor airframe in QGC, then set rotor positions from the **measured** real frame and hover throttle from Phase 7.

**10.3 Check the hardware-in-the-loop option.** PX4's HITL guide has mostly covered Gazebo Classic and jMAVSim; check whether it supports the new Gazebo before planning around it. PX4 lists SIH, simulation running on the autopilot itself, as an alternative to HITL ([PX4 simulation docs](https://docs.px4.io/v1.14/en/simulation/)). SIH uses generic quad physics rather than the X650 model, but it proves the real board runs the mission logic.

**10.4 Jetson in the loop.** Install JetPack and ROS 2 on the Jetson. JetPack 6 is Ubuntu 22.04, so it gets Humble while the laptop runs Jazzy; keep the nodes free of distro-specific code, or run Jazzy in a Docker container on the Jetson. Run the Phase 4–9 nodes on it, connected by Ethernet to the PC running the simulator and the bridge agent. Check that camera and detection nodes keep up their frame rate.

**10.5 Connect Jetson and Pixhawk.** Use a serial telemetry port or Ethernet, with the bridge agent running on the Jetson.

**10.6 Bench tests, propellers off.**

- [ ] Sensor calibration in QGC
- [ ] Motor order and direction (Actuators test)
- [ ] RC loss and telemetry loss failsafes
- [ ] Gripper servo opens and closes

**10.7 First flights**, following the report's risk plan:

1. Request the campus flight permit early (report risk 14).
2. Tethered or under 0.5 m hover.
3. Low manual flight, then a short autonomous hop, with a 20 m exclusion zone.

**10.8 Compare real and simulated flights.** Check hover throttle, attitude response and flight time, then update the model so the simulator stays trustworthy.

**Done when:** the real drone hovers steadily, its hover throttle is within about 10% of the model's, and the mission software runs unchanged on the Jetson.

## Attachment checklist

Every part the real drone carries joins the model by Phase 7; the real Pixhawk and Jetson take over in Phase 10. Update the Status column as each lands.

| Component | Joins the model in | How it is modeled | Needed first | Status |
| --- | --- | --- | --- | --- |
| Jetson (software role) | Phase 4 | ROS 2 nodes running on the PC | ROS 2 and the bridge working | Not started |
| Depth camera (D455) | Phase 5 | Depth-camera sensor link, 87° view, 0.6–6 m | Weighed mass, mount position | Not started |
| Down-facing landing camera | Phase 6 | Camera link pointing down | Team decision to add one | Not started |
| Jetson (weight) | Phase 7 | Fixed box link on the top plate | Weighed mass with case and cables | Not started |
| Gripper | Phase 7 | Fixed link plus a detachable joint | Printed part from the teammate, servo mass | Not started |
| Package | Phase 7 | Separate box model, at most 1 kg | Test masses, e.g. 0.5 and 1 kg | Not started |
| Real battery | Phase 7 | Battery block updated to the real mass and size | 10000 mAh pack chosen; weigh it | Not started |
| Wind | Phase 9 | Wind system in the campus world | 8 m/s limit from the report | Not started |
| Real Pixhawk and Jetson | Phase 10 | SIH on the board, Jetson in the loop | Phases 3–9 done | Not started |
