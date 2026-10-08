import 'package:flutter/material.dart';

import '../customer/customer_api.dart';
import '../customer/customer_models.dart';
import '../customer/pages/customer_order_detail_page.dart';
import '../driver/driver_api.dart';
import '../driver/driver_models.dart';
import '../driver/pages/driver_order_detail_page.dart';

/// Push bildirishnomasi bosilganda tegishli sahifani ochadi.
///
/// Backend `data` kontrakti (`OrderStatusPush`, `DriverModerationService`):
///   - `type=order_status`, `order_id`, `role` (customer | driver) — buyurtma sahifasi;
///   - `type=driver_moderation` — ilova ochiladi, yo'naltirishni mavjud
///     moderatsiya poller'i (`notifications/unread`) o'zi qiladi.
///
/// Rol joriy rejimga qarab emas, xabardagi `role` bo'yicha tanlanadi: bitta
/// foydalanuvchi ikkala rolda bo'lishi mumkin va xabar aynan o'sha rolga tegishli.
class PushTapRouter {
  PushTapRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> open(Map<String, dynamic> data) async {
    if (data['type']?.toString() != 'order_status') return;
    final orderId = int.tryParse(data['order_id']?.toString() ?? '');
    if (orderId == null) return;

    try {
      final page = data['role']?.toString() == 'driver'
          ? await _driverPage(orderId)
          : await _customerPage(orderId);
      if (page == null) return;
      await navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => page));
    } catch (e) {
      // Buyurtmani olib bo'lmadi (tarmoq, sessiya) — ilova shunchaki ochiq qoladi.
      debugPrint('PushTapRouter: $e');
    }
  }

  static Future<Widget?> _customerPage(int orderId) async {
    final api = CustomerApi.instance;
    // Buyurtma joriy yoki arxivda — ikkalasini parallel so'raymiz (sekin tarmoqda kutish ikki baravar kam).
    final lists = await Future.wait([api.currentOrders(), api.archiveOrders()]);
    final CustomerOrder? order = lists.expand((l) => l).where((o) => o.id == orderId).firstOrNull;
    return order == null ? null : CustomerOrderDetailPage(order: order);
  }

  static Future<Widget?> _driverPage(int orderId) async {
    final api = DriverApi.instance;
    final results = await Future.wait<Object?>([api.currentOrder(), api.archiveOrders()]);
    final current = results[0] as DriverOrder?;
    final archive = results[1] as List<DriverOrder>;
    final DriverOrder? order = current?.id == orderId ? current : archive.where((o) => o.id == orderId).firstOrNull;
    return order == null ? null : DriverOrderDetailPage(order: order);
  }
}
