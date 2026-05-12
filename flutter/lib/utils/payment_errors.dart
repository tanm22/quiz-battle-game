import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Maps a [PaymentFailureResponse] from the Razorpay SDK to a
/// `(title, body)` pair safe to surface to a user.
///
/// Razorpay's `response.message` is fine for real business errors
/// ("Card declined", "Insufficient funds") but useless for WebView-
/// level failures — `net::ERR_NAME_NOT_RESOLVED` and friends just
/// confuse non-engineers. This helper:
///   * returns hand-written copy for each named SDK error code, and
///   * for the `default` (code-less / unknown) branch, swaps any
///     message containing the Chromium `net::` jargon (anywhere in
///     the string, case-insensitive) for a generic retry prompt.
///
/// Extracted as a pure top-level function so it can be unit-tested
/// without a `BuildContext` or live `Razorpay` instance.
(String, String) friendlyPaymentError(PaymentFailureResponse r) {
  switch (r.code) {
    case Razorpay.NETWORK_ERROR:
      return (
        'No internet connection',
        "Couldn't reach the payment gateway. Check your network and try again.",
      );
    case Razorpay.TLS_ERROR:
      return (
        'Secure connection failed',
        "Couldn't establish a secure connection. Check that your device's date and time are set correctly, then try again.",
      );
    case Razorpay.INVALID_OPTIONS:
      return (
        'Payment setup error',
        'Something went wrong setting up this payment. Please go back and start the upgrade again.',
      );
    case Razorpay.INCOMPATIBLE_PLUGIN:
      return (
        'Update required',
        "This version of the app can't process payments. Please update to the latest version.",
      );
    case Razorpay.UNKNOWN_ERROR:
      // Razorpay's SDK fallback sends the literal string "An unknown
      // error occurred." — give the user something marginally less
      // bleak.
      return (
        'Payment failed',
        'Something went wrong while processing your payment. Please try again.',
      );
    default:
      final raw = r.message?.trim() ?? '';
      // Chromium / WebView errors leak through as `net::ERR_*` —
      // useless to a normal user. Razorpay's real-world payloads
      // sometimes embed the jargon mid-string (e.g. "Network error:
      // net::ERR_NAME_NOT_RESOLVED"), so a `startsWith` check would
      // miss them; the contains check is case-insensitive so a future
      // SDK upgrade emitting `NET::` still matches.
      if (raw.isEmpty || raw.toLowerCase().contains('net::')) {
        return (
          'Payment failed',
          'The payment could not be completed. Please try again in a moment.',
        );
      }
      // Real Razorpay business errors (card declined, insufficient
      // funds, OTP failed) are human-readable — pass through.
      return ('Payment failed', raw);
  }
}
