import 'package:gps_tracker/config/imports.dart';

class ShowRegisterDialogue {
  late TextEditingController nameController;
  late TextEditingController emailController;

  void showDialog() {
    nameController = TextEditingController();
    emailController = TextEditingController();

    showGeneralDialog(
      context: currentContext!,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        bool isLogin = false;
        return StatefulBuilder(
          builder: (context, dialogSetState) {
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
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: isLogin
                    ? _loginForm(
                        key: const ValueKey('login'),
                        onContinue: () async {
                          if (emailController.text.isNotEmpty) {
                            final provider = Provider.of<TrackingProvider>(
                              context,
                              listen: false,
                            );
                            await provider.saveUserData(
                              nameController.text,
                              email: emailController.text,
                              isLogin: true,
                            );
                            // ✅ Pop using root navigator
                            if (currentContext?.mounted ?? false) {
                              Navigator.of(
                                currentContext!,
                                rootNavigator: true,
                              ).pop();
                            }
                          }
                        },
                        onSwitch: () {
                          dialogSetState(() {
                            isLogin = false;
                          });
                        },
                      )
                    : _registerForm(
                        key: const ValueKey('register'),
                        onSave: () async {
                          if (emailController.text.isNotEmpty &&
                              nameController.text.isNotEmpty) {
                            final provider = Provider.of<TrackingProvider>(
                              context,
                              listen: false,
                            );
                            await provider.saveUserData(
                              nameController.text,
                              email: emailController.text,
                              isLogin: false,
                            );
                            // ✅ Pop using root navigator
                            if (currentContext?.mounted ?? false) {
                              Navigator.of(
                                currentContext!,
                                rootNavigator: true,
                              ).pop();
                            }
                          }
                        },
                        onSwitch: () {
                          dialogSetState(() {
                            isLogin = true;
                          });
                        },
                      ),
              ),
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      emailController.dispose();
    });
  }

  Widget _loginForm({
    required Key key,
    required VoidCallback onContinue,
    required VoidCallback onSwitch,
  }) {
    return AlertDialog(
      key: key,
      title: const Text("Login"),
      content: TextField(
        controller: emailController,
        decoration: const InputDecoration(hintText: "example@email.com"),
      ),
      actions: [
        TextButton(onPressed: onContinue, child: const Text("Continue")),
        TextButton(onPressed: onSwitch, child: const Text("Create Account")),
      ],
    );
  }

  Widget _registerForm({
    required Key key,
    required VoidCallback onSave,
    required VoidCallback onSwitch,
  }) {
    return AlertDialog(
      key: key,
      title: const Text("Create Account"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "John Doe"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(hintText: "example@email.com"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onSave, child: const Text("Save")),
        TextButton(onPressed: onSwitch, child: const Text("Login")),
      ],
    );
  }
}
