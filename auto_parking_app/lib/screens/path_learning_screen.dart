import 'package:flutter/material.dart';

class PathLearningScreen extends StatelessWidget {
  final bool isConnected;
  final Function(String) sendData;
  final int? batteryPercent;

  const PathLearningScreen({
    super.key,
    required this.isConnected,
    required this.sendData,
    this.batteryPercent,
  });

  @override
  Widget build(BuildContext context) {
    final battery = batteryPercent ?? 0;

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
              const SizedBox(width: 15),
              const Text(
                "Battery Level",
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 30),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected && battery >= 80
                      ? Colors.blueAccent
                      : isConnected && battery >= 30 && battery < 80
                          ? Colors.green
                          : isConnected && battery >= 0 && battery < 30
                              ? Colors.red
                              : Colors.grey[700],
                ),
                child: Center(
                  child: Text(
                    "$battery%",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 165),
        
          

            GestureDetector(
            onTap: isConnected
                ? () {
                    sendData("b");
                  }
                : null,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(13),
                color: isConnected ? Colors.lightBlueAccent : Colors.grey[700]!,
              ),
              child: Center(
                child: Text(
                  "Start Learning",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20,),
          GestureDetector(
            onTap: isConnected
                ? () {
                    sendData("u");
                  }
                : null,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(13),
                color: isConnected ? Colors.lightBlueAccent : Colors.grey[700]!,
              ),
              child: Center(
                child: Text(
                  "Stop Learning",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          
               
           SizedBox(height: 20),

           GestureDetector(
            onTap: isConnected
                ? () {
                    sendData("j");
                  }
                : null,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(13),
                color: isConnected ? Colors.lightBlueAccent : Colors.grey[700]!,
              ),
              child: Center(
                child: Text(
                  "Play",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}