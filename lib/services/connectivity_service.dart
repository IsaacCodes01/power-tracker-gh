import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  // Quick one-time check: is there any network connection right now?
  // Note: this confirms a network exists (WiFi/mobile data), not that
  // it can actually reach the internet, but it's a solid first check.
  Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // A live stream, letting the app react in real time if the
  // connection drops or comes back while someone's using it.
  Stream<bool> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged.map(
      (result) => !result.contains(ConnectivityResult.none),
    );
  }

  // hasConnection() alone can't catch "registered on the network but no
  // data bundle left" — the phone still shows as connected in that case,
  // it just can't actually move any data. This does a real, tiny request
  // (Google's own connectivity-check endpoint, ~0 bytes back) with a
  // short timeout so a dead/exhausted connection is caught in a few
  // seconds instead of only discovered when the real sign-in/submit
  // call eventually fails or hangs.
  Future<bool> hasRealInternetAccess({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await http
          .get(Uri.parse('https://www.gstatic.com/generate_204'))
          .timeout(timeout);
      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
