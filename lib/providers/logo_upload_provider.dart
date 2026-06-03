import 'package:gps_tracker/config/imports.dart';

class LogoUploadProvider extends ChangeNotifier {
  bool isUploading = false;
  Future<Map<String, dynamic>> uploadUserLogo({
    required File? imageFile,
  }) async {
    isUploading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');
    String? savedUserId = prefs.getString('user_id');
    if (savedEmail == null || savedUserId == null) {
      return {
        'success': false,
        'message':
            'User data is missing. ${savedUserId == null ? "User ID is missing. " : ""}${savedEmail == null ? "Email is missing." : ""}',
      };
    }

    final result = await UserLogoUploadService.uploadUserLogo(
      userId: savedUserId,
      email: savedEmail,
      imageFile: imageFile,
    );
    isUploading = false;
    notifyListeners();
    print('Upload result: $result');
    prefs.remove('image_path');
    prefs.setString('image_path', result['image_path'] ?? '');
    print('Saved image path in prefs: ${prefs.getString('image_path')}');
    return result;
  }
}
