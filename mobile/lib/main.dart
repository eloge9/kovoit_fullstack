import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (_) {}
  try {
    await NotificationService.init();
  } catch (_) {}
  runApp(const ProviderScope(child: KoVoitApp()));
}
