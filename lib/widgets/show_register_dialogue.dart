import 'package:gps_tracker/config/imports.dart';

class ShowRegisterDialogue {
  void showDialog() {
    showGeneralDialog(
      context: currentContext!,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _RegisterDialogContent();
      },
    );
  }
}

class _RegisterDialogContent extends StatefulWidget {
  const _RegisterDialogContent();

  @override
  State<_RegisterDialogContent> createState() => _RegisterDialogContentState();
}

class _RegisterDialogContentState extends State<_RegisterDialogContent> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLogin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _nameController.clear();
      _emailController.clear();
    });
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty) {
      _showError("Please enter your email");
      return;
    }
    if (!_isValidEmail(_emailController.text.trim())) {
      _showError("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<TrackingProvider>(context, listen: false);
      await provider.saveUserData(
        _nameController.text,
        email: _emailController.text.trim(),
        isLogin: true,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        _showError("Login failed: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty) {
      _showError("Please enter your name");
      return;
    }
    if (_nameController.text.trim().length < 5) {
      _showError("Name must be at least 5 characters");
      return;
    }
    if (_nameController.text.trim().length > 10) {
      _showError("Name must be less than 10 characters");
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError("Please enter your email");
      return;
    }
    if (!_isValidEmail(_emailController.text.trim())) {
      _showError("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<TrackingProvider>(context, listen: false);
      await provider.saveUserData(
        _nameController.text.trim(),
        email: _emailController.text.trim(),
        isLogin: false,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        _showError("Registration failed: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _showError(String message) {
    if (!mounted) return;
    ShowSnackbar().show(message: message);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.3, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
          );
        },
        child: _isLogin ? _buildLoginForm() : _buildRegisterForm(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return AlertDialog(
      key: const ValueKey('login'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Welcome Back! 👋",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "example@email.com",
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _toggleMode,
          child: const Text("Create Account"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("Continue"),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return AlertDialog(
      key: const ValueKey('register'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Create Account 🚀",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: "John Doe",
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "example@email.com",
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _toggleMode,
          child: const Text("Login Instead"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("Save"),
        ),
      ],
    );
  }
}
