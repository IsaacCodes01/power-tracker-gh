// A degraded mobile data connection often still reports as "connected"
// (connectivity_plus only checks the OS network interface, not whether
// data actually flows) — so a pre-flight connectivity check alone isn't
// enough. Firebase calls also have no built-in timeout, so on a dead or
// exhausted-data connection they can hang indefinitely, leaving a loading
// spinner stuck with no explanation.
//
// Wrap any network-bound Future in .withNetworkTimeout() to make it fail
// fast with a clear, actionable message instead of hanging forever.

class NetworkTimeoutException implements Exception {
  final String _message;

  const NetworkTimeoutException([
    this._message =
        'This is taking longer than expected. Your connection may be '
        'unstable — please check it and try again.',
  ]);

  @override
  String toString() => _message;
}

// Distinct from NetworkTimeoutException: this is for a FAST rejection
// (the reachability probe failed in a few seconds, or the network layer
// itself refused the request almost immediately) rather than something
// that hung. In practice this is most often "registered on the network
// but out of data bundle" — the phone shows as connected, but nothing
// actually gets through.
class NetworkUnavailableException implements Exception {
  final String _message;

  const NetworkUnavailableException([
    this._message =
        "Couldn't reach the server. Please check your data balance or "
        'Wi-Fi, then try again.',
  ]);

  @override
  String toString() => _message;
}

extension NetworkTimeoutX<T> on Future<T> {
  // Default of 20s: long enough that it won't false-positive on a normal
  // slow-but-working connection, short enough that nobody waits "till
  // thy kingdom come" wondering if the app is broken.
  Future<T> withNetworkTimeout({
    Duration duration = const Duration(seconds: 20),
  }) {
    return timeout(
      duration,
      onTimeout: () => throw const NetworkTimeoutException(),
    );
  }
}
