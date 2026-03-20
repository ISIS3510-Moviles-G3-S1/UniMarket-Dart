import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'core/app_router.dart';
import 'core/auth_service.dart';
import 'core/notification_service.dart';
import 'core/theme/theme_context.dart';
import 'view_models/browse_view_model.dart';
import 'view_models/home_view_model.dart';
import 'view_models/profile_view_model.dart';
import 'view_models/sell_view_model.dart';
import 'view_models/session_view_model.dart';

class RealNotificationService implements NotificationService {
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  Future<void> initialize() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request permissions after initialization
    await requestNotificationPermissions();
  }

  @override
  Future<bool> requestNotificationPermissions() async {
    try {
      // Check and log current permission status
      final androidPermission = await Permission.notification.status;
      print('DEBUG: Android notification permission status: $androidPermission');

      // Request Android notification permission (API 33+)
      final androidStatus = await Permission.notification.request();
      print('DEBUG: Android notification permission result: $androidStatus');

      // Request iOS notification permission
      final iosResult = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      print('DEBUG: iOS notification permission result: $iosResult');

      return androidStatus.isGranted || (iosResult ?? false);
    } catch (e) {
      print('ERROR: Failed to request notification permissions: $e');
      return false;
    }
  }

  @override
  Future<bool> hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      print('DEBUG: Current notification permission status: $status');
      return status.isGranted;
    } catch (e) {
      print('ERROR: Failed to check notification permission: $e');
      return false;
    }
  }

  @override
  Future<void> showInactivityNotification() async {
    try {
      final hasPermission = await hasNotificationPermission();
      if (!hasPermission) {
        print('WARN: Notification permission not granted, requesting...');
        final granted = await requestNotificationPermissions();
        if (!granted) {
          print('WARN: User denied notification permission, skipping notification');
          return;
        }
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'inactivity_channel',
        'Inactivity Notifications',
        channelDescription: 'Notifications for user inactivity',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        0,
        'Welcome back!',
        'It\'s been a while since your last visit. Check out new listings!',
        platformChannelSpecifics,
      );

      print('DEBUG: Inactivity notification shown');
    } catch (e) {
      print('ERROR: Failed to show inactivity notification: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications (won't fail even if permissions are denied)
  final notificationService = RealNotificationService();
  try {
    await notificationService.initialize();
    print('DEBUG: Notification service initialized successfully');
  } catch (e) {
    print('WARN: Failed to initialize notification service: $e');
    // Continue anyway, use dummy service
  }

  runApp(UniMarketApp(notificationService: notificationService));
}

class UniMarketApp extends StatelessWidget {
  const UniMarketApp({super.key, this.notificationService});

  final NotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeContext()),

        Provider(create: (_) => AuthService()),

        if (notificationService != null)
          Provider<NotificationService>.value(value: notificationService!),

        ChangeNotifierProvider(
          create: (context) => SessionViewModel(
            authService: context.read<AuthService>(),
            notificationService: notificationService,
          ),
        ),

        ChangeNotifierProxyProvider<SessionViewModel, ProfileViewModel>(
          create: (context) =>
              ProfileViewModel(context.read<SessionViewModel>()),
          update: (_, session, previous) =>
              previous ?? ProfileViewModel(session),
        ),

        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => BrowseViewModel()),
        ChangeNotifierProvider(create: (_) => SellViewModel()),

        ProxyProvider<SessionViewModel, GoRouter>(
          update: (_, session, __) => createAppRouter(session),
        ),
      ],
      child: Consumer2<ThemeContext, GoRouter>(
        builder: (context, themeCtx, router, _) => MaterialApp.router(
          title: 'UniMarket',
          theme: themeCtx.currentTheme,
          routerConfig: router,
        ),
      ),
    );
  }
}