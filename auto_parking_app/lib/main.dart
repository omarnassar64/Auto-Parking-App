import 'package:flutter/material.dart';
import 'package:parking_modes/screens/path_learning_screen.dart';
import 'services/bluetooth_service.dart';
import 'screens/manual_mode_screen.dart';
import 'screens/automatic_mode_screen.dart';
import 'screens/auto_parking_mode_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

// Main screen and bottom navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final BluetoothService _bluetoothService = BluetoothService();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bluetoothService.addListener(_onBluetoothStateChanged);
  }

  @override
  void dispose() {
    _bluetoothService.removeListener(_onBluetoothStateChanged);
    _bluetoothService.dispose();
    super.dispose();
  }

  void _onBluetoothStateChanged() {
    if (mounted) {
      setState(() {
        _errorMessage = _bluetoothService.errorMessage;
      });
    }
  }

  void _updateError(String? error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
      });
    }
  }

  Future<void> _showDeviceSelectionDialog() async {
    await _bluetoothService.showDeviceSelectionDialog(context, _updateError);
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: ClipPath(
        clipper: CustomAppBarClipper(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      _selectedIndex == 0 ? "Manual Control" : _selectedIndex == 1 ? "Autonumous Mode" : _selectedIndex == 2 ? "Auto-Parking Mode" : "Path-Learning Mode",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.bluetooth_searching,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _showDeviceSelectionDialog,
                      tooltip: "Select Device",
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _bluetoothService.isConnected,
                      onChanged: _bluetoothService.isConnecting
                          ? null
                          : (value) {
                              if (value) {
                                if (_bluetoothService.selectedDevice != null) {
                                  _bluetoothService.connectToDevice(
                                    _bluetoothService.selectedDevice!,
                                    context,
                                    _updateError,
                                  );
                                } else {
                                  _showDeviceSelectionDialog();
                                }
                              } else {
                                _bluetoothService.disconnect(_updateError);
                              }
                            },
                      activeColor: Colors.greenAccent,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ManualModeScreen(
        isConnected: _bluetoothService.isConnected,
        sendData: (data) => _bluetoothService.sendData(data),
        errorMessage: _errorMessage,
        batteryPercent: _bluetoothService.batteryPercent,
      ),
      AutomaticModeScreen(
        isConnected: _bluetoothService.isConnected,
        sendData: (data) => _bluetoothService.sendData(data),
        batteryPercent: _bluetoothService.batteryPercent,
      ),
      AutoParkingModeScreen(
        isConnected: _bluetoothService.isConnected,
        sendData: (data) => _bluetoothService.sendData(data),
        batteryPercent: _bluetoothService.batteryPercent,
      ),
      PathLearningScreen(
        isConnected: _bluetoothService.isConnected,
        sendData: (data) => _bluetoothService.sendData(data),
        batteryPercent: _bluetoothService.batteryPercent,
      )
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: "Manual",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.autorenew),
            label: "Autonumous",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: "Parking",
          ),
          
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: "Learning",
          ),
        ],
      ),
    );
  }
}

class CustomAppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
