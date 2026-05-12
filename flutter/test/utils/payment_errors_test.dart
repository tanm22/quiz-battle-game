import 'package:flutter_test/flutter_test.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:quiz_battle/utils/payment_errors.dart';

// Tiny helper — PaymentFailureResponse's constructor is
// `(code, message, error)` and we never care about `error` here.
PaymentFailureResponse _resp(int? code, String? message) =>
    PaymentFailureResponse(code, message, null);

void main() {
  group('friendlyPaymentError — named SDK codes', () {
    test('NETWORK_ERROR maps to a "No internet" prompt', () {
      final (title, body) = friendlyPaymentError(
        _resp(Razorpay.NETWORK_ERROR, 'whatever the sdk says'),
      );
      expect(title, contains('No internet'));
      expect(body, isNotEmpty);
    });

    test('TLS_ERROR maps to a "Secure connection" prompt', () {
      final (title, body) = friendlyPaymentError(
        _resp(Razorpay.TLS_ERROR, 'ssl handshake failed'),
      );
      expect(title, contains('Secure connection'));
      expect(body, isNotEmpty);
    });

    test('INVALID_OPTIONS maps to a "Payment setup error" prompt', () {
      final (title, body) = friendlyPaymentError(
        _resp(Razorpay.INVALID_OPTIONS, 'bad opts'),
      );
      expect(title, contains('Payment setup error'));
      expect(body, isNotEmpty);
    });

    test('INCOMPATIBLE_PLUGIN maps to an "Update required" prompt', () {
      final (title, body) = friendlyPaymentError(
        _resp(Razorpay.INCOMPATIBLE_PLUGIN, 'plugin too old'),
      );
      expect(title, contains('Update required'));
      expect(body, isNotEmpty);
    });

    test(
      'UNKNOWN_ERROR is swapped for friendly text (not the SDK literal)',
      () {
        // This is the literal string Razorpay's SDK emits when it gives up.
        final (title, body) = friendlyPaymentError(
          _resp(Razorpay.UNKNOWN_ERROR, 'An unknown error occurred.'),
        );
        expect(title, 'Payment failed');
        expect(body, isNot(equals('An unknown error occurred.')));
        expect(body, isNot(contains('unknown error occurred')));
      },
    );
  });

  group('friendlyPaymentError — default branch (code == null)', () {
    // Regression test for the original bug — Razorpay's real-world
    // payloads embed Chromium jargon mid-string, so the old
    // `startsWith('net::')` check missed them. This pins down the
    // contains-based suppression so it doesn't regress.
    test(
      'mid-string "net::" message returns the generic fallback '
      '(NOT the raw SDK string)',
      () {
        const raw = 'Network error: net::ERR_NAME_NOT_RESOLVED';
        final (title, body) = friendlyPaymentError(_resp(null, raw));
        expect(title, 'Payment failed');
        expect(body, isNot(contains('net::')));
        expect(body, isNot(contains(raw)));
        // And it should be the friendly retry prompt:
        expect(body.toLowerCase(), contains('try again'));
      },
    );

    test(
      'leading "net::" message still returns the generic fallback '
      '(covers the original startsWith case)',
      () {
        final (title, body) = friendlyPaymentError(
          _resp(null, 'net::ERR_INTERNET_DISCONNECTED'),
        );
        expect(title, 'Payment failed');
        expect(body, isNot(contains('net::')));
        expect(body.toLowerCase(), contains('try again'));
      },
    );

    test('real human-readable business error passes through', () {
      const raw = 'Card declined by issuer';
      final (title, body) = friendlyPaymentError(_resp(null, raw));
      expect(title, 'Payment failed');
      expect(body, raw);
    });

    test('null message falls back to the generic prompt', () {
      final (title, body) = friendlyPaymentError(_resp(null, null));
      expect(title, 'Payment failed');
      expect(body.toLowerCase(), contains('try again'));
    });

    test('empty message falls back to the generic prompt', () {
      final (title, body) = friendlyPaymentError(_resp(null, ''));
      expect(title, 'Payment failed');
      expect(body.toLowerCase(), contains('try again'));
    });
  });
}
