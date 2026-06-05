import 'package:flutter/material.dart';

class RootDetectionScreen extends StatefulWidget {
  const RootDetectionScreen({super.key});

  @override
  State<RootDetectionScreen> createState() => _RootDetectionScreenState();
}

class _RootDetectionScreenState extends State<RootDetectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A0000),
              const Color(0xFF4A0000),
              const Color(0xFF7F0000),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: _buildStatusIcon(size),
                    );
                  },
                ),

                SizedBox(height: size.height * 0.04),

                // Status Title
                Text(
                  'Warning!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.08,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                SizedBox(height: size.height * 0.02),

                // Status Message
                Text(
                  'Your device is compromised',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: size.width * 0.045,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: size.height * 0.06),

                // Details Card
                _buildDetailsCard(size),

                SizedBox(height: size.height * 0.04),

                // Action Button
                _buildActionButton(size),

                SizedBox(height: size.height * 0.02),

                // Bottom Text
                Text(
                  'For security reasons, some features may be limited',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: size.width * 0.03,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Size size) {
    final iconSize = size.width * 0.3;

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.withOpacity(0.2),
        border: Border.all(color: Colors.red, width: 3),
        boxShadow: [
          BoxShadow(color: (Colors.red), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Icon(
        Icons.warning_rounded,
        size: iconSize * 0.5,
        color: Colors.red,
      ),
    );
  }

  Widget _buildDetailsCard(Size size) {
    return Container(
      width: size.width * 0.85,
      padding: EdgeInsets.all(size.width * 0.05),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.android,
            label: 'Root Access',
            status: 'Detected',
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 30),
          _buildDetailRow(
            icon: Icons.apple,
            label: 'Jailbreak',
            status: 'Detected',
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 30),
          _buildDetailRow(
            icon: Icons.security,
            label: 'Security Risk',
            status: 'High',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String status,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: Colors.red[300],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(Size size) {
    return GestureDetector(
      onTap: () {
        _showWarningDialog();
      },
      child: Container(
        width: size.width * 0.7,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:  [Colors.orange, Colors.red] ,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (  Colors.red ).withOpacity(
                0.3,
              ),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Learn More',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _showWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Security Warning', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Your device appears to be rooted or jailbroken. This can compromise the security of your location data and private information.\n\n'
          'Do you still want to continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Exit App', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
