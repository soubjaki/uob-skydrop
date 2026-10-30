"""Shared helpers for the SkyDrop flight scripts (MAVSDK classic API)."""

import asyncio
import math

from mavsdk_grpc import System

# PX4 SITL sends MAVLink for offboard apps to UDP port 14540.
PX4_ADDRESS = "udpin://0.0.0.0:14540"

METERS_PER_DEG_LAT = 111_320.0


async def first(stream, test=lambda _: True):
    """Return the first item of a telemetry stream that passes `test`."""
    async for item in stream:
        if test(item):
            return item


async def connect(address=PX4_ADDRESS):
    """Connect to PX4 and wait until it has a position and a home point."""
    drone = System()
    await drone.connect(system_address=address)

    print("Waiting for PX4...")
    await first(drone.core.connection_state(), lambda s: s.is_connected)
    print("Connected. Waiting for a position estimate...")
    await first(drone.telemetry.health(),
                lambda h: h.is_global_position_ok and h.is_home_position_ok)
    print("Position estimate OK")
    return drone


async def take_off(drone, altitude_m, timeout_s=60):
    """Arm, take off, and wait until the drone is near the target height."""
    await drone.action.set_takeoff_altitude(altitude_m)
    print("Arming")
    await drone.action.arm()
    print(f"Taking off to {altitude_m:.0f} m")
    await drone.action.takeoff()
    await asyncio.wait_for(
        first(drone.telemetry.position(),
              lambda p: p.relative_altitude_m >= 0.95 * altitude_m),
        timeout_s)
    print("Reached takeoff altitude")


async def wait_until_disarmed(drone):
    await first(drone.telemetry.armed(), lambda armed: not armed)


def offset_position(lat_deg, lon_deg, north_m, east_m):
    """Latitude/longitude of a point north_m / east_m away (small distances)."""
    dlat = north_m / METERS_PER_DEG_LAT
    dlon = east_m / (METERS_PER_DEG_LAT * math.cos(math.radians(lat_deg)))
    return lat_deg + dlat, lon_deg + dlon


def horizontal_distance_m(lat1, lon1, lat2, lon2):
    """Flat-earth distance in meters; accurate enough within a campus."""
    north = (lat2 - lat1) * METERS_PER_DEG_LAT
    east = (lon2 - lon1) * METERS_PER_DEG_LAT * math.cos(math.radians(lat1))
    return math.hypot(north, east)
