import 'package:flutter/material.dart';
import '../helpers/color_helper.dart';
import '../services/activity_service.dart';
import '../styles/app_text_styles.dart';
import '../types/activity_event.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  late Future<List<ActivityEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _eventsFuture = ActivityService.instance.getRecentEvents();
  }

  Future<void> _refresh() async {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            onPressed: () async {
              await ActivityService.instance.clearAll();
              _refresh();
            },
            icon: Icon(Icons.delete_forever_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ActivityEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load events',
                style: TextStyle(color: Colors.red[400]),
              ),
            );
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final showDateHeader =
                  index == 0 ||
                  !_isSameDay(events[index - 1].timestamp, event.timestamp);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) _DateHeader(date: event.timestamp),
                  _EventCard(event: event),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final theme = Theme.of(context);

    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, yesterday)) {
      label = 'Yesterday';
    } else {
      label = _formatDate(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          // Expanded(
          //   child: Divider(
          //     color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          //     thickness: 1,
          //   ),
          // ),
          // const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final config = _eventConfig(event.type);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: config.accentColor.withAlpha(100),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                config.icon,
                color: ColorHelper.mixedPrimary(
                  context,
                  config.accentColor,
                  0.5,
                ),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.type.label,
                    style: theme.textTheme.cardTitle(context),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.6),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.vehicleName,
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.bluetooth_rounded,
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.4),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.macAddress,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer
                                .withValues(alpha: 0.4),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time
            Text(
              _formatTime(event.timestamp),
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer.withValues(
                  alpha: 0.6,
                ),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  _EventConfig _eventConfig(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.connectedToVehicle:
        return _EventConfig(
          Icons.bluetooth_connected_rounded,
          const Color(0xFF3B82F6),
        );
      case ActivityEventType.disconnectedFromVehicle:
        return _EventConfig(
          Icons.bluetooth_disabled_rounded,
          const Color(0xFF6B7280),
        );
      case ActivityEventType.userLockedVehicle:
        return _EventConfig(Icons.lock_rounded, const Color(0xFF10B981));
      case ActivityEventType.userUnlockedVehicle:
        return _EventConfig(Icons.lock_open_rounded, const Color(0xFFF59E0B));
      case ActivityEventType.userOpenedTrunk:
        return _EventConfig(Icons.sensor_door_rounded, const Color(0xFF8B5CF6));
      case ActivityEventType.userStartedEngine:
        return _EventConfig(
          Icons.power_settings_new_rounded,
          const Color(0xFF22C55E),
        );
      case ActivityEventType.userStoppedEngine:
        return _EventConfig(Icons.power_off_rounded, const Color(0xFFEF4444));
      case ActivityEventType.proximityLocked:
        return _EventConfig(Icons.sensors_rounded, const Color(0xFF06B6D4));
      case ActivityEventType.proximityUnlocked:
        return _EventConfig(Icons.sensors_rounded, const Color(0xFFF97316));
      case ActivityEventType.authenticationFailed:
        return _EventConfig(Icons.gpp_bad_rounded, const Color(0xFFEF4444));
    }
  }
}

class _EventConfig {
  const _EventConfig(this.icon, this.accentColor);
  final IconData icon;
  final Color accentColor;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSecondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.history_rounded,
              color: theme.colorScheme.onSecondaryContainer,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Events from the past 30 days\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
