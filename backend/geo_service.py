"""
Geofencing Service
Handles GPS coordinate validation and distance calculations
"""
import math
from typing import Tuple, Optional, List
from database import Location


class GeoService:
    """Service for geolocation and distance calculations"""

    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance between two GPS coordinates using Haversine formula

        Args:
            lat1: Latitude of point 1
            lon1: Longitude of point 1
            lat2: Latitude of point 2
            lon2: Longitude of point 2

        Returns:
            Distance in meters
        """
        # Earth's radius in meters
        R = 6371000

        # Convert latitude and longitude to radians
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)

        # Haversine formula
        a = (math.sin(delta_lat / 2) ** 2 +
             math.cos(lat1_rad) * math.cos(lat2_rad) *
             math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        distance = R * c
        return distance

    @staticmethod
    def verify_location(
        lat: float,
        lon: float,
        allowed_locations: List[Location]
    ) -> Tuple[bool, Optional[float], Optional[str]]:
        """
        Verify if GPS coordinates are within any allowed location's radius

        Args:
            lat: User's latitude
            lon: User's longitude
            allowed_locations: List of allowed Location objects

        Returns:
            Tuple of (is_verified, distance_from_nearest, nearest_location_name)
        """
        if not allowed_locations:
            # No geofencing configured, allow all locations
            return True, None, None

        min_distance = float('inf')
        nearest_location_name = None
        is_within_range = False

        for location in allowed_locations:
            if not location.is_active:
                continue

            distance = GeoService.calculate_distance(
                lat, lon,
                location.latitude, location.longitude
            )

            # Track nearest location
            if distance < min_distance:
                min_distance = distance
                nearest_location_name = location.name

            # Check if within allowed radius
            if distance <= location.radius_meters:
                is_within_range = True

        return is_within_range, min_distance, nearest_location_name

    @staticmethod
    def validate_coordinates(lat: Optional[float], lon: Optional[float]) -> bool:
        """
        Validate GPS coordinates are within valid ranges

        Args:
            lat: Latitude (-90 to 90)
            lon: Longitude (-180 to 180)

        Returns:
            True if valid, False otherwise
        """
        if lat is None or lon is None:
            return False

        if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
            return False

        if lat < -90 or lat > 90:
            return False

        if lon < -180 or lon > 180:
            return False

        return True
