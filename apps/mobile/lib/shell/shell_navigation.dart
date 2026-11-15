import 'package:flutter/widgets.dart';

/// Pushes a screen inside the active tab so the bottom navigation stays
/// visible. Set by [HomeShell] while it is mounted.
typedef ShellPush = Future<dynamic> Function(Widget screen);

ShellPush? shellPush;
