"""Phase 3, step 2: a basic delivery flight with no sensors yet.

Takes off, flies to a drop point, hovers (stand-in for the package release),
then returns home and lands. If the drop point is not reached in time, the
drone returns home instead of hanging.

Run the simulator first (./simulation/run_x650_v2.sh), then:
    source ~/skydrop-venv/bin/activate
    python scripts/mission.py
"""

import asyncio

from common import (connect, first, horizontal_distance_m, offset_position,
                    take_off, wait_until_disarmed)

CRUISE_ALT_M = 20.0        # above home
DROP_NORTH_M = 50.0        # drop point relative to home
DROP_EAST_M = 0.0
ARRIVAL_RADIUS_M = 2.0     # report's GPS approach tolerance
LEG_TIMEOUT_S = 120
DROP_HOVER_S = 10


async def main():
    drone = await connect()
    home = await first(drone.telemetry.home())
    print(f"Home: {home.latitude_deg:.6f}, {home.longitude_deg:.6f}, "
          f"{home.absolute_altitude_m:.1f} m")

    await take_off(drone, CRUISE_ALT_M)

    drop_lat, drop_lon = offset_position(home.latitude_deg, home.longitude_deg,
                                         DROP_NORTH_M, DROP_EAST_M)
    print(f"Flying to drop point {DROP_NORTH_M:.0f} m N, {DROP_EAST_M:.0f} m E")
    await drone.action.goto_location(drop_lat, drop_lon,
                                     home.absolute_altitude_m + CRUISE_ALT_M, 0)
    try:
        await asyncio.wait_for(
            first(drone.telemetry.position(),
                  lambda p: horizontal_distance_m(p.latitude_deg, p.longitude_deg,
                                                  drop_lat, drop_lon)
                  < ARRIVAL_RADIUS_M),
            LEG_TIMEOUT_S)
        print(f"At drop point. Hovering {DROP_HOVER_S} s (release stand-in)")
        await asyncio.sleep(DROP_HOVER_S)
    except asyncio.TimeoutError:
        print("Drop point not reached in time - aborting")

    print("Returning home")
    await drone.action.return_to_launch()
    await wait_until_disarmed(drone)
    print("Mission complete: landed and disarmed")


if __name__ == "__main__":
    asyncio.run(main())
