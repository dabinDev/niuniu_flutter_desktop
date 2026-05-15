import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class NiuNiuKaipanApp extends StatelessWidget {
  const NiuNiuKaipanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '牛牛开盘',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
