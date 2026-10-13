import 'dart:convert';

// Messages on hmi/feedback, turned into one line for the operator.
//
// The reasoning agent answers every prompt there:
//   {"request_id", "ok": false, "error"}                       not understood / rejected
//   {"request_id", "ok": true, "needs_confirmation": true, "instruction"}   confirm on hmi/confirm
//   {"request_id", "ok": true, "forwarded": true, "instruction"}           sent to the robots
//   {"request_id", "ok": true, "discarded": true}
// The conveyor's QC agent forwards the conveyor's warnings there too:
//   {"source": "conveyor", "station", "warning", "product", "detail"}
enum FeedbackKind { needsConfirmation, forwarded, discarded, error, conveyorWarning, other }

class FleetFeedback {
  final FeedbackKind kind;
  final String? requestId;
  final String text;
  final Map<String, dynamic>? instruction;
  final DateTime time;

  FleetFeedback(this.kind, this.requestId, this.text, {this.instruction, DateTime? time})
      : time = time ?? DateTime.now();

  bool get isProblem => kind == FeedbackKind.error || kind == FeedbackKind.conveyorWarning;

  /// Null for a payload that is not a JSON object.
  static FleetFeedback? parse(String payload) {
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final m = decoded;
    final rid = m['request_id']?.toString();

    if (m['source'] == 'conveyor') {
      final product = m['product'] == null ? '' : ' (${m['product']})';
      return FleetFeedback(FeedbackKind.conveyorWarning, rid,
          'Conveyor warning$product: ${_warningText(m['warning']?.toString())}. ${m['detail'] ?? ''}'.trim());
    }
    final instruction = m['instruction'] is Map<String, dynamic> ? m['instruction'] as Map<String, dynamic> : null;
    if (m['ok'] == false) {
      return FleetFeedback(FeedbackKind.error, rid, 'Not sent: ${m['error'] ?? 'unknown error'}');
    }
    if (m['needs_confirmation'] == true && instruction != null) {
      return FleetFeedback(FeedbackKind.needsConfirmation, rid, 'Please confirm: ${describe(instruction)}',
          instruction: instruction);
    }
    if (m['forwarded'] == true && instruction != null) {
      return FleetFeedback(FeedbackKind.forwarded, rid, 'Sent to the robots: ${describe(instruction)}',
          instruction: instruction);
    }
    if (m['discarded'] == true) {
      return FleetFeedback(FeedbackKind.discarded, rid, 'Discarded, nothing was sent to the robots.');
    }
    return FleetFeedback(FeedbackKind.other, rid, payload);
  }

  /// "ABCD: manufacturing_1 -> quality_station -> package_area (fail: waste_area)"
  static String describe(Map<String, dynamic> i) =>
      '${i['product']}: ${i['source']} -> ${i['quality_check']} -> ${i['success_dest']} '
      '(fail: ${i['fail_dest']})';

  static String _warningText(String? code) {
    switch (code) {
      case 'SWITCH_NO_ACK':
        return 'the camera did not confirm the product program';
      case 'NO_PRODUCT':
        return 'no product name for the part at the camera, conveyor stopped';
      case 'PRODUCT_REJECTED':
        return 'product name rejected';
      case 'PRODUCT_STALE':
        return 'old product name discarded';
      default:
        return code ?? 'warning';
    }
  }
}

/// Payload for hmi/user_prompt: the reasoning agent echoes request_id in its feedback.
String promptPayload(String prompt, String requestId) => jsonEncode({'prompt': prompt, 'request_id': requestId});

/// Payload for hmi/confirm.
String confirmPayload(String requestId, bool confirm) => jsonEncode({'request_id': requestId, 'confirm': confirm});
