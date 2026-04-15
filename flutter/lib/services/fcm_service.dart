import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'quiz_service.dart';

/// Push notification plumbing for the 4 compulsory event types:
///  - notif.streak.warning
///  - notif.referral.converted
///  - notif.tournament.remind
///  - notif.match.invite
///
/// Responsibilities:
///  1. Initialize Firebase on app start.
///  2. Request notification permission (iOS + Android 13+).
///  3. Fetch the FCM registration token and push it to the backend.
///  4. Re-register when the token rotates.
///  5. Render foreground messages as local notifications so the user sees them
///     while the app is open (FCM only auto-displays when the app is backgrounded).
///  6. Surface background taps to a route callback.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  /// Called once at app startup before runApp (so Firebase is ready early).
  Future<void> initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[fcm] Firebase init failed: $e');
    }
  }

  /// Called after the user is authenticated — registers the token with the
  /// backend and wires up foreground/background handlers. Safe to call more
  /// than once; subsequent calls are no-ops.
  Future<void> registerForUser() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) {
      debugPrint('[fcm] Firebase not initialized — skipping FCM registration');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // iOS + Android 13+ require explicit permission.
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[fcm] notifications denied by user — skipping token registration');
      return;
    }

    await _setupLocalNotifications();

    // Upload the initial token.
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _pushTokenToBackend(token);
    } else {
      debugPrint('[fcm] FirebaseMessaging returned no token');
    }

    // Tokens can rotate (new install, restore, revoked); keep backend in sync.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen(_pushTokenToBackend);

    // Foreground display: FCM delivers the payload but doesn't draw a banner
    // while the app has focus, so we render it locally.
    _messageSub?.cancel();
    _messageSub = FirebaseMessaging.onMessage.listen(_showForeground);

    // App was opened from a notification tap (background or terminated start).
    _openedAppSub?.cancel();
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(initialMessage);
    }

    _initialized = true;
    debugPrint('[fcm] registered for push notifications');
  }

  /// Clear the local flag (e.g. on logout). We intentionally don't delete the
  /// token — the server's $addToSet + invalid-token cleanup handles stale entries.
  void reset() {
    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _openedAppSub?.cancel();
    _tokenRefreshSub = null;
    _messageSub = null;
    _openedAppSub = null;
    _initialized = false;
  }

  Future<void> _pushTokenToBackend(String token) async {
    try {
      await QuizService().updateFCMToken(token);
      debugPrint('[fcm] token registered with backend (len=${token.length})');
    } catch (e) {
      debugPrint('[fcm] failed to register token with backend: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    // Android: channel id must match the one the Go notification worker writes
    // in AndroidConfig.Notification.ChannelID ("default_channel").
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifs.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final androidImpl = _localNotifs
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          'default_channel',
          'Quiz Battle notifications',
          description: 'Streak, referral, tournament, and match invite alerts',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _showForeground(RemoteMessage msg) async {
    final title = msg.notification?.title ?? msg.data['title'] ?? 'Quiz Battle';
    final body = msg.notification?.body ?? msg.data['body'] ?? '';
    await _localNotifs.show(
      msg.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Quiz Battle notifications',
          channelDescription: 'Streak, referral, tournament, and match invite alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: msg.data['event']?.toString(),
    );
  }

  void _handleTap(RemoteMessage msg) {
    // Hook for future navigation: inspect msg.data['event'] and route.
    // Left as a debug log for now; wiring into GoRouter/Navigator is out of
    // scope for the notification phase and can be added when tap routing is
    // a product requirement.
    debugPrint('[fcm] notification tapped: event=${msg.data['event']}');
  }
}
