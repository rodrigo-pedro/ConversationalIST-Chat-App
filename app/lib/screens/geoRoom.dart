import 'dart:async';

import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class Geo extends StatefulWidget {
  const Geo({Key? key}) : super(key: key);

  @override
  _GeoState createState() => _GeoState();
}

class _GeoState extends State<Geo> {
  late GoogleMapController _mapController;
  final username = Hive.box('box').get('username');
  late LatLng _center;
  double _radius = 10000;

  final _markers = <Marker>{};
  final _circles = <Circle>{};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  void dispose() {
    super.dispose();
    _mapController.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String chatroomName = ModalRoute.of(context)!.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chooseLocation),
        actions: [
          IconButton(
              onPressed: () async {
                Prediction? p = await PlacesAutocomplete.show(
                    offset: 0,
                    radius: 100000,
                    types: [],
                    strictbounds: false,
                    context: context,
                    apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!,
                    mode: Mode.overlay,
                    language: "en",
                    components: [Component(Component.country, "us"), Component(Component.country, "pt")]);

                if (p != null) {
                  GoogleMapsPlaces places = GoogleMapsPlaces(
                    apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!,
                    apiHeaders: await const GoogleApiHeaders().getHeaders(),
                  );
                  PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);
                  final latLng = LatLng(detail.result.geometry!.location.lat, detail.result.geometry!.location.lng);
                  _markers.clear();
                  _circles.clear();
                  if (!mounted) return;
                  _markers.add(Marker(
                      markerId: const MarkerId('new_location'),
                      position: latLng,
                      infoWindow: InfoWindow(
                        title: AppLocalizations.of(context)!.newLocation,
                        snippet: AppLocalizations.of(context)!.desiredLocation,
                      )));
                  _circles.add(Circle(
                      circleId: const CircleId('circle'),
                      center: latLng,
                      radius: _radius,
                      fillColor: Colors.blue.withOpacity(0.2),
                      strokeColor: Colors.blue,
                      strokeWidth: 4));
                  _mapController.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: latLng,
                        zoom: 15,
                      ),
                    ),
                  );
                  setState(() {});
                }


              },
              icon: const Icon(Icons.search)),
          IconButton(
              onPressed: () {
                FirestoreHelper.createGeorestrictedChatroom(chatroomName, username, _markers.first.position, _radius);
                Navigator.popUntil(context, ModalRoute.withName("/home"));
              },
              icon: const Icon(Icons.check)),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<Position>(
            future: _determinePosition(),
            // a previously-obtained Future<String> or null
            builder: (BuildContext context, AsyncSnapshot<Position> snapshot) {
              if (snapshot.hasData) {
                _center = LatLng(snapshot.data!.latitude, snapshot.data!.longitude);
                if (_markers.isEmpty) {
                  _markers.add(Marker(
                    markerId: const MarkerId('current_location'),
                    position: LatLng(snapshot.data!.latitude, snapshot.data!.longitude),
                    infoWindow: InfoWindow(
                      title: AppLocalizations.of(context)!.currentLocation,
                      snippet: AppLocalizations.of(context)!.whereYouAre,
                    ),
                  ));

                  _circles.add(Circle(
                      circleId: const CircleId('circle'),
                      center: LatLng(_markers.first.position.latitude, _markers.first.position.longitude),
                      radius: _radius,
                      fillColor: Colors.blue.withOpacity(0.2),
                      strokeColor: Colors.blue,
                      strokeWidth: 4));
                }

                return GoogleMap(
                  zoomControlsEnabled: false,
                  markers: _markers,
                  onLongPress: (pos) {
                    _markers.clear();
                    _circles.clear();
                    _markers.add(Marker(
                        markerId: const MarkerId('new_location'),
                        position: pos,
                        infoWindow: InfoWindow(
                          title: AppLocalizations.of(context)!.newLocation,
                          snippet: AppLocalizations.of(context)!.desiredLocation,
                        )));
                    _circles.add(Circle(
                        circleId: const CircleId('circle'),
                        center: pos,
                        radius: _radius,
                        fillColor: Colors.blue.withOpacity(0.2),
                        strokeColor: Colors.blue,
                        strokeWidth: 4));
                    setState(() {});
                  },
                  circles: _circles,
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 11.0,
                  ),
                );
              } else if (snapshot.hasError) {
                return SnackBar(content: Text(snapshot.error.toString()));
              } else {
                return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(AppLocalizations.of(context)!.awaitingResult),
                    ),
                  )
                ]);
              }
            },
          ),
          TextFormField(
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.radius,
              hintText: AppLocalizations.of(context)!.radius,
              fillColor: Theme.of(context).canvasColor,
              filled: true,
            ),
            onChanged: (newRadius) {
              if (newRadius.isNotEmpty) {
                _circles.clear();
                _circles.add(Circle(
                    circleId: const CircleId('circle'),
                    center: LatLng(_markers.first.position.latitude, _markers.first.position.longitude),
                    radius: double.parse(newRadius),
                    fillColor: Colors.blue.withOpacity(0.2),
                    strokeColor: Colors.blue,
                    strokeWidth: 4));
                setState(() {
                  _radius = double.parse(newRadius);
                });
              }

            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: () {
          _markers.clear();
          _mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _center, zoom: 11)));
          setState(() {});
        },
      ),
    );
  }

  Future<Position> _determinePosition() async {
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

    return await Geolocator.getCurrentPosition();
  }
}
