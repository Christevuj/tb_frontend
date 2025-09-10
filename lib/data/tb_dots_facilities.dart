// TB DOTS Healthcare Centers in Davao
class TBDotsFacility {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? operatingHours;

  TBDotsFacility({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.operatingHours,
  });
}

final List<TBDotsFacility> tbDotsFacilities = [
  TBDotsFacility(
    name: "Southern Philippines Medical Center",
    address: "JP Laurel Ave, Bajada, Davao City, 8000 Davao del Sur",
    latitude: 7.0907,
    longitude: 125.6126,
    phoneNumber: "(082) 227-2731",
    operatingHours: "24/7",
  ),
  TBDotsFacility(
    name: "Davao City Health Office",
    address: "Pichon Street, Davao City, Davao del Sur",
    latitude: 7.0722,
    longitude: 125.6127,
    phoneNumber: "(082) 224-3866",
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "Talomo District Health Center",
    address: "Talomo, Davao City, Davao del Sur",
    latitude: 7.0503,
    longitude: 125.5989,
    phoneNumber: "(082) 224-1172",
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "Buhangin District Health Center",
    address: "Buhangin, Davao City, Davao del Sur",
    latitude: 7.1044,
    longitude: 125.6297,
    phoneNumber: "(082) 241-1000",
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "Toril District Health Center",
    address: "Toril, Davao City, Davao del Sur",
    latitude: 7.0247,
    longitude: 125.5019,
    phoneNumber: "(082) 291-2370",
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "Bunawan District Health Center",
    address: "Bunawan, Davao City, Davao del Sur",
    latitude: 7.1922,
    longitude: 125.6375,
  ),
  TBDotsFacility(
    name: "Tibungco Health Center",
    address: "Tibungco, Davao City, Davao del Sur",
    latitude: 7.1631,
    longitude: 125.6644,
  ),
  TBDotsFacility(
    name: "Calinan District Health Center",
    address: "Calinan, Davao City, Davao del Sur",
    latitude: 7.1869,
    longitude: 125.4061,
  ),
  TBDotsFacility(
    name: "Marilog District Health Center",
    address: "Marilog, Davao City, Davao del Sur",
    latitude: 7.4011,
    longitude: 125.2894,
  ),
  TBDotsFacility(
    name: "Paquibato District Health Center",
    address: "Paquibato, Davao City, Davao del Sur",
    latitude: 7.3439,
    longitude: 125.6456,
  ),
];
