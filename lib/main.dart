import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late GoogleMapController mapController;
  LocationData? currentLocation;
  final Location location = Location();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  static const String googleMapsApiKey =
      'apı key is here'; // Google Maps API Key

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    final LocationData locationResult = await location.getLocation();
    setState(() {
      currentLocation = locationResult;
      _markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position:
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      );
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _showWalkDialog() async {
    TextEditingController _textFieldController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bugün kaç km yürümek istersiniz?'),
          content: TextField(
            controller: _textFieldController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: "Km giriniz"),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
                double distanceKm = double.parse(_textFieldController.text);
                _addRandomLocationMarker(distanceKm);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addRandomLocationMarker(double distanceKm) async {
    if (currentLocation == null) return;

    final double distanceInMeters = distanceKm * 1000;
    final double earthRadius = 6378137.0; // Earth radius in meters

    final double randomDistance = Random().nextDouble() * distanceInMeters;
    final double randomAngle = Random().nextDouble() * 2 * pi;

    final double deltaLat = randomDistance / earthRadius;
    final double deltaLng = randomDistance /
        (earthRadius * cos(pi * currentLocation!.latitude! / 180));

    final double newLat = currentLocation!.latitude! + deltaLat * 180 / pi;
    final double newLng = currentLocation!.longitude! + deltaLng * 180 / pi;

    final LatLng randomLocation = LatLng(newLat, newLng);

    setState(() {
      _markers
          .removeWhere((marker) => marker.markerId.value == 'randomLocation');

      _markers.add(
        Marker(
          markerId: MarkerId('randomLocation'),
          position: randomLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Random Location'),
        ),
      );

      _getDirections(
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        randomLocation,
      );

      mapController.animateCamera(CameraUpdate.newLatLng(randomLocation));
    });
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    final String url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> routes = data['routes'];
      if (routes.isNotEmpty) {
        final String encodedPoints = routes[0]['overview_polyline']['points'];
        final List<LatLng> polylinePoints = _decodePolyline(encodedPoints);

        setState(() {
          _polylines
              .removeWhere((polyline) => polyline.polylineId.value == 'route');
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points: polylinePoints,
              color: Colors.blue,
              width: 5,
            ),
          );
        });
      }
    } else {
      throw Exception('Failed to load directions');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    final len = encoded.length;
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final double plat = (lat / 1E5);
      final double plong = (lng / 1E5);
      points.add(LatLng(plat, plong));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Maps Example'),
        actions: [
          IconButton(
            icon: Icon(Icons.directions_walk),
            onPressed: _showWalkDialog,
          ),
        ],
      ),
      body: currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    currentLocation!.latitude!, currentLocation!.longitude!),
                zoom: 15.0,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}
