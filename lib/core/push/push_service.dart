import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../api/request_headers.dart';
import '../config/api_config.dart';
import '../i18n/i18n.dart';
import '../session/session_store.dart';

/// Ilova yopiq/fonda bo'lganda kelgan xabar — bildirishnomani tizim o'zi
/// ko'rsatadi, bu yerda qiladigan ish yo'q. Handler top-level bo'lishi shart.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

/// Push xabarnomalar (Firebase Cloud Messaging).
///
/// - Qurilma tokeni sessiya bor paytda serverga yuboriladi (`POST /api/push/token`)
///   va chiqishda o'chiriladi — boshqa akkaunt shu telefonda kirsa, oldingi
///   egasining xabarlari kelmaydi.
/// - Ilova ochiq turganda FCM bildirishnomani ko'rsatmaydi, shuning uchun uni
///   `flutter_local_notifications` bilan o'zimiz chiqaramiz.
/// - Bildirishnoma bosilganda `onTap` chaqiriladi (yo'naltirish ilova
///   qatlamida — `screens/push_tap_router.dart`).
///
/// Push ikkilamchi: Firebase ishga tushmasa ham ilova odatdagidek ishlaydi.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Backend `config('push.android_channel_id')` bilan bir xil.
  static const _channel = AndroidNotificationChannel(
    'alix_orders',
    'Buyurtmalar',
    description: 'Buyurtma holati va arizangiz bo‘yicha xabarlar',
    importance: Importance.high,
  );

  /// Bildirishnoma bosilganda (data payload bilan).
  void Function(Map<String, dynamic> data)? onTap;

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _lastSentToken;
  String? _lastSentLocale;

  /// Ilova sahifalari ko'rsatilgunga qadar bosilgan xabar shu yerda kutadi.
  Map<String, dynamic>? _pendingTap;
  bool _appReady = false;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return;

    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _handleTap(_decode(r.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final fm = FirebaseMessaging.instance;
      // iOS: ilova ochiq bo'lsa ham tizim bildirishnomasini ko'rsatsin.
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleTap(m.data));
      fm.onTokenRefresh.listen((t) => _sendToken(t, force: true));

      final initial = await fm.getInitialMessage();
      if (initial != null) _handleTap(initial.data);

      _ready = true;
      I18n.instance.addListener(_onLocaleChanged);
      SessionStore.onSessionSaved = () async {
        // Login'dan keyin ham bosilgan xabarlar navbatda qolib ketmasin.
        markAppReady();
        await syncToken();
      };
      SessionStore.beforeClear = unregister;
    } catch (e) {
      debugPrint('PushService.init: $e');
    }
  }

  /// Sessiya bo'lsa: ruxsat so'raydi va tokenni serverga yuboradi.
  Future<void> syncToken() async {
    if (!_ready) return;
    try {
      final session = await SessionStore().getRefreshToken();
      if (session == null || session.isEmpty) return;

      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) debugPrint('PushService: FCM token $token');
      if (token != null) await _sendToken(token);
    } catch (e) {
      debugPrint('PushService.syncToken: $e');
    }
  }

  /// Chiqishdan oldin: serverdan va qurilmadan tokenni o'chiradi.
  /// Tarmoq bo'lmasa ham chiqish to'xtab qolmasligi uchun vaqt cheklangan.
  Future<void> unregister() async {
    if (!_ready) return;
    try {
      final session = await SessionStore().getRefreshToken();
      final token = _lastSentToken ?? await FirebaseMessaging.instance.getToken();
      if (session != null && session.isNotEmpty && token != null) {
        await http
            .delete(
              Uri.parse('${ApiConfig.baseUrl}/api/push/token'),
              headers: jsonAuthHeaders(session),
              body: jsonEncode({'token': token}),
            )
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('PushService.unregister: $e');
    }
    // Server so'rovi o'tmagan bo'lsa ham eski token endi ishlamaydi.
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 4));
    } catch (_) {}
    _lastSentToken = null;
    _lastSentLocale = null;
  }

  /// AuthGate foydalanuvchini kerakli sahifaga olib borgach chaqiriladi —
  /// ilova yopiq paytda bosilgan xabar shundan keyin ochiladi.
  void markAppReady() {
    _appReady = true;
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onTap?.call(pending));
    }
  }

  // -------------------------------------------------------------------------

  Future<void> _sendToken(String token, {bool force = false}) async {
    final locale = I18n.instance.code;
    if (!force && token == _lastSentToken && locale == _lastSentLocale) return;

    final session = await SessionStore().getRefreshToken();
    if (session == null || session.isEmpty) return;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/push/token'),
        headers: jsonAuthHeaders(session),
        body: jsonEncode({
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _lastSentToken = token;
        _lastSentLocale = locale;
      }
    } catch (e) {
      debugPrint('PushService._sendToken: $e');
    }
  }

  /// Xabar matni tili server tomonda token bilan saqlanadi — til almashsa yangilaymiz.
  void _onLocaleChanged() {
    if (_lastSentToken != null && I18n.instance.code != _lastSentLocale) {
      _sendToken(_lastSentToken!);
    }
  }

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    // iOS'da tizim o'zi ko'rsatadi (setForegroundNotificationPresentationOptions).
    if (!Platform.isAndroid) return;

    await _local.show(
      id: m.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_monochrome',
          styleInformation: BigTextStyleInformation(n.body ?? ''),
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

  void _handleTap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    if (!_appReady) {
      _pendingTap = data;
      return;
    }
    onTap?.call(data);
  }

  Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final v = jsonDecode(payload);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}
