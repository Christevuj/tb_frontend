// gtb_facility_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/models/facility.dart';

// Replace this import with the actual path in your project:
import 'package:tb_frontend/services/facility_repository.dart';
import '../services/chat_service.dart';
import '../chat_screens/guest_healthworker_chat_screen.dart';
import 'glistfacility.dart' as glist;

class GtbfacilityPage extends StatefulWidget {
  final String? selectedFacilityName;
  final String? selectedFacilityAddress;
  final bool allowDoctorMessage;

  const GtbfacilityPage({
    super.key,
    this.selectedFacilityName,
    this.selectedFacilityAddress,
    this.allowDoctorMessage = false,
  });

  @override
  _GtbfacilityPageState createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final PageController _pageController = PageController(viewportFraction: 0.94);
  final TextEditingController _searchController = TextEditingController();
  final String _apiKey =
      'AIzaSyB1qCMW00SQ5345y6l9SiVOaZn6rSyXpcs'; // Use your actual API key

  LatLng? _currentLocation;
  bool _loading = true;
  List<Facility> _facilities = [];
  List<Facility> _filteredFacilities = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _selectedIndex = 0;

  // Search functionality
  bool _showSearchDropdown = false;
  List<Map<String, dynamic>> _searchSuggestions = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchTimer;

  // Animation for facility container
  bool _isSearching = false;
  bool _isContainerHidden = false;

  // Contacts popup search
  final TextEditingController _contactsSearchController =
      TextEditingController();
  String _contactsSearchQuery = '';
  StreamSubscription<Position>? _positionStreamSubscription; // 👈 Added

  // Marker highlighting flag
  bool _shouldHighlightMarker = false; // Only highlight when user interacts

  static const double _zoomLevel = 15.0;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) {
      // This page is intended for Android only per your request.
      setState(() => _loading = false);
      return;
    }
    _initEverything();

    // Setup search functionality
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        setState(() => _showSearchDropdown = false);
      }
    });
  }

  Future<void> _initEverything() async {
    try {
      await _ensureLocationPermission();
      await _getCurrentLocation();

      // 👇 Start listening for continuous location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy
              .high, // Changed from 'best' to 'high' for better performance
          distanceFilter: 10, // Update every 10 meters to reduce battery usage
          timeLimit: Duration(seconds: 30), // Add timeout for position updates
        ),
      ).listen(
        (Position pos) {
          debugPrint(
              'Position update: ${pos.latitude}, ${pos.longitude} (accuracy: ${pos.accuracy}m)');

          // Validate the position
          if (pos.latitude == 0.0 && pos.longitude == 0.0) {
            debugPrint('Warning: Received (0,0) position, ignoring...');
            return;
          }

          final LatLng newPos = LatLng(pos.latitude, pos.longitude);

          setState(() {
            _currentLocation = newPos;
          });

          // Move map with you like Google Maps (but only if significant movement)
          if (_currentLocation != null) {
            _animateCameraTo(newPos, zoom: _zoomLevel);
          }

          // Rebuild "You are here" marker
          _buildMarkers();
        },
        onError: (error) {
          debugPrint('Position stream error: $error');
          // Don't show error to user for stream errors, just log them
        },
      );

      await _loadFacilities();
      _buildMarkers();

      // Center map on current location first, then facilities
      if (_currentLocation != null) {
        debugPrint('Centering map on current location: $_currentLocation');
        _animateCameraTo(_currentLocation!, zoom: _zoomLevel);
      } else if (_facilities.isNotEmpty && _facilities[0].coordinates != null) {
        debugPrint('No current location, centering on first facility');
        _animateCameraTo(_facilities[0].coordinates!, zoom: _zoomLevel);
      } else {
        debugPrint(
            'No location or facilities available for initial camera position');
      }
    } catch (e) {
      debugPrint('Init error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _ensureLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('Location services enabled: $serviceEnabled');

    if (!serviceEnabled) {
      // Show dialog to user about enabling location services
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please enable location services in your device settings'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      throw 'Location services are disabled. Please enable location services in your device settings.';
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('Current location permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('Permission after request: $permission');

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission is required to show your position on the map'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        throw 'Location permission denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission permanently denied. Please enable in app settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      throw 'Location permission denied forever. Please enable location permission in app settings.';
    }

    debugPrint('Location permission granted successfully');
  }

  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('Getting current location...');

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Add timeout
      );

      debugPrint('Location obtained: ${pos.latitude}, ${pos.longitude}');
      debugPrint('Location accuracy: ${pos.accuracy} meters');
      debugPrint('Location timestamp: ${pos.timestamp}');

      // Validate that we got a reasonable location (not 0,0 or obviously wrong)
      if (pos.latitude == 0.0 && pos.longitude == 0.0) {
        debugPrint('Warning: Got (0,0) location, this might be invalid');
      }

      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });

      debugPrint('Current location set successfully');
    } catch (e) {
      debugPrint('Error getting current location: $e');

      // Try to get last known position as fallback
      try {
        debugPrint('Trying to get last known position...');
        Position? lastPos = await Geolocator.getLastKnownPosition();

        if (lastPos != null) {
          debugPrint(
              'Last known location: ${lastPos.latitude}, ${lastPos.longitude}');
          setState(() {
            _currentLocation = LatLng(lastPos.latitude, lastPos.longitude);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Using last known location. Current location unavailable.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          debugPrint('No last known location available');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Unable to determine your location. Please check your location settings.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (lastPosError) {
        debugPrint('Error getting last known position: $lastPosError');
      }

      // Don't rethrow the error, let the app continue without current location
    }
  }

  Future<void> _loadFacilities() async {
    final f = await FacilityRepository.getFacilitiesWithCoordinates();
    setState(() {
      _facilities = f;
      _filteredFacilities = f; // Initialize filtered list
    });

    // If a specific facility was requested, scroll to it
    if (widget.selectedFacilityName != null) {
      _scrollToSelectedFacility();
    }
  }

  void _scrollToSelectedFacility() {
    if (widget.selectedFacilityName == null) return;

    // Find the index of the selected facility
    int facilityIndex = -1;
    for (int i = 0; i < _filteredFacilities.length; i++) {
      if (_filteredFacilities[i].name == widget.selectedFacilityName ||
          _filteredFacilities[i].address == widget.selectedFacilityAddress) {
        facilityIndex = i;
        break;
      }
    }

    if (facilityIndex != -1) {
      setState(() => _selectedIndex = facilityIndex);

      // Scroll to the facility in the carousel after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            facilityIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }

        // Also center the map on the selected facility
        if (_filteredFacilities[facilityIndex].coordinates != null) {
          _animateCameraTo(_filteredFacilities[facilityIndex].coordinates!,
              zoom: 15);
        }

        // Rebuild markers to highlight the selected facility
        _buildMarkers();
      });
    }
  }

  void _filterFacilities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFacilities = _facilities;
      } else {
        _filteredFacilities = _facilities.where((facility) {
          return facility.name.toLowerCase().contains(query.toLowerCase()) ||
              facility.address.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      _selectedIndex = 0; // Reset selection when filtering
      _shouldHighlightMarker = false; // Reset highlighting when filtering
    });
    _buildMarkers(); // Rebuild markers for filtered facilities
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text;
      setState(() {
        _isSearching = query.isNotEmpty;
      });

      if (query.isEmpty) {
        setState(() {
          _showSearchDropdown = false;
          _searchSuggestions = [];
        });
        _filterFacilities('');
        return;
      }

      _generateSearchSuggestions(query);
    });
  }

  void _generateSearchSuggestions(String query) {
    List<Map<String, dynamic>> suggestions = [];

    // Add facility suggestions
    for (final facility in _facilities) {
      if (facility.name.toLowerCase().contains(query.toLowerCase()) ||
          facility.address.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add({
          'type': 'facility',
          'title': facility.name,
          'subtitle': facility.address,
          'data': facility,
          'icon': Icons.local_hospital,
        });
      }
    }

    // Add location search suggestion
    if (query.length > 2) {
      suggestions.insert(0, {
        'type': 'location',
        'title': 'Search "$query" on map',
        'subtitle': 'Find this location and nearby facilities',
        'data': query,
        'icon': Icons.search,
      });
    }

    setState(() {
      _searchSuggestions =
          suggestions.take(6).toList(); // Limit to 6 suggestions
      _showSearchDropdown = suggestions.isNotEmpty;
    });
  }

  Future<void> _searchLocation(String locationName) async {
    try {
      final encodedLocation = Uri.encodeComponent(locationName);
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedLocation&key=$_apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          final newLocation = LatLng(lat, lng);

          // Move camera to searched location
          await _animateCameraTo(newLocation, zoom: _zoomLevel);

          // Show snackbar with result
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Found: ${data['results'][0]['formatted_address']}'),
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xE0F44336),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Location not found. Please try a different search.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error searching location. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onSuggestionTapped(Map<String, dynamic> suggestion) {
    setState(() {
      _showSearchDropdown = false;
      _isSearching = false;
    });
    _searchFocusNode.unfocus();

    if (suggestion['type'] == 'facility') {
      final facility = suggestion['data'] as Facility;
      _searchController.text = facility.name;

      // Find the index of this facility in filtered list
      final index =
          _filteredFacilities.indexWhere((f) => f.name == facility.name);
      if (index >= 0) {
        setState(() => _selectedIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        if (facility.coordinates != null) {
          _animateCameraTo(facility.coordinates!, zoom: _zoomLevel + 1);
        }
      }
      _filterFacilities(facility.name);
    } else if (suggestion['type'] == 'location') {
      final locationQuery = suggestion['data'] as String;
      _searchController.text = locationQuery;
      _searchLocation(locationQuery);
    }
  }

  Future<int> _getTotalWorkersByAddress(String address) async {
    try {
      // Count healthcare workers with matching facility.address
      final healthcareSnap = await FirebaseFirestore.instance
          .collection('healthcare')
          .where('facility.address', isEqualTo: address)
          .get();
      int healthcareCount = healthcareSnap.docs.length;

      // Count doctors with matching address in any affiliation
      final doctorsSnap =
          await FirebaseFirestore.instance.collection('doctors').get();
      int doctorCount = 0;
      for (var doc in doctorsSnap.docs) {
        final data = doc.data();
        if (data['affiliations'] is List) {
          for (var aff in data['affiliations']) {
            if (aff is Map && aff['address'] == address) {
              doctorCount++;
            }
          }
        }
      }
      return healthcareCount + doctorCount;
    } catch (e) {
      debugPrint('Error getting worker count: $e');
      return 0;
    }
  }

  void _buildMarkers() {
    final Set<Marker> markers = {};

    // Marker for current location
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    for (int i = 0; i < _filteredFacilities.length; i++) {
      final facility = _filteredFacilities[i];
      if (facility.coordinates == null) continue;
      
      // Only highlight selected marker if user has interacted (clicked marker or nearest facility)
      final bool isSelected = _shouldHighlightMarker && i == _selectedIndex;
      
      markers.add(Marker(
        markerId: MarkerId('${facility.name}_$i'),
        position: facility.coordinates!,
        infoWindow: InfoWindow(title: facility.name, snippet: facility.address),
        // Gray for unselected, Red for selected (only when user interacts)
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure,
        ),
        onTap: () => _onMarkerTapped(i),
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _shouldHighlightMarker = true; // Enable highlighting when marker is clicked
    });
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    final coords = _filteredFacilities[index].coordinates;
    if (coords != null) {
      _animateCameraTo(coords, zoom: _zoomLevel + 1);
    }
    _buildMarkers();
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _filteredFacilities.length) return;
    setState(() => _selectedIndex = index);
    final coords = _filteredFacilities[index].coordinates;
    if (coords != null) {
      _animateCameraTo(coords, zoom: _zoomLevel + 1);
    }
    _buildMarkers();
  }

  Future<void> _animateCameraTo(LatLng target, {double zoom = 15.0}) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom)),
    );
  }

  Future<void> _createRouteToFacility(LatLng destination) async {
    if (_currentLocation == null) return;
    try {
      final points = await _getDirections(_currentLocation!, destination);
      if (points.isEmpty) {
        setState(() => _polylines = {});
        return;
      }
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 6,
        color: const Color.fromARGB(223, 195, 73, 64), // Red accent color
      );
      setState(() {
        _polylines = {polyline};
      });
    } catch (e) {
      debugPrint('Error creating route: $e');
    }
  }

  Future<List<LatLng>> _getDirections(LatLng origin, LatLng dest) async {
    final originStr = '${origin.latitude},${origin.longitude}';
    final destStr = '${dest.latitude},${dest.longitude}';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr&mode=driving&key=$_apiKey';

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw 'Directions API returned ${resp.statusCode}';
    }
    final json = jsonDecode(resp.body);
    if (json['routes'] == null || (json['routes'] as List).isEmpty) {
      return [];
    }
    final overview = json['routes'][0]['overview_polyline']['points'] as String;
    return _decodePolyline(overview);
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final latitude = lat / 1e5;
      final longitude = lng / 1e5;
      poly.add(LatLng(latitude, longitude));
    }

    return poly;
  }

  void _onSeeDirectionsPressed() {
    final facility = _filteredFacilities[_selectedIndex];
    if (facility.coordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No coordinates for this facility')));
      return;
    }

    // Check if there's already a route displayed
    if (_polylines.isNotEmpty) {
      // Clear the route
      setState(() {
        _polylines = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route cleared'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xE0F44336),
        ),
      );
    } else {
      // Navigate to facility and show route when directions button is pressed
      _animateCameraTo(facility.coordinates!, zoom: _zoomLevel + 1);
      _createRouteToFacility(facility.coordinates!);
    }
  }

  void _findNearestFacility() {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Current location not available. Please enable location services.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_filteredFacilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No facilities available.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    double shortestDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < _filteredFacilities.length; i++) {
      final facility = _filteredFacilities[i];
      if (facility.coordinates != null) {
        final distance = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          facility.coordinates!.latitude,
          facility.coordinates!.longitude,
        );

        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearestIndex = i;
        }
      }
    }

    // Update selected index and navigate to nearest facility
    setState(() {
      _selectedIndex = nearestIndex;
      _shouldHighlightMarker = true; // Enable highlighting when nearest facility is found
    });
    _pageController.animateToPage(
      nearestIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    _buildMarkers();

    // Show distance in snackbar
    final distanceKm = (shortestDistance / 1000).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nearest facility: ${_filteredFacilities[nearestIndex].name} (${distanceKm}km away)',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xE0F44336),
      ),
    );
  }

  // Get TB DOTS schedule based on facility name
  String _getTbDotsSchedule(String facilityName) {
    final schedules = {
      'AGDAO': 'Mon, Tues, Thurs, Fri | 8:00 AM-12:00 NN',
      'BAGUIO': 'Tuesday | 8:00 AM-12:00 NN',
      'BUHANGIN': 'Thursday | 8:00 AM-12:00 NN',
      'BUNAWAN': 'Monday - Friday | 8:00 AM-5:00 PM',
      'CALINAN': 'Thursday | 8:00 AM-12:00 NN',
      'DAVAO CHEST CENTER': 'Daily | 8:00 AM-5:00 PM',
      'DISTRICT A': 'Monday-Tuesday, Thurs | 8:00 AM-5:00 PM',
      'DISTRICT B': 'Thursday | 8:00 AM-12:00 NN',
      'DISTRICT C': 'Tuesday | 8:00 AM-5:00 PM',
      'DISTRICT D': 'Tuesday | 8:00 AM-12:00 NN',
      'MARILOG': 'Mon-Wed, Fri | 8:00 AM-12:00 NN',
      'PAQUIBATO': 'Tuesday | 8:00 AM-12:00 NN',
      'SASA': 'Daily | 8:00 AM-5:00 PM',
      'TALOMO CENTRAL': 'Daily | 8:00 AM-12:00 NN',
      'TALOMO NORTH': 'Mon-Wed, Fri | 8:00 AM-12:00 NN',
      'TALOMO SOUTH': 'Mon-Tues, Thurs-Fri | 8:00 AM-12:00 NN',
      'TORIL A': 'Wednesday | 1:00 PM-5:00 PM',
      'TORIL B': 'Thursday | 8:00 AM-12:00 NN',
      'TUGBOK': 'Daily | 8:00 AM-4:00 PM',
    };

    // Try to match facility name with schedule keys
    for (var key in schedules.keys) {
      if (facilityName.toUpperCase().contains(key)) {
        return schedules[key]!;
      }
    }
    
    return 'Schedule not available';
  }

  // Build styled schedule text with bold days
  Widget _buildStyledSchedule(String schedule) {
    // List of day patterns to make bold
    final dayPatterns = [
      'Monday', 'Mon', 'Tuesday', 'Tues', 'Wednesday', 'Wed',
      'Thursday', 'Thurs', 'Friday', 'Fri', 'Saturday', 'Sat',
      'Sunday', 'Sun', 'Daily'
    ];

    List<TextSpan> spans = [];
    int currentIndex = 0;

    // Find all matches of day patterns in the schedule
    while (currentIndex < schedule.length) {
      bool foundMatch = false;

      // Check each day pattern
      for (var day in dayPatterns) {
        if (currentIndex + day.length <= schedule.length) {
          String substring = schedule.substring(currentIndex, currentIndex + day.length);
          
          // Case-insensitive match
          if (substring.toLowerCase() == day.toLowerCase()) {
            // Add the day with bold styling
            spans.add(TextSpan(
              text: substring,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
                fontWeight: FontWeight.w600, // Light bold
              ),
            ));
            currentIndex += day.length;
            foundMatch = true;
            break;
          }
        }
      }

      // If no day pattern found, add the next character as normal text
      if (!foundMatch) {
        int nextDayIndex = schedule.length;
        
        // Find the next day pattern
        for (var day in dayPatterns) {
          int index = schedule.indexOf(RegExp(day, caseSensitive: false), currentIndex + 1);
          if (index != -1 && index < nextDayIndex) {
            nextDayIndex = index;
          }
        }

        // Add all text until the next day pattern as normal text
        spans.add(TextSpan(
          text: schedule.substring(currentIndex, nextDayIndex),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ));
        currentIndex = nextDayIndex;
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _onViewContactsPressed() {
    final facility = _filteredFacilities[_selectedIndex];
    // Reset search state when opening popup
    _contactsSearchController.clear();
    setState(() {
      _contactsSearchQuery = '';
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.90,
            height: MediaQuery.of(context).size.height *
                0.8, // Increased height for better visibility
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header with facility info and TB DOTS schedule
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Close button and facility name row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              facility.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Facility Address
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              facility.address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // TB DOTS Schedule
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'TB Day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildStyledSchedule(_getTbDotsSchedule(facility.name)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // Search Bar for contacts
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _contactsSearchController,
                    onChanged: (value) {
                      setStateDialog(() {
                        _contactsSearchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search health workers...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade600),
                      suffixIcon: _contactsSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade600),
                              onPressed: () {
                                _contactsSearchController.clear();
                                setStateDialog(() {
                                  _contactsSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('healthcare')
                        .where('facility.address', isEqualTo: facility.address)
                        .snapshots(),
                    builder: (context, healthcareSnapshot) {
                      if (healthcareSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xE0F44336)),
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('doctors')
                            .snapshots(),
                        builder: (context, doctorsSnapshot) {
                          if (doctorsSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xE0F44336)),
                              ),
                            );
                          }

                          if (healthcareSnapshot.hasError ||
                              doctorsSnapshot.hasError) {
                            return const Center(
                              child: Text(
                                'Error loading staff',
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          if (!healthcareSnapshot.hasData ||
                              !doctorsSnapshot.hasData) {
                            return const Center(
                              child: Text(
                                'No data available',
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          List<Map<String, dynamic>> allStaff = [];

                          // Add health workers
                          for (var doc in healthcareSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            allStaff.add({
                              ...data,
                              'id': doc.id,
                              'type': 'Health Worker',
                              'name':
                                  data['fullName'] ?? data['name'] ?? 'No info',
                              'email': data['email'] ?? 'No info',
                              'position': data['role'] ?? 'No info',
                              'profilePicture': data['profilePicture'] ?? '',
                              'phone': data['phone'] ?? 'No info',
                            });
                          }

                          // Add doctors who have this facility in their affiliations
                          for (var doc in doctorsSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final affiliations =
                                data['affiliations'] as List? ?? [];
                            for (var affiliation in affiliations) {
                              if (affiliation is Map &&
                                  affiliation['address'] == facility.address) {
                                allStaff.add({
                                  'name': data['fullName'] ??
                                      data['name'] ??
                                      'No info',
                                  'fullName': data['fullName'] ?? 'No info',
                                  'email': data['email'] ?? 'No info',
                                  'role': data['role'] ?? 'No info',
                                  'specialization':
                                      data['specialization'] ?? 'No info',
                                  'profilePicture':
                                      data['profilePicture'] ?? '',
                                  'phone': affiliation['phone'] ??
                                      data['phone'] ??
                                      'No info',
                                  'position': data['role'] ?? 'Doctor',
                                  'id': doc.id,
                                  'type': 'Doctor',
                                  'schedules': affiliation['schedules'] ?? [],
                                });
                              }
                            }
                          }

                          if (allStaff.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No health workers found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This facility has no registered health workers yet.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          // Filter staff based on search query
                          final filteredStaff = _contactsSearchQuery.isEmpty
                              ? allStaff
                              : allStaff.where((worker) {
                                  final name = (worker['name'] ??
                                          worker['fullName'] ??
                                          '')
                                      .toLowerCase();
                                  final position = (worker['position'] ??
                                          worker['type'] ??
                                          '')
                                      .toLowerCase();
                                  final query =
                                      _contactsSearchQuery.toLowerCase();
                                  return name.contains(query) ||
                                      position.contains(query);
                                }).toList();

                          if (filteredStaff.isEmpty &&
                              _contactsSearchQuery.isNotEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try searching with different keywords.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredStaff.length,
                            itemBuilder: (context, index) {
                              final worker = filteredStaff[index];
                              return _buildHealthWorkerCard(context, worker);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthWorkerCard(
      BuildContext context, Map<String, dynamic> worker) {
    final name = worker['name'] ?? worker['fullName'] ?? 'No info';
    final position = worker['position'] ?? worker['type'] ?? 'No info';
    final profilePicture = worker['profilePicture'] as String?;
    final type = worker['type'] ?? 'Health Worker';
    final isDoctor = type == 'Doctor';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Modern Profile Icon/Image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(223, 58, 58, 58),
                        const Color.fromARGB(223, 39, 39, 39).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(223, 52, 51, 51).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: profilePicture != null && profilePicture.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            profilePicture,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                            cacheHeight: 120,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDoctor
                              ? Colors.blue.withOpacity(0.1)
                              : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDoctor
                                    ? Colors.blue
                                    : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              position,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDoctor
                                    ? Colors.blue
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Message Button - Modern Style matching facility cards
            const SizedBox(height: 12),
            Builder(
              builder: (context) => ElevatedButton.icon(
                onPressed: () => _handleMessageTap(
                  context: context,
                  workerId: worker['id'] ?? '',
                  workerName: name,
                  workerType: type,
                  profilePicture: profilePicture,
                ),
                icon: const Icon(Icons.message_rounded, size: 16),
                label: Text(
                    'Message ${type == 'Doctor' ? 'Doctor' : 'Health Worker'}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xE0F44336),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  elevation: 4,
                  shadowColor: const Color(0xE0F44336).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessageTap({
    required BuildContext context,
    required String workerId,
    required String workerName,
    required String workerType,
    String? profilePicture,
  }) async {
    // If it's a doctor, show the restriction dialog
    if (workerType == 'Doctor') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.redAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
          content: Text(
            'You need to create an account and login to message doctors.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // For health workers, allow messaging
    try {
      // Try to get current user, or create a temporary guest ID
      User? currentUser = FirebaseAuth.instance.currentUser;
      String guestUid;

      if (currentUser == null) {
        // Try anonymous sign-in first
        try {
          debugPrint(
              'Guest not authenticated, attempting anonymous sign-in...');
          final userCredential =
              await FirebaseAuth.instance.signInAnonymously();
          currentUser = userCredential.user;
          if (currentUser != null) {
            guestUid = currentUser.uid;
            debugPrint('Guest signed in anonymously with UID: $guestUid');
          } else {
            throw Exception('Anonymous sign-in returned null user');
          }
        } catch (authError) {
          // If anonymous auth is disabled, use a device-based temporary ID
          debugPrint('Anonymous auth not available: $authError');
          debugPrint('Using temporary guest ID...');

          // Generate a unique temporary guest ID
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          guestUid = 'guest_$timestamp';

          // Show info to user that they're using temporary guest mode
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Opening chat as temporary guest'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } else {
        guestUid = currentUser.uid;
      }

      // Create/update user documents with proper roles
      final ChatService chatService = ChatService();

      // Register guest user with 'guest' role
      await chatService.createUserDoc(
        userId: guestUid,
        name: 'Anonymous',
        role: 'guest',
      );

      // Register health worker
      await chatService.createUserDoc(
        userId: workerId,
        name: workerName,
        role: 'healthcare',
      );

      // Navigate to guest-healthworker chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuestHealthWorkerChatScreen(
              guestId: guestUid,
              healthWorkerId: workerId,
              healthWorkerName: workerName,
              healthWorkerProfilePicture: profilePicture,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening chat: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _contactsSearchController.dispose();
    _searchTimer?.cancel();
    _positionStreamSubscription?.cancel(); // 👈 Cancel stream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facilities (Android only)')),
        body: const Center(
            child: Text('This map page is intended for Android devices only.')),
      );
    }

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: _currentLocation ??
                          (_facilities.isNotEmpty &&
                                  _facilities[0].coordinates != null
                              ? _facilities[0].coordinates!
                              : const LatLng(7.0731,
                                  125.6128)), // Davao City center as default
                      zoom: _zoomLevel),
                  myLocationEnabled: true,
                  // Hide default zoom controls (+ / -) shown on some Android devices
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                ),
                // Back Button and Search Bar with Dropdown
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Modern Back Button
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Color(0xFF1F2937), size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Search Bar
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (value) {
                                  _filterFacilities(value);
                                  setState(() {
                                    _isSearching = value.isNotEmpty;
                                  });
                                },
                                onTap: () {
                                  if (_searchController.text.isNotEmpty) {
                                    _generateSearchSuggestions(
                                        _searchController.text);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search facilities or locations...',
                                  hintStyle:
                                      TextStyle(color: Colors.grey.shade500),
                                  prefixIcon: Icon(Icons.search,
                                      color: Colors.grey.shade600),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear,
                                              color: Colors.grey.shade600),
                                          onPressed: () {
                                            _searchController.clear();
                                            _filterFacilities('');
                                            setState(() {
                                              _showSearchDropdown = false;
                                              _searchSuggestions = [];
                                              _isSearching = false;
                                            });
                                            _searchFocusNode.unfocus();
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Search Suggestions Dropdown
                      if (_showSearchDropdown && _searchSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchSuggestions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              return InkWell(
                                onTap: () => _onSuggestionTapped(suggestion),
                                borderRadius: BorderRadius.vertical(
                                  top: index == 0
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottom: index == _searchSuggestions.length - 1
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: suggestion['type'] ==
                                                  'facility'
                                              ? const Color(0xE0F44336)
                                                  .withOpacity(0.1)
                                              : Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          suggestion['icon'] as IconData,
                                          size: 20,
                                          color:
                                              suggestion['type'] == 'facility'
                                                  ? const Color(0xE0F44336)
                                                  : Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              suggestion['title'] as String,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                            if (suggestion['subtitle'] !=
                                                null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                suggestion['subtitle']
                                                    as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 100,
                  child: FloatingActionButton.small(
                    heroTag: 'btn-recenter',
                    backgroundColor: const Color(0xFFFBBC0C),
                    foregroundColor: Colors.white,
                    onPressed: () {
                      if (_currentLocation != null) {
                        _animateCameraTo(_currentLocation!, zoom: _zoomLevel);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                // Nearest facility button - compressed positioning
                // Adjusted bottom positions after increasing facility container height
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: 16,
                  bottom: (_isSearching || _isContainerHidden)
                      ? 160 // Compressed: closer to List View button (adjusted)
                      : 383, // Shifted down to match larger facility container
                  child: FloatingActionButton(
                    heroTag: 'btn-nearest',
                    onPressed: _findNearestFacility,
                    backgroundColor: const Color.fromARGB(223, 68, 198, 77),
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.near_me, size: 24),
                  ),
                ),
                // List View Floating Button - compressed positioning
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: 16,
                  bottom: (_isSearching || _isContainerHidden)
                      ? 100 // Compressed: proper spacing from Nearest button (adjusted)
                      : 320, // Shifted down to match larger facility container
                  child: FloatingActionButton.extended(
                    heroTag: 'btn-list-view',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const glist.GListFacility(),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xE0F44336),
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.list_rounded, size: 20),
                    label: const Text('List View',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                // Facility container with sliding animation and swipe gesture
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: 0,
                  right: 0,
                  bottom: (_isSearching || _isContainerHidden)
                      ? -250 // Hide almost completely, leaving small slit
                      : 0, // Slide down when searching or hidden
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      // Swipe down to hide, swipe up to show
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! > 500) {
                          // Swipe down - hide container
                          setState(() {
                            _isContainerHidden = true;
                          });
                        } else if (details.primaryVelocity! < -500) {
                          // Swipe up - show container
                          setState(() {
                            _isContainerHidden = false;
                          });
                        }
                      }
                    },
                    onTap: () {
                      // Tap to toggle container when hidden
                      if (_isContainerHidden || _isSearching) {
                        setState(() {
                          _isContainerHidden = false;
                          _isSearching = false;
                        });
                        // Clear search when showing container via tap
                        if (_searchController.text.isNotEmpty) {
                          _searchController.clear();
                          _filterFacilities('');
                          setState(() {
                            _showSearchDropdown = false;
                            _searchSuggestions = [];
                          });
                          _searchFocusNode.unfocus();
                        }
                      }
                    },
                    child: SafeArea(
                      child: SizedBox(
                        height: 320, // increased to fit the indicator dots
                        child: Column(
                          children: [
                            // Carousel
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _filteredFacilities.length,
                                onPageChanged: _onPageChanged,
                                itemBuilder: (context, index) {
                                  final facility = _filteredFacilities[index];
                                  final bool isSelected = index == _selectedIndex;

                                  return FutureBuilder<int>(
                                    future:
                                        _getTotalWorkersByAddress(facility.address),
                                    builder: (context, snapshot) {
                                      final count = snapshot.data ?? 0;
                                      final isActive = count > 0;

                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white, // Solid white background
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isSelected
                                                  ? const Color(0xE0F44336)
                                                      .withOpacity(0.15)
                                                  : Colors.black
                                                      .withOpacity(0.08),
                                              blurRadius: isSelected ? 20 : 12,
                                              offset: isSelected
                                                  ? const Offset(0, 8)
                                                  : const Offset(0, 4),
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                              16), // Increased padding for better spacing
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  // Modern Facility Icon
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          const Color.fromARGB(223, 58, 58, 58),
                                                          const Color.fromARGB(223, 39, 39, 39)
                                                              .withOpacity(0.8),
                                                        ],
                                                        begin: Alignment.topLeft,
                                                        end:
                                                            Alignment.bottomRight,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(16),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color.fromARGB(223, 52, 51, 51)
                                                              .withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.local_hospital_rounded,
                                                      color: Color.fromARGB(255, 255, 255, 255),
                                                      size: 22,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Facility Name and Status
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          facility.name,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                Color(0xFF1A1A1A),
                                                            letterSpacing: -0.2,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isActive
                                                                ? const Color(
                                                                        0xFF10B981)
                                                                    .withOpacity(
                                                                        0.1)
                                                                : Colors
                                                                    .grey.shade100,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(12),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: [
                                                              Container(
                                                                width: 4,
                                                                height: 4,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: isActive
                                                                      ? const Color(
                                                                          0xFF10B981)
                                                                      : Colors
                                                                          .grey
                                                                          .shade400,
                                                                  shape:
                                                                      BoxShape.circle,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                isActive
                                                                    ? 'Active'
                                                                    : 'No Workers',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight.w600,
                                                                  color: isActive
                                                                      ? const Color(
                                                                          0xFF10B981)
                                                                      : Colors
                                                                          .grey
                                                                          .shade600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Address with modern styling
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.white.withOpacity(0.7),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                    width: 1,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.04),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_rounded,
                                                      color: Color(0xFF6B7280),
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        facility.address,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Color(0xFF374151),
                                                          height: 1.4,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Health Workers Count (blue when active, gray when none)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isActive
                                                        ? [
                                                            const Color(0xFF3B82F6)
                                                                .withOpacity(0.12),
                                                            const Color(0xFF3B82F6)
                                                                .withOpacity(0.06),
                                                          ]
                                                        : [
                                                            Colors.grey.shade100,
                                                            Colors.grey.shade50,
                                                          ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isActive
                                                        ? const Color(0xFF3B82F6)
                                                            .withOpacity(0.22)
                                                        : Colors.grey.shade300,
                                                    width: 1,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: isActive
                                                          ? const Color(0xFF3B82F6)
                                                              .withOpacity(0.06)
                                                          : Colors.black
                                                              .withOpacity(0.03),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? const Color(0xFF3B82F6)
                                                            : Colors.grey.shade400,
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: isActive
                                                                ? const Color(0xFF3B82F6)
                                                                    .withOpacity(0.18)
                                                                : Colors.black
                                                                    .withOpacity(0.06),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Icon(
                                                        Icons.people_rounded,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '$count Health Worker${count != 1 ? 's' : ''} Available',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: isActive
                                                            ? const Color(0xFF1E40AF)
                                                            : Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Buttons section - sleek design
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          _onViewContactsPressed(),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(0xE0F44336),
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 4,
                                                        shadowColor: const Color(
                                                                0xE0F44336)
                                                            .withOpacity(0.3),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  14),
                                                        ),
                                                        padding: const EdgeInsets
                                                            .symmetric(vertical: 12),
                                                      ),
                                                      child: const Text(
                                                        'Contacts',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () =>
                                                          _onSeeDirectionsPressed(),
                                                      style: OutlinedButton.styleFrom(
                                                        side: BorderSide(
                                                          color: _polylines
                                                                  .isNotEmpty
                                                              ? Colors.orange
                                                              : const Color(
                                                                  0xE0F44336),
                                                          width: 2,
                                                        ),
                                                        foregroundColor: _polylines
                                                                .isNotEmpty
                                                            ? Colors.orange
                                                            : const Color(
                                                                0xE0F44336),
                                                        backgroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  14),
                                                        ),
                                                        padding: const EdgeInsets
                                                            .symmetric(vertical: 12),
                                                      ),
                                                      child: Text(
                                                        _polylines.isNotEmpty
                                                            ? 'Clear Route'
                                                            : 'See Directions',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            // Dots indicator below carousel
                            const SizedBox(height: 8),
                            if (_filteredFacilities.isNotEmpty)
                              Container(
                                height: 24,
                                alignment: Alignment.center,
                                child: Builder(builder: (context) {
                                  // Always show exactly 3 dots. Map the active dot as:
                                  // first page -> left, last page -> right, others -> center.
                                  final int activeDot = _filteredFacilities.length <= 1
                                      ? 1
                                      : (_selectedIndex == 0
                                          ? 0
                                          : (_selectedIndex == _filteredFacilities.length - 1 ? 2 : 1));
                                  final int midIndex = (_filteredFacilities.length / 2).floor();

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(3, (i) {
                                      return GestureDetector(
                                        onTap: () {
                                          if (!_pageController.hasClients) return;
                                          int target;
                                          if (i == 0) {
                                            target = 0;
                                          } else if (i == 2) {
                                            target = _filteredFacilities.length - 1;
                                          } else {
                                            target = midIndex;
                                          }
                                          target = target.clamp(0, _filteredFacilities.length - 1);
                                          _pageController.animateToPage(
                                            target,
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          margin: const EdgeInsets.symmetric(horizontal: 6),
                                          width: activeDot == i ? 16 : 10,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: activeDot == i ? const Color(0xE0F44336) : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),	
    );
  }
}





















