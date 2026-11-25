class BusStopItem {
  final String name;
  final String bengaliName;
  final String subtitle;
  final int routesCount;

  const BusStopItem({
    required this.name,
    this.bengaliName = '',
    this.subtitle = '',
    this.routesCount = 0,
  });

  String get displayName => bengaliName.isNotEmpty ? '$name ($bengaliName)' : name;
}

class KolkataStops {
  static const List<BusStopItem> popularStops = [
    BusStopItem(name: 'Howrah Station', bengaliName: 'হাওড়া স্টেশন', subtitle: 'Major Railway & Bus Terminus', routesCount: 360),
    BusStopItem(name: 'Sealdah Station', bengaliName: 'শিয়ালদহ স্টেশন', subtitle: 'Central Railway & Bus Hub', routesCount: 280),
    BusStopItem(name: 'Esplanade', bengaliName: 'এসপ্ল্যানেড / ধর্মতলা', subtitle: 'Central Kolkata Mega Transit Hub', routesCount: 450),
    BusStopItem(name: 'Sector V', bengaliName: 'সেক্টর ৫ (সল্টলেক)', subtitle: 'Salt Lake IT Hub Terminus', routesCount: 220),
    BusStopItem(name: 'Ultadanga', bengaliName: 'উল্টোডাঙা (হুডকো)', subtitle: 'North Kolkata Major Transit Hub', routesCount: 310),
    BusStopItem(name: 'Airport', bengaliName: 'নেতাজি সুভাষচন্দ্র বসু বিমানবন্দর', subtitle: 'NSCBI Airport Terminus', routesCount: 85),
    BusStopItem(name: 'Ruby Hospital', bengaliName: 'রুবি হসপিটাল', subtitle: 'EM Bypass Junction Hub', routesCount: 180),
    BusStopItem(name: 'Gariahat', bengaliName: 'গড়িয়াহাট', subtitle: 'South Kolkata Commercial Hub', routesCount: 210),
    BusStopItem(name: 'Shyambazar', bengaliName: 'শ্যামবাজার ৫-পয়েন্ট', subtitle: 'North Kolkata Heritage Crossing', routesCount: 240),
    BusStopItem(name: 'Jadavpur', bengaliName: 'যাদবপুর (৮বি)', subtitle: 'University & South Terminal', routesCount: 140),
    BusStopItem(name: 'Exide', bengaliName: 'এক্সাইড / রবীন্দ্র সদন', subtitle: 'South Central Transit Hub', routesCount: 290),
    BusStopItem(name: 'Karunamoyee', bengaliName: 'করুণাময়ী', subtitle: 'Salt Lake Central Bus & Metro Station', routesCount: 160),
    BusStopItem(name: 'Park Circus', bengaliName: 'পার্ক সার্কাস ৭-পয়েন্ট', subtitle: 'Central-South Kolkata Junction', routesCount: 230),
    BusStopItem(name: 'Howrah Maidan', bengaliName: 'হাওড়া ময়দান', subtitle: 'Metro & City Bus Hub', routesCount: 90),
    BusStopItem(name: 'Behala Chowrasta', bengaliName: 'বেহালা চৌরাস্তা', subtitle: 'Diamond Harbour Road Hub', routesCount: 144),
    BusStopItem(name: 'Garia', bengaliName: 'গড়িয়া (কবি সুভাষ)', subtitle: 'South Kolkata Terminus & Metro', routesCount: 170),
    BusStopItem(name: 'Barasat', bengaliName: 'বারাসাত', subtitle: 'North 24 Parganas District Terminus', routesCount: 190),
    BusStopItem(name: 'Barrackpore', bengaliName: 'ব্যারাকপুর', subtitle: 'BT Road Bus Terminus', routesCount: 110),
    BusStopItem(name: 'BBD Bagh', bengaliName: 'বিবাদী বাগ (ডালহৌসি)', subtitle: 'Central Business District', routesCount: 260),
    BusStopItem(name: 'Science City', bengaliName: 'সায়েন্স সিটি', subtitle: 'EM Bypass & Parama Flyover', routesCount: 130),
    BusStopItem(name: 'Chinar Park', bengaliName: 'চিনার পার্ক', subtitle: 'Rajarhat Main Road Junction', routesCount: 120),
    BusStopItem(name: 'Eco Space', bengaliName: 'ইকো স্পেস', subtitle: 'New Town Action Area II', routesCount: 95),
    BusStopItem(name: 'College More', bengaliName: 'কলেজ মোড়', subtitle: 'Sector V University Hub', routesCount: 140),
    BusStopItem(name: 'Bhowanipore', bengaliName: 'ভবানীপুর', subtitle: 'Ashutosh Mukherjee Road Hub', routesCount: 96),
    BusStopItem(name: 'New Town', bengaliName: 'নিউ টাউন', subtitle: 'Action Area I & Bus Stand', routesCount: 150),
    BusStopItem(name: 'Dunlop', bengaliName: 'ডানলপ', subtitle: 'BT Road North Gateway', routesCount: 175),
    BusStopItem(name: 'Dakshineswar', bengaliName: 'দক্ষিণেশ্বর', subtitle: 'Temple & Metro/Bus Terminus', routesCount: 140),
    BusStopItem(name: 'Santragachi', bengaliName: 'সাঁতরাগাছি', subtitle: 'Kona Expressway Bus & Rail Terminal', routesCount: 160),
    BusStopItem(name: 'Taratala', bengaliName: 'তারাতলা', subtitle: 'DH Road & Majerhat Link', routesCount: 140),
    BusStopItem(name: 'Tollygunge', bengaliName: 'টালিগঞ্জ (মহানায়ক উত্তম কুমার)', subtitle: 'Tram & Metro Terminus', routesCount: 150),
    BusStopItem(name: 'Babughat', bengaliName: 'বাবুঘাট', subtitle: 'Hooghly Riverfront Bus Stand', routesCount: 200),
    BusStopItem(name: 'Moulali', bengaliName: 'মৌলালী', subtitle: 'AJC Bose Road 4-Point', routesCount: 190),
    BusStopItem(name: 'Rajabazar', bengaliName: 'রাজাবাজার', subtitle: 'APC Road Science College', routesCount: 140),
    BusStopItem(name: 'Kankurgachi', bengaliName: 'কাঁকুড়গাছি', subtitle: 'VIP Road & Salt Lake Gateway', routesCount: 130),
    BusStopItem(name: 'Phoolbagan', bengaliName: 'ফুলবাগান', subtitle: 'Central-East Metro & Bus Hub', routesCount: 120),
    BusStopItem(name: 'Beleghata', bengaliName: 'বেলেঘাটা', subtitle: 'Building More & EM Bypass', routesCount: 110),
    BusStopItem(name: 'City Center 1', bengaliName: 'সিটি সেন্টার ১', subtitle: 'DC Block Salt Lake', routesCount: 110),
    BusStopItem(name: 'Bikash Bhawan', bengaliName: 'বিকাশ ভবন', subtitle: 'Government Secretariat Salt Lake', routesCount: 90),
    BusStopItem(name: 'Khanna Cinema', bengaliName: 'খান্না সিনেমা', subtitle: 'Shyambazar-Maniktala Link', routesCount: 100),
    BusStopItem(name: 'Belgharia', bengaliName: 'বেলঘরিয়া', subtitle: 'Express Highway & BT Road', routesCount: 95),
    BusStopItem(name: 'Sodepur', bengaliName: 'সোদপুর', subtitle: 'BT Road Commuter Hub', routesCount: 110),
    BusStopItem(name: 'Nabanna', bengaliName: 'নবান্ন', subtitle: 'State Secretariat Toll Plaza', routesCount: 120),
    BusStopItem(name: 'Mandirtala', bengaliName: 'মন্দিরতলা', subtitle: 'Vidyasagar Setu Toll Plaza', routesCount: 110),
    BusStopItem(name: 'Thakurpukur', bengaliName: 'ঠাকুরপুকুর', subtitle: 'South Suburban Transit Hub', routesCount: 100),
    BusStopItem(name: 'Joka', bengaliName: 'জোকা', subtitle: 'IIM & Diamond Harbour Road Terminus', routesCount: 80),
    BusStopItem(name: 'Mukundapur', bengaliName: 'মুকুন্দপুর', subtitle: 'AMRI & Medica Hospital Hub', routesCount: 125),
    BusStopItem(name: 'Ajay Nagar', bengaliName: 'অজয় নগর', subtitle: 'EM Bypass & Peerless Hospital', routesCount: 110),
    BusStopItem(name: 'Baghajatin', bengaliName: 'বাঘাযতীন', subtitle: 'South Eastern Rail & Bus', routesCount: 95),
    BusStopItem(name: 'Patuli', bengaliName: 'পাটুলি', subtitle: 'Floating Market & Bypass', routesCount: 85),
    BusStopItem(name: 'Kamalgazi', bengaliName: 'কমলগাজী', subtitle: 'Baruipur & Sonarpur Bypass', routesCount: 90),
    BusStopItem(name: 'Sonarpur', bengaliName: 'সোনারপুর', subtitle: 'South 24 Parganas Hub', routesCount: 80),
    BusStopItem(name: 'Baruipur', bengaliName: 'বারুইপুর', subtitle: 'District Headquarter Terminus', routesCount: 120),
    BusStopItem(name: 'Kidderpore', bengaliName: 'খিদিরপুর', subtitle: 'Tram Depot & Docks', routesCount: 130),
    BusStopItem(name: 'Majerhat', bengaliName: 'মাঝেরহাট', subtitle: 'Bridge & Rail Station', routesCount: 135),
    BusStopItem(name: 'Wipro More', bengaliName: 'উইপ্রো মোড়', subtitle: 'Sector V Core IT Hub', routesCount: 160),
    BusStopItem(name: 'College Street', bengaliName: 'কলেজ স্ট্রিট', subtitle: 'Boi Para & Presidency', routesCount: 115),
    BusStopItem(name: 'Central', bengaliName: 'সেন্ট্রাল', subtitle: 'Chittaranjan Avenue', routesCount: 180),
    BusStopItem(name: 'Chandni Chowk', bengaliName: 'চাঁদনি চক', subtitle: 'Electronics Market', routesCount: 210),
    BusStopItem(name: 'Dhakuria', bengaliName: 'ঢাকুড়িয়া', subtitle: 'Southern Avenue Link', routesCount: 110),
    BusStopItem(name: 'Golpark', bengaliName: 'গোলপার্ক', subtitle: 'Ramakrishna Mission Circle', routesCount: 130),
  ];

  /// Instant local fuzzy match (0ms latency, 100% offline resilient)
  static List<BusStopItem> searchLocal(String query, {int limit = 12}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return popularStops.take(limit).toList();
    }

    // 1. Prefix matches (e.g. "how" -> Howrah Station first)
    final prefix = <BusStopItem>[];
    // 2. Contains matches (e.g. "sec" -> Falta Sector 1)
    final contains = <BusStopItem>[];

    for (final stop in popularStops) {
      final nameLower = stop.name.toLowerCase();
      final bengaliLower = stop.bengaliName.toLowerCase();
      final subLower = stop.subtitle.toLowerCase();

      if (nameLower.startsWith(q) || bengaliLower.startsWith(q)) {
        prefix.add(stop);
      } else if (nameLower.contains(q) || bengaliLower.contains(q) || subLower.contains(q)) {
        contains.add(stop);
      }
    }

    prefix.sort((a, b) => b.routesCount.compareTo(a.routesCount));
    contains.sort((a, b) => b.routesCount.compareTo(a.routesCount));

    return [...prefix, ...contains].take(limit).toList();
  }
}

