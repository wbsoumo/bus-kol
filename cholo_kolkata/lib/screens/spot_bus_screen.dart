import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/kolkata_stops.dart';
import '../services/settings_service.dart';
import '../models/models.dart';
import 'results_screen.dart';

class SpotBusScreen extends StatefulWidget {
  const SpotBusScreen({super.key});

  @override
  State<SpotBusScreen> createState() => _SpotBusScreenState();
}

class _SpotBusScreenState extends State<SpotBusScreen> {
  final ApiService _api = ApiService();
  final SettingsService _settings = SettingsService();

  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _busNoCtrl;

  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();

  List<BusStopItem> _fromSuggestions = [];
  List<BusStopItem> _toSuggestions = [];
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

  @override
  void initState() {
    super.initState();
    // Restore persistent last search from SettingsService
    _fromCtrl = TextEditingController(text: _settings.lastFromStop);
    _toCtrl = TextEditingController(text: _settings.lastToStop);
    _busNoCtrl = TextEditingController(text: _settings.lastBusNo);
  }

  @override
  void dispose() {
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _busNoCtrl.dispose();
    super.dispose();
  }

  void _onFromChanged(String val) async {
    final clean = val.trim();
    // 1. Instant 0ms local match (WIMT real-time search)
    final localMatches = KolkataStops.searchLocal(clean, limit: 12);
    setState(() {
      _fromSuggestions = localMatches;
      _showFromSuggestions = true;
      _showToSuggestions = false;
      _showBusSuggestions = false;
    });

    if (clean.isEmpty) return;

    // 2. Asynchronous background enrichment from 2,500+ stop server database
    try {
      final serverMatches = await _api.searchStops(clean);
      if (mounted && _fromCtrl.text.trim() == clean) {
        setState(() {
          _fromSuggestions = serverMatches;
        });
      }
    } catch (_) {}
  }

  void _onToChanged(String val) async {
    final clean = val.trim();
    // 1. Instant 0ms local match (WIMT real-time search)
    final localMatches = KolkataStops.searchLocal(clean, limit: 12);
    setState(() {
      _toSuggestions = localMatches;
      _showToSuggestions = true;
      _showFromSuggestions = false;
      _showBusSuggestions = false;
    });

    if (clean.isEmpty) return;

    // 2. Asynchronous background enrichment from 2,500+ stop server database
    try {
      final serverMatches = await _api.searchStops(clean);
      if (mounted && _toCtrl.text.trim() == clean) {
        setState(() {
          _toSuggestions = serverMatches;
        });
      }
    } catch (_) {}
  }

  void _selectFromStop(BusStopItem item) {
    setState(() {
      _fromCtrl.text = item.name;
      _showFromSuggestions = false;
    });
    // Auto-advance cursor & focus to TO stop, showing its suggestions like WIMT
    _toFocusNode.requestFocus();
    _onToChanged(_toCtrl.text);
  }

  void _selectToStop(BusStopItem item) {
    setState(() {
      _toCtrl.text = item.name;
      _showToSuggestions = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _swapStops() {
    setState(() {
      final temp = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = temp;
      _showFromSuggestions = false;
      _showToSuggestions = false;
    });
  }

  void _findBuses() {
    setState(() {
      _showFromSuggestions = false;
      _showToSuggestions = false;
      _showBusSuggestions = false;
    });
    FocusScope.of(context).unfocus();

    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();

    if (from.isEmpty || to.isEmpty) {
      setState(() => _alert = 'Please enter both departure and destination stops.');
      return;
    }

    // Save persistent last search
    _settings.saveLastSearch(from, to);

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

    // Save persistent last bus number
    _settings.saveLastBusNo(busNo);

    setState(() {
      _showBusSuggestions = false;
      _showFromSuggestions = false;
      _showToSuggestions = false;
    });
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ResultsScreen(fromStop: busNo, toStop: ''),
      ),
    );
  }

  Widget _buildSuggestionsList({
    required List<BusStopItem> items,
    required bool isFrom,
    required ValueChanged<BusStopItem> onSelected,
    required VoidCallback onClose,
    required AppThemeOption theme,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final pinColor = isFrom ? theme.primary : const Color(0xFFD32F2F);
    final pinBgColor = isFrom ? theme.lightBg : const Color(0xFFFFEBEE);
    final queryText = (isFrom ? _fromCtrl.text : _toCtrl.text).trim();
    final headerTitle = queryText.isEmpty
        ? 'POPULAR BUS TERMINI & STOPS'
        : 'MATCHING STOPS (${items.length})';

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Suggestion Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: const Color(0xFFF1F5F9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        queryText.isEmpty ? Icons.star_rounded : Icons.search_rounded,
                        size: 14,
                        color: pinColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        headerTitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueGrey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onClose,
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (ctx, i) => Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
                itemBuilder: (ctx, i) {
                  final stop = items[i];
                  return InkWell(
                    onTap: () => onSelected(stop),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Station Pin Badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: pinBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: pinColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Station Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        stop.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (stop.bengaliName.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${stop.bengaliName})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (stop.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    stop.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Route Density Badge
                          if (stop.routesCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFC8E6C9), width: 0.8),
                              ),
                              child: Text(
                                '${stop.routesCount}+ routes',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final currentTheme = _settings.currentTheme;

        return GestureDetector(
          onTap: () {
            setState(() {
              _showFromSuggestions = false;
              _showToSuggestions = false;
              _showBusSuggestions = false;
            });
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: ListView(
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
                      const Text(
                        'FROM BUS STOP',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF546E7A),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
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
                            Icon(Icons.circle, color: currentTheme.primary, size: 12),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _fromCtrl,
                                focusNode: _fromFocusNode,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  hintText: 'Type departure stop (e.g. Howrah Station)',
                                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                onTap: () {
                                  _onFromChanged(_fromCtrl.text);
                                },
                                onChanged: _onFromChanged,
                              ),
                            ),
                            if (_fromCtrl.text.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _fromCtrl.clear();
                                  _fromFocusNode.requestFocus();
                                  _onFromChanged('');
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.clear, size: 16, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // From Autocomplete Suggestions (Where Is My Train station list style)
                      if (_showFromSuggestions)
                        _buildSuggestionsList(
                          items: _fromSuggestions,
                          isFrom: true,
                          onSelected: _selectFromStop,
                          onClose: () => setState(() => _showFromSuggestions = false),
                          theme: currentTheme,
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.swap_vert, size: 20, color: currentTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),

                      // To Stop Input Box
                      const Text(
                        'TO BUS STOP',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF546E7A),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
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
                                focusNode: _toFocusNode,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  hintText: 'Type destination stop (e.g. Sector V)',
                                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                onTap: () {
                                  _onToChanged(_toCtrl.text);
                                },
                                onChanged: _onToChanged,
                              ),
                            ),
                            if (_toCtrl.text.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _toCtrl.clear();
                                  _toFocusNode.requestFocus();
                                  _onToChanged('');
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.clear, size: 16, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // To Autocomplete Suggestions (Where Is My Train station list style)
                      if (_showToSuggestions)
                        _buildSuggestionsList(
                          items: _toSuggestions,
                          isFrom: false,
                          onSelected: _selectToStop,
                          onClose: () => setState(() => _showToSuggestions = false),
                          theme: currentTheme,
                        ),

                      if (_alert.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _alert,
                            style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Solid Theme Color FIND BUSES button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          onPressed: _findBuses,
                          child: const Text(
                            'FIND BUSES',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
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
                      Row(
                        children: [
                          Icon(Icons.tag, color: currentTheme.primary, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'BUS NO. / ROUTE LOOKUP',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: Color(0xFF546E7A),
                              letterSpacing: 0.5,
                            ),
                          ),
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
                              backgroundColor: currentTheme.primary,
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
                            border: Border.all(color: currentTheme.primary.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                                          color: currentTheme.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          r.routeNo,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${r.origin} ➔ ${r.destination}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        r.fareText,
                                        style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
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
                          const Text(
                            'SUGGESTIONS:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF78909C),
                              letterSpacing: 0.5,
                            ),
                          ),
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
                                      backgroundColor: currentTheme.lightBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(color: currentTheme.primary.withValues(alpha: 0.3)),
                                      ),
                                      label: Text(
                                        no,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: currentTheme.badgeText),
                                      ),
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
                                Icon(Icons.directions_bus_outlined, size: 16, color: currentTheme.primary),
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
          ),
        );
      },
    );
  }
}
