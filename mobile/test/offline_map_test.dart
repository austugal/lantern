import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/offline_map.dart';

String collection(dynamic geometry) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': geometry,
      'properties': {'name': 'Road'},
    },
  ],
});

void main() {
  test('offline map preserves valid road geometry and attribution', () {
    final area = OfflineArea.parse(
      collection({
        'type': 'LineString',
        'coordinates': [
          [-0.1, 51.5],
          [-0.11, 51.51],
        ],
      }),
    );
    expect(area.shapes.single.points.last, [-0.11, 51.51]);
    expect(area.shapes.single.label, 'Road');
  });
  test('invalid and excessive coordinates are rejected before rendering', () {
    for (final coordinate in [
      [181, 0],
      [0, 90],
      ['x', 10],
      [10],
    ]) {
      expect(
        () => OfflineArea.parse(
          collection({'type': 'Point', 'coordinates': coordinate}),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => OfflineArea.parse(
        collection({
          'type': 'LineString',
          'coordinates': List.filled(50001, [0, 1]),
        }),
      ),
      throwsFormatException,
    );
  });
  test('unsupported nesting and oversized maps rejected', () {
    expect(
      () => OfflineArea.parse(
        collection({'type': 'GeometryCollection', 'geometries': []}),
      ),
      throwsFormatException,
    );
    expect(
      () => OfflineArea.parse(' ' * (OfflineArea.maxBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => OfflineArea.parse('{"type":"FeatureCollection","features":[]}'),
      throwsFormatException,
    );
  });
  test('Overpass download becomes a persistent offline map', () {
    final result = overpassToGeoJson(
      jsonEncode({
        'elements': [
          {
            'type': 'way',
            'tags': {'highway': 'service', 'name': 'Hotel driveway'},
            'geometry': [
              {'lat': 51.5, 'lon': -0.1},
              {'lat': 51.51, 'lon': -0.11},
            ],
          },
          {
            'type': 'node',
            'lat': 51.5,
            'lon': -0.1,
            'tags': {'amenity': 'hospital'},
          },
        ],
      }),
    );
    final area = OfflineArea.parse(result);
    expect(area.shapes.length, 2);
    expect(area.attribution, contains('OpenStreetMap'));
    expect(DateTime.tryParse(area.savedAt), isNotNull);
  });
  test('partial service result never replaces complete saved map', () {
    expect(
      () => overpassToGeoJson('{"elements":[],"remark":"timeout"}'),
      throwsFormatException,
    );
  });
}
