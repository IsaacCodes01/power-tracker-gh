import 'package:connectivity_plus/connectivity_plus.dart';

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
}
