import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final username = Hive.box('box').get('username');
  late LatLng _center;

  final _markers = <Marker>{};

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
    String docId = ModalRoute.of(context)!.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.sendLocation),
        actions: [
          IconButton(
              onPressed: () async {
                Prediction? p = await PlacesAutocomplete.show(
                    offset: 0,
                    radius: 100000,
                    types: [],
                    hint: "Search area",
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
                  _markers.add(Marker(
                      markerId: const MarkerId('new_location'),
                      position: latLng,
                      infoWindow: InfoWindow(
                        title: AppLocalizations.of(context)!.newLocation,
                        snippet: AppLocalizations.of(context)!.desiredLocation,
                      )));

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
                FirestoreHelper.sendLocation(docId, username, _markers.first.position);
                Navigator.popUntil(context, ModalRoute.withName("/chat"));
              },
              icon: const Icon(Icons.send)),
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
                }
                return GoogleMap(
                  zoomControlsEnabled: false,
                  markers: _markers,
                  onLongPress: (pos) {
                    _markers.clear();
                    _markers.add(Marker(
                        markerId: const MarkerId('new_location'),
                        position: pos,
                        infoWindow: InfoWindow(
                          title: AppLocalizations.of(context)!.newLocation,
                          snippet: AppLocalizations.of(context)!.desiredLocation,
                        )));
                    setState(() {});
                  },
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 11.0,
                  ),
                );
              } else if (snapshot.hasError) {
                return SnackBar(content: Text(snapshot.error.toString()));
              } else {
                return Column(mainAxisAlignment: MainAxisAlignment.center, children:  [
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _markers.clear();
          _mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _center, zoom: 11)));
          setState(() {});
        },
        child: const Icon(Icons.my_location),
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
