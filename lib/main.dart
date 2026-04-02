import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/remote/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: BookshelfApp(),
    ),
  );
}
