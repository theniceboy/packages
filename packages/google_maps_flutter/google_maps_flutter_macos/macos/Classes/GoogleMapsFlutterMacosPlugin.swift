import Cocoa
import FlutterMacOS
import WebKit

public class GoogleMapsFlutterMacosPlugin: NSObject, FlutterPlugin {
    static var registrar: FlutterPluginRegistrar?

    public static func register(with registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        let factory = GoogleMapViewFactory(registrar: registrar)
        registrar.register(factory, withId: "plugins.flutter.dev/google_maps_flutter_macos")
    }
}

class GoogleMapViewFactory: NSObject, FlutterPlatformViewFactory {
    private let registrar: FlutterPluginRegistrar

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let channel = FlutterMethodChannel(
            name: "plugins.flutter.dev/google_maps_flutter_macos_\(viewId)",
            binaryMessenger: registrar.messenger
        )
        return GoogleMapView(viewId: viewId, channel: channel, args: args as? [String: Any])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class GoogleMapView: NSView, WKNavigationDelegate, WKScriptMessageHandler {
    private let channel: FlutterMethodChannel
    private var webView: WKWebView!
    private var mapReady = false
    private var pendingCalls: [String] = []
    private var apiKeyStored: String = ""

    init(viewId: Int64, channel: FlutterMethodChannel, args: [String: Any]?) {
        self.channel = channel
        super.init(frame: .zero)

        let config = WKWebViewConfiguration()
        let contentController = config.userContentController
        contentController.add(self, name: "flutter")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)

        channel.setMethodCallHandler(handleMethodCall)

        apiKeyStored = args?["apiKey"] as? String ?? ""
        let apiKey = apiKeyStored
        let lat = args?["lat"] as? Double ?? 0.0
        let lng = args?["lng"] as? Double ?? 0.0
        let zoom = args?["zoom"] as? Double ?? 14.0
        let style = args?["style"] as? String ?? "[]"
        let mapType = args?["mapType"] as? String ?? "roadmap"
        let minZoom = args?["minZoom"] as? Double
        let maxZoom = args?["maxZoom"] as? Double
        let zoomControl = args?["zoomControl"] as? Bool ?? true
        let trafficEnabled = args?["trafficEnabled"] as? Bool ?? false

        let html = Self.generateHTML(
            apiKey: apiKey, lat: lat, lng: lng, zoom: zoom, style: style,
            mapType: mapType, minZoom: minZoom, maxZoom: maxZoom,
            zoomControl: zoomControl, trafficEnabled: trafficEnabled
        )
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost"))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "evaluateJavaScript":
            if let js = call.arguments as? String {
                if !mapReady {
                    pendingCalls.append(js)
                    result(nil)
                    return
                }
                webView.evaluateJavaScript(js) { value, error in
                    if let error = error {
                        result(FlutterError(code: "JS_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        result(value)
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected string", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("typeof loadGoogleMapsAPI") { [weak self] result, _ in
            if let r = result as? String, r == "function" {
                self?.webView.evaluateJavaScript("loadGoogleMapsAPI()", completionHandler: nil)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "flutter", let body = message.body as? [String: Any] else { return }
        guard let type = body["type"] as? String else { return }

        if type == "mapReady" {
            mapReady = true
            for js in pendingCalls {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
            pendingCalls.removeAll()
        }

        channel.invokeMethod("event", arguments: body)
    }

    static func generateHTML(
        apiKey: String, lat: Double, lng: Double, zoom: Double, style: String,
        mapType: String, minZoom: Double?, maxZoom: Double?,
        zoomControl: Bool, trafficEnabled: Bool
    ) -> String {
        let minZoomStr = minZoom.map { String($0) } ?? "null"
        let maxZoomStr = maxZoom.map { String($0) } ?? "null"
        let escapedStyle = style
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        return """
<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<style>html,body,#map{width:100%;height:100%;margin:0;padding:0;}</style>
</head><body>
<div id="map"></div>
<script>
let map, trafficLayer;
let markers = {}, polylines = {}, polygons = {}, circles = {}, heatmaps = {};
let groundOverlays = {}, tileOverlays = {};
let infoWindows = {}, openInfoWindowId = null;
let mapIsMoving = false;
let mapStyleJson = '\(escapedStyle)';

function postMsg(data) { window.webkit.messageHandlers.flutter.postMessage(data); }

function initMap() {
    const opts = {
        center: {lat: \(lat), lng: \(lng)},
        zoom: \(zoom),
        mapTypeId: '\(mapType)',
        zoomControl: \(zoomControl),
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: false,
        clickableIcons: true
    };
    try { opts.styles = JSON.parse(mapStyleJson); } catch(e) { opts.styles = []; }
    if (\(minZoomStr) !== null) opts.minZoom = \(minZoomStr);
    if (\(maxZoomStr) !== null) opts.maxZoom = \(maxZoomStr);

    map = new google.maps.Map(document.getElementById('map'), opts);

    if (\(trafficEnabled ? "true" : "false")) {
        trafficLayer = new google.maps.TrafficLayer();
        trafficLayer.setMap(map);
    }

    postMsg({type: 'mapReady'});

    map.addListener('bounds_changed', function() {
        if (!mapIsMoving) {
            mapIsMoving = true;
            postMsg({type: 'cameraMoveStarted'});
        }
        const c = map.getCenter();
        postMsg({
            type: 'cameraMove',
            lat: c.lat(), lng: c.lng(),
            zoom: map.getZoom(),
            heading: map.getHeading() || 0,
            tilt: map.getTilt() || 0
        });
    });

    map.addListener('idle', function() {
        mapIsMoving = false;
        const c = map.getCenter();
        const b = map.getBounds();
        const ne = b ? b.getNorthEast() : c;
        const sw = b ? b.getSouthWest() : c;
        postMsg({
            type: 'cameraIdle',
            lat: c.lat(), lng: c.lng(),
            zoom: map.getZoom(),
            heading: map.getHeading() || 0,
            tilt: map.getTilt() || 0,
            neLat: ne.lat(), neLng: ne.lng(),
            swLat: sw.lat(), swLng: sw.lng()
        });
    });

    map.addListener('click', function(e) {
        if (e.placeId) {
            e.stop();
            postMsg({type: 'poiTap', placeId: e.placeId, name: '', lat: e.latLng.lat(), lng: e.latLng.lng()});
        } else {
            postMsg({type: 'tap', lat: e.latLng.lat(), lng: e.latLng.lng()});
        }
    });

    map.addListener('rightclick', function(e) {
        postMsg({type: 'longPress', lat: e.latLng.lat(), lng: e.latLng.lng()});
    });
}

// === MARKERS ===
function addMarker(id, lat, lng, opts) {
    removeMarker(id);
    const markerOpts = {
        position: {lat: lat, lng: lng},
        map: map,
        zIndex: opts.zIndex || 0,
        visible: opts.visible !== false,
        opacity: opts.opacity != null ? opts.opacity : 1.0,
        draggable: opts.draggable === true
    };
    if (opts.title) markerOpts.title = opts.title;

    if (opts.iconUrl) {
        const icon = {url: opts.iconUrl};
        if (opts.iconWidth && opts.iconHeight) {
            icon.scaledSize = new google.maps.Size(opts.iconWidth, opts.iconHeight);
            icon.size = new google.maps.Size(opts.iconWidth, opts.iconHeight);
        }
        if (opts.anchorX != null && opts.anchorY != null) {
            icon.anchor = new google.maps.Point(opts.anchorX, opts.anchorY);
        }
        markerOpts.icon = icon;
    } else if (opts.hue != null) {
        markerOpts.icon = {
            url: generateMarkerSvg(opts.hue),
            scaledSize: new google.maps.Size(27, 43),
            size: new google.maps.Size(27, 43),
            anchor: new google.maps.Point(13.5, 43)
        };
    }

    const marker = new google.maps.Marker(markerOpts);

    if (opts.iwTitle || opts.iwSnippet) {
        const content = '<div><strong>' + escapeHtml(opts.iwTitle || '') + '</strong>' +
                       (opts.iwSnippet ? '<br>' + escapeHtml(opts.iwSnippet) : '') + '</div>';
        const iw = new google.maps.InfoWindow({content: content});
        iw.addListener('closeclick', function() { if (openInfoWindowId === id) openInfoWindowId = null; });
        infoWindows[id] = iw;
    }

    marker.addListener('click', function() {
        postMsg({type: 'markerTap', markerId: id});
    });

    if (opts.draggable) {
        marker.addListener('dragstart', function(e) {
            postMsg({type: 'markerDragStart', markerId: id, lat: e.latLng.lat(), lng: e.latLng.lng()});
        });
        marker.addListener('drag', function(e) {
            postMsg({type: 'markerDrag', markerId: id, lat: e.latLng.lat(), lng: e.latLng.lng()});
        });
        marker.addListener('dragend', function(e) {
            postMsg({type: 'markerDragEnd', markerId: id, lat: e.latLng.lat(), lng: e.latLng.lng()});
        });
    }

    markers[id] = marker;
}

function removeMarker(id) {
    if (markers[id]) { markers[id].setMap(null); delete markers[id]; }
    if (infoWindows[id]) { infoWindows[id].close(); delete infoWindows[id]; }
    if (openInfoWindowId === id) openInfoWindowId = null;
}

function showInfoWindow(id) {
    if (openInfoWindowId && openInfoWindowId !== id && infoWindows[openInfoWindowId]) {
        infoWindows[openInfoWindowId].close();
    }
    if (infoWindows[id] && markers[id]) {
        infoWindows[id].open(map, markers[id]);
        openInfoWindowId = id;
    }
}

function hideInfoWindow(id) {
    if (infoWindows[id]) { infoWindows[id].close(); }
    if (openInfoWindowId === id) openInfoWindowId = null;
}

function isInfoWindowShown(id) {
    return openInfoWindowId === id && infoWindows[id] != null;
}

// === POLYLINES ===
function addPolyline(id, path, opts) {
    removePolyline(id);
    const poly = new google.maps.Polyline({
        path: path,
        strokeColor: opts.color || '#4285F4',
        strokeWeight: opts.width || 4,
        strokeOpacity: opts.opacity != null ? opts.opacity : 1.0,
        geodesic: opts.geodesic !== false,
        visible: opts.visible !== false,
        zIndex: opts.zIndex || 0,
        clickable: opts.clickable !== false,
        map: map
    });
    poly.addListener('click', function() {
        postMsg({type: 'polylineTap', polylineId: id});
    });
    polylines[id] = poly;
}

function removePolyline(id) {
    if (polylines[id]) { polylines[id].setMap(null); delete polylines[id]; }
}

// === POLYGONS ===
function addPolygon(id, paths, opts) {
    removePolygon(id);
    const poly = new google.maps.Polygon({
        paths: paths,
        strokeColor: opts.strokeColor || '#000000',
        strokeWeight: opts.strokeWeight || 1,
        strokeOpacity: opts.strokeOpacity != null ? opts.strokeOpacity : 1.0,
        fillColor: opts.fillColor || '#000000',
        fillOpacity: opts.fillOpacity != null ? opts.fillOpacity : 0.35,
        geodesic: opts.geodesic !== false,
        visible: opts.visible !== false,
        zIndex: opts.zIndex || 0,
        clickable: opts.clickable !== false,
        map: map
    });
    poly.addListener('click', function() {
        postMsg({type: 'polygonTap', polygonId: id});
    });
    polygons[id] = poly;
}

function removePolygon(id) {
    if (polygons[id]) { polygons[id].setMap(null); delete polygons[id]; }
}

// === CIRCLES ===
function addCircle(id, lat, lng, radius, opts) {
    removeCircle(id);
    const circle = new google.maps.Circle({
        center: {lat: lat, lng: lng},
        radius: radius,
        strokeColor: opts.strokeColor || '#000000',
        strokeWeight: opts.strokeWeight || 1,
        strokeOpacity: opts.strokeOpacity != null ? opts.strokeOpacity : 1.0,
        fillColor: opts.fillColor || '#000000',
        fillOpacity: opts.fillOpacity != null ? opts.fillOpacity : 0.35,
        visible: opts.visible !== false,
        zIndex: opts.zIndex || 0,
        clickable: opts.clickable !== false,
        map: map
    });
    circle.addListener('click', function() {
        postMsg({type: 'circleTap', circleId: id});
    });
    circles[id] = circle;
}

function removeCircle(id) {
    if (circles[id]) { circles[id].setMap(null); delete circles[id]; }
}

// === HEATMAPS ===
function addHeatmap(id, data, opts) {
    removeHeatmap(id);
    const points = data.map(function(d) {
        return {location: new google.maps.LatLng(d.lat, d.lng), weight: d.weight || 1};
    });
    const heatmapOpts = {data: points, map: map};
    if (opts.dissipating != null) heatmapOpts.dissipating = opts.dissipating;
    if (opts.maxIntensity != null) heatmapOpts.maxIntensity = opts.maxIntensity;
    if (opts.opacity != null) heatmapOpts.opacity = opts.opacity;
    if (opts.radius != null) heatmapOpts.radius = opts.radius;
    if (opts.gradient) heatmapOpts.gradient = opts.gradient;
    heatmaps[id] = new google.maps.visualization.HeatmapLayer(heatmapOpts);
}

function removeHeatmap(id) {
    if (heatmaps[id]) { heatmaps[id].setMap(null); delete heatmaps[id]; }
}

// === GROUND OVERLAYS ===
function addGroundOverlay(id, url, neLat, neLng, swLat, swLng, opts) {
    removeGroundOverlay(id);
    const bounds = new google.maps.LatLngBounds({lat: swLat, lng: swLng}, {lat: neLat, lng: neLng});
    const overlay = new google.maps.GroundOverlay(url, bounds, {
        opacity: opts.opacity != null ? opts.opacity : 1.0,
        clickable: opts.clickable !== false,
        map: opts.visible !== false ? map : null
    });
    overlay.addListener('click', function() {
        postMsg({type: 'groundOverlayTap', groundOverlayId: id});
    });
    groundOverlays[id] = overlay;
}

function removeGroundOverlay(id) {
    if (groundOverlays[id]) { groundOverlays[id].setMap(null); delete groundOverlays[id]; }
}

// === MAP CONFIGURATION ===
function setMapStyle(style) {
    try { map.setOptions({styles: JSON.parse(style)}); } catch(e) { map.setOptions({styles: []}); }
}

function setMapType(type) { map.setMapTypeId(type); }

function setZoomControl(enabled) { map.setOptions({zoomControl: enabled}); }

function setMinMaxZoom(min, max) {
    const opts = {};
    if (min !== null) opts.minZoom = min;
    if (max !== null) opts.maxZoom = max;
    map.setOptions(opts);
}

function setTrafficEnabled(enabled) {
    if (enabled) {
        if (!trafficLayer) trafficLayer = new google.maps.TrafficLayer();
        trafficLayer.setMap(map);
    } else if (trafficLayer) {
        trafficLayer.setMap(null);
    }
}

function setRestriction(neLat, neLng, swLat, swLng) {
    if (neLat === null) {
        map.setOptions({restriction: null});
    } else {
        map.setOptions({restriction: {
            latLngBounds: new google.maps.LatLngBounds({lat: swLat, lng: swLng}, {lat: neLat, lng: neLng}),
            strictBounds: false
        }});
    }
}

function setGestureHandling(mode) { map.setOptions({gestureHandling: mode}); }

// === CAMERA ===
function moveCamera(lat, lng, zoom, heading, tilt) {
    if (lat !== null && lng !== null) map.panTo({lat: lat, lng: lng});
    if (zoom !== null) map.setZoom(zoom);
    if (heading !== null) map.setHeading(heading);
    if (tilt !== null) map.setTilt(tilt);
}

function fitBounds(neLat, neLng, swLat, swLng, padding) {
    const bounds = new google.maps.LatLngBounds({lat: swLat, lng: swLng}, {lat: neLat, lng: neLng});
    map.fitBounds(bounds, padding || 0);
}

function panBy(dx, dy) { map.panBy(dx, dy); }

function zoomBy(delta, focusX, focusY) {
    const currentZoom = map.getZoom();
    const newZoom = currentZoom + delta;
    if (focusX !== null && focusY !== null) {
        const latLng = pixelToLatLng(focusX, focusY);
        if (latLng) {
            map.setZoom(delta > 0 ? Math.ceil(newZoom) : Math.floor(newZoom));
            map.panTo(latLng);
            return;
        }
    }
    map.setZoom(delta > 0 ? Math.ceil(newZoom) : Math.floor(newZoom));
}

function zoomTo(zoom) { map.setZoom(zoom); }

// === COORDINATE CONVERSION ===
function getVisibleRegion() {
    const b = map.getBounds();
    if (!b) return null;
    const ne = b.getNorthEast(), sw = b.getSouthWest();
    return JSON.stringify({neLat: ne.lat(), neLng: ne.lng(), swLat: sw.lat(), swLng: sw.lng()});
}

function latLngToScreenCoordinate(lat, lng) {
    const projection = map.getProjection();
    if (!projection) return null;
    const bounds = map.getBounds();
    if (!bounds) return null;
    const ne = bounds.getNorthEast(), sw = bounds.getSouthWest();
    const topRight = projection.fromLatLngToPoint(ne);
    const bottomLeft = projection.fromLatLngToPoint(sw);
    const scale = Math.pow(2, map.getZoom());
    const worldPoint = projection.fromLatLngToPoint(new google.maps.LatLng(lat, lng));
    return JSON.stringify({
        x: Math.round((worldPoint.x - bottomLeft.x) * scale),
        y: Math.round((worldPoint.y - topRight.y) * scale)
    });
}

function pixelToLatLng(x, y) {
    const projection = map.getProjection();
    if (!projection) return null;
    const bounds = map.getBounds();
    if (!bounds) return null;
    const ne = bounds.getNorthEast(), sw = bounds.getSouthWest();
    const topRight = projection.fromLatLngToPoint(ne);
    const bottomLeft = projection.fromLatLngToPoint(sw);
    const scale = Math.pow(2, map.getZoom());
    const worldPoint = new google.maps.Point(x / scale + bottomLeft.x, y / scale + topRight.y);
    const ll = projection.fromPointToLatLng(worldPoint);
    return ll;
}

function screenCoordinateToLatLng(x, y) {
    const ll = pixelToLatLng(x, y);
    if (!ll) return null;
    return JSON.stringify({lat: ll.lat(), lng: ll.lng()});
}

function getZoomLevel() { return map.getZoom(); }

// === UTILS ===
function generateMarkerSvg(hue) {
    const color = hueToHex(hue);
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="27" height="43" viewBox="0 0 27 43">' +
        '<path d="M13.5 0C6.044 0 0 6.044 0 13.5 0 25.5 13.5 43 13.5 43S27 25.5 27 13.5C27 6.044 20.956 0 13.5 0z" fill="' + color + '"/>' +
        '<circle cx="13.5" cy="13.5" r="5" fill="white"/>' +
        '</svg>';
    return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg);
}

function hueToHex(hue) {
    const h = ((hue % 360) + 360) % 360;
    const s = 1, l = 0.5;
    const a = s * Math.min(l, 1 - l);
    const f = n => {
        const k = (n + h / 30) % 12;
        const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
        return Math.round(255 * color).toString(16).padStart(2, '0');
    };
    return '#' + f(0) + f(8) + f(4);
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

window.onerror = function(msg, url, line, col, error) {
    postMsg({type: 'jsError', message: msg + ' (line ' + line + ')'});
};

function gm_authFailure() {
    postMsg({type: 'jsError', message: 'Google Maps auth failure - check API key'});
}

function loadGoogleMapsAPI() {
    var script = document.createElement('script');
    script.src = 'https://maps.googleapis.com/maps/api/js?key=\(apiKey)&callback=initMap&libraries=places,visualization';
    script.async = true;
    document.head.appendChild(script);
}
</script>
</body></html>
"""
    }
}
