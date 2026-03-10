import 'package:flutter/material.dart';
import '../../core/reengagement_notification_manager.dart';
import '../../core/user_activity_service.dart';

/// Widget to display user's activity status (for testing/debugging)
class ActivityStatusWidget extends StatefulWidget {
  const ActivityStatusWidget({super.key});

  @override
  State<ActivityStatusWidget> createState() => _ActivityStatusWidgetState();
}

class _ActivityStatusWidgetState extends State<ActivityStatusWidget> {
  final _notificationManager = ReEngagementNotificationManager();
  final _activityService = UserActivityService();
  Map<String, dynamic>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final status = await _notificationManager.getInactivityStatus();
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _testNotification() async {
    await _notificationManager.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Test notification sent. Check iOS Notification Center (swipe down).',
          ),
        ),
      );
    }
  }

  Future<void> _clearActivity() async {
    await _activityService.clearActivity();
    await _loadStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final days = _status?['daysSinceLastActivity'] ?? 0;
    final isInactive = _status?['isInactive'] ?? false;
    final lastType = _status?['lastActivityType'] ?? 'none';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInactive ? Icons.notifications_active : Icons.check_circle,
                  color: isInactive ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Activity Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Days since last activity', '$days days'),
            _buildStatusRow('Status', isInactive ? 'Inactive' : 'Active'),
            _buildStatusRow('Last activity type', lastType),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testNotification,
                    icon: const Icon(Icons.notifications),
                    label: const Text('Test Notification'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearActivity,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Activity'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Re-engagement notification will trigger if user is inactive for 5+ days',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
