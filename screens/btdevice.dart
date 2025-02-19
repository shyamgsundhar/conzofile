import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import 'bt_provider.dart'; // Import your BluetoothProvider file

class BluetoothDevicePage extends StatefulWidget {
  BluetoothDevicePage({super.key});

  @override
  _BluetoothDevicePageState createState() => _BluetoothDevicePageState();
}

class _BluetoothDevicePageState extends State<BluetoothDevicePage> {
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.trim().toLowerCase();
      });
    });
  }

  Future<void> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.warning, color: Color(0xffD41414)),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: Color(0xffD41414),
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
            ],
          ),
          content: Text(
            content,
            style: TextStyle(
              color: Colors.black,
              fontSize: 16.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16.sp,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffD41414),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothProvider = Provider.of<BluetoothProvider>(context);

    List<BluetoothDevice> allDevices = [
      ...bluetoothProvider.availableDevices,
      ...bluetoothProvider.pairedDevices,
    ];

    List<BluetoothDevice> filteredDevices = allDevices
        .where((device) =>
            device.name?.toLowerCase().contains(_searchQuery) ?? false)
        .toList();

    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xfff2f2f2),
        appBar: AppBar(
          backgroundColor: Color(0xfff2f2f2),
          title: Padding(
            padding: EdgeInsets.symmetric(vertical: 5.0),
            child: Text(
              'Device List',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            SizedBox(height: 20.h),
            Center(
              child: GestureDetector(
                onTap: bluetoothProvider.toggleBluetooth,
                child: CircleAvatar(
                  backgroundColor: bluetoothProvider.bluetoothState ==
                          BluetoothState.STATE_ON
                      ? Color(0xffD41414)
                      : Colors.grey.shade400,
                  radius: 50,
                  child: CircleAvatar(
                    backgroundColor: bluetoothProvider.bluetoothState ==
                            BluetoothState.STATE_ON
                        ? Color(0xffD41414)
                        : Colors.grey,
                    radius: 45,
                    child: Icon(
                      Icons.bluetooth,
                      color: Colors.white,
                      size: 45,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bluetooth Status:',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  bluetoothProvider.bluetoothState == BluetoothState.STATE_ON
                      ? '  on'
                      : '  off',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: bluetoothProvider.bluetoothState ==
                            BluetoothState.STATE_ON
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search devices...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            if (bluetoothProvider.selectedDevice != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  'Connected to: ${bluetoothProvider.selectedDevice!.name}',
                  style: TextStyle(
                    color: Color(0xffD41414),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredDevices.length,
                itemBuilder: (context, index) {
                  BluetoothDevice device = filteredDevices[index];
                  bool isConnected = device == bluetoothProvider.selectedDevice;

                  return ListTile(
                    title: Text(device.name ?? 'Unknown device'),
                    subtitle: Text(device.address),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isConnected ? Color(0xffD41414) : Colors.black,
                      ),
                      onPressed: () async {
                        if (bluetoothProvider.isLoading) {
                          return;
                        }
                        _showConfirmationDialog(
                          context: context,
                          title: isConnected ? 'Disconnect' : 'Connect',
                          content: isConnected
                              ? 'Are you sure you want to disconnect from ${device.name}?'
                              : 'Are you sure you want to connect to ${device.name}?',
                          onConfirm: () async {
                            bluetoothProvider.setLoading(true, device);
                            if (isConnected) {
                              await bluetoothProvider.disconnectFromDevice();
                            } else {
                              await bluetoothProvider.connectToDevice(device);
                            }
                            bluetoothProvider.setLoading(false);
                          },
                        );
                      },
                      child: bluetoothProvider.isLoading &&
                              bluetoothProvider.connectingDevice == device
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              isConnected ? 'Disconnect' : 'Connect',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
