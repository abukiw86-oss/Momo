import 'dart:io';
import 'dart:async';

class InternetChecker {
  Future<bool> quickCheck() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}
