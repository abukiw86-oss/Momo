import 'config/imports.dart';

import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSplashSequence();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  Future<void> _startSplashSequence() async {
    await Future.wait([
      _controller.forward(),
      _preloadAppData(),
      Future.delayed(const Duration(seconds: 4)),
    ]);

    if (mounted) {
      _navigateToNext();
    }
  }

  Future<void> _preloadAppData() async {
    // await Future.wait([
    //   _loadUserProfile(),
    //   _loadFriendsList(),
    //   _loadMapSettings(),
    //   _loadCachedLocations(),
    // ]);
  }
  void _navigateToNext() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const FreeTrackerMap()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMapWithFriends(size),
                      const SizedBox(height: 40),

                      const Text(
                        'Momo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tagline
                      Text(
                        'Connect. Track. Meet.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 60),

                      _buildLoadingIndicator(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMapWithFriends(Size screenSize) {
    final containerSize = screenSize.width * 0.6;
    final maxSize = containerSize > 300 ? 300.0 : containerSize;

    return Container(
      width: maxSize,
      height: maxSize * 0.8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                CustomPaint(painter: MapGridPainter(), size: Size.infinite),

                _buildPulsingMarker(
                  position: const Alignment(-0.4, -0.2),
                  color: const Color(0xFFFF6D00),
                  label: 'You',
                ),
                _buildPulsingMarker(
                  position: const Alignment(0.3, 0.1),
                  color: const Color(0xFF00E5FF),
                  label: 'Alex',
                ),

                _buildPulsingMarker(
                  position: const Alignment(-0.1, 0.4),
                  color: const Color(0xFF76FF03),
                  label: 'Sarah',
                ),

                ..._buildConnectionLines(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingMarker({
    required Alignment position,
    required Color color,
    required String label,
  }) {
    return Align(
      alignment: position,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildConnectionLines() {
    return [
      Positioned.fill(child: CustomPaint(painter: ConnectionLinesPainter())),
    ];
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Connecting friends...',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
      ],
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    for (double i = 0; i <= size.width; i += size.width / 6) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i <= size.height; i += size.height / 6) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ConnectionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final you = Offset(size.width * 0.3, size.height * 0.4);
    final alex = Offset(size.width * 0.65, size.height * 0.55);
    final sarah = Offset(size.width * 0.45, size.height * 0.7);

    _drawDashedLine(canvas, you, alex, paint);
    _drawDashedLine(canvas, you, sarah, paint);
    _drawDashedLine(canvas, alex, sarah, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final distance = (end - start).distance;
    final direction = (end - start) / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final startPoint = start + direction * currentDistance;
      final endPoint =
          start + direction * (currentDistance + dashWidth).clamp(0, distance);
      canvas.drawLine(startPoint, endPoint, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
