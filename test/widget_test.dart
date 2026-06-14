// Smoke test — verifies the test runner works without booting the full app.
// Full app initialization (Supabase, Firebase, Google Maps) requires platform
// channels that are not available in the test VM.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test environment is functional', () {
    expect(1 + 1, equals(2));
  });
}
