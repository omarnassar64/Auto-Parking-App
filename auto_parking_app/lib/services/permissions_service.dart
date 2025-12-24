import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<bool> ensurePermissions(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Check Android SDK version to determine which permissions are needed
    // For Android 12+ (API 31+): BLUETOOTH_CONNECT and BLUETOOTH_SCAN
    // For Android 11 and below: BLUETOOTH, BLUETOOTH_ADMIN, and LOCATION
    
    final permissionsToRequest = <Permission>[];
    final permissionsToCheck = <Permission>[];
    
    // Always check bluetoothConnect and bluetoothScan (for Android 12+)
    permissionsToRequest.add(Permission.bluetoothConnect);
    permissionsToRequest.add(Permission.bluetoothScan);
    permissionsToCheck.add(Permission.bluetoothConnect);
    permissionsToCheck.add(Permission.bluetoothScan);
    
    // For older Android versions, also need location permission
    // Note: permission_handler handles SDK version internally
    permissionsToRequest.add(Permission.locationWhenInUse);
    permissionsToCheck.add(Permission.locationWhenInUse);
    
    // Also check legacy bluetooth permission for older devices
    permissionsToCheck.add(Permission.bluetooth);

    // Request permissions
    final statuses = await permissionsToRequest.request();
    
    // Re-check statuses after request to ensure accuracy
    final finalStatuses = <Permission, PermissionStatus>{};
    for (final permission in permissionsToRequest) {
      final currentStatus = statuses[permission] ?? await permission.status;
      finalStatuses[permission] = currentStatus;
      debugPrint("Permission ${permission.toString()}: ${currentStatus.toString()}");
    }
    
    // Check legacy bluetooth permission status separately
    try {
      final legacyBluetoothStatus = await Permission.bluetooth.status;
      finalStatuses[Permission.bluetooth] = legacyBluetoothStatus;
      debugPrint("Permission bluetooth (legacy): ${legacyBluetoothStatus.toString()}");
    } catch (e) {
      debugPrint("Legacy bluetooth permission not available: $e");
      // This is okay on newer Android versions
    }
    
    // Check each permission status properly
    final missingPermissions = <String>[];
    final permanentlyDeniedPermissions = <String>[];
    bool hasAllPermissions = true;
    
    // First, check if we have the new Android 12+ permissions
    final connectStatus = finalStatuses[Permission.bluetoothConnect] ?? 
                         await Permission.bluetoothConnect.status;
    final scanStatus = finalStatuses[Permission.bluetoothScan] ?? 
                      await Permission.bluetoothScan.status;
    
    final hasNewPermissions = connectStatus.isGranted && scanStatus.isGranted;
    
    // Check each permission
    for (final permission in permissionsToCheck) {
      final status = finalStatuses[permission] ?? await permission.status;
      
      // For bluetooth permission on newer Android, it might not be available
      // but that's okay if bluetoothConnect and bluetoothScan are granted
      if (permission == Permission.bluetooth) {
        if (hasNewPermissions) {
          continue; // Skip bluetooth permission check if newer permissions are granted
        }
      }
      
      // For location permission on Android 12+, it's not always required
      // if BLUETOOTH_SCAN has neverForLocation flag (which we set in manifest)
      if (permission == Permission.locationWhenInUse) {
        // If we have new permissions and location is denied, check if it's actually needed
        if (hasNewPermissions && !status.isGranted) {
          // On Android 12+ with neverForLocation flag, location might not be strictly required
          // But some devices still need it, so we'll still check it
          // However, we'll be more lenient - only require it if it's permanently denied
          if (!status.isPermanentlyDenied) {
            continue; // Allow if not permanently denied on Android 12+
          }
        }
      }
      
      if (!status.isGranted) {
        hasAllPermissions = false;
        String permissionName = permission.toString();
        if (permission == Permission.bluetoothConnect) {
          permissionName = "Bluetooth Connect";
        } else if (permission == Permission.bluetoothScan) {
          permissionName = "Bluetooth Scan";
        } else if (permission == Permission.locationWhenInUse) {
          permissionName = "Location";
        } else if (permission == Permission.bluetooth) {
          permissionName = "Bluetooth";
        }
        missingPermissions.add(permissionName);
        
        // Track permanently denied permissions
        if (status.isPermanentlyDenied) {
          permanentlyDeniedPermissions.add(permissionName);
        }
      }
    }
    
    // Show dialog for permanently denied permissions (only once)
    if (permanentlyDeniedPermissions.isNotEmpty) {
      await showPermissionSettingsDialog(context, permanentlyDeniedPermissions);
    }

    return hasAllPermissions;
  }

  static Future<void> showPermissionSettingsDialog(
    BuildContext context,
    List<String> missingPermissions,
  ) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permissions Required"),
          content: Text(
            "The following permissions are required but were denied:\n\n"
            "${missingPermissions.join('\n')}\n\n"
            "Please grant these permissions in app settings to continue.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Open Settings"),
            ),
          ],
        );
      },
    );
    
    if (shouldOpen == true) {
      await openAppSettings();
    }
  }
}