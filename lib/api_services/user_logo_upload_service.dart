import 'package:gps_tracker/config/imports.dart';

class UserLogoUploadService {
  static String baseUrl = dotenv.env['USER_LOGO_API_URL']!;
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> uploadUserLogo({
    required String userId,
    required String email,
    File? imageFile,
  }) async {
    try {
      Map<String, dynamic> formDataMap = {'user_id': userId, 'email': email};
      if (imageFile != null) {
        formDataMap['image'] = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        );
      }

      FormData formData = FormData.fromMap(formDataMap);

      Response response = await _dio.post(
        "$baseUrl/upload_user_logo.php",
        data: formData,
      );
      final responseData = response.data;

      if (response.statusCode == 201) {
        print('Upload successful: $responseData');
        return {
          'success': true,
          'message': responseData['message'] ?? 'logo uploaded!',
          'image_path': responseData['data']['image_path'] ?? '',
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'An error occurred.',
        };
      }
    } on DioException catch (e) {
      String errorMsg = 'Network communication failure';
      if (e.response != null && e.response?.data != null) {
        errorMsg = e.response?.data['error'] ?? errorMsg;
      } else {
        errorMsg = e.message ?? errorMsg;
      }
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      return {'success': false, 'message': 'An unexpected error occurred!'};
    }
  }
}
