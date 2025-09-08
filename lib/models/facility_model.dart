class Facility {
  final String name;
  final String address;
  final String? email;
  final double? latitude;
  final double? longitude;

  const Facility({
    required this.name,
    required this.address,
    this.email,
    this.latitude,
    this.longitude,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      email: (json['email'] != null && json['email'].toString().isNotEmpty)
          ? json['email']
          : null,
      latitude: (json['latitude'] != null) ? json['latitude'].toDouble() : null,
      longitude:
          (json['longitude'] != null) ? json['longitude'].toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'Facility(name: $name, address: $address, email: $email, lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Facility &&
        other.name == name &&
        other.address == address &&
        other.email == email;
  }

  @override
  int get hashCode {
    return name.hashCode ^ address.hashCode ^ email.hashCode;
  }
}
