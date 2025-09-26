// TB DOTS Healthcare Centers in Davao
class TBDotsFacility {
  final String name;
  final String address;
  final String email;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? operatingHours;

  TBDotsFacility({
    required this.name,
    required this.address,
    required this.email,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.operatingHours,
  });
}

final List<TBDotsFacility> tbDotsFacilities = [
  TBDotsFacility(
    name: "AGDAO",
    address: "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
    email: "agdaohealthcenter@gmail.com",
    latitude: 7.0850,
    longitude: 125.6250,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "BAGUIO (MALAGOS HC)",
    address: "Purok 2A Malagos, Baguio District, Davao City",
    email: "baguiodistricthealthcenter@gmail.com",
    latitude: 7.1500,
    longitude: 125.4800,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "BUHANGIN (NHA BUHANGIN HC)",
    address: "NHA Chapet St., Buhangin, Davao City",
    email: "buhanginhealthdistrict01@gmail.com",
    latitude: 7.1044,
    longitude: 125.6297,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "BUNAWAN",
    address: "Daang Maharlika Highway, Bunawan, Davao City",
    email: "bunawandistrict2020@gmail.com",
    latitude: 7.1922,
    longitude: 125.6375,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "CALINAN",
    address: "P34, Aurora St., Calinan, Davao City",
    email: "calinanruralhealthcenter@gmail.com",
    latitude: 7.1869,
    longitude: 125.4061,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "DAVAO CHEST CENTER",
    address: "Villa Abrille St., Brgy 30-C, Davao City",
    email: "davaochestcenter2021@gmail.com",
    latitude: 7.0750,
    longitude: 125.6100,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "DISTRICT A (TOMAS CLAUDIO HC)",
    address: "Camus Ext., Corner Quirino Ave., Davao City",
    email: "tomasclaudiohc.davao@gmail.com",
    latitude: 7.0720,
    longitude: 125.6080,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "DISTRICT B (EL RIO HC)",
    address: "Garcia Heights, Bajada, Davao City",
    email: "bdistrict20@gmail.com",
    latitude: 7.0907,
    longitude: 125.6126,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "DISTICT C (MINIFOREST HC)",
    address: "Brgy 23-C, Quezon Boulevard, Davao City",
    email: "districtc2020@gmail.com",
    latitude: 7.0722,
    longitude: 125.6127,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "DISTRICT D (JACINTO HC)",
    address: "Emilio Jacinto St., Davao City",
    email: "healthcenterjacinto@gmail.com",
    latitude: 7.0700,
    longitude: 125.6150,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "MARILOG (MARAHAN HC)",
    address: "Sitio Marahan, Brgy. Marilog, Davao City",
    email: "marilogrhu2017@gmail.com",
    latitude: 7.4011,
    longitude: 125.2894,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "PAQUIBATO (MALABOG HC)",
    address: "Brgy Malabog, Davao City",
    email: "malabogrhu@gmail.com",
    latitude: 7.3439,
    longitude: 125.6456,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "SASA",
    address: "Bangoy Km 9,  Sasa, Davao City",
    email: "sasadistrict@gmail.com",
    latitude: 7.1200,
    longitude: 125.6400,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "TALOMO CENTRAL (GSIS HC)",
    address: "GSIS Village, Matina, Davao City",
    email: "talomocentralhc@gmail.com",
    latitude: 7.0503,
    longitude: 125.5989,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "TALOMO NORTH (SIR HC)",
    address: "Daang Patnubay St., SIR Ph-1, Sandawa, Davao City",
    email: "talomonorthhc@gmail.com",
    latitude: 7.0600,
    longitude: 125.5900,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "TALOMO SOUTH (PUAN HC)",
    address: "Puan, Talomo, Davao City",
    email: "talomosouthhc@gmail.com",
    latitude: 7.0400,
    longitude: 125.5800,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "TORIL A",
    address: "Agton St., Toril, Davao City",
    email: "torilhealthcenter2@gmail.com",
    latitude: 7.0247,
    longitude: 125.5019,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "TORIL B",
    address: "Juan Dela Cruz St., Daliao, Toril, Davao City",
    email: "chotorilb@gmail.com",
    latitude: 7.0200,
    longitude: 125.4950,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
  TBDotsFacility(
    name: "TUGBOK",
    address: "Sampaguita St., Mintal, Tugbok District, Davao City",
    email: "tugbokruralhealthunit@gmail.com",
    latitude: 7.1631,
    longitude: 125.6644,
    operatingHours: "Monday-Friday: 8:00 AM - 5:00 PM",
  ),
];
