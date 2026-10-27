// The tray_manager legacy bridge is still the simplest API for a static tray
// menu; the native API is tracked for a later upgrade.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

/// Windows-only window, tray and start-with-Windows integration.
class WindowsShell {
  WindowsShell._();

  /// True once [initialize] ran on Windows; used to hide desktop-only settings
  /// in widget tests and on Android.
  static bool isActive = false;
  static bool trayAvailable = false;

  static Future<void> initialize() async {
    if (!Platform.isWindows) return;

    await windowManager.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble('window.width') ?? 1120;
    final height = prefs.getDouble('window.height') ?? 780;
    final x = prefs.getDouble('window.x');
    final y = prefs.getDouble('window.y');

    final options = WindowOptions(
      size: Size(width, height),
      minimumSize: const Size(460, 620),
      center: x == null || y == null,
      title: 'HabitPulse',
      titleBarStyle: TitleBarStyle.normal,
    );

    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        if (x != null && y != null) {
          await windowManager.setPosition(Offset(x, y));
        }
        await windowManager.show();
        await windowManager.focus();
      }),
    );

    windowManager.addListener(_WindowStateListener(prefs));

    try {
      await trayManager.setIcon('assets/app_icon.ico');
      await trayManager.setToolTip('HabitPulse');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Show HabitPulse'),
            MenuItem(key: 'hide', label: 'Hide'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: 'Quit HabitPulse'),
          ],
        ),
      );
      trayManager.addListener(_TrayListener());
      // Closing the window hides to the tray; Quit lives in the tray menu.
      await windowManager.setPreventClose(true);
      trayAvailable = true;
    } on Object catch (error) {
      debugPrint('Tray setup failed: $error');
    }

    try {
      LaunchAtStartup.instance.setup(
        appName: 'HabitPulse',
        appPath: Platform.resolvedExecutable,
      );
    } on Object catch (error) {
      debugPrint('Startup setup failed: $error');
    }

    isActive = true;
  }
}

class _WindowStateListener extends WindowListener {
  _WindowStateListener(this.prefs);

  final SharedPreferences prefs;
  Timer? _saveTimer;

  @override
  void onWindowResize() => _queueSave();

  @override
  void onWindowMove() => _queueSave();

  void _queueSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      await prefs.setDouble('window.width', size.width);
      await prefs.setDouble('window.height', size.height);
      await prefs.setDouble('window.x', position.dx);
      await prefs.setDouble('window.y', position.dy);
    });
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}

class _TrayListener extends TrayListener {
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'hide':
        await windowManager.hide();
      case 'quit':
        await windowManager.setPreventClose(false);
        await trayManager.destroy();
        await windowManager.destroy();
    }
  }
}
