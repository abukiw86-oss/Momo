import 'package:gps_tracker/providers/providers.dart';

import '/config/imports.dart';

class ChangeLogoScreen extends StatefulWidget {
  const ChangeLogoScreen({super.key});

  @override
  State<ChangeLogoScreen> createState() => _ChangeLogoScreenState();
}

class _ChangeLogoScreenState extends State<ChangeLogoScreen> {
  final ImagePicker _picker = ImagePicker();
  LogoUploadProvider imageUploadProvider = LogoUploadProvider();
  File? _selectedImage;

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to select image: $e')));
      }
    }
  }

  Future<void> _submitForm() async {
    final result = await imageUploadProvider.uploadUserLogo(
      imageFile: _selectedImage,
    );

    if (mounted) {
      ShowSnackbar().show(
        message: result['message'] ?? 'Unknown response from server',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Logo')),
      body: imageUploadProvider.isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : null,
                        child: _selectedImage == null
                            ? const Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Tap circle to select custom logo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('update Logo'),
                  ),
                ],
              ),
            ),
    );
  }
}
