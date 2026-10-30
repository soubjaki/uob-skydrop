# UOB SkyDrop — Full Simulation Roadmap (Manual Control → Full Autonomy)

This is your step-by-step path through the **entire simulation phase**, before you touch real hardware. It's split into phases. Do not skip a phase — each one is a checkpoint that the next phase depends on.

**Stack you'll be using** (matches your report's software section):
- Ubuntu 22.04 LTS
- PX4 Autopilot (SITL)
- Gazebo (the current PX4-integrated version, sometimes called "gz sim" — not old Gazebo Classic)
- ROS 2 Humble
- Micro XRCE-DDS Agent (bridges PX4 ⇄ ROS 2)
- QGroundControl
- Python 3, OpenCV, MAVSDK-Python (for scripted control)

---

## PHASE 0 — Machine Setup

### Step 0.1 — Choose your environment
You have three options. Pick one per teammate (doesn't need to be the same for all three):
- **Native Ubuntu 22.04** (dual-boot or dedicated machine) — best performance, fewest bugs. Recommended if possible.
- **VirtualBox/VMware VM running Ubuntu 22.04** — works, but Gazebo 3D rendering can be slow/laggy without GPU passthrough.
- **WSL2 on Windows 11 with Ubuntu 22.04** — works well for PX4+ROS2, but Gazebo GUI rendering requires WSLg (built into Windows 11) or an X server. More finicky to set up than native Linux.

Avoid macOS for this — PX4+Gazebo+ROS2 support on Mac is much rockier; if a teammate only has a Mac, have them use a VM or WSL2-equivalent isn't available, so a Linux VM is their only real option.

### Step 0.2 — Install Ubuntu 22.04
- Download the ISO from ubuntu.com, create a bootable USB (Rufus on Windows, or `dd`/BalenaEtcher), and install — or create the VM and install into it (allocate at least 4 CPU cores, 8GB RAM, 60GB disk, and enable 3D acceleration in VM settings).
- Update the system first:
```bash
sudo apt update && sudo apt upgrade -y
```

### Step 0.3 — Install basic tools
```bash
sudo apt install -y git curl wget build-essential python3-pip python3-venv
```

---

## PHASE 1 — Get PX4 + Gazebo Running (No ROS2 yet)

Goal of this phase: **see a drone sitting in a simulated world**, nothing more.

### Step 1.1 — Clone PX4-Autopilot
```bash
cd ~
git clone https://github.com/PX4/PX4-Autopilot.git --recursive
```
This will take a while (it's a large repo with submodules).

### Step 1.2 — Run PX4's setup script
This installs Gazebo, all build dependencies, and the toolchain in one shot.
```bash
bash ~/PX4-Autopilot/Tools/setup/ubuntu.sh
```
**Reboot your machine after this finishes.** It changes low-level permissions/groups.

### Step 1.3 — Build and launch PX4 SITL with Gazebo
```bash
cd ~/PX4-Autopilot
make px4_sitl
```
The first build takes 10–20 minutes. When it's done it should automatically launch Gazebo with a default quadcopter (the `x500` model — visually close enough to your X650 for now; PX4 doesn't ship an exact X650 sim model, so x500 is your stand-in airframe in simulation).

**Checkpoint:** You should see a Gazebo window with a small quadcopter sitting on a flat ground plane, and in the terminal, a `pxh>` PX4 shell prompt.

### Step 1.4 — Try it from the PX4 shell (sanity check only)
In the `pxh>` prompt that appeared:
```
commander takeoff
```
You should see the drone lift off in Gazebo. Then:
```
commander land
```
If this works, your simulator + firmware are correctly linked. Kill everything (`Ctrl+C`) before moving on.

---

## PHASE 2 — Manual Control via QGroundControl

This is your literal "flying it by hand" phase — the part you said you want to start with.

### Step 2.1 — Install QGroundControl
```bash
sudo usermod -aG dialout $USER
sudo apt-get remove modemmanager -y
sudo apt install gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-libav -y
sudo apt install libqt5gui5 -y
```
Log out and back in (group change). Then download the QGroundControl AppImage from https://qgroundcontrol.com/ (Ubuntu/Linux build), make it executable, and run it:
```bash
chmod +x ./QGroundControl.AppImage
./QGroundControl.AppImage
```

### Step 2.2 — Connect QGC to your running SITL instance
1. Launch PX4 SITL again (`make px4_sitl` from Phase 1.3) — leave Gazebo running.
2. Open QGroundControl. It **auto-detects** the SITL instance over UDP (localhost) within a few seconds — you'll see the vehicle icon populate and telemetry (battery %, GPS, altitude) start flowing.

**Checkpoint:** QGC shows "Ready to Fly" or similar status, with a map view showing your drone's simulated GPS position.

### Step 2.3 — Fly manually using QGC's virtual joystick
1. In QGC, go to **Application Settings → General** and enable **"Virtual Joystick"**.
2. A joystick overlay will appear on the main flight view.
3. Arm the drone (there's an arm switch/slider in QGC), then use the virtual joystick to throttle up, take off, move around, and land.

Alternative (recommended if you have one): plug in an actual **USB gamepad/RC-style joystick** (e.g., an Xbox controller or a dedicated flight joystick) — QGC auto-detects it under **Application Settings → General → Joystick**, and flying with a real stick teaches you far more about drone handling (pitch/roll/yaw/throttle feel) than the virtual on-screen one.

### Step 2.4 — Practice basic manual maneuvers
Spend real time here before moving on — this builds intuition you'll need to sanity-check your automation later:
- Take off, hover at a fixed altitude for 30 seconds without drifting.
- Fly a square pattern and land back near takeoff point.
- Practice a controlled descent and landing.
- Deliberately induce a "loss of control" scenario and recover (helps you understand failsafes later).

### Step 2.5 — Try PX4's built-in flight modes
In QGC, switch between modes (Manual/Stabilized → Position → Altitude) and feel the difference — Position mode uses GPS to hold location; this is the mode your later automation will build on top of.

---

## PHASE 3 — Move to Programmatic Control (Automation, Step 1: Scripted Missions)

Goal: fly the drone using **code**, not your hands — starting with the simplest possible automation.

### Step 3.1 — Install MAVSDK-Python
This is the easiest first entry point into automation — much simpler than full ROS2 for a first script.
```bash
python3 -m venv ~/skydrop-venv
source ~/skydrop-venv/bin/activate
pip install mavsdk
```

### Step 3.2 — Write your first automated flight script
Create `~/skydrop_scripts/basic_flight.py`:
```python
import asyncio
from mavsdk import System

async def run():
    drone = System()
    await drone.connect(system_address="udp://:14540")

    print("Waiting for drone connection...")
    async for state in drone.core.connection_state():
        if state.is_connected:
            print("Drone connected!")
            break

    print("Arming...")
    await drone.action.arm()

    print("Taking off...")
    await drone.action.takeoff()
    await asyncio.sleep(10)

    print("Landing...")
    await drone.action.land()

asyncio.run(run())
```
With PX4 SITL + Gazebo still running from Phase 1, run:
```bash
python3 ~/skydrop_scripts/basic_flight.py
```
**Checkpoint:** the drone arms, takes off, hovers 10 seconds, and lands — with zero manual input from you.

### Step 3.3 — Add waypoint navigation
Extend the script to fly to specific GPS offsets using `drone.action.goto_location(lat, lon, altitude, yaw)`. Start with small offsets (~0.0001° lat/lon ≈ 10m) around the home position so you can watch it in QGC's map view in real time.

### Step 3.4 — Simulate a basic delivery mission (no sensors yet)
Chain together: arm → takeoff → fly to "delivery point" (a hardcoded GPS offset) → hover 5s (simulating drop-off) → return to home → land. This is your first end-to-end automated mission — but it's still "blind" (no obstacle avoidance, no QR verification). That's what the rest of the phases add.

---

## PHASE 4 — Bring In ROS 2 (needed for your Jetson-side autonomy logic)

Your report's software architecture (Figure 3.7) — obstacle avoidance, sensor processing, QR verification — needs to run as ROS2 nodes talking to PX4, since that's the standard PX4 companion-computer architecture (and what your Jetson will run for real).

### Step 4.1 — Install ROS 2 Humble
```bash
sudo apt update && sudo apt install locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
sudo apt install software-properties-common -y
sudo add-apt-repository universe
sudo apt update && sudo apt install curl -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update && sudo apt upgrade -y
sudo apt install ros-humble-desktop ros-dev-tools -y
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

### Step 4.2 — Install the Micro XRCE-DDS Agent (the PX4 ⇄ ROS2 bridge)
```bash
cd ~
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent
mkdir build && cd build
cmake ..
make
sudo make install
sudo ldconfig /usr/local/lib/
```

### Step 4.3 — Set up your ROS2 workspace with PX4 message definitions
```bash
mkdir -p ~/skydrop_ws/src
cd ~/skydrop_ws/src
git clone https://github.com/PX4/px4_msgs.git
git clone https://github.com/PX4/px4_ros_com.git
cd ~/skydrop_ws
source /opt/ros/humble/setup.bash
colcon build
echo "source ~/skydrop_ws/install/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

### Step 4.4 — Run the full stack together (3 terminals)
**Terminal 1** — Gazebo + PX4:
```bash
cd ~/PX4-Autopilot
make px4_sitl
```
**Terminal 2** — the DDS agent (bridges PX4's internal uORB topics to ROS2 topics):
```bash
MicroXRCEAgent udp4 -p 8888
```
**Terminal 3** — verify ROS2 sees PX4 topics:
```bash
source ~/skydrop_ws/install/setup.bash
ros2 topic list
```
**Checkpoint:** you should see topics like `/fmu/out/vehicle_odometry`, `/fmu/in/vehicle_command`, etc.

### Step 4.5 — Write your first ROS2 "offboard control" node
This replaces your MAVSDK script with a ROS2-native equivalent (needed because your final obstacle-avoidance/QR nodes will all be ROS2 nodes talking to this same interface). PX4 provides an official example — clone and run it:
```bash
cd ~/skydrop_ws/src
git clone https://github.com/PX4/px4-offboard.git
cd ~/skydrop_ws
colcon build
source install/setup.bash
ros2 launch px4_offboard offboard_velocity_control.launch.py
```
Study this example closely — it's the template your future automated mission node will be built from (arm → switch to offboard mode → stream setpoints → take off → navigate → land).

---

## PHASE 5 — Add the Camera (Obstacle Avoidance Sensor)

### Step 5.1 — Add a depth-camera-equipped drone model
PX4's Gazebo integration includes drone models with sensors pre-attached (e.g., `x500_depth`, which has a simulated depth camera similar in function to your real RealSense D455). Launch with:
```bash
PX4_GZ_MODEL=x500_depth make px4_sitl
```

### Step 5.2 — Bridge the camera feed into ROS2
Install `ros_gz` (the Gazebo⇄ROS2 bridge) if not already present, then bridge the camera topic so you can subscribe to it from a ROS2 node, e.g.:
```bash
ros2 run ros_gz_bridge parameter_bridge /depth_camera@sensor_msgs/msg/Image@gz.msgs.Image
```

### Step 5.3 — View and process the feed with OpenCV
Install OpenCV + the ROS2↔OpenCV bridge:
```bash
sudo apt install ros-humble-cv-bridge python3-opencv -y
```
Write a small ROS2 subscriber node that grabs frames from `/depth_camera`, converts with `cv_bridge`, and displays with `cv2.imshow()`. **Checkpoint:** you see a live depth image window updating as the simulated drone moves.

### Step 5.4 — Write a basic reactive obstacle-avoidance node
Start simple: read the depth image, find the minimum distance in the central region of the frame, and if it's below a threshold, publish a "stop/divert" command instead of the planned forward velocity. This is intentionally crude — refine later with proper path-replanning (e.g., a simple potential-field or A* over a local costmap) once the basic reactive version works.

---

## PHASE 6 — QR/ArUco Precision Landing

### Step 6.1 — Place an ArUco marker in the simulated world
Create a custom Gazebo world file (a `.sdf` file) based on the default one, and add a flat textured model with an ArUco marker image (generate one with OpenCV's `cv2.aruco` module or online generators) as your "delivery pad."

### Step 6.2 — Detect the marker from the drone's camera
```bash
pip install opencv-contrib-python
```
Write a ROS2 node using `cv2.aruco.detectMarkers()` on the camera feed to find the marker's pixel position and estimate its pose relative to the drone (`cv2.aruco.estimatePoseSingleMarkers`).

### Step 6.3 — Two-stage landing logic (matches your report's risk mitigation plan)
1. GPS approach to within ~2m of the marker's known/estimated location.
2. Switch to vision-based fine approach: center the marker in-frame, descend slowly while continuously re-centering, and only complete the final drop when the marker is confidently detected and centered.

---

## PHASE 7 — Build Your Campus World

### Step 7.1 — Create a simplified 3D model of UOB campus
You don't need architectural precision — simple box/plane geometry for buildings, walkways, and delivery points is enough to test navigation logic and geofencing. Use Gazebo's SDF format directly, or model in **Blender** and export to a format Gazebo can import, then reference it in your custom world file.

### Step 7.2 — Add geofence boundaries
Set up a PX4 geofence (via QGC's **Plan** view, Geofence tab) matching your campus perimeter, so any bug that sends the drone outside the simulated campus triggers an automatic Return-to-Home — test that this actually works by deliberately commanding an out-of-bounds waypoint.

### Step 7.3 — Run full missions against this campus model
This is where your report's risk-mitigation item ("validate every waypoint mission in a SITL simulator mapped to the UOB campus 3-D model before live deployment") gets fulfilled directly — plan real delivery routes in QGC's mission planner over your campus model and fly them in SITL.

---

## PHASE 8 — Integrate Everything Into One Autonomous Mission

By now you have separate working pieces: automated takeoff/nav, obstacle avoidance, marker-based landing, a campus world. This phase wires them into the single mission described in your Figure 3.7.

### Step 8.1 — Build a mission state machine
Write a top-level ROS2 node (or a Python script coordinating your other nodes) implementing states: `IDLE → TAKEOFF → EN_ROUTE → OBSTACLE_CHECK → APPROACH_LANDING → PRECISION_LANDING → PAYLOAD_RELEASE → RETURN → LAND → IDLE`. Use a simple library like `smach` or just an explicit `if/elif` state variable — don't over-engineer this for a first version.

### Step 8.2 — Add the peripheral checks from your architecture
Layer in: battery-level check before committing to a mission (simulate battery drain if PX4's simulated battery model allows, or track elapsed flight time as a proxy), and a simulated QR-verification step (simulate "correct recipient" logic in code even though there's no real phone/app yet).

### Step 8.3 — Add failure injection and test your risk table directly
Your report already lists this — go through it deliberately in simulation:
- Kill the simulated GPS mid-flight (PX4 has failure injection commands via `pxh>` shell, e.g., `failure gps off`) — confirm RTH/failsafe behavior triggers.
- Cut telemetry link — confirm your defined behavior kicks in.
- Force a "low battery" condition — confirm the drone aborts/returns instead of continuing.

### Step 8.4 — Run repeatable, logged test missions
Use PX4's built-in flight log (`.ulg` files, viewable at https://review.px4.io) to review every simulated flight afterward — altitude profile, battery estimate, mode changes, errors. Build a habit of reviewing these logs after every mission run; this is exactly what you'll do with real flight logs later.

---

## PHASE 9 — Hardware-in-the-Loop (HIL) — the Bridge to Real Hardware

Once your full mission logic is solid and repeatable in pure software simulation:

### Step 9.1 — Set PX4 to HIL mode
Flash your real Pixhawk with PX4 firmware built with HIL support, and in QGC, switch the simulation connection from SITL to HIL — now the **real flight controller** runs your actual firmware and mission logic, but still reacts to a simulated physics/world environment instead of real motors.

### Step 9.2 — Validate identical behavior
Re-run your Phase 8 mission and failure-injection tests in HIL mode and confirm the physical Pixhawk behaves identically to pure SITL. Only once this matches should you move to your hardware/implementation phase.

---

## Suggested Order of Effort (given 3 team members)

- **Person A**: Phases 0–3 (environment, manual flight, first automation) → then owns Phase 8 (mission state machine/integration).
- **Person B**: Phase 4 (ROS2 bridge) → then Phase 5 (camera/obstacle avoidance).
- **Person C**: Phase 6 (QR/ArUco landing) → then Phase 7 (campus world + geofence).

Sync weekly (matches your report's risk-mitigation plan of weekly reviews with Dr. Karam) and integrate incrementally rather than each person building in isolation until the end — integration delays are literally item #12 in your own risk table.
