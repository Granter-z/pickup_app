enum AddressComponentType {
  province,
  city,
  district,
  street,
  road,
  community,
  building,
  unit,
  room,
  poi,
  station,
  number,
  unknown,
}

class AddressComponent {
  final String text;
  final AddressComponentType type;
  final double confidence;

  const AddressComponent({
    required this.text,
    required this.type,
    this.confidence = 1.0,
  });

  @override
  String toString() => 'AddressComponent($type: "$text", confidence: $confidence)';
}

class ParsedAddress {
  final String? province;
  final String? city;
  final String? district;
  final String? street;
  final String? road;
  final String? community;
  final String? poi;
  final String? station;
  final String? building;
  final String? unit;
  final String? room;
  final String? number;
  final String rawText;
  final List<AddressComponent> components;
  final double confidence;
  final List<String> warnings;

  const ParsedAddress({
    this.province,
    this.city,
    this.district,
    this.street,
    this.road,
    this.community,
    this.poi,
    this.station,
    this.building,
    this.unit,
    this.room,
    this.number,
    required this.rawText,
    this.components = const [],
    this.confidence = 1.0,
    this.warnings = const [],
  });

  bool get isValid => rawText.isNotEmpty;

  bool get hasRegionInfo => province != null || city != null || district != null;

  bool get hasDetailInfo =>
      building != null || unit != null || room != null || number != null;

  String get fullAddress {
    final parts = <String>[
      if (province != null) province!,
      if (city != null) city!,
      if (district != null) district!,
      if (street != null) street!,
      if (road != null) road!,
      if (community != null) community!,
      if (building != null) building!,
      if (unit != null) unit!,
      if (room != null) room!,
      if (number != null) number!,
      if (poi != null) poi!,
      if (station != null) station!,
    ];
    return parts.isEmpty ? rawText : parts.join();
  }

  ParsedAddress copyWith({
    String? province,
    String? city,
    String? district,
    String? street,
    String? road,
    String? community,
    String? poi,
    String? station,
    String? building,
    String? unit,
    String? room,
    String? number,
    String? rawText,
    List<AddressComponent>? components,
    double? confidence,
    List<String>? warnings,
  }) {
    return ParsedAddress(
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      street: street ?? this.street,
      road: road ?? this.road,
      community: community ?? this.community,
      poi: poi ?? this.poi,
      station: station ?? this.station,
      building: building ?? this.building,
      unit: unit ?? this.unit,
      room: room ?? this.room,
      number: number ?? this.number,
      rawText: rawText ?? this.rawText,
      components: components ?? this.components,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
    );
  }

  @override
  String toString() => 'ParsedAddress("$fullAddress", confidence: $confidence)';
}
