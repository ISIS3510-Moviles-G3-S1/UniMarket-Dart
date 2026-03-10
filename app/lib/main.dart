import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/app_router.dart';
import 'core/reengagement_notification_manager.dart';
import 'view_models/home_view_model.dart';
import 'view_models/browse_view_model.dart';
import 'view_models/sell_view_model.dart';
import 'view_models/profile_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize re-engagement notification system
  final notificationManager = ReEngagementNotificationManager();
  await notificationManager.initialize();
  await notificationManager.requestPermissions();
  
  // Check for inactivity when app starts
  await notificationManager.checkAndNotifyInactivity();
  
  runApp(const UniMarketApp());
}

class UniMarketApp extends StatelessWidget {
  const UniMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => BrowseViewModel()),
        ChangeNotifierProvider(create: (_) => SellViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: MaterialApp.router(
        title: 'UniMarket',
        theme: AppTheme.theme,
        routerConfig: createAppRouter(),
      ),
    );
  }
}
