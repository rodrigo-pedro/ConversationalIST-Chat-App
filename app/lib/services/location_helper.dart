import 'package:geolocator/geolocator.dart';

class LocationHelper {
  static userInRange(double userLat, double userLon, double roomLat, double roomLon, radius) {
    return Geolocator.distanceBetween(
        userLat,
        userLon,
        roomLat,
        roomLon) <=
        radius;
  }

  static getCurrentPosition() async {
    var permissions = await _checkLocationPermissions();
    if (permissions) {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } else {
      return null;
    }
  }

  static _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }


    return Future.value(true);
  }
}