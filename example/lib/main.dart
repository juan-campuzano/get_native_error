import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_native_error/get_native_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NativeError.install();
  } on MissingPluginException {
    // Widget tests and platforms without the native implementation.
  }
  NativeCrashReport? pending;
  try {
    pending = await NativeError.takePendingCrash();
  } on MissingPluginException {
    pending = null;
  }
  runApp(MyApp(pendingCrash: pending));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.pendingCrash});

  final NativeCrashReport? pendingCrash;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> _crashNative() async {
    await NativeError.crashNative();
  }

  @override
  Widget build(BuildContext context) {
    final crash = widget.pendingCrash;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Native crash capture')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Fatal native signals are written to disk and returned here '
                'on the next launch. Report the payload with your own API.',
              ),
              const SizedBox(height: 16),
              if (crash == null)
                const Text('No pending native crash.')
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(crash.toJson().toString()),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _crashNative,
                child: const Text('Crash natively'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
