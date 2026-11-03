import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelracer/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(RacerStore.productIdsFor(TargetPlatform.iOS), {'pixelracerstar'});
    expect(RacerStore.starId, 'pixelracerstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(RacerStore.productIdsFor(TargetPlatform.android),
        {'pixelracercoffee', 'pixelracerchocolate'});
    expect(RacerStore.productIdsFor(TargetPlatform.android),
        isNot(contains('pixelracerstar')));
  });
}
