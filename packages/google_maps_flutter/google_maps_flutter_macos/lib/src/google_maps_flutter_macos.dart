import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:stream_transform/stream_transform.dart';

class GoogleMapsFlutterMacOS extends GoogleMapsFlutterPlatform {
  static void registerWith() {
    GoogleMapsFlutterPlatform.instance = GoogleMapsFlutterMacOS();
  }

  final Map<int, _MapState> _maps = {};

  _MapState _map(int mapId) {
    final state = _maps[mapId];
    assert(state != null, 'Map $mapId not found');
    return state!;
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {
    _maps[mapId]?.dispose();
    _maps.remove(mapId);
  }

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapObjects mapObjects = const MapObjects(),
    MapConfiguration mapConfiguration = const MapConfiguration(),
  }) {
    if (_maps[creationId]?.widget != null) {
      return _maps[creationId]!.widget!;
    }

    final state = _MapState(
      mapId: creationId,
      onPlatformViewCreated: onPlatformViewCreated,
      widgetConfiguration: widgetConfiguration,
      mapConfiguration: mapConfiguration,
      initialMapObjects: mapObjects,
    );
    _maps[creationId] = state;
    return state.buildWidget();
  }

  // === Configuration ===

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration update, {
    required int mapId,
  }) async {
    await _map(mapId)._applyConfiguration(update);
  }

  // === Markers ===

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {
    final state = _map(mapId);
    for (final marker in markerUpdates.objectsToAdd) {
      await state._addMarker(marker);
    }
    for (final marker in markerUpdates.objectsToChange) {
      await state._addMarker(marker);
    }
    for (final markerId in markerUpdates.objectIdsToRemove) {
      await state._js("removeMarker('${markerId.value}')");
    }
  }

  // === Polylines ===

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {
    final state = _map(mapId);
    for (final poly in polylineUpdates.objectsToAdd) {
      await state._addPolyline(poly);
    }
    for (final poly in polylineUpdates.objectsToChange) {
      await state._addPolyline(poly);
    }
    for (final id in polylineUpdates.objectIdsToRemove) {
      await state._js("removePolyline('${id.value}')");
    }
  }

  // === Polygons ===

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {
    final state = _map(mapId);
    for (final poly in polygonUpdates.objectsToAdd) {
      await state._addPolygon(poly);
    }
    for (final poly in polygonUpdates.objectsToChange) {
      await state._addPolygon(poly);
    }
    for (final id in polygonUpdates.objectIdsToRemove) {
      await state._js("removePolygon('${id.value}')");
    }
  }

  // === Circles ===

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {
    final state = _map(mapId);
    for (final circle in circleUpdates.objectsToAdd) {
      await state._addCircle(circle);
    }
    for (final circle in circleUpdates.objectsToChange) {
      await state._addCircle(circle);
    }
    for (final id in circleUpdates.objectIdsToRemove) {
      await state._js("removeCircle('${id.value}')");
    }
  }

  // === Heatmaps ===

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {
    final state = _map(mapId);
    for (final hm in heatmapUpdates.objectsToAdd) {
      await state._addHeatmap(hm);
    }
    for (final hm in heatmapUpdates.objectsToChange) {
      await state._addHeatmap(hm);
    }
    for (final id in heatmapUpdates.objectIdsToRemove) {
      await state._js("removeHeatmap('${id.value}')");
    }
  }

  // === Tile Overlays ===

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {
    // Tile overlays require custom tile providers which need a Dart↔JS bridge per tile request.
    // This is a limitation of the WKWebView approach — not supported (same effective limitation as noted in web).
  }

  @override
  Future<void> clearTileCache(
    TileOverlayId tileOverlayId, {
    required int mapId,
  }) async {}

  // === Cluster Managers ===

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {
    // Marker clustering requires loading the @googlemaps/markerclusterer JS library.
    // Not yet implemented — would need adding the library to the HTML template.
  }

  // === Ground Overlays ===

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {
    final state = _map(mapId);
    for (final overlay in groundOverlayUpdates.objectsToAdd) {
      await state._addGroundOverlay(overlay);
    }
    for (final overlay in groundOverlayUpdates.objectsToChange) {
      await state._addGroundOverlay(overlay);
    }
    for (final id in groundOverlayUpdates.objectIdsToRemove) {
      await state._js("removeGroundOverlay('${id.value}')");
    }
  }

  // === Camera ===

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    return moveCamera(cameraUpdate, mapId: mapId);
  }

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    await _map(mapId)._applyCamera(cameraUpdate);
  }

  // === Style ===

  @override
  Future<void> setMapStyle(String? mapStyle, {required int mapId}) async {
    await _map(mapId)._js("setMapStyle('${_esc(mapStyle ?? '[]')}')");
  }

  @override
  Future<String?> getStyleError({required int mapId}) async => null;

  // === Queries ===

  @override
  Future<LatLngBounds> getVisibleRegion({required int mapId}) async {
    final state = _map(mapId);
    if (state._lastBounds != null) return state._lastBounds!;
    final result = await state._js('getVisibleRegion()');
    if (result is String) {
      final data = json.decode(result) as Map<String, dynamic>;
      return LatLngBounds(
        southwest: LatLng(
          (data['swLat'] as num).toDouble(),
          (data['swLng'] as num).toDouble(),
        ),
        northeast: LatLng(
          (data['neLat'] as num).toDouble(),
          (data['neLng'] as num).toDouble(),
        ),
      );
    }
    return LatLngBounds(
      southwest: const LatLng(0, 0),
      northeast: const LatLng(0, 0),
    );
  }

  @override
  Future<ScreenCoordinate> getScreenCoordinate(
    LatLng latLng, {
    required int mapId,
  }) async {
    final result = await _map(
      mapId,
    )._js('latLngToScreenCoordinate(${latLng.latitude}, ${latLng.longitude})');
    if (result is String) {
      final data = json.decode(result) as Map<String, dynamic>;
      return ScreenCoordinate(
        x: (data['x'] as num).toInt(),
        y: (data['y'] as num).toInt(),
      );
    }
    return const ScreenCoordinate(x: 0, y: 0);
  }

  @override
  Future<LatLng> getLatLng(
    ScreenCoordinate screenCoordinate, {
    required int mapId,
  }) async {
    final result = await _map(mapId)._js(
      'screenCoordinateToLatLng(${screenCoordinate.x}, ${screenCoordinate.y})',
    );
    if (result is String) {
      final data = json.decode(result) as Map<String, dynamic>;
      return LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      );
    }
    return const LatLng(0, 0);
  }

  @override
  Future<double> getZoomLevel({required int mapId}) async {
    final result = await _map(mapId)._js('getZoomLevel()');
    if (result is num) return result.toDouble();
    return _map(mapId)._lastZoom ?? 14.0;
  }

  // === Info Windows ===

  @override
  Future<void> showMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {
    await _map(mapId)._js("showInfoWindow('${markerId.value}')");
  }

  @override
  Future<void> hideMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {
    await _map(mapId)._js("hideInfoWindow('${markerId.value}')");
  }

  @override
  Future<bool> isMarkerInfoWindowShown(
    MarkerId markerId, {
    required int mapId,
  }) async {
    final result = await _map(
      mapId,
    )._js("isInfoWindowShown('${markerId.value}')");
    return result == true;
  }

  // === Event Streams ===

  Stream<MapEvent<Object?>> _events(int mapId) => _map(mapId).events;

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _events(mapId).whereType<CameraMoveStartedEvent>();

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _events(mapId).whereType<CameraMoveEvent>();

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _events(mapId).whereType<CameraIdleEvent>();

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      _events(mapId).whereType<MarkerTapEvent>();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      _events(mapId).whereType<InfoWindowTapEvent>();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      _events(mapId).whereType<MarkerDragStartEvent>();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      _events(mapId).whereType<MarkerDragEvent>();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      _events(mapId).whereType<MarkerDragEndEvent>();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      _events(mapId).whereType<PolylineTapEvent>();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      _events(mapId).whereType<PolygonTapEvent>();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      _events(mapId).whereType<CircleTapEvent>();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) =>
      _events(mapId).whereType<MapTapEvent>();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      _events(mapId).whereType<MapLongPressEvent>();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      _events(mapId).whereType<ClusterTapEvent>();

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      _events(mapId).whereType<GroundOverlayTapEvent>();

  @override
  Stream<PoiTapEvent> onPoiTap({required int mapId}) =>
      _events(mapId).whereType<PoiTapEvent>();

  static String _esc(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');
}

// ============================================================================

String _colorToCss(Color c) {
  return '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

double _colorOpacity(Color c) => ((c.value >> 24) & 0xFF) / 255.0;

class _MapState {
  final int mapId;
  final PlatformViewCreatedCallback onPlatformViewCreated;
  final MapWidgetConfiguration widgetConfiguration;
  final MapConfiguration mapConfiguration;
  final MapObjects initialMapObjects;
  final StreamController<MapEvent<Object?>> _streamController =
      StreamController<MapEvent<Object?>>.broadcast();

  MethodChannel? _channel;
  Widget? widget;
  bool _ready = false;
  final List<String> _pendingJS = [];
  LatLngBounds? _lastBounds;
  double? _lastZoom;

  Stream<MapEvent<Object?>> get events => _streamController.stream;

  _MapState({
    required this.mapId,
    required this.onPlatformViewCreated,
    required this.widgetConfiguration,
    required this.mapConfiguration,
    required this.initialMapObjects,
  });

  void _connectChannel(int viewId) {
    _channel = MethodChannel(
      'plugins.flutter.dev/google_maps_flutter_macos_$viewId',
    );
    _channel!.setMethodCallHandler(_handleMethodCall);
  }

  Widget buildWidget() {
    final cam = widgetConfiguration.initialCameraPosition;
    const apiKey = 'AIzaSyAsLysmr3Hl_Yv0qY4w9mlBgQlHSGfBQRw';

    final mapType = switch (mapConfiguration.mapType) {
      MapType.satellite => 'satellite',
      MapType.terrain => 'terrain',
      MapType.hybrid => 'hybrid',
      MapType.none => 'none',
      _ => 'roadmap',
    };

    widget = AppKitView(
      viewType: 'plugins.flutter.dev/google_maps_flutter_macos',
      creationParams: {
        'apiKey': apiKey,
        'lat': cam.target.latitude,
        'lng': cam.target.longitude,
        'zoom': cam.zoom,
        'style': mapConfiguration.style ?? '[]',
        'mapType': mapType,
        'minZoom': mapConfiguration.minMaxZoomPreference?.minZoom,
        'maxZoom': mapConfiguration.minMaxZoomPreference?.maxZoom,
        'zoomControl': mapConfiguration.zoomControlsEnabled ?? true,
        'trafficEnabled': mapConfiguration.trafficEnabled ?? false,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _connectChannel,
    );
    return widget!;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'event') return;
    final data = Map<String, dynamic>.from(call.arguments as Map);
    final type = data['type'] as String;

    switch (type) {
      case 'jsError':
        debugPrint('[GoogleMapsFlutterMacOS] JS Error: ${data['message']}');

      case 'mapReady':
        _ready = true;
        for (final js in _pendingJS) {
          _channel?.invokeMethod('evaluateJavaScript', js);
        }
        _pendingJS.clear();
        _applyInitialMapObjects();
        onPlatformViewCreated(mapId);

      case 'cameraMoveStarted':
        _streamController.add(CameraMoveStartedEvent(mapId));

      case 'cameraMove':
        final pos = CameraPosition(
          target: LatLng(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          ),
          zoom: (data['zoom'] as num?)?.toDouble() ?? 0,
          bearing: (data['heading'] as num?)?.toDouble() ?? 0,
          tilt: (data['tilt'] as num?)?.toDouble() ?? 0,
        );
        _streamController.add(CameraMoveEvent(mapId, pos));

      case 'cameraIdle':
        _lastZoom = (data['zoom'] as num?)?.toDouble();
        if (data['neLat'] != null) {
          _lastBounds = LatLngBounds(
            southwest: LatLng(
              (data['swLat'] as num).toDouble(),
              (data['swLng'] as num).toDouble(),
            ),
            northeast: LatLng(
              (data['neLat'] as num).toDouble(),
              (data['neLng'] as num).toDouble(),
            ),
          );
        }
        _streamController.add(CameraIdleEvent(mapId));

      case 'tap':
        _streamController.add(
          MapTapEvent(
            mapId,
            LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            ),
          ),
        );

      case 'longPress':
        _streamController.add(
          MapLongPressEvent(
            mapId,
            LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            ),
          ),
        );

      case 'poiTap':
        _streamController.add(
          PoiTapEvent(
            mapId,
            PointOfInterest(
              position: LatLng(
                (data['lat'] as num).toDouble(),
                (data['lng'] as num).toDouble(),
              ),
              name: data['name'] as String? ?? '',
              placeId: data['placeId'] as String? ?? '',
            ),
          ),
        );

      case 'markerTap':
        _streamController.add(
          MarkerTapEvent(mapId, MarkerId(data['markerId'] as String)),
        );

      case 'markerDragStart':
        _streamController.add(
          MarkerDragStartEvent(
            mapId,
            LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            ),
            MarkerId(data['markerId'] as String),
          ),
        );

      case 'markerDrag':
        _streamController.add(
          MarkerDragEvent(
            mapId,
            LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            ),
            MarkerId(data['markerId'] as String),
          ),
        );

      case 'markerDragEnd':
        _streamController.add(
          MarkerDragEndEvent(
            mapId,
            LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            ),
            MarkerId(data['markerId'] as String),
          ),
        );

      case 'polylineTap':
        _streamController.add(
          PolylineTapEvent(mapId, PolylineId(data['polylineId'] as String)),
        );

      case 'polygonTap':
        _streamController.add(
          PolygonTapEvent(mapId, PolygonId(data['polygonId'] as String)),
        );

      case 'circleTap':
        _streamController.add(
          CircleTapEvent(mapId, CircleId(data['circleId'] as String)),
        );

      case 'groundOverlayTap':
        _streamController.add(
          GroundOverlayTapEvent(
            mapId,
            GroundOverlayId(data['groundOverlayId'] as String),
          ),
        );
    }
  }

  void _applyInitialMapObjects() {
    for (final marker in initialMapObjects.markers) {
      _addMarker(marker);
    }
    for (final polyline in initialMapObjects.polylines) {
      _addPolyline(polyline);
    }
    for (final polygon in initialMapObjects.polygons) {
      _addPolygon(polygon);
    }
    for (final circle in initialMapObjects.circles) {
      _addCircle(circle);
    }
    for (final heatmap in initialMapObjects.heatmaps) {
      _addHeatmap(heatmap);
    }
    for (final overlay in initialMapObjects.groundOverlays) {
      _addGroundOverlay(overlay);
    }
  }

  // === Marker ===

  Future<void> _addMarker(Marker marker) async {
    final id = _escJS(marker.markerId.value);
    final lat = marker.position.latitude;
    final lng = marker.position.longitude;
    final title = _escJS(marker.infoWindow.title ?? '');
    final snippet = _escJS(marker.infoWindow.snippet ?? '');

    String iconUrl = '';
    double? hue;
    double? iconWidth;
    double? iconHeight;
    double? anchorX;
    double? anchorY;

    final icon = marker.icon;
    if (icon == BitmapDescriptor.defaultMarker) {
      hue = 0;
    } else {
      final iconJson = icon.toJson();
      if (iconJson is List && iconJson.isNotEmpty) {
        switch (iconJson[0]) {
          case 'defaultMarker':
            hue = iconJson.length > 1 ? (iconJson[1] as num).toDouble() : 0;
          case 'bytes':
            if (iconJson.length > 1) {
              final payload = iconJson[1];
              if (payload is Uint8List) {
                iconUrl = 'data:image/png;base64,${base64Encode(payload)}';
              } else if (payload is Map) {
                if (payload['byteData'] case final Uint8List bytes) {
                  iconUrl = 'data:image/png;base64,${base64Encode(bytes)}';
                  if (payload['width'] case final num w)
                    iconWidth = w.toDouble();
                  if (payload['height'] case final num h)
                    iconHeight = h.toDouble();
                }
              }
            }
          case 'asset':
          case 'assetImage':
            hue = 0;
          case 'asset':
          case 'assetImage':
            // Asset-based markers: not directly supported in WKWebView
            // since we don't have access to Flutter's asset bundle from JS.
            hue = 0;
          case 'mapBitmap':
            if (iconJson.length > 1) {
              final config = iconJson[1] as Map;
              if (config['byteData'] case final Uint8List bytes) {
                iconUrl = 'data:image/png;base64,${base64Encode(bytes)}';
                if (config['width'] case final num w) iconWidth = w.toDouble();
                if (config['height'] case final num h)
                  iconHeight = h.toDouble();
                if (config['imagePixelRatio'] case final num ratio
                    when iconWidth == null && iconHeight == null) {
                  // Would need actual image dimensions — fall back to natural size
                }
              }
            }
        }
      }
    }

    final anchor = marker.anchor;
    if (iconWidth != null && iconHeight != null) {
      anchorX = iconWidth * anchor.dx;
      anchorY = iconHeight * anchor.dy;
    }

    final opts = StringBuffer('{');
    opts.write("zIndex:${marker.zIndex},");
    opts.write("visible:${marker.visible},");
    opts.write("opacity:${marker.alpha},");
    opts.write("draggable:${marker.draggable},");
    if (title.isNotEmpty) opts.write("iwTitle:'$title',");
    if (snippet.isNotEmpty) opts.write("iwSnippet:'$snippet',");
    if (iconUrl.isNotEmpty) {
      opts.write("iconUrl:'$iconUrl',");
      if (iconWidth != null) opts.write("iconWidth:$iconWidth,");
      if (iconHeight != null) opts.write("iconHeight:$iconHeight,");
      if (anchorX != null) opts.write("anchorX:$anchorX,");
      if (anchorY != null) opts.write("anchorY:$anchorY,");
    } else if (hue != null) {
      opts.write("hue:$hue,");
    }
    opts.write('}');

    await _js("addMarker('$id',$lat,$lng,$opts)");
  }

  // === Polyline ===

  Future<void> _addPolyline(Polyline polyline) async {
    final id = _escJS(polyline.polylineId.value);
    final points = polyline.points
        .map((p) => '{lat:${p.latitude},lng:${p.longitude}}')
        .join(',');
    final color = _colorToCss(polyline.color);
    final opacity = _colorOpacity(polyline.color);

    final opts = StringBuffer('{');
    opts.write("color:'$color',");
    opts.write("width:${polyline.width},");
    opts.write("opacity:$opacity,");
    opts.write("geodesic:${polyline.geodesic},");
    opts.write("visible:${polyline.visible},");
    opts.write("zIndex:${polyline.zIndex},");
    opts.write("clickable:${polyline.consumeTapEvents},");
    opts.write('}');

    await _js("addPolyline('$id',[$points],$opts)");
  }

  // === Polygon ===

  Future<void> _addPolygon(Polygon polygon) async {
    final id = _escJS(polygon.polygonId.value);

    // Outer path
    final outerPath = polygon.points
        .map((p) => '{lat:${p.latitude},lng:${p.longitude}}')
        .join(',');

    // Holes — need to ensure reverse winding
    final holePaths = polygon.holes
        .map((hole) {
          final pts = hole
              .map((p) => '{lat:${p.latitude},lng:${p.longitude}}')
              .join(',');
          return '[$pts]';
        })
        .join(',');

    final paths = holePaths.isNotEmpty
        ? '[[$outerPath],$holePaths]'
        : '[[$outerPath]]';

    final strokeColor = _colorToCss(polygon.strokeColor);
    final strokeOpacity = _colorOpacity(polygon.strokeColor);
    final fillColor = _colorToCss(polygon.fillColor);
    final fillOpacity = _colorOpacity(polygon.fillColor);

    final opts = StringBuffer('{');
    opts.write("strokeColor:'$strokeColor',");
    opts.write("strokeWeight:${polygon.strokeWidth},");
    opts.write("strokeOpacity:$strokeOpacity,");
    opts.write("fillColor:'$fillColor',");
    opts.write("fillOpacity:$fillOpacity,");
    opts.write("geodesic:${polygon.geodesic},");
    opts.write("visible:${polygon.visible},");
    opts.write("zIndex:${polygon.zIndex},");
    opts.write("clickable:${polygon.consumeTapEvents},");
    opts.write('}');

    await _js("addPolygon('$id',$paths,$opts)");
  }

  // === Circle ===

  Future<void> _addCircle(Circle circle) async {
    final id = _escJS(circle.circleId.value);
    final lat = circle.center.latitude;
    final lng = circle.center.longitude;
    final radius = circle.radius;

    final strokeColor = _colorToCss(circle.strokeColor);
    final strokeOpacity = _colorOpacity(circle.strokeColor);
    final fillColor = _colorToCss(circle.fillColor);
    final fillOpacity = _colorOpacity(circle.fillColor);

    final opts = StringBuffer('{');
    opts.write("strokeColor:'$strokeColor',");
    opts.write("strokeWeight:${circle.strokeWidth},");
    opts.write("strokeOpacity:$strokeOpacity,");
    opts.write("fillColor:'$fillColor',");
    opts.write("fillOpacity:$fillOpacity,");
    opts.write("visible:${circle.visible},");
    opts.write("zIndex:${circle.zIndex},");
    opts.write("clickable:${circle.consumeTapEvents},");
    opts.write('}');

    await _js("addCircle('$id',$lat,$lng,$radius,$opts)");
  }

  // === Heatmap ===

  Future<void> _addHeatmap(Heatmap heatmap) async {
    final id = _escJS(heatmap.heatmapId.value);

    final data = heatmap.data
        .map((d) {
          return '{lat:${d.point.latitude},lng:${d.point.longitude},weight:${d.weight}}';
        })
        .join(',');

    final opts = StringBuffer('{');
    opts.write("dissipating:${heatmap.dissipating},");
    if (heatmap.maxIntensity != null)
      opts.write("maxIntensity:${heatmap.maxIntensity},");
    opts.write("opacity:${heatmap.opacity},");
    opts.write("radius:${heatmap.radius.radius},");

    if (heatmap.gradient case final gradient?) {
      final colors = <String>[];
      if (gradient.colors.isNotEmpty) {
        final first = gradient.colors.first.color;
        colors.add("'rgba(${first.red},${first.green},${first.blue},0)'");
      }
      for (final gc in gradient.colors) {
        final c = gc.color;
        colors.add("'rgba(${c.red},${c.green},${c.blue},${c.opacity})'");
      }
      opts.write("gradient:[${colors.join(',')}],");
    }
    opts.write('}');

    await _js("addHeatmap('$id',[$data],$opts)");
  }

  // === Ground Overlay ===

  Future<void> _addGroundOverlay(GroundOverlay overlay) async {
    final id = _escJS(overlay.groundOverlayId.value);
    final bounds = overlay.bounds;
    if (bounds == null) return;

    String imageUrl = '';
    final image = overlay.image;
    final imageJson = image.toJson();
    if (imageJson is Map) {
      if (imageJson['byteData'] case final Uint8List bytes) {
        imageUrl = 'data:image/png;base64,${base64Encode(bytes)}';
      } else if (imageJson['assetName'] case final String asset) {
        imageUrl = asset;
      }
    }
    if (imageUrl.isEmpty) return;

    final opacity = 1.0 - overlay.transparency;
    final opts = StringBuffer('{');
    opts.write("opacity:$opacity,");
    opts.write("visible:${overlay.visible},");
    opts.write("clickable:${overlay.clickable},");
    opts.write('}');

    await _js(
      "addGroundOverlay('$id','${_escJS(imageUrl)}',${bounds.northeast.latitude},${bounds.northeast.longitude},${bounds.southwest.latitude},${bounds.southwest.longitude},$opts)",
    );
  }

  // === Configuration ===

  Future<void> _applyConfiguration(MapConfiguration update) async {
    if (update.style case final style?) {
      await _js("setMapStyle('${GoogleMapsFlutterMacOS._esc(style)}')");
    }
    if (update.mapType case final mapType?) {
      final type = switch (mapType) {
        MapType.satellite => 'satellite',
        MapType.terrain => 'terrain',
        MapType.hybrid => 'hybrid',
        MapType.none => 'none',
        _ => 'roadmap',
      };
      await _js("setMapType('$type')");
    }
    if (update.zoomControlsEnabled case final enabled?) {
      await _js("setZoomControl($enabled)");
    }
    if (update.minMaxZoomPreference case final pref?) {
      await _js(
        "setMinMaxZoom(${pref.minZoom ?? 'null'},${pref.maxZoom ?? 'null'})",
      );
    }
    if (update.trafficEnabled case final enabled?) {
      await _js("setTrafficEnabled($enabled)");
    }
    if (update.cameraTargetBounds case final bounds?) {
      if (bounds.bounds case final b?) {
        await _js(
          "setRestriction(${b.northeast.latitude},${b.northeast.longitude},${b.southwest.latitude},${b.southwest.longitude})",
        );
      } else {
        await _js("setRestriction(null,null,null,null)");
      }
    }
    if (update.webGestureHandling case final handling?) {
      final mode = switch (handling) {
        WebGestureHandling.none => 'none',
        WebGestureHandling.cooperative => 'cooperative',
        WebGestureHandling.greedy => 'greedy',
        _ => 'auto',
      };
      await _js("setGestureHandling('$mode')");
    }
  }

  // === Camera ===

  Future<void> _applyCamera(CameraUpdate cameraUpdate) async {
    final json = cameraUpdate.toJson();
    if (json is! List || json.isEmpty) return;
    final type = json[0] as String;

    switch (type) {
      case 'newCameraPosition':
        final pos = json[1] as Map;
        final target = pos['target'] as List;
        final zoom = pos['zoom'] as num?;
        final heading = pos['bearing'] as num?;
        final tilt = pos['tilt'] as num?;
        await _js(
          'moveCamera(${target[0]},${target[1]},${zoom ?? 'null'},${heading ?? 'null'},${tilt ?? 'null'})',
        );
      case 'newLatLng':
        final latLng = json[1] as List;
        await _js('moveCamera(${latLng[0]},${latLng[1]},null,null,null)');
      case 'newLatLngZoom':
        final latLng = json[1] as List;
        final zoom = json[2] as num;
        await _js('moveCamera(${latLng[0]},${latLng[1]},$zoom,null,null)');
      case 'newLatLngBounds':
        final bounds = json[1] as List;
        final padding = json[2] as num;
        final sw = bounds[0] as List;
        final ne = bounds[1] as List;
        await _js('fitBounds(${ne[0]},${ne[1]},${sw[0]},${sw[1]},$padding)');
      case 'scrollBy':
        final dx = json[1] as num;
        final dy = json[2] as num;
        await _js('panBy($dx,$dy)');
      case 'zoomBy':
        final delta = json[1] as num;
        if (json.length > 2 && json[2] != null) {
          final focus = json[2] as List;
          await _js('zoomBy($delta,${focus[0]},${focus[1]})');
        } else {
          await _js('zoomBy($delta,null,null)');
        }
      case 'zoomIn':
        await _js('zoomBy(1,null,null)');
      case 'zoomOut':
        await _js('zoomBy(-1,null,null)');
      case 'zoomTo':
        final zoom = json[1] as num;
        await _js('zoomTo($zoom)');
    }
  }

  // === JS Bridge ===

  Future<dynamic> _js(String js) async {
    if (!_ready) {
      _pendingJS.add(js);
      return null;
    }
    return _channel?.invokeMethod('evaluateJavaScript', js);
  }

  void dispose() {
    _streamController.close();
  }

  static String _escJS(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');
}
