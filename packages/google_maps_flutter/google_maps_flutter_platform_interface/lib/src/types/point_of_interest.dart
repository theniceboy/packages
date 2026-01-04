// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'location.dart';

/// Represents a Point of Interest (POI) on the map.
///
/// A POI is a location that is marked on the map by Google Maps, such as
/// a business, landmark, or other notable location.
class PointOfInterest {
  /// Creates a [PointOfInterest].
  const PointOfInterest({
    required this.placeId,
    required this.name,
    required this.position,
  });

  /// The Google Place ID for this POI.
  ///
  /// This can be used with the Google Places API to get more information
  /// about the place.
  final String placeId;

  /// The name of the POI.
  final String name;

  /// The geographic position of the POI.
  final LatLng position;

  /// Creates a [PointOfInterest] from a JSON object.
  static PointOfInterest? fromJson(Object? json) {
    if (json == null) {
      return null;
    }
    assert(json is Map<String, dynamic>);
    final Map<String, dynamic> data = json as Map<String, dynamic>;
    return PointOfInterest(
      placeId: data['placeId'] as String,
      name: data['name'] as String,
      position: LatLng.fromJson(data['position'])!,
    );
  }

  /// Converts this [PointOfInterest] to a JSON object.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'placeId': placeId,
      'name': name,
      'position': position.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PointOfInterest &&
        other.placeId == placeId &&
        other.name == name &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(placeId, name, position);

  @override
  String toString() {
    return 'PointOfInterest(placeId: $placeId, name: $name, position: $position)';
  }
}
