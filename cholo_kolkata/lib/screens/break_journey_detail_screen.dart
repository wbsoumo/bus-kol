import 'package:flutter/material.dart';
import '../services/external_app_launcher.dart';
import '../services/multi_transit_service.dart';
import '../services/settings_service.dart';
import 'live_track_sheet.dart';
import 'metro_result_screen.dart';
import 'transit_detail_screen.dart';

class BreakJourneyDetailScreen extends StatefulWidget {
  final String fromQuery;
  final String toQuery;
  final BreakJourneyOption option;
  final String categoryLabel;

  const BreakJourneyDetailScreen({
    super.key,
    required this.fromQuery,
    required this.toQuery,
    required this.option,
    this.categoryLabel = 'FASTEST BREAK JOURNEY',
  });

  @override
  State<BreakJourneyDetailScreen> createState() => _BreakJourneyDetailScreenState();
}

class _BreakJourneyDetailScreenState extends State<BreakJourneyDetailScreen> {
  final Set<int> _expandedLegs = <int>{}; // Intermediate stops COLLAPSED by default

  Color _modeColor(TransitMode mode) {
    switch (mode) {
      case TransitMode.train:
        return const Color(0xFF3949AB);
      case TransitMode.bus:
        return SettingsService().currentTheme.primary;
      case TransitMode.auto:
        return const Color(0xFF00796B);
      case TransitMode.ferry:
        return const Color(0xFF0277BD);
      case TransitMode.metro:
        return const Color(0xFF1565C0);
    }
  }

  IconData _modeIcon(TransitMode mode) {
    switch (mode) {
      case TransitMode.train:
        return Icons.train;
      case TransitMode.bus:
        return Icons.directions_bus;
      case TransitMode.auto:
        return Icons.electric_rickshaw;
      case TransitMode.ferry:
        return Icons.directions_boat;
      case TransitMode.metro:
        return Icons.subway;
    }
  }

  void _openFullLegRoute(BreakJourneyLeg leg) {
    if (leg.mode == TransitMode.bus && leg.busRouteId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveTrackScreen(
            routeId: leg.busRouteId!,
            routeNo: leg.badge,
            busType: leg.busType ?? 'City Bus',
            initialFrom: leg.fromStop,
            initialTo: leg.toStop,
          ),
        ),
      );
    } else if (leg.mode == TransitMode.metro && leg.metroPlan != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MetroResultScreen(plan: leg.metroPlan!)),
      );
    } else if (leg.detailRoute != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransitDetailScreen(
            route: leg.detailRoute!,
            initialFrom: leg.fromStop,
            initialTo: leg.toStop,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().currentTheme;
    final opt = widget.option;
    final changes = opt.legs.length > 1 ? opt.legs.length - 1 : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: theme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Break Journey Breakdown',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              '${widget.fromQuery} ➔ ${widget.toQuery}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          // Top Summary Banner
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.categoryLabel,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Text(
                          'Total ₹${opt.totalFareInr}',
                          style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mode icons with directional arrows chain
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < opt.legs.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _modeColor(opt.legs[i].mode).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _modeColor(opt.legs[i].mode).withAlpha(80)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_modeIcon(opt.legs[i].mode), size: 16, color: _modeColor(opt.legs[i].mode)),
                                const SizedBox(width: 5),
                                Text(
                                  '${transitModeLabel(opt.legs[i].mode)} (${opt.legs[i].badge})',
                                  style: TextStyle(
                                    color: _modeColor(opt.legs[i].mode),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol(Icons.timer, '${opt.totalEtaMins} mins', 'TOTAL ETA', theme.primary),
                      _divider(),
                      _statCol(Icons.swap_horiz, changes == 0 ? 'Direct' : '$changes Change${changes > 1 ? 's' : ''}', 'TRANSFERS', theme.primary),
                      _divider(),
                      _statCol(Icons.straighten, '${opt.totalDistanceKm} km', 'DISTANCE', theme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Step-by-step Full Breakdown
          for (int i = 0; i < opt.legs.length; i++) ...[
            if (i > 0) _buildTransferConnector(opt.legs[i - 1], opt.legs[i]),
            _buildLegBreakdownCard(i, opt.legs[i]),
          ],
        ],
      ),

      // Floating Google Maps original PNG button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await ExternalAppLauncher.openGoogleMapsBreakJourney(opt);
          if (res == 'failed' && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open Google Maps.')),
            );
          }
        },
        backgroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        icon: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset('assets/icons/google_maps.png', width: 28, height: 28, fit: BoxFit.cover),
        ),
        label: const Text(
          'Open Route in Maps',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: const Color(0xFFE2E8F0));

  Widget _statCol(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(height: 3),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A))),
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildTransferConnector(BreakJourneyLeg prev, BreakJourneyLeg next) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCA28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Color(0xFFEF6C00), shape: BoxShape.circle),
            child: const Icon(Icons.directions_walk, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHANGE AT ${prev.toStop.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFE65100)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(_modeIcon(prev.mode), size: 13, color: _modeColor(prev.mode)),
                    const SizedBox(width: 3),
                    Text(transitModeLabel(prev.mode), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _modeColor(prev.mode))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFE65100)),
                    ),
                    Icon(_modeIcon(next.mode), size: 13, color: _modeColor(next.mode)),
                    const SizedBox(width: 3),
                    Text(transitModeLabel(next.mode), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _modeColor(next.mode))),
                    const SizedBox(width: 6),
                    Text('to ${next.fromStop}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegBreakdownCard(int legIndex, BreakJourneyLeg leg) {
    final color = _modeColor(leg.mode);
    final isExpanded = _expandedLegs.contains(legIndex);
    final allStops = leg.stops.isNotEmpty ? leg.stops : [leg.fromStop, leg.toStop];
    final intermediate = allStops.length > 2 ? allStops.sublist(1, allStops.length - 1) : <String>[];

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leg Top Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_modeIcon(leg.mode), size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'LEG ${legIndex + 1} • ${transitModeLabel(leg.mode)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    leg.badge,
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                const Spacer(),
                Text('${leg.etaMins} mins', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('₹${leg.fareInr}', style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${leg.timingText} • ${leg.distanceKm} km',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const Divider(height: 18),

            // Boarding Point
            _stationNodeRow(leg.fromStop, color, isBoard: true),

            // Collapsible Intermediate Stations (Default Collapsed)
            if (intermediate.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedLegs.remove(legIndex);
                    } else {
                      _expandedLegs.add(legIndex);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                  child: Row(
                    children: [
                      Container(width: 3, height: 26, color: color.withAlpha(110)),
                      const SizedBox(width: 14),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: color),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded
                            ? 'Hide ${intermediate.length} intermediate stations/stops'
                            : '${intermediate.length} intermediate stations/stops (Tap to view)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                ...intermediate.map((name) => _stationNodeRow(name, color, isIntermediate: true)),
            ] else
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Container(width: 3, height: 18, color: color.withAlpha(110)),
              ),

            // Alighting Point
            _stationNodeRow(leg.toStop, color, isAlight: true),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openFullLegRoute(leg),
                icon: Icon(Icons.map_outlined, size: 16, color: color),
                label: Text(
                  'Open Full ${transitModeLabel(leg.mode)} Map & Schedule',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stationNodeRow(
    String name,
    Color color, {
    bool isBoard = false,
    bool isAlight = false,
    bool isIntermediate = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: isIntermediate ? 10 : 14,
            height: isIntermediate ? 10 : 14,
            margin: EdgeInsets.symmetric(horizontal: isIntermediate ? 2 : 0),
            decoration: BoxDecoration(
              color: isBoard
                  ? const Color(0xFF2E7D32)
                  : isAlight
                      ? const Color(0xFFC62828)
                      : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isBoard
                    ? const Color(0xFF2E7D32)
                    : isAlight
                        ? const Color(0xFFC62828)
                        : color,
                width: 2.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: (isBoard || isAlight) ? FontWeight.w900 : FontWeight.w600,
                fontSize: (isBoard || isAlight) ? 13.5 : 12,
                color: (isBoard || isAlight) ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ),
          if (isBoard) _tag('BOARD', const Color(0xFF2E7D32)),
          if (isAlight) _tag('GET DOWN', const Color(0xFFC62828)),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9.5)),
    );
  }
}
