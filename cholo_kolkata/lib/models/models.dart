class BusRoute {
  final int id;
  final String routeNo;
  final String routeName;
  final String origin;
  final String destination;
  final String busType;
  final String category;
  final int totalStops;
  final int? stopsBetween;
  final String? fromStop;
  final String? toStop;
  final int estimatedFare;
  final String fareText;
  final String? mediaToken;
  final bool isReturn;

  BusRoute({
    required this.id,
    required this.routeNo,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.busType,
    required this.category,
    required this.totalStops,
    this.stopsBetween,
    this.fromStop,
    this.toStop,
    required this.estimatedFare,
    required this.fareText,
    this.mediaToken,
    this.isReturn = false,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] ?? 0,
      routeNo: json['route_no'] ?? '',
      routeName: json['route_name'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      busType: json['bus_type'] ?? 'Ordinary Bus',
      category: json['category'] ?? 'Kolkata Bus',
      totalStops: json['total_stops'] ?? 0,
      stopsBetween: json['stops_between'],
      fromStop: json['from_stop'],
      toStop: json['to_stop'],
      estimatedFare: json['estimated_fare'] ?? 10,
      fareText: json['fare_text'] ?? '₹10',
      mediaToken: json['media_token'],
      isReturn: json['is_return'] == 1,
    );
  }
}

class TransferLeg {
  final int id;
  final String routeNo;
  final String routeName;
  final String busType;
  final String fromStop;
  final String toStop;
  final int stops;
  final int fare;

  TransferLeg({
    required this.id,
    required this.routeNo,
    required this.routeName,
    required this.busType,
    required this.fromStop,
    required this.toStop,
    required this.stops,
    required this.fare,
  });

  factory TransferLeg.fromJson(Map<String, dynamic> json) {
    return TransferLeg(
      id: json['id'] ?? 0,
      routeNo: json['route_no'] ?? '',
      routeName: json['route_name'] ?? '',
      busType: json['bus_type'] ?? 'Ordinary Bus',
      fromStop: json['from_stop'] ?? '',
      toStop: json['to_stop'] ?? json['hub_stop'] ?? '',
      stops: json['stops'] ?? 0,
      fare: json['fare'] ?? 10,
    );
  }
}

class TransferRoute {
  final String hubName;
  final TransferLeg leg1;
  final TransferLeg leg2;
  final int totalStops;
  final int totalTimeMins;
  final int totalFare;
  final String fareText;

  TransferRoute({
    required this.hubName,
    required this.leg1,
    required this.leg2,
    required this.totalStops,
    required this.totalTimeMins,
    required this.totalFare,
    required this.fareText,
  });

  factory TransferRoute.fromJson(Map<String, dynamic> json) {
    return TransferRoute(
      hubName: json['hub_name'] ?? '',
      leg1: TransferLeg.fromJson(json['leg1']),
      leg2: TransferLeg.fromJson(json['leg2']),
      totalStops: json['total_stops'] ?? 0,
      totalTimeMins: json['total_time_mins'] ?? 0,
      totalFare: json['total_fare'] ?? 0,
      fareText: json['fare_text'] ?? '₹0',
    );
  }
}

class MetroLine {
  final String lineId;
  final String lineNumber;
  final String lineName;
  final String lineColor;
  final String terminalFrom;
  final String terminalTo;
  final String firstTrain;
  final String lastTrain;
  final String peakHeadway;
  final String offpeakHeadway;
  final int totalStations;
  final String specialFeature;

  MetroLine({
    required this.lineId,
    required this.lineNumber,
    required this.lineName,
    required this.lineColor,
    required this.terminalFrom,
    required this.terminalTo,
    required this.firstTrain,
    required this.lastTrain,
    required this.peakHeadway,
    required this.offpeakHeadway,
    required this.totalStations,
    required this.specialFeature,
  });

  factory MetroLine.fromJson(Map<String, dynamic> json) {
    return MetroLine(
      lineId: json['line_id'] ?? '',
      lineNumber: json['line_number']?.toString() ?? '',
      lineName: json['line_name'] ?? '',
      lineColor: json['line_color'] ?? '#00897B',
      terminalFrom: json['terminal_from'] ?? '',
      terminalTo: json['terminal_to'] ?? '',
      firstTrain: json['first_train'] ?? '',
      lastTrain: json['last_train'] ?? '',
      peakHeadway: json['peak_headway'] ?? '',
      offpeakHeadway: json['offpeak_headway'] ?? '',
      totalStations: json['total_stations'] ?? 0,
      specialFeature: json['special_feature'] ?? '',
    );
  }
}

class MetroStation {
  final String stationName;
  final String? stationBengali;
  final String lineId;
  final String lineName;
  final String lineColor;
  final double distanceKm;
  final String? interchangeInfo;

  MetroStation({
    required this.stationName,
    this.stationBengali,
    required this.lineId,
    required this.lineName,
    required this.lineColor,
    required this.distanceKm,
    this.interchangeInfo,
  });

  factory MetroStation.fromJson(Map<String, dynamic> json) {
    return MetroStation(
      stationName: json['station_name'] ?? '',
      stationBengali: json['station_bengali'],
      lineId: json['line_id'] ?? '',
      lineName: json['line_name'] ?? '',
      lineColor: json['line_color'] ?? '#00897B',
      distanceKm: (json['distance_km'] is num) ? (json['distance_km'] as num).toDouble() : 0.0,
      interchangeInfo: json['interchange_info'],
    );
  }
}

class MetroPlan {
  final String type; // DIRECT or INTERCHANGE
  final String fromStation;
  final String toStation;
  final int stationsCount;
  final double distanceKm;
  final int durationMins;
  final int fare;
  final String fareText;
  final String? instructions;
  final String? interchangeStation;
  final String? lineName;
  final String? lineColor;
  final List<MetroStation> stations;

  MetroPlan({
    required this.type,
    required this.fromStation,
    required this.toStation,
    required this.stationsCount,
    required this.distanceKm,
    required this.durationMins,
    required this.fare,
    required this.fareText,
    this.instructions,
    this.interchangeStation,
    this.lineName,
    this.lineColor,
    this.stations = const [],
  });

  factory MetroPlan.fromJson(Map<String, dynamic> json) {
    var rawStns = json['stations'] as List? ?? [];
    return MetroPlan(
      type: json['type'] ?? 'DIRECT',
      fromStation: json['from_station'] ?? '',
      toStation: json['to_station'] ?? '',
      stationsCount: json['stations_count'] ?? 0,
      distanceKm: (json['distance_km'] is num) ? (json['distance_km'] as num).toDouble() : 0.0,
      durationMins: json['duration_mins'] ?? 0,
      fare: json['fare'] ?? 10,
      fareText: json['fare_text'] ?? '₹10',
      instructions: json['instructions'],
      interchangeStation: json['interchange_station'],
      lineName: json['line_name'],
      lineColor: json['line_color'],
      stations: rawStns.map((s) => MetroStation.fromJson(s)).toList(),
    );
  }
}

class ChatMessage {
  final int id;
  final String channel;
  final String userName;
  final String routeRef;
  final String statusTag;
  final String message;
  final String timeStr;

  ChatMessage({
    required this.id,
    required this.channel,
    required this.userName,
    required this.routeRef,
    required this.statusTag,
    required this.message,
    required this.timeStr,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      channel: json['channel'] ?? 'general',
      userName: json['user_name'] ?? 'Commuter',
      routeRef: json['route_ref'] ?? '',
      statusTag: json['status_tag'] ?? 'Normal',
      message: json['message'] ?? '',
      timeStr: json['time_str'] ?? '',
    );
  }
}

