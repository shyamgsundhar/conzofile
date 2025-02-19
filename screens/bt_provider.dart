import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:async';

// class BluetoothProvider with ChangeNotifier, WidgetsBindingObserver {
//   final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
//   BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
//   List<BluetoothDevice> _pairedDevices = [];
//   List<BluetoothDevice> _availableDevices = [];
//   BluetoothDevice? _selectedDevice;
//   BluetoothConnection? _connection;
//   bool _isDiscovering = false;
//   bool _isLoading = false;
//   BluetoothDevice? _connectingDevice;
//   StreamSubscription<BluetoothState>? _stateSubscription;
//   BuildContext? _context;
//   Function(String)? onDataReceived;
//   bool _isDialogShown = false;

//   BluetoothState get bluetoothState => _bluetoothState;
//   List<BluetoothDevice> get pairedDevices => _pairedDevices;
//   List<BluetoothDevice> get availableDevices => _availableDevices;
//   BluetoothDevice? get selectedDevice => _selectedDevice;
//   bool get isDiscovering => _isDiscovering;
//   bool get isConnected => _connection != null && _connection!.isConnected;
//   bool get isLoading => _isLoading;
//   BluetoothDevice? get connectingDevice => _connectingDevice;

//   BluetoothProvider() {
//     _initBluetooth();
//     WidgetsBinding.instance.addObserver(this);
//   }

//   set context(BuildContext context) {
//     _context = context;
//   }

//   @override
//   void dispose() {
//     _stateSubscription?.cancel();
//     disconnectFromDevice();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) async {
//     if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
//       if (_isDiscovering) await _bluetooth.cancelDiscovery();
//       disconnectFromDevice();
//     } else if (state == AppLifecycleState.resumed) {
//       await _initBluetooth();

//       if (!isConnected && _selectedDevice == null) {
//         Future.delayed(Duration(milliseconds: 500), _showConnectionReminderDialog);
//       }
//     }
//   }

//   Future<void> _initBluetooth() async {
//     _stateSubscription?.cancel();
//     _bluetoothState = await _bluetooth.state;
//     notifyListeners();

//     if (_bluetoothState == BluetoothState.STATE_ON) {
//       await _getPairedDevices();
//     }

//     _stateSubscription = _bluetooth.onStateChanged().listen((state) {
//       _bluetoothState = state;
//       notifyListeners();

//       if (state == BluetoothState.STATE_ON) {
//         _getPairedDevices();
//       } else {
//         _clearDevices();
//       }
//     });

//     await refreshConnectionStatus();

//     if (!isConnected && _selectedDevice == null) {
//       Future.delayed(Duration(milliseconds: 500), _showConnectionReminderDialog);
//     }
//   }

//   Future<void> _getPairedDevices() async {
//     try {
//       _pairedDevices = await _bluetooth.getBondedDevices();
//       _startDiscovery();
//       notifyListeners();
//     } catch (e) {
//       _showErrorDialog('Error fetching paired devices: $e');
//     }
//   }

//   void _startDiscovery() async {
//     if (_isDiscovering) return;
//     _isDiscovering = true;
//     _availableDevices.clear();

//     try {
//       await for (var result in _bluetooth.startDiscovery()) {
//         if (!_pairedDevices.any((d) => d.address == result.device.address) &&
//             !_availableDevices.any((d) => d.address == result.device.address)) {
//           _availableDevices.add(result.device);
//           notifyListeners();
//         }
//       }
//     } catch (e) {
//       _showErrorDialog('Error during discovery: $e');
//     } finally {
//       _isDiscovering = false;
//       notifyListeners();
//     }
//   }

//   void _clearDevices() {
//     _availableDevices.clear();
//     _pairedDevices.clear();
//     _selectedDevice = null;

//     SharedPreferences.getInstance().then((prefs) {
//       prefs.remove('lastConnectedDevice');
//     });

//     notifyListeners();
//   }

//   Future<void> connectToDevice(BluetoothDevice device) async {
//     setLoading(true, device);
//     try {
//       _connection = await BluetoothConnection.toAddress(device.address);
//       _selectedDevice = device;
//       listenForIncomingData();

//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString('lastConnectedDevice', device.address);

//       notifyListeners();
//     } catch (e) {
//       _showErrorDialog('Could not connect to device: $e');
//     } finally {
//       setLoading(false);
//     }
//   }

//   Future<void> disconnectFromDevice() async {
//     if (_connection != null) {
//       try {
//         setLoading(true);
//         await _connection!.close();
//       } catch (e) {
//         _showErrorDialog('Error while disconnecting: $e');
//       } finally {
//         _connection = null;
//         _selectedDevice = null;
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//         await prefs.remove('lastConnectedDevice');
//         setLoading(false);
//         notifyListeners();
//       }
//     }
//   }

//   Future<void> refreshConnectionStatus() async {
//     if (_connection != null && _connection!.isConnected) return;

//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? lastConnectedDeviceAddress = prefs.getString('lastConnectedDevice');

//     if (lastConnectedDeviceAddress != null) {
//       try {
//         for (var device in await _bluetooth.getBondedDevices()) {
//           if (device.address == lastConnectedDeviceAddress) {
//             _selectedDevice = device;
//             break;
//           }
//         }

//         if (_selectedDevice != null) {
//           await connectToDevice(_selectedDevice!);
//         }
//       } catch (e) {
//         _showErrorDialog('Error restoring Bluetooth connection: $e');
//         _selectedDevice = null;
//       }
//     } else {
//       _selectedDevice = null;
//     }

//     notifyListeners();
//   }

//   void setLoading(bool value, [BluetoothDevice? device]) {
//     if (_isLoading == value && _connectingDevice == device) return;

//     _isLoading = value;
//     _connectingDevice = device;
//     notifyListeners();

//     if (!value) {
//       _connectingDevice = null;
//     }
//   }

//   Future<void> sendData(String hexString) async {
//     if (_connection != null && _connection!.isConnected) {
//       List<int> bytes = hexStringToBytes(hexString);
//       _connection!.output.add(Uint8List.fromList(bytes));
//       await _connection!.output.allSent;
//       debugPrint('Data sent: $hexString');
//     } else {
//       _showErrorDialog('No active Bluetooth connection');
//     }
//   }

//   void listenForIncomingData() {
//     _connection?.input?.listen((Uint8List data) {
//       String receivedData = bytesToHex(data);
//       debugPrint('Received data: $receivedData');

//       if (validateChecksum(receivedData)) {
//         onDataReceived?.call(receivedData);
//       } else {
//         loopRequestUntilVerified();
//       }
//     }).onDone(() {
//       debugPrint("Disconnected by remote device");
//       disconnectFromDevice();
//     });
//   }

//   Future<void> loopRequestUntilVerified() async {
//     int retries = 0;
//     const maxRetries = 10;
//     while (retries < maxRetries) {
//       await Future.delayed(Duration(seconds: 2));
//       if (_connection != null && _connection!.isConnected) {
//         _connection?.output.add(Uint8List.fromList([0xA0]));
//       } else {
//         break;
//       }
//       retries++;
//     }
//   }

//   List<int> hexStringToBytes(String hex) {
//     hex = hex.replaceAll('0x', '');
//     List<int> bytes = [];
//     for (int i = 0; i < hex.length; i += 2) {
//       bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
//     }
//     return bytes;
//   }

//   String bytesToHex(Uint8List data) {
//     return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
//   }

//   bool validateChecksum(String hexData) {
//     List<int> bytes = hexStringToBytes(hexData);
//     if (bytes.length < 2) return false;

//     int checksum = bytes.last;
//     int xorValue = bytes[0];
//     for (int i = 1; i < bytes.length - 1; i++) {
//       xorValue ^= bytes[i];
//     }
//     return xorValue == checksum;
//   }

//   void toggleBluetooth() async {
//     try {
//       if (_bluetoothState == BluetoothState.STATE_OFF) {
//         await _bluetooth.requestEnable();
//       } else if (_bluetoothState == BluetoothState.STATE_ON) {
//         await _bluetooth.requestDisable();
//       }
//       notifyListeners();
//     } catch (e) {
//       _showErrorDialog('Failed to toggle Bluetooth: $e');
//     }
//   }

//   void _showConnectionReminderDialog() {
//     if (_context == null || _isDialogShown) return;
//     _isDialogShown = true;

//     showDialog(
//       context: _context!,
//       builder: (context) => AlertDialog(
//         title: Text('No Device Connected'),
//         content: Text('It seems no Bluetooth device is connected. Would you like to connect now?'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               _isDialogShown = false;
//               Navigator.pop(context);
//             },
//             child: Text('Dismiss'),
//           ),
//           TextButton(
//             onPressed: () {
//               _isDialogShown = false;
//               Navigator.pop(context);
//               _startDiscovery();
//             },
//             child: Text('Discover Devices'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showErrorDialog(String message) {
//     if (_context == null || _isDialogShown) return;

//     _isDialogShown = true;
//     showDialog(
//       context: _context!,
//       builder: (context) => AlertDialog(
//         title: Text('Error'),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () {
//               _isDialogShown = false;
//               Navigator.pop(context);
//             },
//             child: Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }
// }

class BluetoothProvider with ChangeNotifier, WidgetsBindingObserver {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDevice> _availableDevices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;
  bool _isDiscovering = false;
  bool _isLoading = false;
  BluetoothDevice? _connectingDevice;
  StreamSubscription<BluetoothState>? _stateSubscription;
  BuildContext? _context;
  Function(String)? onDataReceived;
  bool _isDialogShown = false;

  BluetoothState get bluetoothState => _bluetoothState;
  List<BluetoothDevice> get pairedDevices => _pairedDevices;
  List<BluetoothDevice> get availableDevices => _availableDevices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isDiscovering => _isDiscovering;
  bool get isConnected => _connection != null && _connection!.isConnected;
  bool get isLoading => _isLoading;
  BluetoothDevice? get connectingDevice => _connectingDevice;

  BluetoothProvider() {
    _initBluetooth();
    WidgetsBinding.instance.addObserver(this);
  }

  set context(BuildContext context) {
    _context = context;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    disconnectFromDevice();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_isDiscovering) await _bluetooth.cancelDiscovery();
      disconnectFromDevice();
    } else if (state == AppLifecycleState.resumed) {
      await _initBluetooth();

      if (!isConnected && _selectedDevice == null) {
        Future.delayed(
            Duration(milliseconds: 500), _showConnectionReminderDialog);
      }
    }
  }

  Future<void> _initBluetooth() async {
    try {
      _stateSubscription?.cancel();
      _bluetoothState = await _bluetooth.state;
      notifyListeners();

      if (_bluetoothState == BluetoothState.STATE_ON) {
        await _getPairedDevices();
      }

      _stateSubscription = _bluetooth.onStateChanged().listen((state) {
        _bluetoothState = state;
        notifyListeners();

        if (state == BluetoothState.STATE_ON) {
          _getPairedDevices();
        } else {
          _clearDevices();
        }
      });

      await refreshConnectionStatus();

      if (!isConnected && _selectedDevice == null) {
        Future.delayed(
            Duration(milliseconds: 500), _showConnectionReminderDialog);
      }
    } catch (e) {
      _showErrorDialog('Error initializing Bluetooth: $e');
    }
  }

  Future<void> _getPairedDevices() async {
    try {
      _pairedDevices = await _bluetooth.getBondedDevices();
      _startDiscovery();
      notifyListeners();
    } catch (e) {
      _showErrorDialog('Error fetching paired devices: $e');
    }
  }

  void _startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _availableDevices.clear();

    try {
      await for (var result in _bluetooth.startDiscovery()) {
        if (!_pairedDevices.any((d) => d.address == result.device.address) &&
            !_availableDevices.any((d) => d.address == result.device.address)) {
          _availableDevices.add(result.device);
          notifyListeners();
        }
      }
    } catch (e) {
      _showErrorDialog('Error during discovery: $e');
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  void _clearDevices() {
    _availableDevices.clear();
    _pairedDevices.clear();
    _selectedDevice = null;

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('lastConnectedDevice');
    });

    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    setLoading(true, device);
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _selectedDevice = device;
      listenForIncomingData();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastConnectedDevice', device.address);

      notifyListeners();
    } catch (e) {
      _showErrorDialog('Could not connect to device: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> disconnectFromDevice() async {
    if (_connection != null) {
      try {
        setLoading(true);
        await _connection!.close();
      } catch (e) {
        _showErrorDialog('Error while disconnecting: $e');
      } finally {
        _connection = null;
        _selectedDevice = null;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('lastConnectedDevice');
        setLoading(false);
        notifyListeners();
      }
    }
  }

  Future<void> refreshConnectionStatus() async {
    if (_connection != null && _connection!.isConnected) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastConnectedDeviceAddress = prefs.getString('lastConnectedDevice');

    if (lastConnectedDeviceAddress != null) {
      try {
        for (var device in await _bluetooth.getBondedDevices()) {
          if (device.address == lastConnectedDeviceAddress) {
            _selectedDevice = device;
            break;
          }
        }

        if (_selectedDevice != null) {
          await connectToDevice(_selectedDevice!);
        }
      } catch (e) {
        _showErrorDialog('Error restoring Bluetooth connection: $e');
        _selectedDevice = null;
      }
    } else {
      _selectedDevice = null;
    }

    notifyListeners();
  }

  void setLoading(bool value, [BluetoothDevice? device]) {
    if (_isLoading == value && _connectingDevice == device) return;

    _isLoading = value;
    _connectingDevice = device;
    notifyListeners();

    if (!value) {
      _connectingDevice = null;
    }
  }

  Future<void> sendData(String hexString) async {
    if (_connection != null && _connection!.isConnected) {
      List<int> bytes = hexStringToBytes(hexString);
      _connection!.output.add(Uint8List.fromList(bytes));
      await _connection!.output.allSent;
      debugPrint('Data sent: $hexString');
    } else {
      _showErrorDialog('No active Bluetooth connection');
    }
  }

  void listenForIncomingData() {
    _connection?.input?.listen((Uint8List data) {
      String receivedData = bytesToHex(data);
      debugPrint('Received data: $receivedData');

      if (validateChecksum(receivedData)) {
        onDataReceived?.call(receivedData);
      } else {
        loopRequestUntilVerified();
      }
    }).onDone(() {
      debugPrint("Disconnected by remote device");
      disconnectFromDevice();
    });
  }

  Future<void> loopRequestUntilVerified() async {
    int retries = 0;
    const maxRetries = 10;
    while (retries < maxRetries) {
      await Future.delayed(Duration(seconds: 2));
      if (_connection != null && _connection!.isConnected) {
        _connection?.output.add(Uint8List.fromList([0xA0]));
      } else {
        break;
      }
      retries++;
    }
  }

  List<int> hexStringToBytes(String hex) {
    hex = hex.replaceAll('0x', '');
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  String bytesToHex(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  bool validateChecksum(String hexData) {
    List<int> bytes = hexStringToBytes(hexData);
    if (bytes.length < 2) return false;

    int checksum = bytes.last;
    int xorValue = bytes[0];
    for (int i = 1; i < bytes.length - 1; i++) {
      xorValue ^= bytes[i];
    }
    return xorValue == checksum;
  }

  void toggleBluetooth() async {
    try {
      if (_bluetoothState == BluetoothState.STATE_OFF) {
        await _bluetooth.requestEnable();
      } else if (_bluetoothState == BluetoothState.STATE_ON) {
        await _bluetooth.requestDisable();
      }
      notifyListeners();
    } catch (e) {
      _showErrorDialog('Failed to toggle Bluetooth: $e');
    }
  }

  void _showConnectionReminderDialog() {
    if (_context == null || _isDialogShown) return;
    _isDialogShown = true;

    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: Text('No Device Connected'),
        content: Text(
            'It seems no Bluetooth device is connected. Would you like to connect now?'),
        actions: [
          TextButton(
            onPressed: () {
              _isDialogShown = false;
              Navigator.pop(context);
            },
            child: Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              _isDialogShown = false;
              Navigator.pop(context);
              _startDiscovery();
            },
            child: Text('Discover Devices'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (_context == null || _isDialogShown) return;

    _isDialogShown = true;
    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              _isDialogShown = false;
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}















































// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:typed_data';

// class BluetoothProvider with ChangeNotifier, WidgetsBindingObserver {
//   final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
//   BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
//   List<BluetoothDevice> _pairedDevices = [];
//   List<BluetoothDevice> _availableDevices = [];
//   BluetoothDevice? _selectedDevice;
//   BluetoothConnection? _connection;
//   bool _isDiscovering = false;

//   Function(String)? onDataReceived;

//   BluetoothState get bluetoothState => _bluetoothState;
//   List<BluetoothDevice> get pairedDevices => _pairedDevices;
//   List<BluetoothDevice> get availableDevices => _availableDevices;
//   BluetoothDevice? get selectedDevice => _selectedDevice;
//   bool get isDiscovering => _isDiscovering;
//   bool get isConnected => _connection != null && _connection!.isConnected;

//   BluetoothProvider() {
//     _initBluetooth();
//     WidgetsBinding.instance.addObserver(this);
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     disconnectFromDevice();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused ||
//         state == AppLifecycleState.detached) {
//       disconnectFromDevice();
//     } else if (state == AppLifecycleState.resumed) {
//       refreshConnectionStatus();
//     }
//   }

//   Future<void> _initBluetooth() async {
//     _bluetoothState = await _bluetooth.state;
//     notifyListeners();

//     if (_bluetoothState == BluetoothState.STATE_ON) {
//       await _getPairedDevices();
//     }

//     _bluetooth.onStateChanged().listen((state) {
//       _bluetoothState = state;
//       notifyListeners();

//       if (state == BluetoothState.STATE_ON) {
//         _getPairedDevices();
//       } else {
//         _clearDevices();
//       }
//     });

//     await refreshConnectionStatus();
//   }

//   Future<void> _getPairedDevices() async {
//     try {
//       List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
//       _pairedDevices = devices;
//       _startDiscovery();
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error fetching paired devices: $e');
//     }
//   }

//   void _clearDevices() {
//     _availableDevices.clear();
//     _pairedDevices.clear();
//     _selectedDevice = null;

//     SharedPreferences.getInstance().then((prefs) {
//       prefs.remove('lastConnectedDevice');
//     });

//     notifyListeners();
//   }

//   void _startDiscovery() {
//     _isDiscovering = true;
//     _availableDevices.clear();

//     _bluetooth.startDiscovery().listen((result) {
//       if (!_pairedDevices.any((d) => d.address == result.device.address) &&
//           !_availableDevices.any((d) => d.address == result.device.address)) {
//         _availableDevices.add(result.device);
//         notifyListeners();
//       }
//     }).onDone(() {
//       _isDiscovering = false;
//       notifyListeners();
//     });
//   }

//   Future<void> connectToDevice(BluetoothDevice device) async {
//     try {
//       BluetoothConnection connection =
//           await BluetoothConnection.toAddress(device.address);
//       _connection = connection;
//       _selectedDevice = device;

//       listenForIncomingData();

//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString('lastConnectedDevice', device.address);

//       notifyListeners();
//     } catch (e) {
//       debugPrint('Could not connect to device: $e');
//     }
//   }

//   Future<void> disconnectFromDevice() async {
//     if (_connection != null) {
//       await _connection!.close();
//       _connection = null;
//       _selectedDevice = null;

//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.remove('lastConnectedDevice');

//       notifyListeners();
//     }
//   }

//   Future<void> refreshConnectionStatus() async {
//     if (_connection != null && _connection!.isConnected) return;

//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? lastConnectedDeviceAddress = prefs.getString('lastConnectedDevice');

//     if (lastConnectedDeviceAddress != null) {
//       try {
//         List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
//         for (var device in devices) {
//           if (device.address == lastConnectedDeviceAddress) {
//             _selectedDevice = device;
//             break;
//           }
//         }

//         if (_selectedDevice != null) {
//           await connectToDevice(_selectedDevice!);
//         }
//       } catch (e) {
//         debugPrint('Error restoring Bluetooth connection: $e');
//         _selectedDevice = null;
//       }
//     } else {
//       _selectedDevice = null;
//     }

//     notifyListeners();
//   }

//   void toggleBluetooth() async {
//     if (_bluetoothState == BluetoothState.STATE_OFF) {
//       await _bluetooth.requestEnable();
//     } else {
//       await _bluetooth.requestDisable();
//     }
//   }

//   void sendData(String hexString) {
//     if (_connection != null && _connection!.isConnected) {
//       List<int> bytes = hexStringToBytes(hexString);
//       _connection!.output.add(Uint8List.fromList(bytes));
//       _connection!.output.allSent.then((_) {
//         debugPrint('Data sent: $hexString');
//       });
//     }
//   }

//   void listenForIncomingData() {
//     _connection?.input?.listen((Uint8List data) {
//       String receivedData = bytesToHex(data);
//       debugPrint('Received data: $receivedData');

//       if (validateChecksum(receivedData)) {
//         onDataReceived?.call(receivedData);
//       } else {
//         loopRequestUntilVerified();
//       }
//     }).onDone(() {
//       debugPrint("Disconnected by remote device");
//       disconnectFromDevice();
//     });
//   }

//   List<int> hexStringToBytes(String hex) {
//     hex = hex.replaceAll('0x', '');
//     List<int> bytes = [];
//     for (int i = 0; i < hex.length; i += 2) {
//       bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
//     }
//     return bytes;
//   }

//   String bytesToHex(Uint8List data) {
//     return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
//   }

//   bool validateChecksum(String hexData) {
//     List<int> bytes = hexStringToBytes(hexData);

//     if (bytes.length < 2) {
//       return false;
//     }

//     int checksum = bytes.last;
//     int xorValue = bytes[0];
//     for (int i = 1; i < bytes.length - 1; i++) {
//       xorValue ^= bytes[i];
//     }

//     return xorValue == checksum;
//   }

//   void loopRequestUntilVerified() async {
//     while (true) {
//       await Future.delayed(Duration(seconds: 2));
//       _connection?.output.add(Uint8List.fromList([0xA0]));
//     }
//   }
// }






































// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:typed_data';

// class BluetoothProvider with ChangeNotifier, WidgetsBindingObserver {
//   final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
//   BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
//   List<BluetoothDevice> _pairedDevices = [];
//   List<BluetoothDevice> _availableDevices = [];
//   BluetoothDevice? _selectedDevice;
//   BluetoothConnection? _connection;
//   bool _isDiscovering = false;

//   // Callback for received data (can be set from UI)
//   Function(String)? onDataReceived;

//   BluetoothState get bluetoothState => _bluetoothState;
//   List<BluetoothDevice> get pairedDevices => _pairedDevices;
//   List<BluetoothDevice> get availableDevices => _availableDevices;
//   BluetoothDevice? get selectedDevice => _selectedDevice;
//   bool get isDiscovering => _isDiscovering;
//   bool get isConnected => _connection != null && _connection!.isConnected;

//   BluetoothProvider() {
//     _initBluetooth();
//     WidgetsBinding.instance.addObserver(this);
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     disconnectFromDevice();
//     super.dispose();
//   }

//   // Handle app lifecycle changes
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused) {
//       // Disconnect Bluetooth when the app is minimized (paused)
//       disconnectFromDevice();
//     } else if (state == AppLifecycleState.resumed) {
//       // Reconnect to the last connected device when the app is resumed (opened from background)
//       refreshConnectionStatus();
//     }
//   }

//   // Initialize Bluetooth and fetch paired devices
//   Future<void> _initBluetooth() async {
//     _bluetoothState = await _bluetooth.state;
//     notifyListeners();

//     if (_bluetoothState == BluetoothState.STATE_ON) {
//       await _getPairedDevices();
//     }

//     // Listen for Bluetooth state changes
//     _bluetooth.onStateChanged().listen((state) {
//       _bluetoothState = state;
//       notifyListeners();

//       if (state == BluetoothState.STATE_ON) {
//         _getPairedDevices();
//       } else {
//         _clearDevices();
//       }
//     });

//     // Try to restore the last connected device if Bluetooth is on
//     await refreshConnectionStatus();
//   }

//   // Fetch paired devices and start discovery
//   Future<void> _getPairedDevices() async {
//     try {
//       List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
//       _pairedDevices = devices;
//       _startDiscovery(); // Start discovering new devices
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error fetching paired devices: $e');
//     }
//   }

//   // Clear device lists when Bluetooth is off
//   void _clearDevices() {
//     _availableDevices.clear();
//     _pairedDevices.clear();
//     _selectedDevice = null;

//     // Remove saved device from SharedPreferences
//     SharedPreferences.getInstance().then((prefs) {
//       prefs.remove('lastConnectedDevice');
//     });

//     notifyListeners();
//   }

//   // Start Bluetooth discovery
//   void _startDiscovery() {
//     _isDiscovering = true;
//     _availableDevices
//         .clear(); // Clear available devices before starting discovery

//     _bluetooth.startDiscovery().listen((result) {
//       // Add newly discovered devices if they are not in paired devices list
//       if (!_pairedDevices.any((d) => d.address == result.device.address) &&
//           !_availableDevices.any((d) => d.address == result.device.address)) {
//         _availableDevices.add(result.device);
//         notifyListeners();
//       }
//     }).onDone(() {
//       _isDiscovering = false;
//       notifyListeners();
//     });
//   }

//   // Connect to a Bluetooth device
//   Future<void> connectToDevice(BluetoothDevice device) async {
//     try {
//       BluetoothConnection connection =
//           await BluetoothConnection.toAddress(device.address);
//       _connection = connection;
//       _selectedDevice = device;

//       // Start listening for incoming data once connected
//       listenForIncomingData();

//       // Save connected device address in SharedPreferences
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString('lastConnectedDevice', device.address);

//       notifyListeners();
//     } catch (e) {
//       debugPrint('Could not connect to device: $e');
//     }
//   }

//   // Disconnect from the connected Bluetooth device
//   Future<void> disconnectFromDevice() async {
//     if (_connection != null) {
//       await _connection!.close();
//       _connection = null;
//       _selectedDevice = null;

//       // Remove saved device from SharedPreferences
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.remove('lastConnectedDevice');

//       notifyListeners();
//     }
//   }

//   // Refresh connection status and restore last connected device if possible
//   Future<void> refreshConnectionStatus() async {
//     // If a device is already connected, don't attempt to reconnect
//     if (_connection != null && _connection!.isConnected) {
//       debugPrint("Connection already active");
//       return;
//     }

//     // Get the last connected device from SharedPreferences
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? lastConnectedDeviceAddress = prefs.getString('lastConnectedDevice');

//     if (lastConnectedDeviceAddress != null) {
//       try {
//         // Check if the device is still paired
//         List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
//         for (var device in devices) {
//           if (device.address == lastConnectedDeviceAddress) {
//             _selectedDevice = device;
//             break;
//           }
//         }

//         if (_selectedDevice != null) {
//           await connectToDevice(_selectedDevice!); // Reconnect the device
//         }
//       } catch (e) {
//         debugPrint('Error restoring Bluetooth connection: $e');
//         _selectedDevice = null;
//       }
//     } else {
//       _selectedDevice = null;
//     }

//     notifyListeners(); // Update UI
//   }

//   // Toggle Bluetooth on or off
//   void toggleBluetooth() async {
//     if (_bluetoothState == BluetoothState.STATE_OFF) {
//       await _bluetooth.requestEnable();
//     } else {
//       await _bluetooth.requestDisable();
//     }
//   }

//   // Send data to the connected Bluetooth device
//   void sendData(String hexString) {
//     if (_connection != null && _connection!.isConnected) {
//       List<int> bytes = hexStringToBytes(hexString);
//       _connection!.output.add(Uint8List.fromList(bytes));
//       _connection!.output.allSent.then((_) {
//         debugPrint('Data sent: $hexString');
//       });
//     }
//   }

//   // Listen for incoming data from the Bluetooth device
//   void listenForIncomingData() {
//     _connection?.input?.listen((Uint8List data) {
//       String receivedData = bytesToHex(data);
//       debugPrint('Received data: $receivedData');

//       // Validate and process the data
//       if (validateChecksum(receivedData)) {
//         onDataReceived
//             ?.call(receivedData); // Trigger the callback for data received
//       } else {
//         debugPrint('Invalid data received, requesting again...');
//         loopRequestUntilVerified(); // Request again if data is not valid
//       }
//     }).onDone(() {
//       debugPrint("Disconnected by remote device");
//       disconnectFromDevice();
//     });
//   }

//   // Convert a hex string to a list of bytes
//   List<int> hexStringToBytes(String hex) {
//     hex = hex.replaceAll('0x', '');
//     List<int> bytes = [];
//     for (int i = 0; i < hex.length; i += 2) {
//       bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
//     }
//     return bytes;
//   }

//   // Convert bytes to a hex string
//   String bytesToHex(Uint8List data) {
//     return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
//   }

//   // Validate checksum for the received data
//   bool validateChecksum(String hexData) {
//     List<int> bytes = hexStringToBytes(hexData);

//     if (bytes.length < 2) {
//       return false; // Invalid data
//     }

//     int checksum = bytes.last;
//     int xorValue = bytes[0];
//     for (int i = 1; i < bytes.length - 1; i++) {
//       xorValue ^= bytes[i];
//     }

//     return xorValue == checksum;
//   }

//   // Loop request until verified data is received
//   void loopRequestUntilVerified() async {
//     while (true) {
//       await Future.delayed(Duration(seconds: 2)); // Wait before trying again
//       _connection?.output.add(Uint8List.fromList([0xA0])); // Send a request
//     }
//   }
// }



// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:typed_data';

// class BluetoothProvider with ChangeNotifier, WidgetsBindingObserver {
//   final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
//   BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
//   List<BluetoothDevice> _pairedDevices = [];
//   List<BluetoothDevice> _availableDevices = [];
//   BluetoothDevice? _selectedDevice;
//   BluetoothConnection? _connection;
//   bool _isDiscovering = false;

//   // Callback for received data (can be set from UI)
//   Function(String)? onDataReceived;

//   BluetoothState get bluetoothState => _bluetoothState;
//   List<BluetoothDevice> get pairedDevices => _pairedDevices;
//   List<BluetoothDevice> get availableDevices => _availableDevices;
//   BluetoothDevice? get selectedDevice => _selectedDevice;
//   bool get isDiscovering => _isDiscovering;
//   bool get isConnected => _connection != null && _connection!.isConnected;

//   BluetoothProvider() {
//     _initBluetooth();
//     WidgetsBinding.instance.addObserver(this);
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     disconnectFromDevice();
//     super.dispose();
//   }

//   // Handle app lifecycle changes
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused) {
//       // Disconnect Bluetooth when the app is minimized (paused)
//       disconnectFromDevice();
//     } else if (state == AppLifecycleState.resumed) {
//       // Reconnect to the last connected device when the app is resumed (opened from background)
//       refreshConnectionStatus();
//     }
//   }

//   // Initialize Bluetooth and fetch paired devices
//   Future<void> _initBluetooth() async {
//     _bluetoothState = await _bluetooth.state;
//     notifyListeners();

//     if (_bluetoothState == BluetoothState.STATE_ON) {
//       await _getPairedDevices();
//     }

//     // Listen for Bluetooth state changes
//     _bluetooth.onStateChanged().listen((state) {
//       _bluetoothState = state;
//       notifyListeners();

//       if (state == BluetoothState.STATE_ON) {
//         _getPairedDevices();
//       } else {
//         _clearDevices();
//       }
//     });

//     // Try to restore the last connected device if Bluetooth is on
//     await refreshConnectionStatus();
//   }

//   // Fetch paired devices and start discovery
//   Future<void> _getPairedDevices() async {
//     try {
//       List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
//       _pairedDevices = devices;
//       _startDiscovery(); // Start discovering new devices
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error fetching paired devices: $e');
//     }
//   }

//   // Clear device lists when Bluetooth is off
//   void _clearDevices() {
//     _availableDevices.clear();
//     _pairedDevices.clear();
//     _selectedDevice = null;

//     // Remove saved device from SharedPreferences
//     SharedPreferences.getInstance().then((prefs) {
//       prefs.remove('lastConnectedDevice');
//     });

//     notifyListeners();
//   }

//   // Start Bluetooth discovery
//   void _startDiscovery() {
//     _isDiscovering = true;
//     _availableDevices
//         .clear(); // Clear available devices before starting discovery

//     _bluetooth.startDiscovery().listen((result) {
//       // Add newly discovered devices if they are not in paired devices list
//       if (!_pairedDevices.any((d) => d.address == result.device.address) &&
//           !_availableDevices.any((d) => d.address == result.device.address)) {
//         _availableDevices.add(result.device);
//         notifyListeners();
//       }
//     }).onDone(() {
//       _isDiscovering = false;
//       notifyListeners();
//     });
//   }

//   // Connect to a Bluetooth device
//   Future<void> connectToDevice(BluetoothDevice device) async {
//     try {
//       BluetoothConnection connection =
//           await BluetoothConnection.toAddress(device.address);
//       _connection = connection;
//       _selectedDevice = device;

//       // Start listening for incoming data once connected
//       listenForIncomingData();

//       // Save connected device address in SharedPreferences
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString('lastConnectedDevice', device.address);

//       notifyListeners();
//     } catch (e) {
//       debugPrint('Could not connect to device: $e');
//     }
//   }

//   // Disconnect from the connected Bluetooth device
//   Future<void> disconnectFromDevice() async {
//     if (_connection != null) {
//       await _connection!.close();
//       _connection = null;
//       _selectedDevice = null;

//       // Remove saved device from SharedPreferences
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.remove('lastConnectedDevice');

//       notifyListeners();
//     }
//   }

//   // Refresh connection status and restore last connected device if possible
//   Future<void> refreshConnectionStatus() async {
//     // If a device is already connected, don't attempt to reconnect
//     if (_connection != null && _connection!.isConnected) {
//       debugPrint("Connection already active");
//       return;
//     }

//     // Get the last connected device from SharedPreferences
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? lastConnectedDeviceAddress = prefs.getString('lastConnectedDevice');

//     if (lastConnectedDeviceAddress != null) {
//       try {
//         // Check if the device is still paired
//         List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
//         for (var device in devices) {
//           if (device.address == lastConnectedDeviceAddress) {
//             _selectedDevice = device;
//             break;
//           }
//         }

//         if (_selectedDevice != null) {
//           await connectToDevice(_selectedDevice!); // Reconnect the device
//         }
//       } catch (e) {
//         debugPrint('Error restoring Bluetooth connection: $e');
//         _selectedDevice = null;
//       }
//     } else {
//       _selectedDevice = null;
//     }

//     notifyListeners(); // Update UI
//   }

//   // Toggle Bluetooth on or off
//   void toggleBluetooth() async {
//     if (_bluetoothState == BluetoothState.STATE_OFF) {
//       await _bluetooth.requestEnable();
//     } else {
//       await _bluetooth.requestDisable();
//     }
//   }

//   // Send data to the connected Bluetooth device
//   void sendData(String hexString) {
//     if (_connection != null && _connection!.isConnected) {
//       List<int> bytes = hexStringToBytes(hexString);
//       _connection!.output.add(Uint8List.fromList(bytes));
//       _connection!.output.allSent.then((_) {
//         debugPrint('Data sent: $hexString');
//       });
//     }
//   }

//   // Listen for incoming data from the Bluetooth device
//   void listenForIncomingData() {
//     _connection?.input?.listen((Uint8List data) {
//       String receivedData = bytesToHex(data);
//       debugPrint('Received data: $receivedData');

//       // Validate and process the data
//       if (validateChecksum(receivedData)) {
//         onDataReceived
//             ?.call(receivedData); // Trigger the callback for data received
//       } else {
//         debugPrint('Invalid data received, requesting again...');
//         loopRequestUntilVerified(); // Request again if data is not valid
//       }
//     }).onDone(() {
//       debugPrint("Disconnected by remote device");
//       disconnectFromDevice();
//     });
//   }

//   // Convert a hex string to a list of bytes
//   List<int> hexStringToBytes(String hex) {
//     hex = hex.replaceAll('0x', '');
//     List<int> bytes = [];
//     for (int i = 0; i < hex.length; i += 2) {
//       bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
//     }
//     return bytes;
//   }

//   // Convert bytes to a hex string
//   String bytesToHex(Uint8List data) {
//     return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
//   }

//   // Validate checksum for the received data
//   bool validateChecksum(String hexData) {
//     List<int> bytes = hexStringToBytes(hexData);

//     if (bytes.length < 2) {
//       return false; // Invalid data
//     }

//     int checksum = bytes.last;
//     int xorValue = bytes[0];
//     for (int i = 1; i < bytes.length - 1; i++) {
//       xorValue ^= bytes[i];
//     }

//     return xorValue == checksum;
//   }

//   // Loop request until verified data is received
//   void loopRequestUntilVerified() async {
//     while (true) {
//       await Future.delayed(Duration(seconds: 2)); // Wait before trying again
//       _connection?.output.add(Uint8List.fromList([0xA0])); // Send a request
//     }
//   }
// }



