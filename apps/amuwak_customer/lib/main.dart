import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/customer_app.dart';
import 'src/bootstrap/customer_bootstrap.dart';

Future<void> main() async {
  await CustomerBootstrap.initialize();
  runApp(const ProviderScope(child: CustomerApp()));
}
