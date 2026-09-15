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

  // Read every report from previous runs without deleting them, so the UI can
  // show them and let you delete individually.
  List<NativeCrashReport> pending;
  try {
    pending = await NativeError.peekPendingCrashes();
  } on MissingPluginException {
    pending = const <NativeCrashReport>[];
  }

  runApp(MyApp(pendingCrashes: pending));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.pendingCrashes = const <NativeCrashReport>[]});

  final List<NativeCrashReport> pendingCrashes;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _lifecycleListener;
  late List<NativeCrashReport> _crashes;

  @override
  void initState() {
    super.initState();
    _crashes = List<NativeCrashReport>.from(widget.pendingCrashes);
    // Signal a clean shutdown so the next launch does not report an abnormal
    // termination. Not every exit fires a callback, so detection stays
    // heuristic.
    _lifecycleListener = AppLifecycleListener(
      onDetach: () => NativeError.markHealthyExit(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final crashes = await NativeError.peekPendingCrashes();
      setState(() => _crashes = crashes);
    } on MissingPluginException {
      // No native implementation available.
    }
  }

  Future<void> _deleteAt(int index) async {
    try {
      await NativeError.deletePendingCrash(index);
    } on MissingPluginException {
      // Ignore when unavailable; still update the UI.
    }
    await _refresh();
  }

  Future<void> _crash(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      // No native implementation available.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native crash capture'),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Fatal native signals, uncaught exceptions and silent deaths '
                'are written to disk and returned here on the next launch. '
                'Trigger a crash, relaunch, and the reports appear below.',
              ),
              const SizedBox(height: 12),
              Text(
                _crashes.isEmpty
                    ? 'No pending reports.'
                    : '${_crashes.length} pending report(s):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _crashes.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: _crashes.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final crash = _crashes[index];
                          return _CrashTile(
                            crash: crash,
                            onDelete: () => _deleteAt(index),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Text(
                'Trigger a crash (debug only)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _crash(NativeError.crashNative),
                    child: const Text('Crash natively (SIGSEGV)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrashTile extends StatelessWidget {
  const _CrashTile({required this.crash, required this.onDelete});

  final NativeCrashReport crash;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitleLines = <String>[
      crash.diagnosis,
      if (crash.stackTrace != null && crash.stackTrace!.isNotEmpty)
        crash.stackTrace!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_titleFor(crash)),
      subtitle: Text(
        subtitleLines.join('\n'),
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
      ),
      isThreeLine: true,
    );
  }

  String _titleFor(NativeCrashReport crash) {
    switch (crash.kindType) {
      case NativeCrashKind.signal:
        return crash.signal ?? 'signal';
      case NativeCrashKind.java:
      case NativeCrashKind.nsException:
        return crash.exceptionType ?? crash.kind;
      case NativeCrashKind.abnormalTermination:
        return 'Abnormal termination';
      case NativeCrashKind.unknown:
        return crash.kind;
    }
  }
}
