import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/kolkata_geo.dart';
import '../services/multi_transit_service.dart';
import '../services/settings_service.dart';

class TransitDetailScreen extends StatefulWidget {
  final TransitRouteItem route;
  final String initialFrom;
  final String initialTo;

  const TransitDetailScreen({
    super.key,
    required this.route,
    this.initialFrom = '',
    this.initialTo = '',
  });

  @override
  State<TransitDetailScreen> createState() => _TransitDetailScreenState();
}

class _TransitDetailScreenState extends State<TransitDetailScreen> {
  late TransitRouteItem _route;
  bool _isMapView = false;
  int _fromIdx = 0;
  int _toIdx = 0;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _computeIndices();
  }

  void _computeIndices() {
    _fromIdx = 0;
    _toIdx = _route.stops.isNotEmpty ? _route.stops.length - 1 : 0;
    if (widget.initialFrom.isNotEmpty) {
      final fLow = widget.initialFrom.toLowerCase();
      final idx = _route.stops.indexWhere((s) => s.name.toLowerCase().contains(fLow));
      if (idx != -1) _fromIdx = idx;
    }
    if (widget.initialTo.isNotEmpty) {
      final tLow = widget.initialTo.toLowerCase();
      final idx = _route.stops.indexWhere((s) => s.name.toLowerCase().contains(tLow));
      if (idx != -1) _toIdx = idx;
    }
    if (_fromIdx > _toIdx && _route.stops.isNotEmpty) {
      _route = _route.reversed();
      final fLow = widget.initialFrom.toLowerCase();
      final tLow = widget.initialTo.toLowerCase();
      _fromIdx = _route.stops.indexWhere((s) => s.name.toLowerCase().contains(fLow));
      _toIdx = _route.stops.indexWhere((s) => s.name.toLowerCase().contains(tLow));
      if (_fromIdx < 0) _fromIdx = 0;
      if (_toIdx < 0 || _toIdx <= _fromIdx) _toIdx = _route.stops.length - 1;
    }
  }

  void _reverseDirection() {
    setState(() {
      _route = _route.reversed();
      _fromIdx = 0;
      _toIdx = _route.stops.isNotEmpty ? _route.stops.length - 1 : 0;
    });
  }

  Color _modeAccent() {
    switch (_route.mode) {
      case TransitMode.auto:
        return const Color(0xFF00796B);
      case TransitMode.ferry:
        return const Color(0xFF0277BD);
      case TransitMode.train:
        return const Color(0xFF3949AB);
      case TransitMode.metro:
        return const Color(0xFF1565C0);
      case TransitMode.bus:
        return SettingsService().currentTheme.primary;
    }
  }

  IconData _modeIcon() {
    switch (_route.mode) {
      case TransitMode.auto:
        return Icons.electric_rickshaw;
      case TransitMode.ferry:
        return Icons.directions_boat;
      case TransitMode.train:
        return Icons.train;
      case TransitMode.metro:
        return Icons.subway;
      case TransitMode.bus:
        return Icons.directions_bus;
    }
  }

  List<LatLng> _resolvePoints() {
    final pts = <LatLng>[];
    LatLng? startHint;
    LatLng? endHint;
    for (final s in _route.stops) {
      final c = s.latLng ?? KolkataGeo.lookupExactCoord(s.name);
      if (c != null) {
        startHint ??= c;
        endHint = c;
      }
    }
    final total = _route.stops.length;
    for (int i = 0; i < total; i++) {
      final s = _route.stops[i];
      final exact = s.latLng ?? KolkataGeo.lookupExactCoord(s.name);
      if (exact != null) {
        pts.add(exact);
      } else {
        pts.add(
          KolkataGeo.resolveCoordinate(
            s.name,
            i,
            total,
            originHint: startHint,
            destHint: endHint,
          ),
        );
      }
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _modeAccent();
    final theme = SettingsService().currentTheme;
    final pts = _resolvePoints();

    final segMins = (_toIdx > _fromIdx && _route.stops.isNotEmpty)
        ? (_route.stops[_toIdx].travelMins - _route.stops[_fromIdx].travelMins).abs().clamp(4, 240)
        : _route.durationMins;

    final boardStop = _route.stops.isNotEmpty ? _route.stops[_fromIdx] : null;
    final trainSchedule = _route.mode == TransitMode.train && boardStop != null
        ? MultiTransitService.upcomingDeparturesAtOffset(
            _route.departures,
            boardStop.travelMins,
            _route.headwayPeakMins,
            DateTime.now(),
            count: 6,
          )
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: theme.primary,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_modeIcon(), size: 17, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '${transitModeLabel(_route.mode)} • ${_route.code}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
            Text(
              '${_route.origin} ➔ ${_route.destination}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isMapView ? 'Stop Timeline' : 'Map View',
            icon: Icon(_isMapView ? Icons.format_list_bulleted : Icons.map_outlined, color: Colors.white),
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            tooltip: 'Reverse Direction',
            icon: const Icon(Icons.swap_vert, color: Colors.white),
            onPressed: _reverseDirection,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Overview Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(24),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_modeIcon(), size: 14, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            transitModeLabel(_route.mode),
                            style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _route.operatorName,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Text(
                        _route.fareText,
                        style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metricChip(Icons.schedule, '${_route.firstService} – ${_route.lastService}'),
                    _metricChip(Icons.timelapse, 'Every ${_route.headwayPeakMins}–${_route.headwayOffPeakMins} mins'),
                    _metricChip(Icons.straighten, '${_route.distanceKm} km'),
                    _metricChip(Icons.timer_outlined, '~$segMins mins ride'),
                  ],
                ),
                if (trainSchedule != null && trainSchedule.nextFormatted.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NEXT TRAINS FROM ${boardStop!.name.toUpperCase()}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF312E81)),
                            ),
                            Text(
                              '${_route.dailyTripsCount} trains/day',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: trainSchedule.nextFormatted.asMap().entries.map((entry) {
                            final isFirst = entry.key == 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFirst ? const Color(0xFF3949AB) : Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFF9FA8DA)),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isFirst ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_route.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _route.notes,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Toggle Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Colors.grey[200]!), bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  '${_route.stops.length} ${_route.mode == TransitMode.ferry ? 'Ghats' : _route.mode == TransitMode.train ? 'Stations' : 'Stops'} • Offline GPS Ready',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _isMapView = !_isMapView),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(_isMapView ? Icons.list : Icons.map, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _isMapView ? 'TIMELINE' : 'VIEW MAP',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body: Interactive Map OR Stop-by-Stop Timeline
          Expanded(
            child: _isMapView ? _buildMapView(pts, accent) : _buildTimelineView(pts, accent),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF334155)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildMapView(List<LatLng> pts, Color accent) {
    if (pts.isEmpty) {
      return const Center(child: Text('No GPS coordinates available for this corridor.'));
    }
    final center = pts[pts.length ~/ 2];
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _route.mode == TransitMode.train ? 11.2 : 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cholokolkata.cholo_kolkata',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: pts,
              color: accent,
              strokeWidth: 4.5,
            ),
          ],
        ),
        MarkerLayer(
          markers: List.generate(_route.stops.length, (i) {
            final st = _route.stops[i];
            final pt = pts[i];
            final isEnd = i == _fromIdx || i == _toIdx;
            final dotColor = i == _fromIdx
                ? const Color(0xFF2E7D32)
                : i == _toIdx
                    ? const Color(0xFFC62828)
                    : accent;
            return Marker(
              point: pt,
              width: isEnd ? 140 : 28,
              height: isEnd ? 56 : 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEnd)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dotColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        st.name,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Container(
                    width: isEnd ? 14 : 10,
                    height: isEnd ? 14 : 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: dotColor, width: 3),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimelineView(List<LatLng> pts, Color accent) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _route.stops.length,
      itemBuilder: (ctx, idx) {
        final st = _route.stops[idx];
        final coord = idx < pts.length ? pts[idx] : st.latLng;
        final inRange = idx >= _fromIdx && idx <= _toIdx;
        final isStart = idx == _fromIdx;
        final isEnd = idx == _toIdx;

        return InkWell(
          onTap: coord == null
              ? null
              : () {
                  setState(() => _isMapView = true);
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) {
                      _mapController.move(coord, 14.5);
                    }
                  });
                },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Running time column
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${st.travelMins}m',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: inRange ? accent : Colors.grey[500],
                    ),
                  ),
                ),
              ),
              // Vertical track line + dot
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 3,
                      height: 10,
                      color: idx == 0 ? Colors.transparent : (inRange ? accent : Colors.grey[300]),
                    ),
                    Container(
                      width: (isStart || isEnd) ? 14 : 10,
                      height: (isStart || isEnd) ? 14 : 10,
                      decoration: BoxDecoration(
                        color: isStart
                            ? const Color(0xFF2E7D32)
                            : isEnd
                                ? const Color(0xFFC62828)
                                : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isStart
                              ? const Color(0xFF2E7D32)
                              : isEnd
                                  ? const Color(0xFFC62828)
                                  : (inRange ? accent : Colors.grey[400]!),
                          width: 2.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 36,
                      color: idx == _route.stops.length - 1 ? Colors.transparent : (inRange ? accent : Colors.grey[300]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Stop Info
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isStart || isEnd) ? accent.withAlpha(15) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isStart || isEnd) ? accent.withAlpha(90) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    st.name,
                                    style: TextStyle(
                                      fontWeight: (isStart || isEnd) ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 13,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (st.irCode.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      st.irCode,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF3730A3)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (st.lat != null && st.lon != null)
                              Text(
                                '${st.lat!.toStringAsFixed(4)}, ${st.lon!.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                      if (st.lat != null && st.lon != null)
                        Icon(Icons.location_on_outlined, size: 16, color: accent),
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
