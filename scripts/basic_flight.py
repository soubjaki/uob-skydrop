"""Phase 3, step 1: take off, hover, land - with no hands on the controls.

Run the simulator first (./simulation/run_x650_v2.sh), then:
    source ~/skydrop-venv/bin/activate
    python scripts/basic_flight.py
"""

import asyncio

from common import connect, take_off, wait_until_disarmed

TAKEOFF_ALT_M = 10.0
HOVER_S = 10


async def main():
    drone = await connect()
    await take_off(drone, TAKEOFF_ALT_M)

    print(f"Hovering for {HOVER_S} s")
    await asyncio.sleep(HOVER_S)

    print("Landing")
    await drone.action.land()
    await wait_until_disarmed(drone)
    print("Landed and disarmed")


if __name__ == "__main__":
    asyncio.run(main())
