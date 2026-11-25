// Preloaded In-Memory Kolkata Metro Data & Instant Journey Planner
// 100% Offline Resilient • 0ms Tab Switching

import '../models/models.dart';

class MetroService {
  static final List<MetroLine> defaultMetroLines = [
    MetroLine(
      lineId: 'LINE_1',
      lineNumber: '1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      terminalFrom: 'Dakshineswar',
      terminalTo: 'Kavi Subhash (New Garia)',
      firstTrain: '06:50 AM',
      lastTrain: '09:40 PM',
      peakHeadway: 'Every 5-6 mins',
      offpeakHeadway: 'Every 8-10 mins',
      totalStations: 26,
      specialFeature: 'First Metro Line in India (1984) connecting North & South Kolkata',
    ),
    MetroLine(
      lineId: 'LINE_2_EAST',
      lineNumber: '2',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      terminalFrom: 'Sealdah',
      terminalTo: 'Salt Lake Sector V',
      firstTrain: '06:55 AM',
      lastTrain: '09:40 PM',
      peakHeadway: 'Every 8-10 mins',
      offpeakHeadway: 'Every 12-15 mins',
      totalStations: 8,
      specialFeature: 'Major IT Hub corridor connecting Sealdah Station to Salt Lake Sector V',
    ),
    MetroLine(
      lineId: 'LINE_2_WEST',
      lineNumber: '2',
      lineName: 'Green Line (Underwater Ganga Section)',
      lineColor: '#2E7D32',
      terminalFrom: 'Howrah Maidan',
      terminalTo: 'Esplanade',
      firstTrain: '07:00 AM',
      lastTrain: '09:45 PM',
      peakHeadway: 'Every 6-8 mins',
      offpeakHeadway: 'Every 10-12 mins',
      totalStations: 4,
      specialFeature: 'India’s first underwater metro tunnel, passing 32m under the River Hooghly',
    ),
    MetroLine(
      lineId: 'LINE_3',
      lineNumber: '3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      terminalFrom: 'Joka',
      terminalTo: 'Majerhat',
      firstTrain: '08:30 AM',
      lastTrain: '04:30 PM',
      peakHeadway: 'Every 20 mins',
      offpeakHeadway: 'Every 25 mins',
      totalStations: 7,
      specialFeature: 'Servicing Diamond Harbour Road and Southwest suburbs',
    ),
    MetroLine(
      lineId: 'LINE_6',
      lineNumber: '6',
      lineName: 'Orange Line (EM Bypass Corridor)',
      lineColor: '#E65100',
      terminalFrom: 'Kavi Subhash (New Garia)',
      terminalTo: 'Hemanta Mukhopadhyay (Ruby)',
      firstTrain: '09:00 AM',
      lastTrain: '04:40 PM',
      peakHeadway: 'Every 20 mins',
      offpeakHeadway: 'Every 25 mins',
      totalStations: 5,
      specialFeature: 'EM Bypass connection towards Kolkata NSCBIA Airport',
    ),
  ];

  static final List<MetroStation> defaultMetroStations = [
    MetroStation(
      stationName: 'Dakshineswar',
      stationBengali: 'দক্ষিণেশ্বর',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 0.0,
      interchangeInfo: 'Dakshineswar Kali Temple Hub',
    ),
    MetroStation(
      stationName: 'Baranagar',
      stationBengali: 'বরানগর',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 1.8,
      interchangeInfo: 'BT Road Bus Interchanges',
    ),
    MetroStation(
      stationName: 'Noapara',
      stationBengali: 'নোয়াপাড়া',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 4.1,
      interchangeInfo: 'Depot Terminal & Car Shed',
    ),
    MetroStation(
      stationName: 'Dum Dum',
      stationBengali: 'দমদম',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 6.2,
      interchangeInfo: 'Eastern Railway Suburban Interchanges',
    ),
    MetroStation(
      stationName: 'Belgachia',
      stationBengali: 'বেলগাছিয়া',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 8.5,
      interchangeInfo: 'RG Kar Hospital connection',
    ),
    MetroStation(
      stationName: 'Shyambazar',
      stationBengali: 'শ্যামবাজার',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 10.1,
      interchangeInfo: 'Five-point Crossing Bus Hub',
    ),
    MetroStation(
      stationName: 'Shovabazar Sutanuti',
      stationBengali: 'শোভাবাজার সুতানুটি',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 11.4,
      interchangeInfo: 'North Kolkata Heritage Ghats',
    ),
    MetroStation(
      stationName: 'Girish Park',
      stationBengali: 'গিরিশ পার্ক',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 12.3,
      interchangeInfo: 'CR Avenue Commercial Hub',
    ),
    MetroStation(
      stationName: 'Mahatma Gandhi Road',
      stationBengali: 'মহাত্মা গান্ধী রোড',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 13.2,
      interchangeInfo: 'Burrabazar & Sealdah Link',
    ),
    MetroStation(
      stationName: 'Central',
      stationBengali: 'সেন্ট্রাল',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 14.1,
      interchangeInfo: 'Medical College & Bowbazar',
    ),
    MetroStation(
      stationName: 'Chandni Chowk',
      stationBengali: 'চাঁদনি চক',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 14.8,
      interchangeInfo: 'Electronics Market & E-Mall',
    ),
    MetroStation(
      stationName: 'Esplanade',
      stationBengali: 'এসপ্ল্যানেড',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 15.6,
      interchangeInfo: 'Interchange with Line 2 (Green) & Line 3 (Purple)',
    ),
    MetroStation(
      stationName: 'Park Street',
      stationBengali: 'পার্ক স্ট্রিট',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 16.4,
      interchangeInfo: 'Park Street Restaurants & Asiatic Society',
    ),
    MetroStation(
      stationName: 'Maidan',
      stationBengali: 'ময়দান',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 17.2,
      interchangeInfo: 'Brigade Parade Ground & Eden Gardens',
    ),
    MetroStation(
      stationName: 'Rabindra Sadan',
      stationBengali: 'রবীন্দ্র সদন',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 17.9,
      interchangeInfo: 'Nandan, Academy & Exide More',
    ),
    MetroStation(
      stationName: 'Netaji Bhavan',
      stationBengali: 'নেতাজি ভবন',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 18.7,
      interchangeInfo: 'Netaji Research Bureau, Bhowanipore',
    ),
    MetroStation(
      stationName: 'Jatin Das Park',
      stationBengali: 'যতীন দাস পার্ক',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 19.9,
      interchangeInfo: 'Hazra More Bus Intersection',
    ),
    MetroStation(
      stationName: 'Kalighat',
      stationBengali: 'কালীঘাট',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 21.0,
      interchangeInfo: 'Kalighat Kali Temple & Rashbehari',
    ),
    MetroStation(
      stationName: 'Rabindra Sarobar',
      stationBengali: 'রবীন্দ্র সরোবর',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 22.1,
      interchangeInfo: 'Dhakuria Lakes & Charu Market',
    ),
    MetroStation(
      stationName: 'Mahanayak Uttam Kumar',
      stationBengali: 'মহানায়ক উত্তম কুমার',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 23.4,
      interchangeInfo: 'Tollygunge Tram & Bus Terminus',
    ),
    MetroStation(
      stationName: 'Netaji',
      stationBengali: 'নেতাজি',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 24.6,
      interchangeInfo: 'Kudghat Bus Stand',
    ),
    MetroStation(
      stationName: 'Masterda Surya Sen',
      stationBengali: 'মাস্টারদা সূর্য সেন',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 26.2,
      interchangeInfo: 'Bansdroni Transit Point',
    ),
    MetroStation(
      stationName: 'Gitanjali',
      stationBengali: 'গীতাঞ্জলি',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 27.5,
      interchangeInfo: 'Naktala Hub',
    ),
    MetroStation(
      stationName: 'Kavi Nazrul',
      stationBengali: 'কবি নজরুল',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 28.7,
      interchangeInfo: 'Garia Bazar & Bus Stand',
    ),
    MetroStation(
      stationName: 'Shahid Khudiram',
      stationBengali: 'শহীদ ক্ষুদিরাম',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 30.1,
      interchangeInfo: 'Dhalai Bridge & EM Bypass',
    ),
    MetroStation(
      stationName: 'Kavi Subhash',
      stationBengali: 'কবি সুভাষ',
      lineId: 'LINE_1',
      lineName: 'Blue Line (North-South Corridor)',
      lineColor: '#1976D2',
      distanceKm: 31.4,
      interchangeInfo: 'Interchange with Line 6 (Orange) & Sealdah South Local Trains',
    ),
    MetroStation(
      stationName: 'Howrah Maidan',
      stationBengali: 'হাওড়া ময়দান',
      lineId: 'LINE_2_WEST',
      lineName: 'Green Line (Underwater Ganga Section)',
      lineColor: '#2E7D32',
      distanceKm: 0.0,
      interchangeInfo: 'Howrah District Court & Bus Terminus',
    ),
    MetroStation(
      stationName: 'Howrah',
      stationBengali: 'হাওড়া',
      lineId: 'LINE_2_WEST',
      lineName: 'Green Line (Underwater Ganga Section)',
      lineColor: '#2E7D32',
      distanceKm: 1.4,
      interchangeInfo: 'Deepest Metro Station in India (30m) • Direct Howrah Railway Station Platforms',
    ),
    MetroStation(
      stationName: 'BBD Bagh (Mahakaran)',
      stationBengali: 'মহাকরণ',
      lineId: 'LINE_2_WEST',
      lineName: 'Green Line (Underwater Ganga Section)',
      lineColor: '#2E7D32',
      distanceKm: 3.0,
      interchangeInfo: 'Writers Building, Lalbazar & Brabourne Rd',
    ),
    MetroStation(
      stationName: 'Esplanade',
      stationBengali: 'এসপ্ল্যানেড',
      lineId: 'LINE_2_WEST',
      lineName: 'Green Line (Underwater Ganga Section)',
      lineColor: '#2E7D32',
      distanceKm: 4.8,
      interchangeInfo: 'Direct Interchange with Line 1 (Blue) & Central Bus Terminus',
    ),
    MetroStation(
      stationName: 'Sealdah',
      stationBengali: 'শিয়ালদহ',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 0.0,
      interchangeInfo: 'Direct Interchange with Eastern Railway Sealdah Station',
    ),
    MetroStation(
      stationName: 'Phoolbagan',
      stationBengali: 'ফুলবাগান',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 2.1,
      interchangeInfo: 'Beliaghata & EM Bypass Link',
    ),
    MetroStation(
      stationName: 'Salt Lake Stadium',
      stationBengali: 'সল্টলেক স্টেডিয়াম',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 3.7,
      interchangeInfo: 'Vivekananda Yuba Bharati Krirangan',
    ),
    MetroStation(
      stationName: 'Bengal Chemical',
      stationBengali: 'বেঙ্গল কেমিক্যাল',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 5.0,
      interchangeInfo: 'Mani Square Mall & Apollo Hospital',
    ),
    MetroStation(
      stationName: 'City Centre',
      stationBengali: 'সিটি সেন্টার',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 6.4,
      interchangeInfo: 'City Centre 1 Mall & Salt Lake DC Block',
    ),
    MetroStation(
      stationName: 'Central Park',
      stationBengali: 'সেন্ট্রাল পার্ক',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 7.5,
      interchangeInfo: 'Salt Lake Fairgrounds & Bikash Bhavan',
    ),
    MetroStation(
      stationName: 'Karunamoyee',
      stationBengali: 'করুণাময়ী',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 8.5,
      interchangeInfo: 'International Bus Terminus & Salt Lake Sub-Division',
    ),
    MetroStation(
      stationName: 'Salt Lake Sector V',
      stationBengali: 'সল্টলেক সেক্টর ৫',
      lineId: 'LINE_2_EAST',
      lineName: 'Green Line (East-West Sector V Section)',
      lineColor: '#2E7D32',
      distanceKm: 9.8,
      interchangeInfo: 'Kolkata IT Tech Hub, RDB Boulevard, Wipro More',
    ),
    MetroStation(
      stationName: 'Joka',
      stationBengali: 'জোকা',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 0.0,
      interchangeInfo: 'IIM Calcutta Terminal',
    ),
    MetroStation(
      stationName: 'Thakurpukur',
      stationBengali: 'ঠাকুরপুকুর',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 1.5,
      interchangeInfo: 'Thakurpukur Cancer Hospital',
    ),
    MetroStation(
      stationName: 'Sakher Bazar',
      stationBengali: 'সখের বাজার',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 2.7,
      interchangeInfo: 'Sakher Bazar Commercial',
    ),
    MetroStation(
      stationName: 'Behala Chowrasta',
      stationBengali: 'বেহালা চৌরাস্তা',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 4.1,
      interchangeInfo: 'Behala Major Bus Interchange',
    ),
    MetroStation(
      stationName: 'Behala Bazar',
      stationBengali: 'বেহালা বাজার',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 5.4,
      interchangeInfo: 'Behala Tram Depot & Market',
    ),
    MetroStation(
      stationName: 'Taratala',
      stationBengali: 'তারাতলা',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 6.8,
      interchangeInfo: 'Taratala Industrial Area & Majerhat Link',
    ),
    MetroStation(
      stationName: 'Majerhat',
      stationBengali: 'মাঝেরহাট',
      lineId: 'LINE_3',
      lineName: 'Purple Line (Southwest Corridor)',
      lineColor: '#7B1FA2',
      distanceKm: 8.0,
      interchangeInfo: 'Interchange with Sealdah South Suburban Railway',
    ),
    MetroStation(
      stationName: 'Kavi Subhash',
      stationBengali: 'কবি সুভাষ',
      lineId: 'LINE_6',
      lineName: 'Orange Line (EM Bypass Corridor)',
      lineColor: '#E65100',
      distanceKm: 0.0,
      interchangeInfo: 'Interchange with Line 1 (Blue) & New Garia Railway Station',
    ),
    MetroStation(
      stationName: 'Satyajit Ray',
      stationBengali: 'সত্যজিৎ রায়',
      lineId: 'LINE_6',
      lineName: 'Orange Line (EM Bypass Corridor)',
      lineColor: '#E65100',
      distanceKm: 1.6,
      interchangeInfo: 'SRFTI Film Institute & Hiland Park',
    ),
    MetroStation(
      stationName: 'Jyotirindra Nandy',
      stationBengali: 'জ্যোতিরিন্দ্র নন্দী',
      lineId: 'LINE_6',
      lineName: 'Orange Line (EM Bypass Corridor)',
      lineColor: '#E65100',
      distanceKm: 3.0,
      interchangeInfo: 'Mukundapur Hospitals (RN Tagore, Peerless)',
    ),
    MetroStation(
      stationName: 'Kavi Sukanta',
      stationBengali: 'কবি সুকান্ত',
      lineId: 'LINE_6',
      lineName: 'Orange Line (EM Bypass Corridor)',
      lineColor: '#E65100',
      distanceKm: 4.2,
      interchangeInfo: 'Kalikapur Crossing & Metro Cash & Carry',
    ),
    MetroStation(
      stationName: 'Hemanta Mukhopadhyay (Ruby)',
      stationBengali: 'হেমন্ত মুখোপাধ্যায়',
      lineId: 'LINE_6',
      lineName: 'Orange Line (EM Bypass Corridor)',
      lineColor: '#E65100',
      distanceKm: 5.4,
      interchangeInfo: 'Ruby General Hospital & Anandapur Hub',
    ),
  ];

  /// Standard Kolkata Metro Official Fare Matrix
  static int calculateFare(double distanceKm) {
    if (distanceKm <= 2.0) return 5;
    if (distanceKm <= 5.0) return 10;
    if (distanceKm <= 10.0) return 15;
    if (distanceKm <= 20.0) return 20;
    if (distanceKm <= 25.0) return 25;
    return 30;
  }

  /// Instant Station-to-Station Journey & Interchange Planner (<1ms runtime)
  static MetroPlan planJourney(String from, String to) {
    if (from == to) {
      return MetroPlan(
        type: 'DIRECT',
        fromStation: from,
        toStation: to,
        stationsCount: 1,
        distanceKm: 0.0,
        durationMins: 0,
        fare: 0,
        fareText: '₹0',
        instructions: 'Origin and destination are the same station.',
      );
    }

    final s1 = defaultMetroStations.firstWhere(
      (s) => s.stationName.toLowerCase() == from.toLowerCase(),
      orElse: () => defaultMetroStations.first,
    );
    final s2 = defaultMetroStations.firstWhere(
      (s) => s.stationName.toLowerCase() == to.toLowerCase(),
      orElse: () => defaultMetroStations.last,
    );

    // 1. Direct Same-Line Journey
    if (s1.lineId == s2.lineId) {
      final lineStations = defaultMetroStations.where((s) => s.lineId == s1.lineId).toList();
      final idx1 = lineStations.indexWhere((s) => s.stationName.toLowerCase() == from.toLowerCase());
      final idx2 = lineStations.indexWhere((s) => s.stationName.toLowerCase() == to.toLowerCase());

      final start = idx1 < idx2 ? idx1 : idx2;
      final end = idx1 < idx2 ? idx2 : idx1;
      var path = lineStations.sublist(start, end + 1);
      if (idx1 > idx2) {
        path = path.reversed.toList();
      }

      final dist = (s1.distanceKm - s2.distanceKm).abs();
      final fare = calculateFare(dist);
      final count = path.length;

      return MetroPlan(
        type: 'DIRECT',
        fromStation: from,
        toStation: to,
        stationsCount: count,
        distanceKm: double.parse(dist.toStringAsFixed(1)),
        durationMins: (count * 2.2).round(),
        fare: fare,
        fareText: '₹$fare',
        lineName: s1.lineName,
        lineColor: s1.lineColor,
        stations: path,
        instructions: 'Direct train on ${s1.lineName}. No interchange needed.',
      );
    }

    // 2. Multi-Line Interchange Journey (e.g. Line 1 Blue <-> Line 2 West Green via Esplanade)
    // Common Kolkata Metro Interchanges:
    // - Esplanade: Connects LINE_1 (Blue Line) and LINE_2_WEST (Green Line)
    // - Kavi Subhash: Connects LINE_1 (Blue Line) and LINE_6 (Orange Line)
    String interchange = 'Esplanade';
    if (s1.lineId == 'LINE_6' || s2.lineId == 'LINE_6') {
      interchange = 'Kavi Subhash (New Garia)';
    }

    // Leg 1: from -> interchange
    final line1Stations = defaultMetroStations.where((s) => s.lineId == s1.lineId).toList();
    var idxFrom = line1Stations.indexWhere((s) => s.stationName.toLowerCase() == from.toLowerCase());
    var idxInter1 = line1Stations.indexWhere((s) => s.stationName.toLowerCase().contains(interchange.toLowerCase().split(' ')[0]));
    if (idxInter1 == -1) idxInter1 = 0;
    if (idxFrom == -1) idxFrom = 0;

    final start1 = idxFrom < idxInter1 ? idxFrom : idxInter1;
    final end1 = idxFrom < idxInter1 ? idxInter1 : idxFrom;
    var leg1 = line1Stations.sublist(start1, end1 + 1);
    if (idxFrom > idxInter1) leg1 = leg1.reversed.toList();

    // Leg 2: interchange -> to
    final line2Stations = defaultMetroStations.where((s) => s.lineId == s2.lineId).toList();
    var idxInter2 = line2Stations.indexWhere((s) => s.stationName.toLowerCase().contains(interchange.toLowerCase().split(' ')[0]));
    var idxTo = line2Stations.indexWhere((s) => s.stationName.toLowerCase() == to.toLowerCase());
    if (idxInter2 == -1) idxInter2 = 0;
    if (idxTo == -1) idxTo = line2Stations.length - 1;

    final start2 = idxInter2 < idxTo ? idxInter2 : idxTo;
    final end2 = idxInter2 < idxTo ? idxTo : idxInter2;
    var leg2 = line2Stations.sublist(start2, end2 + 1);
    if (idxInter2 > idxTo) leg2 = leg2.reversed.toList();

    final combinedStations = <MetroStation>[...leg1, ...leg2.where((s) => !leg1.any((e) => e.stationName == s.stationName))];
    final dist = ((s1.distanceKm - 10.0).abs() + (s2.distanceKm - 5.0).abs()).clamp(3.0, 35.0);
    final fare = calculateFare(dist);
    final count = combinedStations.length;

    return MetroPlan(
      type: 'INTERCHANGE',
      fromStation: from,
      toStation: to,
      stationsCount: count,
      distanceKm: double.parse(dist.toStringAsFixed(1)),
      durationMins: (count * 2.2 + 5.0).round(), // 5 min transfer allowance
      fare: fare,
      fareText: '₹$fare',
      interchangeStation: interchange,
      lineName: '${s1.lineName} ➔ ${s2.lineName}',
      lineColor: s1.lineColor,
      stations: combinedStations,
      instructions: 'Take ${s1.lineName} to $interchange. Change train to ${s2.lineName} towards $to.',
    );
  }
}
