import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'results_screen.dart';

class SpotBusScreen extends StatefulWidget {
  const SpotBusScreen({super.key});

  @override
  State<SpotBusScreen> createState() => _SpotBusScreenState();
}

class _SpotBusScreenState extends State<SpotBusScreen> {
  final ApiService _api = ApiService();

  final TextEditingController _fromCtrl = TextEditingController(text: 'Howrah Station');
  final TextEditingController _toCtrl = TextEditingController(text: 'Sector V');
  final TextEditingController _busNoCtrl = TextEditingController();

  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  List<BusRoute> _busSuggestions = [];
  bool _showFromSuggestions = false;
  bool _showToSuggestions = false;
  bool _showBusSuggestions = false;

  final List<String> _popularBusNumbers = [
    '215A', 'S-12', 'AC-12', '44A', 'AC-24', 'V-1', '12C', '201', 'S-24', '30B'
  ];

  String _alert = '';

  final List<Map<String, String>> _recentSearches = [
    {'from': 'Howrah Station', 'to': 'Sector V'},
    {'from': 'Esplanade', 'to': 'Airport'},
    {'from': 'Ultadanga', 'to': 'Ruby Hospital'},
    {'from': 'Sealdah Station', 'to': 'Howrah Station'},
  ];

  void _onFromChanged(String val) async {
    if (val.trim().length < 2) {
      setState(() {
        _fromSuggestions = [];
        _showFromSuggestions = false;
      });
      return;
    }
    final results = await _api.searchStops(val);
    setState(() {
      _fromSuggestions = results;
      _showFromSuggestions = results.isNotEmpty;
    });
  }

  void _onToChanged(String val) async {
    if (val.trim().length < 2) {
      setState(() {
        _toSuggestions = [];
        _showToSuggestions = false;
      });
      return;
    }
    final results = await _api.searchStops(val);
    setState(() {
      _toSuggestions = results;
      _showToSuggestions = results.isNotEmpty;
    });
  }

  void _swapStops() {
    setState(() {
      final temp = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = temp;
    });
  }

  void _findBuses() {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();

    if (from.isEmpty || to.isEmpty) {
      setState(() => _alert = 'Please enter both departure and destination stops.');
      return;
    }

    setState(() => _alert = '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ResultsScreen(fromStop: from, toStop: to),
      ),
    );
  }

  void _onBusNoChanged(String val) async {
    if (val.trim().isEmpty) {
      setState(() {
        _busSuggestions = [];
        _showBusSuggestions = false;
      });
      return;
    }
    final results = await _api.searchBusNumbers(val);
    setState(() {
      _busSuggestions = results;
      _showBusSuggestions = results.isNotEmpty;
    });
  }

  void _searchByBusNumber([String? term]) {
    final busNo = (term ?? _busNoCtrl.text).trim();
    if (busNo.isEmpty) return;
    _busNoCtrl.text = busNo;
    setState(() => _showBusSuggestions = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ResultsScreen(fromStop: busNo, toStop: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // CARD 1: FROM ➔ TO SEARCH (Authentic WIMT Clear Writable Card)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // From Stop Input Box
                const Text('FROM BUS STOP', style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF2E7D32), size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _fromCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: InputBorder.none,
                            hintText: 'Type departure stop (e.g. Howrah Station)',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                          onChanged: _onFromChanged,
                        ),
                      ),
                      if (_fromCtrl.text.isNotEmpty)
                        InkWell(
                          onTap: () => setState(() => _fromCtrl.clear()),
                          child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                        ),
                    ],
                  ),
                ),

                // From Autocomplete Suggestions
                if (_showFromSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: _fromSuggestions.map((s) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _fromCtrl.text = s;
                              _showFromSuggestions = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Color(0xFF00695C)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Dashed line & Circular Swap Button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 15),
                        height: 20,
                        width: 2,
                        color: Colors.grey[400],
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _swapStops,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 3)],
                          ),
                          child: const Icon(Icons.swap_vert, size: 20, color: Color(0xFF00695C)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // To Stop Input Box
                const Text('TO BUS STOP', style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFFD32F2F), size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _toCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: InputBorder.none,
                            hintText: 'Type destination stop (e.g. Sector V)',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                          onChanged: _onToChanged,
                        ),
                      ),
                      if (_toCtrl.text.isNotEmpty)
                        InkWell(
                          onTap: () => setState(() => _toCtrl.clear()),
                          child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                        ),
                    ],
                  ),
                ),

                // To Autocomplete Suggestions
                if (_showToSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: _toSuggestions.map((s) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _toCtrl.text = s;
                              _showToSuggestions = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Color(0xFFD32F2F)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                if (_alert.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_alert, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),

                const SizedBox(height: 14),

                // Solid Teal FIND BUSES button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: _findBuses,
                    child: const Text('FIND BUSES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // CARD 2: BUS NUMBER / ROUTE NAME LOOKUP (With Autocomplete & Suggestions)
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tag, color: Color(0xFF00897B), size: 16),
                    SizedBox(width: 6),
                    Text('BUS NO. / ROUTE LOOKUP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF546E7A), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _busNoCtrl,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                                  border: InputBorder.none,
                                  hintText: 'e.g. 215A, S-12, AC-12, 44A',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                onChanged: _onBusNoChanged,
                                onSubmitted: (_) => _searchByBusNumber(),
                              ),
                            ),
                            if (_busNoCtrl.text.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _busNoCtrl.clear();
                                    _showBusSuggestions = false;
                                  });
                                },
                                child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _searchByBusNumber(),
                      child: const Text('SEARCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),

                // Live Bus Number Autocomplete Suggestions List
                if (_showBusSuggestions && _busSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF80CBC4)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: _busSuggestions.take(5).map((r) {
                        return InkWell(
                          onTap: () => _searchByBusNumber(r.routeNo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00695C),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(r.routeNo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('${r.origin} ➔ ${r.destination}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 6),
                                Text(r.fareText, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 10),

                // Popular Route Suggestions Chips
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Color(0xFFFFA000)),
                    const SizedBox(width: 4),
                    const Text('SUGGESTIONS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF78909C), letterSpacing: 0.5)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _popularBusNumbers.map((no) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                backgroundColor: const Color(0xFFE0F2F1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFB2DFDB)),
                                ),
                                label: Text(no, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                onPressed: () => _searchByBusNumber(no),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // CARD 3: RECENT SEARCHES (Exact WIMT Commuter Flow)
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, color: Colors.grey, size: 16),
                        SizedBox(width: 6),
                        Text('RECENT SEARCHES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Text('Popular', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._recentSearches.map((s) {
                  return InkWell(
                    onTap: () {
                      _fromCtrl.text = s['from']!;
                      _toCtrl.text = s['to']!;
                      _findBuses();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus_outlined, size: 16, color: Color(0xFF00695C)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${s['from']} ➔ ${s['to']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
