// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui show window;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'banner.dart';
import 'basic.dart';
import 'binding.dart';
import 'container.dart';
import 'framework.dart';
import 'locale_query.dart';
import 'media_query.dart';
import 'navigator.dart';
import 'performance_overlay.dart';
import 'semantics_debugger.dart';
import 'text.dart';
import 'title.dart';

/// Signature for a function that is called when the operating system changes the current locale.
///
/// Used by [WidgetsApp.onLocaleChanged].
typedef Future<LocaleQueryData> LocaleChangedCallback(Locale locale);

/// A convenience class that wraps a number of widgets that are commonly
/// required for an application.
///
/// See also: [CheckedModeBanner], [DefaultTextStyle], [MediaQuery],
/// [LocaleQuery], [Title], [Navigator], [Overlay], [SemanticsDebugger] (the
/// widgets wrapped by this one).
///
/// The [onGenerateRoute] argument is required, and corresponds to
/// [Navigator.onGenerateRoute].
class WidgetsApp extends StatefulWidget {
  /// Creates a widget that wraps a number of widgets that are commonly
  /// required for an application.
  ///
  /// The boolean arguments, [color], [navigatorObservers], and
  /// [onGenerateRoute] must not be null.
  const WidgetsApp({
    Key key,
    @required this.onGenerateRoute,
    this.onUnknownRoute,
    this.title,
    this.textStyle,
    @required this.color,
    this.navigatorObservers: const <NavigatorObserver>[],
    this.initialRoute,
    this.onLocaleChanged,
    this.showPerformanceOverlay: false,
    this.checkerboardRasterCacheImages: false,
    this.checkerboardOffscreenLayers: false,
    this.showSemanticsDebugger: false,
    this.debugShowCheckedModeBanner: true
  }) : assert(onGenerateRoute != null),
       assert(color != null),
       assert(navigatorObservers != null),
       assert(showPerformanceOverlay != null),
       assert(checkerboardRasterCacheImages != null),
       assert(checkerboardOffscreenLayers != null),
       assert(showSemanticsDebugger != null),
       assert(debugShowCheckedModeBanner != null),
       super(key: key);

  /// A one-line description of this app for use in the window manager.
  final String title;

  /// The default text style for [Text] in the application.
  final TextStyle textStyle;

  /// The primary color to use for the application in the operating system
  /// interface.
  ///
  /// For example, on Android this is the color used for the application in the
  /// application switcher.
  final Color color;

  /// The route generator callback used when the app is navigated to a
  /// named route.
  ///
  /// If this returns null when building the routes to handle the specified
  /// [initialRoute], then all the routes are discarded and
  /// [Navigator.defaultRouteName] is used instead (`/`). See [initialRoute].
  ///
  /// During normal app operation, the [onGenerateRoute] callback will only be
  /// applied to route names pushed by the application, and so should never
  /// return null.
  final RouteFactory onGenerateRoute;

  /// Called when [onGenerateRoute] fails to generate a route.
  ///
  /// This callback is typically used for error handling. For example, this
  /// callback might always generate a "not found" page that describes the route
  /// that wasn't found.
  ///
  /// Unknown routes can arise either from errors in the app or from external
  /// requests to push routes, such as from Android intents.
  final RouteFactory onUnknownRoute;

  /// The name of the first route to show.
  ///
  /// Defaults to [Window.defaultRouteName], which may be overridden by the code
  /// that launched the application.
  ///
  /// If the route contains slashes, then it is treated as a "deep link", and
  /// before this route is pushed, the routes leading to this one are pushed
  /// also. For example, if the route was `/a/b/c`, then the app would start
  /// with the three routes `/a`, `/a/b`, and `/a/b/c` loaded, in that order.
  ///
  /// If any part of this process fails to generate routes, then the
  /// [initialRoute] is ignored and [Navigator.defaultRouteName] is used instead
  /// (`/`). This can happen if the app is started with an intent that specifies
  /// a non-existent route.
  ///
  /// See also:
  ///
  ///  * [Navigator.initialRoute], which is used to implement this property.
  ///  * [Navigator.push], for pushing additional routes.
  ///  * [Navigator.pop], for removing a route from the stack.
  final String initialRoute;

  /// Callback that is called when the operating system changes the
  /// current locale.
  final LocaleChangedCallback onLocaleChanged;

  /// Turns on a performance overlay.
  /// https://flutter.io/debugging/#performanceoverlay
  final bool showPerformanceOverlay;

  /// Checkerboards raster cache images.
  ///
  /// See [PerformanceOverlay.checkerboardRasterCacheImages].
  final bool checkerboardRasterCacheImages;

  /// Checkerboards layers rendered to offscreen bitmaps.
  ///
  /// See [PerformanceOverlay.checkerboardOffscreenLayers].
  final bool checkerboardOffscreenLayers;

  /// Turns on an overlay that shows the accessibility information
  /// reported by the framework.
  final bool showSemanticsDebugger;

  /// Turns on a "SLOW MODE" little banner in checked mode to indicate
  /// that the app is in checked mode. This is on by default (in
  /// checked mode), to turn it off, set the constructor argument to
  /// false. In release mode this has no effect.
  ///
  /// To get this banner in your application if you're not using
  /// WidgetsApp, include a [CheckedModeBanner] widget in your app.
  ///
  /// This banner is intended to avoid people complaining that your
  /// app is slow when it's in checked mode. In checked mode, Flutter
  /// enables a large number of expensive diagnostics to aid in
  /// development, and so performance in checked mode is not
  /// representative of what will happen in release mode.
  final bool debugShowCheckedModeBanner;

  /// The list of observers for the [Navigator] created for this app.
  final List<NavigatorObserver> navigatorObservers;

  /// If true, forces the performance overlay to be visible in all instances.
  ///
  /// Used by `showPerformanceOverlay` observatory extension.
  static bool showPerformanceOverlayOverride = false;

  /// If false, prevents the debug banner from being visible.
  ///
  /// Used by `debugAllowBanner` observatory extension.
  ///
  /// This is how `flutter run` turns off the banner when you take a screen shot
  /// with "s".
  static bool debugAllowBannerOverride = true;

  @override
  _WidgetsAppState createState() => new _WidgetsAppState();
}

class _WidgetsAppState extends State<WidgetsApp> implements WidgetsBindingObserver {
  GlobalObjectKey<NavigatorState> _navigator;
  LocaleQueryData _localeData;

  @override
  void initState() {
    super.initState();
    _navigator = new GlobalObjectKey<NavigatorState>(this);
    didChangeLocale(ui.window.locale);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // On Android: the user has pressed the back button.
  @override
  Future<bool> didPopRoute() async {
    assert(mounted);
    final NavigatorState navigator = _navigator.currentState;
    assert(navigator != null);
    return await navigator.maybePop();
  }

  @override
  Future<bool> didPushRoute(String route) async {
    assert(mounted);
    final NavigatorState navigator = _navigator.currentState;
    assert(navigator != null);
    navigator.pushNamed(route);
    return true;
  }

  @override
  void didChangeMetrics() {
    setState(() {
      // The properties of ui.window have changed. We use them in our build
      // function, so we need setState(), but we don't cache anything locally.
    });
  }

  @override
  void didChangeLocale(Locale locale) {
    if (widget.onLocaleChanged != null) {
      widget.onLocaleChanged(locale).then<Null>((LocaleQueryData data) {
        if (mounted)
          setState(() { _localeData = data; });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { }

  @override
  void didHaveMemoryPressure() { }

  @override
  Widget build(BuildContext context) {
    if (widget.onLocaleChanged != null && _localeData == null) {
      // If the app expects a locale but we don't yet know the locale, then
      // don't build the widgets now.
      // TODO(ianh): Make this unnecessary. See https://github.com/flutter/flutter/issues/1865
      // TODO(ianh): The following line should not be included in release mode, only in profile and debug modes.
      WidgetsBinding.instance.preventThisFrameFromBeingReportedAsFirstFrame();
      return new Container();
    }

    Widget result = new MediaQuery(
      data: new MediaQueryData.fromWindow(ui.window),
      child: new LocaleQuery(
        data: _localeData,
        child: new Title(
          title: widget.title,
          color: widget.color,
          child: new Navigator(
            key: _navigator,
            initialRoute: widget.initialRoute ?? ui.window.defaultRouteName,
            onGenerateRoute: widget.onGenerateRoute,
            onUnknownRoute: widget.onUnknownRoute,
            observers: widget.navigatorObservers
          )
        )
      )
    );
    if (widget.textStyle != null) {
      result = new DefaultTextStyle(
        style: widget.textStyle,
        child: result
      );
    }

    PerformanceOverlay performanceOverlay;
    // We need to push a performance overlay if any of the display or checkerboarding
    // options are set.
    if (widget.showPerformanceOverlay || WidgetsApp.showPerformanceOverlayOverride) {
      performanceOverlay = new PerformanceOverlay.allEnabled(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    } else if (widget.checkerboardRasterCacheImages || widget.checkerboardOffscreenLayers) {
      performanceOverlay = new PerformanceOverlay(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    }

    if (performanceOverlay != null) {
      result = new Stack(
        children: <Widget>[
          result,
          new Positioned(top: 0.0, left: 0.0, right: 0.0, child: performanceOverlay),
        ]
      );
    }
    if (widget.showSemanticsDebugger) {
      result = new SemanticsDebugger(
        child: result
      );
    }
    assert(() {
      if (widget.debugShowCheckedModeBanner && WidgetsApp.debugAllowBannerOverride) {
        result = new CheckedModeBanner(
          child: result
        );
      }
      return true;
    });
    return result;
  }

}
