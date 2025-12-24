import 'dart:async';
import 'package:flutter/material.dart';

class ManualModeScreen extends StatefulWidget {
  final bool isConnected;
  final Function(String) sendData;
  final String? errorMessage;
  final int? batteryPercent;

  const ManualModeScreen({
    super.key,
    required this.isConnected,
    required this.sendData,
    this.errorMessage,
    this.batteryPercent,
  });

  @override
  State<ManualModeScreen> createState() => _ManualModeScreenState();
}

class _ManualModeScreenState extends State<ManualModeScreen> {
  double sliderValue = 5;

  @override
  Widget build(BuildContext context) {
    final battery = widget.batteryPercent ?? 0 ;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Battery circle directly under app bar
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox( width: 15,),
              Text("Battery Level" , style: TextStyle(
                fontSize: 30,
                color: Colors.white
              ),),
              SizedBox( width: 30,),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isConnected && battery >= 80
                      ? Colors.blueAccent
                      : widget.isConnected && battery >= 30 && battery < 80
                          ? Colors.green
                          : widget.isConnected && battery>= 0  && battery < 30
                              ? Colors.red
                              : Colors.grey[700],
                ),
                child: Center(
                  child: Text(
                    "$battery%",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 25
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 200),
            Text(
              widget.isConnected ? "Connected" : "Not Connected",
              style: TextStyle(
                color: widget.isConnected ? Colors.greenAccent : Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 40),
            // Circular button layout
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center circle (optional decoration)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                      border: Border.all(color: Colors.grey[700]!, width: 2),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.isConnected
                        ? () {
                            widget.sendData("x");
                          }
                        : null,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isConnected ? Colors.red[400]! : Colors.grey[700]!,
                      ),
                      child: Center(
                        child: Text(
                          "Stop",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                
                  // Top button (Up)
                  Positioned(
                    top: 10,
                    child: _buildCircularButton("↑", "w"),
                  ),
                  // Right button (Right)
                  Positioned(
                    right: 10,
                    child: _buildCircularButton("→", "d"),
                  ),
                  // Bottom button (Down)
                  Positioned(
                    bottom: 10,
                    child: _buildCircularButton("↓", "s"),
                  ),
                  // Left button (Left)
                  Positioned(
                    left: 10,
                    child: _buildCircularButton("←", "a"),
                  ),
                ],
                ),  
            ),
            const SizedBox(height: 40),
            // Gear Slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    "Gear: ${sliderValue.toInt()}",
                    style: const TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: sliderValue,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    activeColor: Colors.greenAccent,
                    inactiveColor: Colors.grey,
                    label: "Gear ${sliderValue.toInt()}",
                    onChanged: widget.isConnected
                        ? (value) {
                            setState(() {
                              sliderValue = value;
                            });
                            widget.sendData(value.toInt().toString());
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildCircularButton(String arrow, String sendChar) {
    Timer? repeatTimer;

    return GestureDetector(
      onTapDown: widget.isConnected
          ? (_) {
              widget.sendData(sendChar);
              repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
                widget.sendData(sendChar);
              });
            }
          : null,
      onTapUp: (_) => repeatTimer?.cancel(),
      onTapCancel: () => repeatTimer?.cancel(),
      child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: widget.isConnected
                ? const LinearGradient(
                    colors: [Colors.tealAccent, Colors.greenAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey[700]!, Colors.grey[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            shape: BoxShape.circle,
            boxShadow: widget.isConnected
                ? const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(3, 3),
                      blurRadius: 5,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              arrow,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: widget.isConnected ? Colors.black : Colors.grey[400],
              ),
            ),
          ),
        ),
    );
  }
}

