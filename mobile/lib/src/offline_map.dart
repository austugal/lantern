import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bounded, deliberately small GeoJSON subset for offline area maps.
class MapShape {
  const MapShape(this.points, this.closed, this.label);
  final List<List<double>> points; // longitude, latitude
  final bool closed;
  final String label;
}

class OfflineArea {
  const OfflineArea(this.shapes, this.attribution, this.savedAt);
  static const maxBytes = 5 * 1024 * 1024;
  static const maxPoints = 50000;
  final List<MapShape> shapes;
  final String attribution;
  final String savedAt;

  factory OfflineArea.parse(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('Map exceeds the 5 MB limit.');
    }
    final root = jsonDecode(source);
    if (root is! Map ||
        root['type'] != 'FeatureCollection' ||
        root['features'] is! List) {
      throw const FormatException('Choose a GeoJSON FeatureCollection.');
    }
    final features = root['features'] as List;
    if (features.length > 5000) {
      throw const FormatException('Map exceeds 5,000 features.');
    }
    var count = 0;
    final shapes = <MapShape>[];
    List<double> point(dynamic value) {
      if (value is! List ||
          value.length < 2 ||
          value[0] is! num ||
          value[1] is! num) {
        throw const FormatException('Invalid map coordinate.');
      }
      final x = (value[0] as num).toDouble();
      final y = (value[1] as num).toDouble();
      if (!x.isFinite ||
          !y.isFinite ||
          x.abs() > 180 ||
          y.abs() > 85.05112878 ||
          ++count > maxPoints) {
        throw const FormatException('Invalid coordinate or map too complex.');
      }
      return [x, y];
    }

    String shortText(dynamic value, int max) =>
        value is String ? value.substring(0, value.length.clamp(0, max)) : '';
    for (final f in features) {
      if (f is! Map || f['geometry'] is! Map) {
        throw const FormatException('Invalid feature.');
      }
      final g = f['geometry'] as Map;
      final coords = g['coordinates'];
      final properties = f['properties'];
      final label = shortText(
        properties is Map ? properties['name'] : null,
        80,
      );
      if (g['type'] == 'Point') {
        shapes.add(MapShape([point(coords)], false, label));
      } else if (g['type'] == 'LineString' &&
          coords is List &&
          coords.length >= 2) {
        shapes.add(MapShape(coords.map(point).toList(), false, label));
      } else if (g['type'] == 'Polygon' &&
          coords is List &&
          coords.isNotEmpty) {
        // Draw outlines (including holes), never misrepresent a hole as filled land.
        for (final ring in coords) {
          if (ring is! List || ring.length < 4) {
            throw const FormatException('Invalid polygon.');
          }
          shapes.add(MapShape(ring.map(point).toList(), true, label));
        }
      } else {
        throw const FormatException(
          'Supported geometry: Point, LineString, Polygon.',
        );
      }
    }
    if (shapes.isEmpty) {
      throw const FormatException('This map has no features.');
    }
    final credit = shortText(root['attribution'], 200);
    return OfflineArea(
      shapes,
      credit.isEmpty ? 'Imported map — verify its source and licence' : credit,
      shortText(root['savedAt'], 40),
    );
  }
}

String overpassToGeoJson(String source) {
  final root = jsonDecode(source);
  if (root is! Map || root['elements'] is! List || root['remark'] != null) {
    throw const FormatException(
      'Map service returned incomplete data. Try later.',
    );
  }
  final elements = root['elements'] as List;
  if (elements.length > 5000) {
    throw const FormatException('Area is too detailed.');
  }
  final features = <Map<String, dynamic>>[];
  for (final e in elements) {
    if (e is! Map) {
      throw const FormatException('Invalid map data.');
    }
    final tags = e['tags'];
    Map<String, dynamic>? geometry;
    if (e['type'] == 'node') {
      geometry = {
        'type': 'Point',
        'coordinates': [e['lon'], e['lat']],
      };
    } else if (e['type'] == 'way' && e['geometry'] is List) {
      final coords = (e['geometry'] as List).map((p) {
        if (p is! Map) {
          throw const FormatException('Invalid map data.');
        }
        return [p['lon'], p['lat']];
      }).toList();
      final closed =
          tags is Map &&
          tags['building'] != null &&
          coords.length >= 4 &&
          coords.first[0] == coords.last[0] &&
          coords.first[1] == coords.last[1];
      geometry = {
        'type': closed ? 'Polygon' : 'LineString',
        'coordinates': closed ? [coords] : coords,
      };
    }
    if (geometry != null) {
      features.add({
        'type': 'Feature',
        'geometry': geometry,
        'properties': {
          'name': tags is Map ? tags['name'] ?? tags['amenity'] ?? '' : '',
        },
      });
    }
  }
  final result = jsonEncode({
    'type': 'FeatureCollection',
    'attribution':
        '© OpenStreetMap contributors · ODbL · openstreetmap.org/copyright',
    'savedAt': DateTime.now().toUtc().toIso8601String(),
    'features': features,
  });
  OfflineArea.parse(result);
  return result;
}

/// Explicit foreground request only. Public Overpass is not an emergency SLA.
Future<String> downloadNearbyArea(
  double lat,
  double lon, {
  void Function(HttpClient)? onClient,
}) async {
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 85 || lon.abs() > 180) {
    throw const FormatException('Location cannot be mapped.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  onClient?.call(client);
  final deadline = Future<String>(() async {
    final query =
        '[out:json][timeout:20][maxsize:16777216];('
        'way(around:500,$lat,$lon)[highway];'
        'way(around:500,$lat,$lon)[building];'
        'node(around:500,$lat,$lon)[amenity];);out geom;';
    final request = await client.postUrl(
      Uri.parse('https://overpass-api.de/api/interpreter'),
    );
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Lantern/0.2 (github.com/austugal/lantern)',
    );
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    request.write('data=${Uri.encodeComponent(query)}');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException(
        'Map service unavailable (${response.statusCode}). Try later.',
      );
    }
    final data = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (data.length + chunk.length > OfflineArea.maxBytes) {
        throw const FormatException('Area exceeds 5 MB.');
      }
      data.add(chunk);
    }
    return overpassToGeoJson(utf8.decode(data.takeBytes()));
  });
  try {
    return await deadline.timeout(const Duration(seconds: 30));
  } finally {
    client.close(force: true);
  }
}
