import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/bus_data_service.dart';
import '../services/search_analytics_service.dart';
import '../services/settings_service.dart';
import 'live_track_sheet.dart';

class AnonymousChatSheet extends StatefulWidget {
  const AnonymousChatSheet({super.key});

  @override
  State<AnonymousChatSheet> createState() => _AnonymousChatSheetState();
}

class _AnonymousChatSheetState extends State<AnonymousChatSheet> {
  final ApiService _api = ApiService();
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _msgCtrl = TextEditingController();

  String _currentChannel = 'general';
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isPosting = false;
  Timer? _pollTimer;

  // Persistent anonymous commuter ID (e.g. Passenger_74921)
  String _myPassengerId = 'Passenger_10000';

  // Mention autocomplete state
  List<String> _mentionSuggestions = [];
  String? _activeMentionPrefix;

  final List<Map<String, String>> _channels = [
    {'id': 'general', 'name': '# ALL KOLKATA'},
    {'id': 'howrah', 'name': '# HOWRAH'},
    {'id': 'sealdah', 'name': '# SEALDAH & BYPASS'},
    {'id': 'metro', 'name': '# METRO ALERTS'},
    {'id': 'airport', 'name': '# AIRPORT / NORTH'},
  ];

  @override
  void initState() {
    super.initState();
    _initUserId();
    _msgCtrl.addListener(_onTextChanged);
    _loadMessages(isInitial: true);

    // Silent background polling every 5s for live group chat updates (0ms reload)
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) {
        _silentRefresh();
      }
    });
  }

  Future<void> _initUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('commuter_passenger_fixed_id');
      if (id == null || !id.startsWith('Passenger_')) {
        final rand = 10000 + (DateTime.now().millisecondsSinceEpoch % 90000);
        id = 'Passenger_$rand';
        await prefs.setString('commuter_passenger_fixed_id', id);
      }
      if (mounted) {
        setState(() => _myPassengerId = id!);
      }
    } catch (_) {
      final rand = 10000 + (DateTime.now().millisecondsSinceEpoch % 90000);
      _myPassengerId = 'Passenger_$rand';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Listen for @ in textfield to suggest matching Kolkata bus routes
  void _onTextChanged() {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    if (selection.baseOffset <= 0) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = []);
      return;
    }

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      final potentialMention = textBeforeCursor.substring(lastAt + 1);
      if (!potentialMention.contains(' ')) {
        _activeMentionPrefix = potentialMention.toUpperCase();
        List<String> matches = [];

        if (_activeMentionPrefix!.isEmpty) {
          // Popular bus routes if user just typed '@'
          matches = ['215A', 'S-12', 'AC-12', '44A', '12C/2', 'AC-9', 'RT-5', '37A'];
        } else {
          final results = BusDataService().searchBusNumbers(_activeMentionPrefix!);
          matches = results.map((r) => r.routeNo).toSet().take(8).toList();
        }

        if (mounted) {
          setState(() => _mentionSuggestions = matches);
        }
        return;
      }
    }

    if (_mentionSuggestions.isNotEmpty) {
      setState(() {
        _mentionSuggestions = [];
        _activeMentionPrefix = null;
      });
    }
  }

  void _insertMention(String bus) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final textBefore = text.substring(0, selection.baseOffset);
    final lastAt = textBefore.lastIndexOf('@');
    if (lastAt != -1) {
      final prefix = text.substring(0, lastAt);
      final suffix = text.substring(selection.baseOffset);
      final newText = '$prefix@$bus $suffix';
      _msgCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lastAt + bus.length + 2),
      );
    }
    setState(() {
      _mentionSuggestions = [];
      _activeMentionPrefix = null;
    });
  }

  /// Always scroll to the very last message
  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (instant) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        } else {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  /// Initial load or channel switch
  void _loadMessages({bool isInitial = false}) async {
    if (isInitial) {
      setState(() => _isLoading = true);
    }
    try {
      final msgs = await _api.getChatMessages(_currentChannel);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        // Jump directly to the last message on open
        _scrollToBottom(instant: true);
        // Double check scroll after full render pass
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom(instant: true));
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Silent background sync - NEVER shows spinner or causes screen reload
  void _silentRefresh() async {
    try {
      final msgs = await _api.getChatMessages(_currentChannel);
      if (mounted && msgs.isNotEmpty) {
        final currentLastId = _messages.isNotEmpty ? _messages.last.id : -1;
        final newLastId = msgs.last.id;
        if (msgs.length != _messages.length || currentLastId != newLastId) {
          setState(() {
            _messages = msgs;
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  /// Send message with instant 0ms optimistic UI
  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    setState(() {
      _mentionSuggestions = [];
      _activeMentionPrefix = null;
    });

    final now = DateTime.now();
    final localTime =
        "${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
    final optimisticId = now.millisecondsSinceEpoch;

    // Optimistic WhatsApp Bubble
    final optimisticMsg = ChatMessage(
      id: optimisticId,
      channel: _currentChannel,
      userName: _myPassengerId,
      routeRef: '',
      statusTag: 'Normal',
      message: text,
      timeStr: localTime,
    );

    setState(() {
      _messages.add(optimisticMsg);
      _isPosting = true;
    });
    _scrollToBottom();

    // Send silently to server in background (attach location if already permitted)
    final loc = await SearchAnalyticsService().getSilentLocation();
    final success = await _api.postChatMessage(
      channel: _currentChannel,
      userName: _myPassengerId,
      routeRef: '',
      statusTag: 'Normal',
      message: text,
      lat: loc?.lat,
      lng: loc?.lng,
      locationName: loc?.locationName,
    );

    if (mounted) {
      setState(() => _isPosting = false);
      if (success) {
        _silentRefresh();
      }
    }
  }

  /// Open bus route details and live track screen when clicking @<bus number>
  void _openBusRoute(String rawMention) {
    final busNum = rawMention.replaceAll('@', '').trim();
    final routes = BusDataService().searchBusNumbers(busNum);
    if (routes.isNotEmpty) {
      final route = routes.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveTrackScreen(
            routeId: route.id,
            routeNo: route.routeNo,
            busType: route.busType,
            initialFrom: route.origin,
            initialTo: route.destination,
          ),
        ),
      );
    } else {
      // Fallback lookup in stops
      final details = BusDataService().getRouteDetails(busNum);
      if (details != null && details['route'] != null) {
        final r = details['route'] as Map<String, dynamic>;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveTrackScreen(
              routeId: r['id'] as int? ?? busNum.hashCode.abs(),
              routeNo: busNum,
              busType: (r['bus_type'] as String?) ?? 'City Bus',
              initialFrom: r['origin'] ?? '',
              initialTo: r['destination'] ?? '',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bus route @$busNum not found in directory'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// WhatsApp distinct sender colors
  Color _getSenderColor(String name) {
    const colors = [
      Color(0xFF1E88E5), // Blue
      Color(0xFF43A047), // Green
      Color(0xFFE53935), // Red
      Color(0xFF8E24AA), // Purple
      Color(0xFFD81B60), // Pink
      Color(0xFF00ACC1), // Cyan
      Color(0xFFFB8C00), // Orange
      Color(0xFF3949AB), // Indigo
      Color(0xFF00897B), // Teal
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  /// Format sender name as Passenger_XXXXX (cannot be changed by user)
  String _formatSenderName(ChatMessage m, bool isMe) {
    if (isMe) return 'You';
    final name = m.userName.trim();
    if (name.startsWith('Passenger_') && name.length >= 14) {
      return name;
    }
    final seed = (m.id > 0) ? (m.id * 173 % 89999 + 10000) : (name.hashCode.abs() % 89999 + 10000);
    return 'Passenger_$seed';
  }

  /// Build WhatsApp message content with clickable @bus mentions
  Widget _buildMessageContent(String text, bool isMe, AppThemeOption currentTheme) {
    final regex = RegExp(r'(@[a-zA-Z0-9\/\-]+)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.3),
      );
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.3),
        ));
      }

      final mention = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () => _openBusRoute(mention),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: currentTheme.primary.withAlpha(28),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: currentTheme.primary.withAlpha(90), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus, size: 12, color: currentTheme.primary),
                  const SizedBox(width: 2.5),
                  Text(
                    mention,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: currentTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.3),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  /// Authentic WhatsApp group speech bubble
  Widget _buildWhatsAppBubble(ChatMessage m, bool isMe, AppThemeOption currentTheme) {
    final senderName = _formatSenderName(m, isMe);
    final senderColor = _getSenderColor(senderName);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 55 : 6,
          right: isMe ? 6 : 55,
          top: 3,
          bottom: 3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12 : 2),
            topRight: Radius.circular(isMe ? 2 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 1.5,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender name (WhatsApp group format)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: senderColor,
                  ),
                ),
              ),

            // Message Body with Clickable @Bus mentions
            _buildMessageContent(m.message, isMe, currentTheme),

            const SizedBox(height: 2),

            // Timestamp & Delivery status
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  m.timeStr,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.done_all,
                    size: 13,
                    color: Color(0xFF34B7F1), // WhatsApp blue double tick
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = SettingsService().currentTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Adjust container height to stay perfectly above keyboard when opened
    final totalHeight = MediaQuery.of(context).size.height * 0.88;
    final sheetHeight = bottomInset > 0 ? (totalHeight - bottomInset * 0.35).clamp(320.0, totalHeight) : totalHeight;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFEFEAE2), // WhatsApp wallpaper canvas
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // WhatsApp Group Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  color: currentTheme.primary,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.groups, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kolkata Transit Community',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              'You: $_myPassengerId • Type @bus to tag',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Channel pills strip (# ALL KOLKATA, # HOWRAH, etc.)
                Container(
                  color: Colors.white,
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _channels.map((ch) {
                      final active = _currentChannel == ch['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                        child: InkWell(
                          onTap: () {
                            if (_currentChannel != ch['id']) {
                              setState(() => _currentChannel = ch['id']!);
                              _loadMessages(isInitial: true);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? currentTheme.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              ch['name']!,
                              style: TextStyle(
                                color: active ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // Messages Feed (WhatsApp Bubbles)
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: currentTheme.primary))
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 44, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No alerts in #${_currentChannel.toUpperCase()}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Type @bus to mention a route and share live status.',
                                    style: TextStyle(color: Colors.grey, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, idx) {
                                final m = _messages[idx];
                                final isMe = m.userName == _myPassengerId || m.userName == 'You';
                                return _buildWhatsAppBubble(m, isMe, currentTheme);
                              },
                            ),
                ),

                // Live @bus mention suggestion strip (above keyboard and composer)
                if (_mentionSuggestions.isNotEmpty)
                  Container(
                    height: 42,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6, left: 2),
                          child: Icon(Icons.directions_bus, size: 15, color: currentTheme.primary),
                        ),
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _mentionSuggestions.length,
                            itemBuilder: (ctx, i) {
                              final bus = _mentionSuggestions[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(
                                    '@$bus',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: currentTheme.primary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  backgroundColor: currentTheme.lightBg,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  onPressed: () => _insertMention(bus),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // WhatsApp Composer Box (Never hidden by keyboard)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F2F5),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
                            ],
                          ),
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              border: InputBorder.none,
                              hintText: 'Message (type @bus to tag)...',
                              hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _sendMessage,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: currentTheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                            ],
                          ),
                          child: _isPosting
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 19),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
