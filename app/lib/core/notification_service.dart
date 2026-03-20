abstract class NotificationService {
  factory NotificationService() => const DummyNotificationService();

  Future<void> initialize();
  Future<void> showInactivityNotification();
  Future<bool> requestNotificationPermissions();
  Future<bool> hasNotificationPermission();
}

class DummyNotificationService implements NotificationService {
  const DummyNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showInactivityNotification() async {}

  @override
  Future<bool> requestNotificationPermissions() async => false;

  @override
  Future<bool> hasNotificationPermission() async => false;
}