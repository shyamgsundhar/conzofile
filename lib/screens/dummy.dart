import 'package:flutter/material.dart';
import 'dart:math';

class BlueWaveScreen extends StatefulWidget {
  @override
  _BlueWaveScreenState createState() => _BlueWaveScreenState();
}

class _BlueWaveScreenState extends State<BlueWaveScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  double _scrollOffset = 0;
  double _idleWaveOffset = 0; // To control idle wave movement

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Start idle animation for waves
    _startIdleWaveAnimation();
  }

  // This method moves the wave even when idle
  void _startIdleWaveAnimation() {
    Future.delayed(Duration(milliseconds: 100), () {
      // Increased delay to slow down the movement
      setState(() {
        _idleWaveOffset += 0.02; // Slow incremental movement
      });
      _startIdleWaveAnimation(); // Repeat animation
    });
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top static wave, doesn't move on scroll
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: WavyBackgroundPainter(
                _scrollOffset,
                _idleWaveOffset,
                isTopWave: true,
              ),
              size: Size(MediaQuery.of(context).size.width,
                  150), // Increased height for top wave
            ),
          ),

          // Scrollable Content with bottom wave
          SingleChildScrollView(
            controller: _scrollController,
            physics: BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: 150), // Give space for the top wave
                Text(
                  "Battery Status",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "49.3% SOC",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 50),

                // Battery Info Box
                Center(
                  child: Container(
                    width: 320,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Voltage: 47.0V",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Remaining Capacity: 14.7Ah",
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),

                // More dummy content to demonstrate scrolling
                SizedBox(height: 50),
                _infoBox("Current: 12.5A"),
                SizedBox(height: 20),
                _infoBox("Temperature: 25°C"),
                SizedBox(height: 20),
                _infoBox("Battery Health: Good"),
                SizedBox(height: 200), // Extra space for scrolling
              ],
            ),
          ),

          // Bottom wave, it moves with scroll
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: WavyBackgroundPainter(
                _scrollOffset,
                _idleWaveOffset,
                isTopWave: false,
              ),
              size: Size(
                  MediaQuery.of(context).size.width, 150), // Bottom wave height
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Center(
      child: Container(
        width: 320,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class WavyBackgroundPainter extends CustomPainter {
  final double scrollOffset;
  final double idleWaveOffset;
  final bool isTopWave;

  WavyBackgroundPainter(this.scrollOffset, this.idleWaveOffset,
      {required this.isTopWave});

  @override
  void paint(Canvas canvas, Size size) {
    // Different wave behavior for top and bottom waves
    if (isTopWave) {
      _drawTopWave(canvas, size);
    } else {
      _drawBottomWave(canvas, size);
    }
  }

  // Top wave with enhanced structure and idle movement
  void _drawTopWave(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.blue.withOpacity(0.2); // Low opacity for top wave
    Path path = Path();

    double waveHeight = 50.0; // Enhanced height for top wave
    double waveWidth =
        size.width / 1.2; // Slightly increased width for smoother flow
    double yOffset = 0;

    path.moveTo(0, yOffset);
    for (double i = 0; i <= size.width; i += 10) {
      path.lineTo(
        i,
        sin((i / waveWidth) * 2 * pi + (scrollOffset * 0.02) + idleWaveOffset) *
                waveHeight +
            40,
      );
    }
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  // Bottom wave with enhanced structure and idle movement
  void _drawBottomWave(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.blue.withOpacity(0.3); // Higher opacity for bottom wave
    Path path = Path();

    double waveHeight = 30.0; // Bottom wave height is a little smaller
    double waveWidth = size.width / 1.2;
    double yOffset = size.height;

    path.moveTo(0, yOffset);
    for (double i = 0; i <= size.width; i += 10) {
      path.lineTo(
        i,
        yOffset +
            sin((i / waveWidth) * 2 * pi +
                    (scrollOffset * 0.05) +
                    idleWaveOffset) *
                waveHeight,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavyBackgroundPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.idleWaveOffset != idleWaveOffset;
  }
}
