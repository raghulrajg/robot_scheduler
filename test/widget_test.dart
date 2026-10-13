import 'package:flutter_test/flutter_test.dart';

import 'package:robot_scheduler/feedback.dart';

void main() {
  const instruction = '{"product": "ABCD", "source": "manufacturing_1", "quality_check": "quality_station", '
      '"success_dest": "package_area", "fail_dest": "waste_area", "request_id": "app1"}';

  test('confirmation request from the reasoning agent', () {
    final fb = FleetFeedback.parse('{"request_id": "app1", "ok": true, "needs_confirmation": true, '
        '"instruction": $instruction, "how_to_confirm": {}}')!;
    expect(fb.kind, FeedbackKind.needsConfirmation);
    expect(fb.requestId, 'app1');
    expect(fb.instruction!['product'], 'ABCD');
    expect(fb.text, contains('ABCD: manufacturing_1 -> quality_station -> package_area (fail: waste_area)'));
  });

  test('forwarded, rejected and discarded prompts', () {
    expect(FleetFeedback.parse('{"request_id": "app1", "ok": true, "forwarded": true, "instruction": $instruction}')!.kind,
        FeedbackKind.forwarded);
    final err = FleetFeedback.parse('{"request_id": "app2", "ok": false, "error": "not understood: no product"}')!;
    expect(err.kind, FeedbackKind.error);
    expect(err.text, 'Not sent: not understood: no product');
    expect(FleetFeedback.parse('{"request_id": "app3", "ok": true, "discarded": true}')!.kind, FeedbackKind.discarded);
  });

  test('conveyor warning forwarded by the QC agent', () {
    final fb = FleetFeedback.parse('{"request_id": null, "ok": false, "source": "conveyor", "station": "qc_01", '
        '"warning": "SWITCH_NO_ACK", "product": "ABCD", "detail": "no ok within 10 s"}')!;
    expect(fb.kind, FeedbackKind.conveyorWarning);
    expect(fb.requestId, isNull);
    expect(fb.text, contains('(ABCD)'));
    expect(fb.text, contains('did not confirm'));
  });

  test('payloads sent by the app', () {
    expect(promptPayload('take ABCD', 'app1'), '{"prompt":"take ABCD","request_id":"app1"}');
    expect(confirmPayload('app1', true), '{"request_id":"app1","confirm":true}');
    expect(FleetFeedback.parse('plain text'), isNull);
    expect(FleetFeedback.parse('[1, 2]'), isNull);
  });
}
