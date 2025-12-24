import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/foundation.dart';
import 'permissions_service.dart';

class BluetoothService extends ChangeNotifier {
  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _errorMessage;
  BluetoothDevice? _selectedDevice;
  int? _batteryPercent;
  StreamSubscription<Uint8List>? _inputSubscription;
  int _lastBatteryUpdateMs = 0;
  
  // Fix for blocking issue
  bool _isSending = false;
  final _sendQueue = Queue<Uint8List>();
  final _receiveBuffer = StringBuffer();
  Completer<void> _connectionCompleter;

  BluetoothService() : _connectionCompleter = Completer<void>() {
    // Initialize the completer as completed initially
    _connectionCompleter.complete();
  }

  BluetoothConnection? get connection => _connection;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  int? get batteryPercent => _batteryPercent;

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _connection?.close();
    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.complete();
    }
    super.dispose();
  }

  void _updateState({
    bool? isConnected,
    bool? isConnecting,
    String? errorMessage,
    BluetoothDevice? selectedDevice,
    BluetoothConnection? connection,
    int? batteryPercent,
  }) {
    bool notify = false;
    if (isConnected != null && _isConnected != isConnected) {
      _isConnected = isConnected;
      notify = true;
    }
    if (isConnecting != null && _isConnecting != isConnecting) {
      _isConnecting = isConnecting;
      notify = true;
    }
    if (errorMessage != _errorMessage) {
      _errorMessage = errorMessage;
      notify = true;
    }
    if (selectedDevice != _selectedDevice) {
      _selectedDevice = selectedDevice;
      notify = true;
    }
    if (connection != _connection) {
      _connection = connection;
      notify = true;
    }
    if (batteryPercent != _batteryPercent) {
      _batteryPercent = batteryPercent;
      notify = true;
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> connectToDevice(
    BluetoothDevice device,
    BuildContext context,
    Function(String?) onError,
  ) async {
    if (_isConnecting || _isConnected) return;

    _updateState(isConnecting: true, errorMessage: null);
    onError(null);

    try {
      final hasPermissions = await PermissionsService.ensurePermissions(context);
      if (!hasPermissions) {
        _updateState(isConnecting: false);
        final errorMsg = "Bluetooth permissions are required. Please grant them in Settings.";
        _updateState(errorMessage: errorMsg);
        onError(errorMsg);
        return;
      }

      final bluetoothState = await FlutterBluetoothSerial.instance.state;
      if (bluetoothState != BluetoothState.STATE_ON) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      _connection = await BluetoothConnection.toAddress(device.address);
      _updateState(
        connection: _connection,
        selectedDevice: device,
        isConnected: true,
        isConnecting: false,
        errorMessage: null,
      );

      // Reset connection completer for this connection
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.complete();
      }
      _connectionCompleter = Completer<void>();
      _connectionCompleter.complete(); // Mark as ready for sending

      // Start listening for incoming data
      receiveData(onError);

      onError(null);
      debugPrint("Connected to ${device.name}");
    } catch (e) {
      debugPrint("Error connecting: $e");
      String errorMsg = e.toString();
      
      if (e.toString().toLowerCase().contains('permission') || 
          e.toString().toLowerCase().contains('denied') ||
          e.toString().toLowerCase().contains('security')) {
        errorMsg = "Bluetooth permissions are required. Please grant them in Settings.";
        final hasPermissions = await PermissionsService.ensurePermissions(context);
        if (!hasPermissions) {
          // Permissions dialog will be shown by ensurePermissions
        }
      }
      
      _updateState(
        isConnected: false,
        isConnecting: false,
        errorMessage: errorMsg,
      );
      onError(errorMsg);
    }
  }

  void handleConnectionLost(Function(String?) onError) {
    _inputSubscription?.cancel();
    _inputSubscription = null;
    _isSending = false;
    _sendQueue.clear();
    _receiveBuffer.clear();
    
    // Complete the connection completer if it's not already completed
    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.complete();
    }
    
    final errorMsg = "Connection lost. Please reconnect.";
    _updateState(
      isConnected: false,
      connection: null,
      selectedDevice: null,
      errorMessage: errorMsg,
    );
    onError(errorMsg);
  }

  Future<void> disconnect(Function(String?) onError) async {
    try {
      _inputSubscription?.cancel();
      _inputSubscription = null;
      _isSending = false;
      _sendQueue.clear();
      _receiveBuffer.clear();
      
      // Complete the connection completer
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.complete();
      }
      
      await _connection?.close();
      _updateState(
        isConnected: false,
        connection: null,
        selectedDevice: null,
        errorMessage: null,
      );
      onError(null);
    } catch (e) {
      debugPrint("Error disconnecting: $e");
    }
  }

  Future<void> sendData(String data) async {
    if (!_isConnected || _connection == null) return;
    
    try {
      final dataBytes = Uint8List.fromList(data.codeUnits);
      
      // Wait for any ongoing send operations to complete
      await _connectionCompleter.future;
      
      // Create a new completer for the next send operation
      _connectionCompleter = Completer<void>();
      
      // Send the data
      _connection!.output.add(dataBytes);
      await _connection!.output.allSent;
      
      // Add a small delay to prevent overwhelming the connection
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Complete the current send operation
      _connectionCompleter.complete();
      
      debugPrint("Sent: $data");
    } catch (e) {
      debugPrint("Error sending data: $e");
      handleConnectionLost((error) {});
    }
  }

  void receiveData(Function(String?) onError) {
    if (!_isConnected || _connection == null) return;

    // Cancel any existing subscription
    _inputSubscription?.cancel();

    try {
      _inputSubscription = _connection!.input!.listen(
        (Uint8List data) {
          // Process data asynchronously to avoid blocking
          _processIncomingDataAsync(data).catchError((error) {
            debugPrint("Error processing incoming data: $error");
          });
        },
        onDone: () {
          debugPrint("Bluetooth input stream closed");
          handleConnectionLost(onError);
        },
        onError: (error) {
          debugPrint("Bluetooth input stream error: $error");
          handleConnectionLost(onError);
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("Error receiving data: $e");
      handleConnectionLost(onError);
    }
  }

  Future<void> _processIncomingDataAsync(Uint8List data) async {
    try {
      // Add data to buffer
      final message = String.fromCharCodes(data);
      _receiveBuffer.write(message);
      
      // Check if we have a complete message (adjust delimiter as needed)
      final bufferString = _receiveBuffer.toString();
      if (bufferString.contains('\n') || bufferString.contains('\r')) {
        // Process complete messages
        final lines = bufferString.split(RegExp(r'[\r\n]+'));
        
        // Keep incomplete last line in buffer
        _receiveBuffer.clear();
        if (!bufferString.endsWith('\n') && !bufferString.endsWith('\r')) {
          _receiveBuffer.write(lines.last);
        }
        
        // Process complete lines
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            await _processMessage(line);
          }
        }
      }
    } catch (e) {
      debugPrint("Error in async data processing: $e");
      // Clear buffer on error to prevent corruption
      _receiveBuffer.clear();
    }
  }

  Future<void> _processMessage(String message) async {
    debugPrint("Processing message: $message");
    
    // Parse battery percentage with throttling
    final int? parsedBattery = int.tryParse(message);
    if (parsedBattery != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const throttleMs = 60 * 1000; // 1 minute
      if (nowMs - _lastBatteryUpdateMs >= throttleMs) {
        _lastBatteryUpdateMs = nowMs;
        debugPrint("Battery Percent: $parsedBattery%");
        // Update on main thread
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateState(batteryPercent: parsedBattery);
        });
      } else {
        debugPrint("Battery update skipped (throttled)");
      }
    } else {
      debugPrint("Non-numeric data received: $message");
      // Handle other message types here if needed
    }
  }

  // Alternative: Send data using queue system
  Future<void> sendWithQueue(String data) async {
    if (!_isConnected || _connection == null) return;
    
    final dataBytes = Uint8List.fromList(data.codeUnits);
    _sendQueue.add(dataBytes);
    await _processSendQueue();
  }

  Future<void> _processSendQueue() async {
    if (_isSending || _sendQueue.isEmpty || !_isConnected || _connection == null) return;
    
    _isSending = true;
    try {
      while (_sendQueue.isNotEmpty && _isConnected) {
        final data = _sendQueue.removeFirst();
        _connection!.output.add(data);
        await _connection!.output.allSent;
        await Future.delayed(const Duration(milliseconds: 10)); // Small delay between sends
      }
    } catch (e) {
      debugPrint("Error in send queue processing: $e");
      handleConnectionLost((error) {});
    } finally {
      _isSending = false;
    }
  }

  Future<void> showDeviceSelectionDialog(
    BuildContext context,
    Function(String?) onError,
  ) async {
    try {
      final hasPermissions = await PermissionsService.ensurePermissions(context);
      if (!hasPermissions) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bluetooth permissions are required"),
            backgroundColor: Colors.red,  
          ),
        );
        return;
      }

      final bluetoothState = await FlutterBluetoothSerial.instance.state;
      if (bluetoothState != BluetoothState.STATE_ON) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      List<BluetoothDevice> bondedDevices;
      try {
        bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      } catch (e) {
        debugPrint("Error getting bonded devices: $e");
        if (e.toString().toLowerCase().contains('permission') || 
            e.toString().toLowerCase().contains('denied')) {
          final hasPermissions = await PermissionsService.ensurePermissions(context);
          if (!hasPermissions) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Bluetooth permissions are required. Please grant them in Settings."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error accessing Bluetooth: $e"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (bondedDevices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No paired devices found. Please pair a device first."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Select Device"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bondedDevices.length,
                itemBuilder: (context, index) {
                  final device = bondedDevices[index];
                  final isCurrentDevice = _selectedDevice?.address == device.address;
                  return ListTile(
                    leading: Icon(
                      isCurrentDevice && _isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      color: isCurrentDevice && _isConnected
                          ? Colors.green
                          : Colors.grey,
                    ),
                    title: Text(device.name ?? "Unknown Device"),
                    subtitle: Text(device.address.toString()),
                    trailing: isCurrentDevice && _isConnected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (!isCurrentDevice || !_isConnected) {
                        connectToDevice(device, context, onError);
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("Error showing device dialog: $e");
      String errorMessage = "Error: $e";
      
      if (e.toString().toLowerCase().contains('permission') || 
          e.toString().toLowerCase().contains('denied') ||
          e.toString().toLowerCase().contains('security')) {
        errorMessage = "Bluetooth permissions are required. Please grant them in Settings.";
        await PermissionsService.ensurePermissions(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}