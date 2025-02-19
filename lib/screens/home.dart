import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myapp/screens/bt_provider.dart';
import 'package:myapp/screens/btdevice.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _receivedData = '';
  String _lastSentData = '';
  bool isRefresh = false;
  bool isRefreshInfo = false;
  bool isRefreshBt = false;
  String batterySerialNumber = "";
  String hardwareVersion = "";
  String softwareVersion = "";
  int soc = 0;
  int remcap = 0;
  List<double> voltages = List.filled(15, 0.0);
  int maxBattery = -1;
  int minBattery = -1;
  double gathervoltage = 0.0;
  double cumvoltage = 0.0;
  double maxvoltage = 0;
  double minvoltage = 0;
  int mintemp = -1;
  int maxtemp = -1;
  double avgvoltage = 0;
  double power = 0;
  int cycle = 0;
  final StreamController<int> _cycleController =
      StreamController<int>.broadcast();
  int noofTemp = 0;
  int t1 = 0;
  int t2 = 0;
  int t3 = 0;
  int t4 = 0;
  int mostemp = 0;

  int noofBattery = 0;
  double voltdiff = 0;
  double current = 0.0;
  bool _hasReceivedResponse = false;
  bool _isSending = false;
  int chargerState = -1;
  int chargeMosState = -1;
  int dischargeMosState = -1;
  int balanceState = -1;
  int noofcycle = 0;
  int cumcharge = 0;
  int batterycapacity = 1;

  final bool _isParsingVoltage = false;
  final bool _isParsingCurrent = false;
  final bool _isParsingRemCap = false;
  bool _isParsingSoc = false;
  final bool _isParsingMaxVoltage = false;
  final bool _isParsingMinVoltage = false;
  final bool _isParsingAvgVoltage = false;
  final bool _isParsingVoltageDifference = false;
  final bool _isParsingnoOfTemp = false;
  final bool _isParsingNoofBattery = false;
  final bool _isParsingIndBattery = false;
  final bool _isParsingIndBatteryVolCell = false;
  final bool _isParsingChargingState = false;

  bool isLoading = false;
  Completer<void>? _refreshCompleter;
  bool isLoadingFirstBox = false;
  bool isLoadingSecondBox = false;
  bool isLoadingThirdBox = false;
  bool isLoadingFourthBox = false;
  bool isLoadingFifthhBox = false;
  bool isLoadingMosBox = false;
  bool isLoadingSixthBox = false;

  Timer? refreshTimer;
  Timer? statusLevelRefreshTimer;
  Timer? infoCorner;
  Timer? cycleCorner;
  ScrollController? _scrollController;
  double _scrollOffset = 0;
  double _idleWaveOffset = 0; // To control idle wave movement
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _scrollController = ScrollController();
      // _scrollController?.addListener(_onScroll);

      // // Start idle animation for waves
      // _startIdleWaveAnimation();
      _initialize();
    });
  }

  // This method moves the wave even when idle
  void _startIdleWaveAnimation() {
    Future.delayed(Duration(milliseconds: 80), () {
      // Increased delay to slow down the movement
      setState(() {
        _idleWaveOffset += 0.02; // Slow incremental movement
      });
      _startIdleWaveAnimation(); // Repeat animation
    });
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController!.offset;
    });
  }

  Future<void> _initialize() async {
    try {
      await _startListeningForData();
      if (!mounted) return;

      await _reconnectToLastDevice();
      if (!mounted) return;

      _startAutoRefresh();
      _startAutoRefreshStatusLevel();
      _startAutoCycleCorner();
    } catch (e) {
      _showErrorMessage('Initialization failed: $e');
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    statusLevelRefreshTimer?.cancel();
    infoCorner?.cancel();
    _cycleController.close();
    cycleCorner?.cancel();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void resetToDefaults() {
    setState(() {
      maxvoltage = 0;
      minvoltage = 0;
      soc = 0;
      remcap = 0;
      voltages = List.filled(15, 0.0);
      maxBattery = -1;
      minBattery = -1;
      gathervoltage = 0.0;
      cumvoltage = 0.0;
      maxvoltage = 0;
      minvoltage = 0;
      avgvoltage = 0;
      noofcycle = 0;
      power = 0;
      cycle = 0;
      noofTemp = 0;
      t1 = 0;
      t2 = 0;
      t3 = 0;
      t4 = 0;
      mintemp = -1;
      maxtemp = -1;
      noofBattery = 0;
      mostemp = 0;
      voltdiff = 0;
      current = 0.0;
      chargerState = -1;
      chargeMosState = -1;
      dischargeMosState = -1;
      balanceState = -1;
      parsedErrorLevels = [];
      softwareVersion = "";
      hardwareVersion = "";
      batterySerialNumber = "";
    });
  }

  Future<void> _refreshConnectionStatus() async {
    if (isRefreshBt) return;
    setState(() {
      isRefreshBt = true;
    });

    try {
      await Provider.of<BluetoothProvider>(context, listen: false)
          .refreshConnectionStatus();
    } finally {
      setState(() {
        isRefreshBt = false;
      });
    }
  }

  Future<void> fetchAllRefreshData() async {
    setState(() {
      isRefresh = true;
    });
    await Future.delayed(Duration(milliseconds: 500));
    await Future.wait([
      _refreshData(),
      _refreshStatusLevel(),
    ]);
    setState(() {
      isRefresh = false;
    });
  }

  void _startAutoRefreshStatusLevel() {
    statusLevelRefreshTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      if (!isLoading) {
        await _refreshStatusLevel();
      }
    });
  }

  void _startAutoCycleCorner() {
    cycleCorner?.cancel();
    cycleCorner = Timer.periodic(Duration(milliseconds: 250), (_) async {
      if (!isLoading) {
        await _refreshCycleCorner();
      }
    });
  }

  void _startAutoRefresh() {
    debugPrint('Starting auto-refresh');
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(Duration(seconds: 10), (_) async {
      if (!isLoading) {
        debugPrint('Refreshing data...');
        await _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    _refreshCompleter = Completer<void>();
    try {
      await Future.wait([
        _process0x90(),
        _process0x04(),
        _process0x91(),
        _process0x92(),
        _process0x93(),
        _process0x94(),
        _process0x95(),
        _process0x96(),
        _process0x97(),
        _process0x62(),
        _process0x63(),
        _process0x50(),
        _process0x52(),
        _process0x57(),
      ]);
      await _processNoCycle();
      _refreshCompleter?.complete();
    } catch (e) {
      _refreshCompleter?.completeError(e);
    } finally {
      // setState(() {
      //   isLoading = false; // Hide loading
      // });
    }
  }

  Future<void> _refreshStatusLevel() async {
    try {
      await _process0x98();
    } catch (e) {}
  }

  Future<void> _refreshCycleCorner() async {
    try {
      await _processCycleCorner();
    } catch (e) {}
  }

  Future<void> _process0x04() async {
    try {
      await sendData("0x04");
      await Future.delayed(Duration(milliseconds: 100));
      await parseMosTemp(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x90() async {
    try {
      await sendData("0x90");
      await Future.delayed(Duration(milliseconds: 100));
      await Future.wait([
        parseSoc(_receivedData),
        parseVoltage(_receivedData),
        parseCurrent(_receivedData),
        parseCumulativeVoltage(_receivedData),
      ]);
    } catch (e) {}
  }

  Future<void> _processNoCycle() async {
    try {
      // Ensure _process0x50 and _process0x52 are executed sequentially.
      await _process0x50();
      await Future.delayed(Duration(milliseconds: 200));
      await _process0x52();
      await Future.delayed(Duration(milliseconds: 200));

      // Calculate the number of cycles based on updated values.
      int u = (cumcharge / (batterycapacity / 1000)).toInt();

      // Update the state.
      setState(() {
        noofcycle = u;
      });
    } catch (e) {
      print('Error in _processNoCycle: $e');
    }
  }

  Future<void> _process0x52() async {
    try {
      await sendData("0x52");
      await Future.delayed(Duration(milliseconds: 200));
      await parseCumCharge(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x50() async {
    try {
      await sendData("0x50");
      await Future.delayed(Duration(milliseconds: 200));
      await parseBatteryCapcity(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x91() async {
    try {
      await sendData("0x91");

      await Future.wait([
        parseVMaxoltage(_receivedData),
        parseVMinVoltage(_receivedData),
        parseVMaxoltageNo(_receivedData),
        parseVMinoltageNo(_receivedData),
      ]);
      avgvoltage = (minvoltage + maxvoltage) / 2;
      voltdiff = (maxvoltage - minvoltage);
      power = (cumvoltage * current) / 1000;

      setState(() {
        avgvoltage = (minvoltage + maxvoltage) / 2;
        voltdiff = (maxvoltage - minvoltage);
        power = (cumvoltage * current) / 1000;
      });
    } catch (e) {}
  }

  Future<void> _process0x92() async {
    try {
      await sendData("0x92");
      await Future.wait([
        parseMinTempNo(_receivedData),
        parseMaxTempNo(_receivedData),
      ]);
    } catch (e) {}
  }

  Future<void> _process0x93() async {
    try {
      await sendData("0x93");
      await Future.delayed(Duration(milliseconds: 100));
      await Future.wait([
        parseRemCap(_receivedData),
        parseChargingState(_receivedData),
      ]); // Parse the Remaining Capacity
    } catch (e) {}
  }

  Future<void> _processCycleCorner() async {
    try {
      await sendData("0x93");
      await Future.delayed(Duration(milliseconds: 200));
      await parseCycle(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x94() async {
    try {
      await sendData("0x94");
      await Future.delayed(Duration(milliseconds: 100));
      await Future.wait([
        parseNoofBattery(_receivedData),
        parseNoofTemp(_receivedData),
      ]);
    } catch (e) {}
  }

  Future<void> _process0x95() async {
    try {
      await sendData("0x95");
      await Future.delayed(Duration(milliseconds: 100));
      await parseVoltages(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x96() async {
    try {
      await sendData("0x96");
      await Future.delayed(Duration(milliseconds: 100));
      await parseIndNoofBattery(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x97() async {
    try {
      await sendData("0x97");
      await Future.delayed(Duration(milliseconds: 250));
      await parseBalance(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x98() async {
    try {
      await sendData("0x98");
      await Future.delayed(Duration(milliseconds: 200));
      await statusLevel(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x57() async {
    try {
      _receivedData = "";
      await sendData("0x57");
      await Future.delayed(Duration(milliseconds: 250));
      await infoCornerSerialNumber(_receivedData);
    } catch (e) {
      debugPrint("Error processing 0x57: $e");
    }
  }

  Future<void> _process0x62() async {
    try {
      _receivedData = "";
      await sendData("0x62");
      await Future.delayed(Duration(milliseconds: 250));
      await infoCornerSoftwareVersion(_receivedData);
    } catch (e) {}
  }

  Future<void> _process0x63() async {
    try {
      _receivedData = "";
      await sendData("0x63");
      await Future.delayed(Duration(milliseconds: 250));
      await infoCornerHardwareVersion(_receivedData);
    } catch (e) {}
  }

  Future<void> _reconnectToLastDevice() async {
    final bluetoothProvider =
        Provider.of<BluetoothProvider>(context, listen: false);
    await bluetoothProvider.refreshConnectionStatus();
    if (bluetoothProvider.selectedDevice != null) {
      await bluetoothProvider
          .connectToDevice(bluetoothProvider.selectedDevice!);
    }
  }

  Future<void> _startListeningForData() async {
    final bluetoothProvider =
        Provider.of<BluetoothProvider>(context, listen: false);
    bluetoothProvider.onDataReceived = (data) {
      setState(() {
        _receivedData = data;
        _hasReceivedResponse = true;
      });
    };
  }

  Future<void> sendData(String hexString) async {
    final bluetoothProvider =
        Provider.of<BluetoothProvider>(context, listen: false);
    setState(() {
      _isSending = true;
    });
    if (bluetoothProvider.isConnected) {
      await bluetoothProvider.sendData(hexString);
      setState(() {
        _lastSentData = hexString;
        _hasReceivedResponse = false;
        _isSending = false;
      });
    } else {
      if (bluetoothProvider.selectedDevice != null) {
        await bluetoothProvider
            .connectToDevice(bluetoothProvider.selectedDevice!);
        if (bluetoothProvider.isConnected) {
          await bluetoothProvider.sendData(hexString);
          setState(() {
            _lastSentData = hexString;
            _hasReceivedResponse = false;
            _isSending = false;
          });
        }
      }
    }
  }

  Future<void> _handleStatusInformationTap() async {
    setState(() {
      isLoadingFifthhBox = true;
      invalidData = null;
    });

    sendData("0x98");
    await Future.delayed(Duration(milliseconds: 200));

    final receivedData = _receivedData;

    if (!_isValidData(receivedData)) {
      setState(() {
        invalidData = receivedData;
        parsedErrorLevels = [];
      });
    } else {
      await statusLevel(receivedData);
    }

    setState(() {
      isLoadingFifthhBox = false;
    });
  }

  bool _isValidData(String receivedData) {
    return receivedData.startsWith("98") && receivedData.length > 2;
  }

  String? invalidData;

  Future<void> parseChargingState(String receivedData) async {
    while (!receivedData.startsWith("93")) {
      sendData("0x93");
      await Future.delayed(Duration(milliseconds: 200));
      if (!receivedData.startsWith("93")) {
        continue;
      }
      return parseChargingState(_receivedData);
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      if (bytes.length < 3) {
        return;
      }

      int output1 = bytes[0];
      int output2 = bytes[1];
      int output3 = bytes[2];

      setState(() {
        chargerState = output1;
        chargeMosState = output2;
        dischargeMosState = output3;
      });
    } catch (e) {}
  }

  Future<void> parseMosTemp(String receivedData, {int retries = 50}) async {
    if (receivedData.isEmpty || !receivedData.startsWith("04")) {
      if (retries > 0) {
        await sendData("0x04");
        await Future.delayed(Duration(milliseconds: 200));
        return parseMosTemp(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseMosTemp");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      setState(() {
        mostemp = bytes[0] - 40;
      });
    } catch (e) {
      debugPrint("Error parsing MOS temperature: $e");
    }
  }

  Future<void> parseIndNoofBattery(String receivedData,
      {int retries = 50}) async {
    if (receivedData.isEmpty || !receivedData.startsWith("96")) {
      if (retries > 0) {
        await sendData("0x96");
        await Future.delayed(Duration(milliseconds: 100));
        return parseIndNoofBattery(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseIndNoofBattery");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.length < 5) {
        throw Exception("Insufficient data length in receivedData: $bytes");
      }

      List<int> adjustedValues =
          bytes.sublist(0, 4).map((b) => b - 40).toList();
      setState(() {
        t1 = adjustedValues[0];
        t2 = adjustedValues[1];
        t3 = adjustedValues[2];
        t4 = adjustedValues[3];
      });
    } catch (e) {
      debugPrint("Error parsing IndNoofBattery: $e");
    }
  }

  List<Map<String, dynamic>> parsedErrorLevels = [];
  String receivedDataDebugInfo = "No data received yet.";

  Future<void> statusLevel(String receivedData, {int retries = 40}) async {
    setState(() {
      receivedDataDebugInfo = receivedData;
    });

    if (!receivedData.startsWith("98")) {
      if (retries > 0) {
        await sendData("0x98");
        await Future.delayed(Duration(milliseconds: 100));
        await statusLevel(_receivedData,
            retries: retries - 1); // Retry with decremented count
        return;
      } else {
        debugPrint("Maximum retries reached for statusLevel");
        return; // Exit if retries are exhausted
      }
    }

    _parseAndSetErrorLevels(receivedData);
  }

  void _parseAndSetErrorLevels(String receivedData) {
    try {
      if (receivedData.length <= 2) {
        debugPrint("Received data is too short to parse: $receivedData");
        return;
      }

      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      List<Map<String, dynamic>> errorLevels = _parseErrorLevels(bytes);

      if (errorLevels.isEmpty) {
        errorLevels.add({"name": "No Errors Detected", "level": 0});
      }

      setState(() {
        parsedErrorLevels = errorLevels;
      });
    } catch (e) {
      debugPrint("Error parsing and setting error levels: $e");
    }
  }

  List<Map<String, dynamic>> _parseErrorLevels(List<int> bytes) {
    List<String> errorNames = [
      "Cell Volt High Level 1",
      "Cell Volt High Level 2",
      "Cell Volt Low Level 1",
      "Cell Volt Low Level 2",
      "Sum Volt High Level 1",
      "Sum Volt High Level 2",
      "Sum Volt Low Level 1",
      "Sum Volt Low Level 2",
      "Chg Temp High Level 1",
      "Chg Temp High Level 2",
      "Chg Temp Low Level 1",
      "Chg Temp Low Level 2",
      "Dischg Temp High Level 1",
      "Dischg Temp High Level 2",
      "Dischg Temp Low Level 1",
      "Dischg Temp Low Level 2",
      "Chg Overcurrent Level 1",
      "Chg Overcurrent Level 2",
      "Dischg Overcurrent Level 1",
      "Dischg Overcurrent Level 2",
      "SOC High Level 1",
      "SOC High Level 2",
      "SOC Low Level 1",
      "SOC Low Level 2",
      "Diff Volt Level 1",
      "Diff Volt Level 2",
      "Diff Temp Level 1",
      "Diff Temp Level 2",
      "Charger Conn Level 1",
      "Charger Conn Level 2",
      "BMS State Level 1",
      "BMS State Level 2"
    ];

    List<Map<String, dynamic>> errorLevels = [];

    for (int byteIndex = 0; byteIndex < bytes.length; byteIndex++) {
      int byte = bytes[byteIndex];

      for (int bitIndex = 0; bitIndex < 8; bitIndex++) {
        if ((byte & (1 << bitIndex)) != 0) {
          int errorIndex = byteIndex * 8 + bitIndex;
          if (errorIndex < errorNames.length) {
            errorLevels.add({"name": errorNames[errorIndex], "level": 1});
          }
        }
      }
    }

    return errorLevels;
  }

  Future<void> parseNoofBattery(String receivedData, {int retries = 50}) async {
    if (!receivedData.startsWith("94")) {
      if (retries > 0) {
        await sendData("0x94");
        await Future.delayed(Duration(milliseconds: 100));
        return parseNoofBattery(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseNoofBattery");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.isEmpty) {
        throw Exception("Received data is empty or invalid: $receivedData");
      }

      int batteryno = bytes[0];
      setState(() {
        noofBattery = batteryno;
      });
    } catch (e) {
      debugPrint("Error parsing number of batteries: $e");
    }
  }

  Future<void> parseNoofTemp(String receivedData, {int retries = 50}) async {
    if (!receivedData.startsWith("94")) {
      if (retries > 0) {
        await sendData("0x94");
        await Future.delayed(Duration(milliseconds: 100));
        return parseNoofTemp(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseNoofTemp");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.length < 2) {
        throw Exception("Insufficient data length in receivedData: $bytes");
      }

      int tempno = bytes[1];
      setState(() {
        noofTemp = tempno;
      });
    } catch (e) {
      debugPrint("Error parsing number of temperatures: $e");
    }
  }

  Future<int> parseBalance(String receivedData) async {
    int retries = 0;
    int maxRetries = 40;

    while (retries < maxRetries) {
      if (!receivedData.startsWith("97")) {
        sendData("0x97");
        await Future.delayed(Duration(milliseconds: 250));
        retries++;
        // Recurse with updated receivedData for retry
        return parseBalance(_receivedData);
      }

      try {
        List<int> bytes = hexStringToBytes(receivedData.substring(2));

        if (bytes.length < 2) {
          throw Exception("Invalid data: Less than 2 bytes received");
        }

        int fbyte = bytes[0];
        int sbyte = bytes[1];

        int newState = (fbyte | sbyte) != 0 ? 1 : 2;

        setState(() {
          balanceState = newState;
        });

        return newState;
      } catch (e) {
        debugPrint("Error parsing balance: $e");

        setState(() {
          balanceState = -1;
        });

        retries++;
        if (retries >= maxRetries) {
          debugPrint("Max retries reached. Returning 0.");
          return 0;
        }

        // Wait for some time before retrying
        await Future.delayed(Duration(milliseconds: 250));
      }
    }

    return 0;
  }

  Future<void> parseCumCharge(String receivedData) async {
    int retryCount = 0;
    int maxRetries = 40;

    while (!receivedData.startsWith("52") && retryCount < maxRetries) {
      sendData("0x52");
      await Future.delayed(Duration(milliseconds: 100));
      receivedData = _receivedData;
      retryCount++;
    }

    if (!receivedData.startsWith("52")) {
      throw Exception("Max retries reached for parseCumCharge");
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.length < 2) {
        throw Exception("Invalid data received: Less than 2 bytes");
      }

      int cum = bytes[1];

      setState(() {
        cumcharge = cum;
      });
    } catch (e) {
      debugPrint("Error parsing cumulative charge: $e");
      rethrow; // Re-throw the exception to propagate it if needed
    }
  }

  Future<void> parseBatteryCapcity(String receivedData) async {
    int retryCount = 0;
    int maxRetries = 40;

    while (!receivedData.startsWith("50") && retryCount < maxRetries) {
      sendData("0x50");
      await Future.delayed(Duration(milliseconds: 100));
      receivedData = _receivedData;
      retryCount++;
    }

    if (!receivedData.startsWith("50")) {
      throw Exception("Max retries reached for parseBatteryCapcity");
    }

    List<int> bytes = hexStringToBytes(receivedData.substring(2));
    int cap = bytes[1];

    setState(() {
      batterycapacity = cap;
    });
  }

  Future<void> parseRemCap(String receivedData, {int retries = 40}) async {
    if (!receivedData.startsWith("93")) {
      if (retries > 0) {
        sendData("0x93");
        await Future.delayed(Duration(milliseconds: 100));
        return parseRemCap(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseRemCap");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.length < 8) {
        throw Exception("Insufficient data length for remaining capacity");
      }

      int remainCapacity =
          (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];

      setState(() {
        remcap = remainCapacity;
      });
    } catch (e) {
      debugPrint("Error parsing remaining capacity: $e");
    }
  }

  Future<void> parseCycle(String receivedData) async {
    if (!receivedData.startsWith("93")) {
      sendData("0x93");
      await Future.delayed(Duration(milliseconds: 30));
      parseCycle(_receivedData);
      return;
    }
    List<int> bytes = hexStringToBytes(receivedData.substring(2));

    int parsecycle = bytes[3];

    if (cycle != parsecycle) {
      cycle = parsecycle;
      _cycleController.add(cycle);
    }
  }

  Future<void> parseVoltages(String receivedData, {int retries = 50}) async {
    final dataSnapshot = receivedData;

    // Retry mechanism if data doesn't start with "95"
    if (dataSnapshot.isEmpty || !dataSnapshot.startsWith("95")) {
      if (retries > 0) {
        await sendData("0x95");
        await Future.delayed(Duration(milliseconds: 100));
        return parseVoltages(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseVoltages");
        return; // Exit if retries are exhausted
      }
    }

    List<double> updatedVoltages = List.from(voltages);
    List<bool> validCases = List.filled(5, false);
    bool validDataFound = false;

    try {
      for (int i = 0; i + 20 <= dataSnapshot.length; i += 20) {
        String frame = dataSnapshot.substring(i, i + 20);

        if (!frame.startsWith("95")) {
          continue; // Skip invalid frames
        }

        String dataWithoutPrefix = frame.substring(2);
        List<int> bytes = hexStringToBytes(dataWithoutPrefix);

        if (bytes.length < 9) {
          continue; // Skip frames with insufficient data
        }

        int caseId = bytes[0];
        if (caseId < 1 || caseId > 5) {
          continue; // Skip frames with invalid caseId
        }

        int cell1Voltage = (bytes[1] << 8) | bytes[2];
        int cell2Voltage = (bytes[3] << 8) | bytes[4];
        int cell3Voltage = (bytes[5] << 8) | bytes[6];

        // Skip frames with invalid voltage values
        if (cell1Voltage == 0 || cell2Voltage == 0 || cell3Voltage == 0) {
          continue;
        }

        validDataFound = true;
        validCases[caseId - 1] = true;

        // Update voltages based on caseId
        switch (caseId) {
          case 1:
            updatedVoltages[0] = cell1Voltage / 1000.0;
            updatedVoltages[1] = cell2Voltage / 1000.0;
            updatedVoltages[2] = cell3Voltage / 1000.0;
            break;
          case 2:
            updatedVoltages[3] = cell1Voltage / 1000.0;
            updatedVoltages[4] = cell2Voltage / 1000.0;
            updatedVoltages[5] = cell3Voltage / 1000.0;
            break;
          case 3:
            updatedVoltages[6] = cell1Voltage / 1000.0;
            updatedVoltages[7] = cell2Voltage / 1000.0;
            updatedVoltages[8] = cell3Voltage / 1000.0;
            break;
          case 4:
            updatedVoltages[9] = cell1Voltage / 1000.0;
            updatedVoltages[10] = cell2Voltage / 1000.0;
            updatedVoltages[11] = cell3Voltage / 1000.0;
            break;
          case 5:
            updatedVoltages[12] = cell1Voltage / 1000.0;
            updatedVoltages[13] = cell2Voltage / 1000.0;
            updatedVoltages[14] = cell3Voltage / 1000.0;
            break;
        }
      }

      if (validDataFound) {
        setState(() {
          voltages = updatedVoltages;
        });
      } else {
        debugPrint("No valid data found in parseVoltages");
      }
    } catch (e) {
      debugPrint("Error parsing voltages: $e");
    }
  }

  Future<void> parseSoc(String receivedData, {int retries = 40}) async {
    if (!receivedData.startsWith("90")) {
      if (retries > 0) {
        sendData("0x90");
        await Future.delayed(Duration(milliseconds: 100));
        return parseSoc(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseSoc");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure that there are enough bytes for parsing
      if (bytes.length >= 8) {
        int socValue = (bytes[6] << 8 | bytes[7]);
        setState(() {
          soc = socValue ~/ 10; // Assuming soc value needs to be divided by 10
        });
      } else {
        debugPrint("Invalid data length for SOC parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing SOC: $e");
    }
  }

  Future<void> parseCurrent(String receivedData, {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "90"
    if (!receivedData.startsWith("90")) {
      if (retries > 0) {
        sendData("0x90");
        await Future.delayed(Duration(milliseconds: 500));
        return parseCurrent(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseCurrent");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure the data length is sufficient
      if (bytes.length >= 6) {
        double parsedCurrent = ((bytes[4] << 8) | bytes[5]) - 30000;
        setState(() {
          current = parsedCurrent *
              0.1; // Multiply by 0.1 to get the correct current value
        });
      } else {
        debugPrint("Invalid data length for current parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing current: $e");
    }
  }

  Future<void> parseVoltage(String receivedData, {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "90"
    if (!receivedData.startsWith("90")) {
      if (retries > 0) {
        sendData("0x90");
        await Future.delayed(Duration(milliseconds: 100));
        return parseVoltage(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseVoltage");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure the data length is sufficient
      if (bytes.length >= 4) {
        int gatherTotalVoltage = (bytes[2] << 8) | bytes[3];
        setState(() {
          gathervoltage = gatherTotalVoltage *
              0.1; // Multiply by 0.1 to get the correct voltage
        });
      } else {
        debugPrint("Invalid data length for voltage parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing voltage: $e");
    }
  }

  Future<void> parseCumulativeVoltage(String receivedData,
      {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "90"
    if (!receivedData.startsWith("90")) {
      if (retries > 0) {
        sendData("0x90");
        await Future.delayed(Duration(milliseconds: 100));
        return parseCumulativeVoltage(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseCumulativeVoltage");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure the data length is sufficient (must have at least 2 bytes for the voltage calculation)
      if (bytes.length >= 2) {
        int cumTotalVoltage = (bytes[0] << 8) | bytes[1];
        setState(() {
          cumvoltage = cumTotalVoltage *
              0.1; // Multiply by 0.1 to get the correct voltage
        });
      } else {
        debugPrint(
            "Invalid data length for cumulative voltage parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing cumulative voltage: $e");
    }
  }

  Future<void> parseVMaxoltage(String receivedData, {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "91"
    if (!receivedData.startsWith("91")) {
      if (retries > 0) {
        sendData("0x91");
        await Future.delayed(Duration(milliseconds: 100));
        return parseVMaxoltage(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseVMaxoltage");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure that the data has at least 2 bytes for voltage calculation
      if (bytes.length >= 2) {
        int parseMaxvol = (bytes[0] << 8) | bytes[1];
        double output = parseMaxvol /
            1000.0; // Divide by 1000 to convert to the correct voltage
        setState(() {
          maxvoltage = output;
        });
      } else {
        debugPrint("Invalid data length for voltage parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing maximum voltage: $e");
    }
  }

  Future<void> parseVMaxoltageNo(String receivedData,
      {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "91"
    if (!receivedData.startsWith("91")) {
      if (retries > 0) {
        sendData("0x91");
        await Future.delayed(Duration(milliseconds: 100));
        return parseVMaxoltageNo(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseVMaxoltageNo");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure that the data has at least 3 bytes
      if (bytes.length >= 3) {
        int parseMaxvolNo = bytes[2];
        setState(() {
          maxBattery = parseMaxvolNo;
        });
      } else {
        debugPrint(
            "Invalid data length for max voltage number parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing max voltage number: $e");
    }
  }

  Future<void> parseMaxTempNo(String receivedData, {int retries = 40}) async {
    if (!receivedData.startsWith("92")) {
      if (retries > 0) {
        sendData("0x92");
        await Future.delayed(Duration(milliseconds: 100));
        return parseMaxTempNo(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Maximum retries reached for parseVMaxoltageNo");
        return;
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.length >= 3) {
        int parseMaxtempNo = bytes[1];
        setState(() {
          maxtemp = parseMaxtempNo;
        });
      } else {
        debugPrint("Invalid data length for max temp number parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing max temp number: $e");
    }
  }

  Future<void> parseMinTempNo(String receivedData, {int retries = 40}) async {
    if (!receivedData.startsWith("92")) {
      if (retries > 0) {
        sendData("0x92");
        await Future.delayed(Duration(milliseconds: 100));
        return parseMinTempNo(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Maximum retries reached for parseVMaxoltageNo");
        return;
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));
      if (bytes.length >= 3) {
        int parseMintempNo = bytes[3];
        setState(() {
          mintemp = parseMintempNo;
        });
      } else {
        debugPrint("Invalid data length for max temp number parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing max temp number: $e");
    }
  }

  Future<void> parseVMinoltageNo(String receivedData,
      {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "91"
    if (!receivedData.startsWith("91")) {
      if (retries > 0) {
        sendData("0x91");
        await Future.delayed(Duration(milliseconds: 100));
        return parseVMinoltageNo(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseVMinoltageNo");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure that the data has at least 6 bytes
      if (bytes.length >= 6) {
        int parseMinvolNo = bytes[5];
        setState(() {
          minBattery = parseMinvolNo;
        });
      } else {
        debugPrint(
            "Invalid data length for min voltage number parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing min voltage number: $e");
    }
  }

  Future<void> parseVMinVoltage(String receivedData, {int retries = 40}) async {
    // Retry mechanism if data doesn't start with "91"
    if (!receivedData.startsWith("91")) {
      if (retries > 0) {
        sendData("0x91");
        await Future.delayed(Duration(milliseconds: 100));
        return parseVMinVoltage(_receivedData,
            retries: retries - 1); // Retry with decremented count
      } else {
        debugPrint("Maximum retries reached for parseVMinVoltage");
        return; // Exit if retries are exhausted
      }
    }

    try {
      List<int> bytes = hexStringToBytes(receivedData.substring(2));

      // Ensure that the data has at least 5 bytes
      if (bytes.length >= 5) {
        int parseMinvol = (bytes[3] << 8) | bytes[4];
        double output = parseMinvol / 1000.0; // Convert to correct voltage
        setState(() {
          minvoltage = output;
        });
      } else {
        debugPrint("Invalid data length for min voltage parsing: $bytes");
      }
    } catch (e) {
      debugPrint("Error parsing min voltage: $e");
    }
  }

  Future<void> infoCornerSerialNumber(String receivedData,
      {int retries = 20}) async {
    if (!receivedData.startsWith("57") || receivedData.length < 40) {
      if (retries > 0) {
        sendData("0x57");
        await Future.delayed(Duration(milliseconds: 500));
        return infoCornerSerialNumber(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Maximum retries reached for Serial Number");
        return;
      }
    }

    String relevantData = receivedData.substring(0, 40);
    String firstFrame = relevantData.substring(0, 20);
    String secondFrame = relevantData.substring(20, 40);

    if (!validateFrames(firstFrame, secondFrame)) {
      if (retries > 0) {
        sendData("0x57");
        await Future.delayed(Duration(milliseconds: 500));
        return infoCornerSerialNumber(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Invalid frames for Serial Number");
        return;
      }
    }

    processAsciiData(relevantData, {0, 9, 10, 19}, (asciiString) {
      if (asciiString.length != 8 || !RegExp(r'^\d+$').hasMatch(asciiString)) {
        if (retries > 0) {
          sendData("0x57");
          Future.delayed(Duration(milliseconds: 500), () {
            infoCornerSerialNumber(_receivedData, retries: retries - 1);
          });
        } else {
          debugPrint("Invalid ASCII data for Serial Number");
        }
      } else {
        setState(() {
          batterySerialNumber = asciiString;
        });
      }
    });

    _receivedData = "";
  }

  Future<void> infoCornerSoftwareVersion(String receivedData,
      {int retries = 10}) async {
    if (!receivedData.startsWith("62") || receivedData.length < 40) {
      if (retries > 0) {
        sendData("0x62");
        await Future.delayed(Duration(milliseconds: 300)); // Reduce delay
        return infoCornerSoftwareVersion(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Maximum retries reached for Software Version");
        return;
      }
    }

    String relevantData = receivedData.substring(0, 40);
    String firstFrame = relevantData.substring(0, 20);
    String secondFrame = relevantData.substring(20, 40);

    if (!validateFrames(firstFrame, secondFrame)) {
      if (retries > 0) {
        sendData("0x62");
        await Future.delayed(Duration(milliseconds: 300)); // Reduce delay
        return infoCornerSoftwareVersion(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Invalid frames for Software Version");
        return;
      }
    }

    processAsciiData(relevantData, {0, 1, 9, 10, 11, 19}, (asciiString) {
      if (asciiString.length != 14) {
        if (retries > 0) {
          sendData("0x62");
          Future.delayed(Duration(milliseconds: 300), () {
            infoCornerSoftwareVersion(_receivedData, retries: retries - 1);
          });
        } else {
          debugPrint("Invalid ASCII data length for Software Version");
        }
      } else {
        setState(() {
          softwareVersion = asciiString;
        });
      }
    });

    _receivedData = ""; // Clear data after processing
  }

  Future<void> infoCornerHardwareVersion(String receivedData,
      {int retries = 10}) async {
    if (!receivedData.startsWith("63") || receivedData.length < 40) {
      if (retries > 0) {
        sendData("0x63");
        await Future.delayed(Duration(milliseconds: 300)); // Reduce delay
        return infoCornerHardwareVersion(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Maximum retries reached for Hardware Version");
        return;
      }
    }

    String relevantData = receivedData.substring(0, 40);
    String firstFrame = relevantData.substring(0, 20);
    String secondFrame = relevantData.substring(20, 40);

    if (!validateFrames(firstFrame, secondFrame)) {
      if (retries > 0) {
        sendData("0x63");
        await Future.delayed(Duration(milliseconds: 300)); // Reduce delay
        return infoCornerHardwareVersion(_receivedData, retries: retries - 1);
      } else {
        debugPrint("Invalid frames for Hardware Version");
        return;
      }
    }

    processAsciiData(relevantData, {0, 1, 9, 10, 11, 19}, (asciiString) {
      if (asciiString.length != 14) {
        if (retries > 0) {
          sendData("0x63");
          Future.delayed(Duration(milliseconds: 300), () {
            infoCornerHardwareVersion(_receivedData, retries: retries - 1);
          });
        } else {
          debugPrint("Invalid ASCII data length for Hardware Version");
        }
      } else {
        setState(() {
          hardwareVersion =
              asciiString.isNotEmpty ? asciiString : "Invalid Hardware Version";
        });
      }
    });

    _receivedData = ""; // Clear data after processing
  }

  bool validateFrames(String firstFrame, String secondFrame) {
    if (firstFrame.length != 20 || secondFrame.length != 20) return false;

    List<int> firstFrameBytes = frameToBytes(firstFrame);
    List<int> secondFrameBytes = frameToBytes(secondFrame);

    if (firstFrameBytes.length != 10 || secondFrameBytes.length != 10)
      return false;

    int firstXorResult = calculateXor(firstFrameBytes.sublist(0, 9));
    int secondXorResult = calculateXor(secondFrameBytes.sublist(0, 9));

    return firstXorResult == firstFrameBytes[9] &&
        secondXorResult == secondFrameBytes[9];
  }

  int calculateXor(List<int> bytes) {
    return bytes.reduce((value, element) => value ^ element);
  }

  List<int> frameToBytes(String frame) {
    List<int> bytes = [];
    for (int i = 0; i < frame.length; i += 2) {
      try {
        bytes.add(int.parse(frame.substring(i, i + 2), radix: 16));
      } catch (e) {
        debugPrint("Error parsing byte: ${frame.substring(i, i + 2)}");
        return [];
      }
    }
    return bytes;
  }

  void processAsciiData(
      String data, Set<int> excludeIndices, Function(String) callback) {
    List<String> hexList = [];
    for (int i = 0; i < data.length; i += 2) {
      hexList.add(data.substring(i, i + 2));
    }

    List<String> asciiOutput = [];
    for (int i = 0; i < hexList.length; i++) {
      if (excludeIndices.contains(i)) continue;
      int hexValue = int.parse(hexList[i], radix: 16);
      if (hexValue >= 0x20 && hexValue <= 0x7E) {
        asciiOutput.add(String.fromCharCode(hexValue));
      }
    }

    String asciiString = asciiOutput.join().trim();
    callback(asciiString);
  }

  List<int> hexStringToBytes(String hex) {
    hex = hex.replaceAll('0x', '');
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  bool validateChecksum(String hexData) {
    List<int> bytes = hexStringToBytes(hexData);

    if (bytes.length < 2) {
      return false; // Not enough data to validate
    }

    int checksum = bytes.last; // Last byte is the checksum
    int xorValue = bytes[0];
    for (int i = 1; i < bytes.length - 1; i++) {
      xorValue ^= bytes[i];
    }

    return xorValue == checksum;
  }

  Color getProgressColor() {
    if (soc > 50) {
      return Color(0xff008000);
    } else if (soc > 20) {
      return Color(0xffF2720F);
    } else {
      return Color(0xffD41414);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothProvider = Provider.of<BluetoothProvider>(context);
    ScreenUtil.init(context);
    return SafeArea(
        child: Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Color(0xfff2f2f2),
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   toolbarHeight: 65.h,
      //   title: Padding(
      //     padding:  EdgeInsets.all(8.0),
      //     child: Text(
      //       "Home",
      //       style: TextStyle(
      //         fontSize: 22.sp,
      //         color: Colors.black,
      //         fontWeight: FontWeight.bold,
      //       ),
      //     ),
      //   ),
      //   actions: [
      //     Padding(
      //       padding:  EdgeInsets.all(8.0),
      //       child: Consumer<BluetoothProvider>(
      //         builder: (context, bluetoothProvider, child) {
      //           return IconButton(
      //             icon: Icon(
      //               bluetoothProvider.selectedDevice != null
      //                   ? Icons.bluetooth_connected
      //                   : Icons.bluetooth,
      //               size: 25.sp,
      //               color: bluetoothProvider.selectedDevice != null
      //                   ? Colors.green
      //                   : Colors.black,
      //             ),
      //             onPressed: () async {
      //               await Navigator.of(context).push(
      //                 MaterialPageRoute(
      //                   builder: (_) => BluetoothDevicePage(),
      //                 ),
      //               );
      //               await _refreshConnectionStatus();
      //               await bluetoothProvider.refreshConnectionStatus();

      //               if (bluetoothProvider.selectedDevice != null) {
      //                 await bluetoothProvider
      //                     .connectToDevice(bluetoothProvider.selectedDevice!);
      //               }
      //             },
      //           );
      //         },
      //       ),
      //     ),
      //   ],
      // ),
      body: Align(
        child: Stack(
          children: [
            // Positioned(
            //   top: 0,
            //   left: 0,
            //   right: 0,
            //   child: CustomPaint(
            //     painter: WavyBackgroundPainter(
            //       _scrollOffset,
            //       _idleWaveOffset,
            //       isTopWave: true,
            //     ),
            //     size: Size(MediaQuery.of(context).size.width,
            //         150), // Increased height for top wave
            //   ),
            // ),
            SingleChildScrollView(
              controller: _scrollController,
              physics: BouncingScrollPhysics(),
              child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: isRefreshBt
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xffD41414),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    //resetInfo();
                                    // await fetchAllInfoData();
                                    try {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              side: BorderSide(
                                                  color: Colors.black38,
                                                  width: 0.5),
                                            ),
                                            contentPadding:
                                                EdgeInsets.all(16.0),
                                            content: isRefreshInfo
                                                ? Center(
                                                    child:
                                                        CircularProgressIndicator())
                                                : Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Align(
                                                        alignment:
                                                            Alignment.topRight,
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child: Icon(
                                                              Icons.close,
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      _buildInfoRow(
                                                        "Battery Serial Number:",
                                                        batterySerialNumber
                                                                .isNotEmpty
                                                            ? batterySerialNumber
                                                            : "Fetching...",
                                                      ),
                                                      SizedBox(height: 10),
                                                      _buildInfoRow(
                                                        "Software Version:",
                                                        softwareVersion
                                                                .isNotEmpty
                                                            ? softwareVersion
                                                            : "Fetching...",
                                                      ),
                                                      SizedBox(height: 10),
                                                      _buildInfoRow(
                                                        "Hardware Version:\n",
                                                        hardwareVersion
                                                                .isNotEmpty
                                                            ? hardwareVersion
                                                            : "Fetching...",
                                                      ),
                                                    ],
                                                  ),
                                          );
                                        },
                                      );
                                    } catch (e) {
                                      debugPrint("Error displaying dialog: $e");
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Color(0xffD41414),
                                    child: isRefreshInfo
                                        ? Padding(
                                            padding: EdgeInsets.all(10.0),
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            "i",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(
                                  height: 180.h,
                                  width: 180.h,
                                  child: InkWell(
                                    onTap: () async {
                                      setState(() {
                                        _isParsingSoc = true;
                                      });

                                      sendData('0x90');
                                      await Future.delayed(
                                          Duration(seconds: 1));
                                      parseSoc(_receivedData);
                                      setState(() {
                                        _isParsingSoc = false;
                                        _receivedData = "";
                                      });
                                    },
                                    child: LiquidCircularProgressIndicator(
                                      value: soc / 100,
                                      valueColor: AlwaysStoppedAnimation(
                                        getProgressColor(),
                                      ),
                                      backgroundColor: Colors.white,
                                      borderColor: Colors.black38,
                                      borderWidth: 0.5,
                                      direction: Axis.vertical,
                                      center: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'SOC',
                                            style: TextStyle(
                                              fontSize: 22.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            _isParsingSoc
                                                ? "Loading..."
                                                : "$soc%",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 45.sp,
                                              fontWeight: FontWeight.w700,
                                              color: soc <= 60
                                                  ? Colors.black
                                                  : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        resetToDefaults();
                                        // Show the loading indicator for 1 second.
                                        Future.delayed(Duration(seconds: 1))
                                            .then((_) async {
                                          try {
                                            // After 1 second, start fetching data with a timeout mechanism.
                                            await Future.any([
                                              fetchAllRefreshData(),
                                              Future.delayed(
                                                Duration(seconds: 3),
                                                () => throw TimeoutException(
                                                    "The operation took too long"),
                                              ),
                                            ]);
                                          } catch (e) {
                                            if (e is TimeoutException) {
                                              print(
                                                  "Operation timed out after 3 seconds");
                                            } else {
                                              print("An error occurred: $e");
                                            }
                                          }
                                        });
                                      },
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Color(0xffD41414),
                                        child: isRefresh
                                            ? Padding(
                                                padding: EdgeInsets.all(10.0),
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Icon(
                                                Icons.sync,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 10.h,
                                    ),
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Color(0xffD41414),
                                      child: StreamBuilder<int>(
                                          stream: _cycleController.stream,
                                          initialData: cycle,
                                          builder: (context, snapshot) {
                                            final currentCycle =
                                                snapshot.data ?? 0;
                                            return Text(
                                              "$currentCycle",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            );
                                          }),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            SizedBox(
                              height: 20.h,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.grey.shade400,
                                        spreadRadius: 0.5,
                                        blurRadius: 3),
                                  ],
                                  color: Color(0xfff2f2f2),
                                  border: Border.all(
                                      color: Colors.black38, width: 0.5),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4.0, vertical: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          isLoadingSecondBox = true;
                                        });
                                        sendData("0x90");
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        parseVoltage(_receivedData);
                                        parseCurrent(_receivedData);

                                        setState(() {
                                          _receivedData = "";
                                        });
                                        sendData("0x93");
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        parseRemCap(_receivedData);
                                        setState(() {
                                          isLoadingSecondBox = false;
                                          _receivedData = "";
                                        });
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          isLoadingSecondBox
                                              ? Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Color(
                                                              0xffD41414)),
                                                )
                                              : Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () async {
                                                        setState(() {
                                                          isLoadingSecondBox =
                                                              true;
                                                        });
                                                        sendData("0x90");
                                                        await Future.delayed(
                                                            Duration(
                                                                seconds: 1));
                                                        parseVoltage(
                                                            _receivedData);
                                                        parseCurrent(
                                                            _receivedData);

                                                        setState(() {
                                                          _receivedData = "";
                                                        });
                                                        sendData("0x93");
                                                        await Future.delayed(
                                                            Duration(
                                                                seconds: 1));
                                                        parseRemCap(
                                                            _receivedData);
                                                        setState(() {
                                                          isLoadingSecondBox =
                                                              false;
                                                          _receivedData = "";
                                                        });
                                                      },
                                                      child: FirstSection(
                                                        img:
                                                            'assets/voltlogo.png',
                                                        name: 'Voltage',
                                                        value: _isParsingVoltage
                                                            ? 'Loading...'
                                                            : '${cumvoltage.toStringAsFixed(3)} V',
                                                      ),
                                                    ),
                                                    VerticalDivider(
                                                      color: Colors.black,
                                                      thickness: 2,
                                                    ),
                                                    InkWell(
                                                      onTap: () async {
                                                        setState(() {
                                                          isLoadingSecondBox =
                                                              true;
                                                        });
                                                        sendData("0x90");
                                                        await Future.delayed(
                                                            Duration(
                                                                seconds: 1));
                                                        parseVoltage(
                                                            _receivedData);
                                                        parseCurrent(
                                                            _receivedData);

                                                        setState(() {
                                                          _receivedData = "";
                                                        });
                                                        sendData("0x93");
                                                        await Future.delayed(
                                                            Duration(
                                                                seconds: 1));
                                                        parseRemCap(
                                                            _receivedData);
                                                        setState(() {
                                                          isLoadingSecondBox =
                                                              false;
                                                          _receivedData = "";
                                                        });
                                                      },
                                                      child: FirstSection(
                                                        img:
                                                            'assets/currentlogo.png',
                                                        name: 'Current',
                                                        value: _isParsingCurrent
                                                            ? 'Loading...'
                                                            : '${current.toStringAsFixed(3)} A',
                                                      ),
                                                    ),
                                                    VerticalDivider(
                                                      color: Colors.black,
                                                      thickness: 2,
                                                    ),
                                                    InkWell(
                                                      onTap: () async {
                                                        setState(() {
                                                          isLoadingSecondBox =
                                                              true;
                                                        });
                                                        sendData("0x90");
                                                        await Future.delayed(
                                                            Duration(
                                                                seconds: 1));
                                                        parseVoltage(
                                                            _receivedData);
                                                        parseCurrent(
                                                            _receivedData);

                                                        setState(() {
                                                          _receivedData = "";
                                                        });
                                                        sendData("0x93");
                                                        await Future.delayed(
                                                            Duration(
                                                                seconds: 1));
                                                        parseRemCap(
                                                            _receivedData);
                                                        setState(() {
                                                          isLoadingSecondBox =
                                                              false;
                                                          _receivedData = "";
                                                        });
                                                      },
                                                      child: FirstSection(
                                                        img:
                                                            'assets/remcaplogo.png',
                                                        name: 'Rem Cap',
                                                        value: _isParsingRemCap
                                                            ? 'Loading...'
                                                            : '${(remcap / 1000).toStringAsFixed(3)} Ah',
                                                      ),
                                                    ),
                                                  ],
                                                )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 12.h,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.grey.shade400,
                                        spreadRadius: 0.5,
                                        blurRadius: 3),
                                  ],
                                  color: Color(0xfff2f2f2),
                                  border: Border.all(
                                      color: Colors.black38, width: 0.5),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 5.0, vertical: 10.0),
                                child: isLoadingFirstBox
                                    ? Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: CircularProgressIndicator(
                                              color: Color(0xffD41414)),
                                        ),
                                      )
                                    : InkWell(
                                        onTap: () async {
                                          setState(() {
                                            isLoadingFirstBox = true;
                                          });
                                          sendData("0x93");
                                          await Future.delayed(
                                              Duration(seconds: 1));
                                          parseChargingState(_receivedData);
                                          _receivedData = "";
                                          sendData("0x97");
                                          await Future.delayed(
                                              Duration(seconds: 1));
                                          parseBalance(_receivedData);
                                          setState(() {
                                            isLoadingFirstBox = false;
                                            _receivedData = "";
                                          });
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                InkWell(
                                                  onTap: () {},
                                                  child: SecondSectionCharge(
                                                    name: "ChgrStatus",
                                                    value: "$chargerState",
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {},
                                                  child: SecondSection(
                                                      name: "DisMos",
                                                      value:
                                                          "$dischargeMosState"),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SecondSection(
                                                  name: "Balance",
                                                  value: "$balanceState",
                                                ),
                                                InkWell(
                                                  onTap: () {},
                                                  child: SecondSection(
                                                      name: "ChgMos",
                                                      value: "$chargeMosState"),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: 12.h,
                            ),
                            InkWell(
                              onTap: () async {
                                await _handleStatusInformationTap();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black38,
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: isLoadingFifthhBox
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xffD41414),
                                        ),
                                      )
                                    : ExpansionTile(
                                        initiallyExpanded: true,
                                        leading: Icon(
                                          Icons.info,
                                          color: Color(0xffD41414),
                                          size: 35,
                                        ),
                                        title: Text(
                                          'Status Information',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18.sp,
                                          ),
                                        ),
                                        children:
                                            parsedErrorLevels.map((error) {
                                          // Determine styles based on error level
                                          Color tileColor = error['level'] == 1
                                              ? Colors.white
                                              : error['level'] == 2
                                                  ? Colors.red
                                                  : Colors.transparent;

                                          Color textColor = error['level'] == 1
                                              ? Colors.black
                                              : error['level'] == 2
                                                  ? Colors.white
                                                  : Colors.grey.shade800;

                                          IconData iconData =
                                              error['level'] == 1
                                                  ? Icons.warning
                                                  : Icons.error;

                                          Color iconColor = error['level'] == 1
                                              ? Colors.orange
                                              : Colors.white;

                                          return ListTile(
                                            tileColor: tileColor,
                                            leading: Icon(
                                              iconData,
                                              color: iconColor,
                                              size: 25,
                                            ),
                                            title: Text(
                                              error['name'],
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: 10.h,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.grey.shade400,
                                        spreadRadius: 0.5,
                                        blurRadius: 3),
                                  ],
                                  color: Color(0xfff2f2f2),
                                  border: Border.all(
                                      color: Colors.black38, width: 0.5),
                                  borderRadius: BorderRadius.circular(10)),
                              child: isLoadingThirdBox
                                  ? Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xffD41414)),
                                    )
                                  : InkWell(
                                      onTap: () async {
                                        setState(() {
                                          isLoadingThirdBox = true;
                                          _receivedData = "";
                                        });
                                        sendData("0x91");
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        parseVMaxoltage(_receivedData);
                                        parseVMinVoltage(_receivedData);
                                        _receivedData = "";
                                        sendData("0x90");
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        parseVoltage(_receivedData);
                                        parseCurrent(_receivedData);
                                        Future.delayed(
                                            Duration(milliseconds: 500));
                                        _process0x52();

                                        _receivedData = "";
                                        sendData("0x93");
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        parseRemCap(_receivedData);

                                        setState(() {
                                          avgvoltage =
                                              (minvoltage + maxvoltage) / 2;
                                          voltdiff =
                                              (maxvoltage) - (minvoltage);
                                          power =
                                              (gathervoltage * current) / 1000;

                                          isLoadingThirdBox = false;
                                          _receivedData = "";
                                        });
                                      },
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    isLoadingThirdBox = true;
                                                    _receivedData = "";
                                                  });
                                                  sendData("0x91");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVMaxoltage(
                                                      _receivedData);
                                                  parseVMinVoltage(
                                                      _receivedData);

                                                  _receivedData = "";
                                                  sendData("0x90");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVoltage(_receivedData);

                                                  parseCurrent(_receivedData);
                                                  Future.delayed(Duration(
                                                      milliseconds: 500));
                                                  _process0x52();
                                                  _process0x50();
                                                  _processNoCycle();
                                                  sendData("0x93");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseRemCap(_receivedData);

                                                  setState(() {
                                                    avgvoltage = (minvoltage +
                                                            maxvoltage) /
                                                        2;
                                                    voltdiff = (maxvoltage) -
                                                        (minvoltage);
                                                    power = (gathervoltage *
                                                            current) /
                                                        1000;
                                                    int u = (cumcharge /
                                                            (batterycapacity /
                                                                1000))
                                                        .toInt();
                                                    noofTemp = u;

                                                    isLoadingThirdBox = false;
                                                    _receivedData = "";
                                                  });
                                                },
                                                child: ThirdSection(
                                                  name: "Max Voltage",
                                                  img: "assets/maxvol.png",
                                                  value: _isParsingMaxVoltage
                                                      ? "..."
                                                      : "$maxvoltage V",
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    isLoadingThirdBox = true;
                                                    _receivedData = "";
                                                  });
                                                  sendData("0x91");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVMaxoltage(
                                                      _receivedData);
                                                  parseVMinVoltage(
                                                      _receivedData);
                                                  _receivedData = "";
                                                  sendData("0x90");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVoltage(_receivedData);

                                                  parseCurrent(_receivedData);
                                                  Future.delayed(Duration(
                                                      milliseconds: 500));
                                                  _process0x52();
                                                  _process0x50();
                                                  _processNoCycle();
                                                  sendData("0x93");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseRemCap(_receivedData);

                                                  setState(() {
                                                    avgvoltage = (minvoltage +
                                                            maxvoltage) /
                                                        2;
                                                    voltdiff = (maxvoltage) -
                                                        (minvoltage);
                                                    power = (gathervoltage *
                                                            current) /
                                                        1000;
                                                    int u = (cumcharge /
                                                            (batterycapacity /
                                                                1000))
                                                        .toInt();
                                                    noofcycle = u;
                                                    isLoadingThirdBox = false;
                                                    _receivedData = "";
                                                  });
                                                },
                                                child: ThirdSection(
                                                  name: "Min Voltage",
                                                  img: "assets/minvol.png",
                                                  value: _isParsingMinVoltage
                                                      ? "..."
                                                      : "$minvoltage V",
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    isLoadingThirdBox = true;
                                                    _receivedData = "";
                                                  });
                                                  sendData("0x91");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVMaxoltage(
                                                      _receivedData);
                                                  parseVMinVoltage(
                                                      _receivedData);
                                                  _receivedData = "";
                                                  sendData("0x90");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVoltage(_receivedData);

                                                  parseCurrent(_receivedData);
                                                  Future.delayed(Duration(
                                                      milliseconds: 500));
                                                  _process0x52();
                                                  _process0x50();
                                                  _processNoCycle();
                                                  sendData("0x93");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseRemCap(_receivedData);

                                                  setState(() {
                                                    avgvoltage = (minvoltage +
                                                            maxvoltage) /
                                                        2;
                                                    voltdiff = (maxvoltage) -
                                                        (minvoltage);
                                                    power = (gathervoltage *
                                                            current) /
                                                        1000;
                                                    int u = (cumcharge /
                                                            (batterycapacity /
                                                                1000))
                                                        .toInt();
                                                    noofcycle = u;
                                                    isLoadingThirdBox = false;
                                                    _receivedData = "";
                                                  });
                                                },
                                                child: ThirdSection(
                                                  name: "Avg Voltage",
                                                  img: "assets/avgvol.png",
                                                  value: _isParsingAvgVoltage
                                                      ? "..."
                                                      : "${avgvoltage.toStringAsFixed(3)} V",
                                                ),
                                              )
                                            ],
                                          ),
                                          SizedBox(
                                            height: 2.h,
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    isLoadingThirdBox = true;
                                                    _receivedData = "";
                                                  });
                                                  sendData("0x91");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVMaxoltage(
                                                      _receivedData);
                                                  parseVMinVoltage(
                                                      _receivedData);
                                                  _receivedData = "";
                                                  sendData("0x90");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVoltage(_receivedData);
                                                  Future.delayed(Duration(
                                                      milliseconds: 500));
                                                  _process0x52();
                                                  _process0x50();
                                                  _processNoCycle();

                                                  parseCurrent(_receivedData);

                                                  sendData("0x93");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseRemCap(_receivedData);

                                                  setState(() {
                                                    avgvoltage = (minvoltage +
                                                            maxvoltage) /
                                                        2;
                                                    voltdiff = (maxvoltage) -
                                                        (minvoltage);
                                                    power = (gathervoltage *
                                                            current) /
                                                        1000;
                                                    int u = (cumcharge /
                                                            (batterycapacity /
                                                                1000))
                                                        .toInt();
                                                    noofcycle = u;
                                                    isLoadingThirdBox = false;
                                                    _receivedData = "";
                                                  });
                                                },
                                                child: ThirdSection(
                                                  name: "Voltage Diff",
                                                  img: "assets/voldiff.png",
                                                  value: _isParsingVoltageDifference
                                                      ? "..."
                                                      : "${voltdiff.toStringAsFixed(3)} V",
                                                ),
                                              ),
                                              InkWell(
                                                  onTap: () async {
                                                    setState(() {
                                                      isLoadingThirdBox = true;
                                                      _receivedData = "";
                                                    });
                                                    sendData("0x91");
                                                    await Future.delayed(
                                                        Duration(seconds: 1));
                                                    parseVMaxoltage(
                                                        _receivedData);
                                                    parseVMinVoltage(
                                                        _receivedData);
                                                    _receivedData = "";
                                                    sendData("0x90");
                                                    await Future.delayed(
                                                        Duration(seconds: 1));
                                                    parseVoltage(_receivedData);
                                                    Future.delayed(Duration(
                                                        milliseconds: 500));
                                                    _process0x52();
                                                    _process0x50();
                                                    _processNoCycle();

                                                    parseCurrent(_receivedData);

                                                    sendData("0x93");
                                                    await Future.delayed(
                                                        Duration(seconds: 1));
                                                    parseRemCap(_receivedData);

                                                    setState(() {
                                                      avgvoltage = (minvoltage +
                                                              maxvoltage) /
                                                          2;
                                                      voltdiff = (maxvoltage) -
                                                          (minvoltage);
                                                      power = (gathervoltage *
                                                              current) /
                                                          1000;
                                                      int u = (cumcharge /
                                                              (batterycapacity /
                                                                  1000))
                                                          .toInt();
                                                      noofcycle = u;
                                                      isLoadingThirdBox = false;
                                                      _receivedData = "";
                                                    });
                                                  },
                                                  child: ThirdSection(
                                                    name: "Cycles",
                                                    img: "assets/cycle.png",
                                                    value: "$noofcycle",
                                                  )),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    isLoadingThirdBox = true;
                                                    _receivedData = "";
                                                  });
                                                  sendData("0x91");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVMaxoltage(
                                                      _receivedData);
                                                  parseVMinVoltage(
                                                      _receivedData);
                                                  _receivedData = "";
                                                  sendData("0x90");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVoltage(_receivedData);
                                                  Future.delayed(Duration(
                                                      milliseconds: 500));
                                                  _process0x52();
                                                  _process0x50();
                                                  _processNoCycle();

                                                  parseCurrent(_receivedData);

                                                  sendData("0x93");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseRemCap(_receivedData);

                                                  setState(() {
                                                    avgvoltage = (minvoltage +
                                                            maxvoltage) /
                                                        2;
                                                    voltdiff = (maxvoltage) -
                                                        (minvoltage);
                                                    power = (gathervoltage *
                                                            current) /
                                                        1000;
                                                    int u = (cumcharge /
                                                            (batterycapacity /
                                                                1000))
                                                        .toInt();
                                                    noofcycle = u;
                                                    isLoadingThirdBox = false;
                                                    _receivedData = "";
                                                  });
                                                },
                                                child: ThirdSection(
                                                  name: "Power KW",
                                                  img: "assets/power.png",
                                                  value:
                                                      "${power.toStringAsFixed(3)} kw",
                                                ),
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            SizedBox(
                              height: 10.h,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.grey.shade400,
                                        spreadRadius: 0.5,
                                        blurRadius: 3),
                                  ],
                                  color: Color(0xfff2f2f2),
                                  border: Border.all(
                                      color: Colors.black38, width: 0.5),
                                  borderRadius: BorderRadius.circular(10)),
                              child: isLoadingFourthBox
                                  ? Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xffD41414)),
                                    )
                                  : InkWell(
                                      onTap: () async {
                                        setState(() {
                                          isLoadingFourthBox = true;
                                        });
                                        sendData("0x94");
                                        parseNoofTemp(_receivedData);
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        setState(() {
                                          _receivedData = "";
                                        });
                                        sendData("0x96");
                                        await Future.delayed(
                                            Duration(seconds: 1));
                                        parseIndNoofBattery(_receivedData);
                                        setState(() {
                                          isLoadingFourthBox = false;
                                          _receivedData = "";
                                        });
                                      },
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 5.0, vertical: 3.0),
                                            child: InkWell(
                                              onTap: () async {
                                                setState(() {
                                                  isLoadingFourthBox = true;
                                                });
                                                sendData("0x94");
                                                parseNoofTemp(_receivedData);
                                                await Future.delayed(
                                                    Duration(seconds: 1));

                                                sendData("0x96");
                                                await Future.delayed(
                                                    Duration(seconds: 1));
                                                parseIndNoofBattery(
                                                    _receivedData);
                                                setState(() {
                                                  isLoadingFourthBox = false;
                                                  _receivedData = "";
                                                });
                                              },
                                              child: Row(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 5.0,
                                                            vertical: 4.0),
                                                    child: Text(
                                                      "No of Temps: ",
                                                      style: TextStyle(
                                                          fontSize: 19.sp,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black),
                                                    ),
                                                  ),
                                                  Text(
                                                    _isParsingnoOfTemp
                                                        ? "..."
                                                        : "$noofTemp",
                                                    style: TextStyle(
                                                        fontSize: 19.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xffD41414)),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 8.h,
                                          ),
                                          Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 5.0,
                                                  vertical: 2.0),
                                              child: Padding(
                                                padding:
                                                    EdgeInsets.only(bottom: 15),
                                                child: InkWell(
                                                  onTap: () async {
                                                    setState(() {
                                                      isLoadingFourthBox = true;
                                                    });
                                                    sendData("0x96");
                                                    parseIndNoofBattery(
                                                        _receivedData);
                                                    await Future.delayed(
                                                        Duration(seconds: 1));

                                                    sendData("0x94");
                                                    parseNoofTemp(
                                                        _receivedData);

                                                    setState(() {
                                                      isLoadingFourthBox =
                                                          false;
                                                      _receivedData = "";
                                                    });
                                                  },
                                                  child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceAround,
                                                      children: [
                                                        FirstSectionTemp(
                                                          img:
                                                              "assets/temp.png",
                                                          name: "T1",
                                                          value:
                                                              _isParsingIndBattery
                                                                  ? "..."
                                                                  : "$t1 °C",
                                                          allValues: [
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t1 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t2 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t3 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t4 °C",
                                                          ],
                                                          mintemp: mintemp,
                                                          maxtemp: maxtemp,
                                                        ),
                                                        FirstSectionTemp(
                                                          img:
                                                              "assets/temp.png",
                                                          name: "T2",
                                                          value:
                                                              _isParsingIndBattery
                                                                  ? "..."
                                                                  : "$t2 °C",
                                                          allValues: [
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t1 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t2 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t3 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t4 °C",
                                                          ],
                                                          mintemp: mintemp,
                                                          maxtemp: maxtemp,
                                                        ),
                                                        FirstSectionTemp(
                                                          img:
                                                              "assets/temp.png",
                                                          name: "T3",
                                                          value:
                                                              _isParsingIndBattery
                                                                  ? "..."
                                                                  : "$t3 °C",
                                                          allValues: [
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t1 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t2 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t3 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t4 °C",
                                                          ],
                                                          mintemp: mintemp,
                                                          maxtemp: maxtemp,
                                                        ),
                                                        FirstSectionTemp(
                                                          img:
                                                              "assets/temp.png",
                                                          name: "T4",
                                                          value:
                                                              _isParsingIndBattery
                                                                  ? "..."
                                                                  : "$t4 °C",
                                                          allValues: [
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t1 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t2 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t3 °C",
                                                            _isParsingIndBattery
                                                                ? "..."
                                                                : "$t4 °C",
                                                          ],
                                                          mintemp: mintemp,
                                                          maxtemp: maxtemp,
                                                        ),
                                                      ]),
                                                ),
                                              ))
                                        ],
                                      ),
                                    ),
                            ),
                            SizedBox(
                              height: 10.h,
                            ),
                            Container(
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.grey.shade400,
                                          spreadRadius: 0.5,
                                          blurRadius: 3),
                                    ],
                                    color: Color(0xfff2f2f2),
                                    border: Border.all(
                                        color: Colors.black38, width: 0.5),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: InkWell(
                                    onTap: () async {
                                      setState(() {
                                        isLoadingMosBox = true;
                                        _receivedData = "";
                                      });
                                      await Future.delayed(
                                          Duration(milliseconds: 200));
                                      sendData("0x04");
                                      await Future.delayed(
                                          Duration(milliseconds: 200));
                                      parseMosTemp(_receivedData);
                                      setState(() {
                                        isLoadingMosBox = false;
                                        _receivedData = "";
                                      });
                                    },
                                    child: isLoadingMosBox
                                        ? Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xffD41414),
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'MOS Temperature',
                                                style: TextStyle(
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black),
                                              ),
                                              Text(
                                                '$mostemp °C',
                                                style: TextStyle(
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xffD41414)),
                                              )
                                            ],
                                          ),
                                  ),
                                )),
                            SizedBox(
                              height: 5.h,
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade400,
                                      spreadRadius: 0.5,
                                      blurRadius: 3,
                                    ),
                                  ],
                                  color: Color(0xfff2f2f2),
                                  border: Border.all(
                                      color: Colors.black38, width: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: isLoadingSixthBox
                                      ? Center(
                                          child: CircularProgressIndicator(
                                              color: Color(0xffD41414)),
                                        )
                                      : InkWell(
                                          onTap: () async {
                                            setState(() {
                                              isLoadingSixthBox = true;
                                            });
                                            sendData("0x94");
                                            await Future.delayed(
                                                Duration(seconds: 1));
                                            parseNoofBattery(_receivedData);

                                            sendData("0x95");
                                            await Future.delayed(
                                                Duration(seconds: 1));
                                            parseVoltages(_receivedData);
                                            setState(() {
                                              isLoadingSixthBox = false;
                                              _receivedData = "";
                                            });
                                          },
                                          child: Column(
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 5.0,
                                                    vertical: 3.0),
                                                child: InkWell(
                                                  onTap: () async {
                                                    setState(() {
                                                      isLoadingSixthBox = true;
                                                    });
                                                    sendData("0x94");
                                                    await Future.delayed(
                                                        Duration(seconds: 1));
                                                    parseNoofBattery(
                                                        _receivedData);
                                                    await Future.delayed(
                                                        Duration(seconds: 1));
                                                    setState(() {
                                                      _receivedData = "";
                                                    });
                                                    sendData("0x95");
                                                    await Future.delayed(
                                                        Duration(seconds: 1));
                                                    parseVoltages(
                                                        _receivedData);
                                                    setState(() {
                                                      isLoadingSixthBox = false;
                                                      _receivedData = "";
                                                    });
                                                  },
                                                  child: Row(
                                                    children: [
                                                      Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 5.0,
                                                                vertical: 4.0),
                                                        child: Text(
                                                          "No of Battery Strings: ",
                                                          style: TextStyle(
                                                              fontSize: 19.sp,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                      ),
                                                      Text(
                                                        _isParsingNoofBattery
                                                            ? "..."
                                                            : "$noofBattery",
                                                        style: TextStyle(
                                                            fontSize: 19.sp,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                                0xffD41414)),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    isLoadingSixthBox = true;
                                                  });
                                                  sendData("0x94");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseNoofBattery(
                                                      _receivedData);
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  setState(() {
                                                    _receivedData = "";
                                                  });
                                                  sendData("0x95");
                                                  await Future.delayed(
                                                      Duration(seconds: 1));
                                                  parseVoltages(_receivedData);
                                                  setState(() {
                                                    isLoadingSixthBox = false;
                                                    _receivedData = "";
                                                  });
                                                },
                                                child: SizedBox(
                                                  height: 320,
                                                  child: GridView.count(
                                                    crossAxisCount: 4,
                                                    crossAxisSpacing: 0.05,
                                                    mainAxisSpacing: 0.005,
                                                    children: List.generate(15,
                                                        (index) {
                                                      final batteryNumber =
                                                          index + 1;
                                                      final voltage =
                                                          voltages[index];
                                                      final Color fillColor =
                                                          (batteryNumber ==
                                                                  maxBattery)
                                                              ? Color(
                                                                  0xff008000)
                                                              : (batteryNumber ==
                                                                      minBattery)
                                                                  ? Color(
                                                                      0xffD41414)
                                                                  : Colors.grey[
                                                                      300]!;
                                                      Color fontColor =
                                                          Colors.white;

                                                      return Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 2.0,
                                                                vertical: 2.0),
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Container(
                                                                  width: 55,
                                                                  height: 30,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color:
                                                                        fillColor,
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: (batteryNumber == maxBattery ||
                                                                              batteryNumber ==
                                                                                  minBattery)
                                                                          ? Colors
                                                                              .white
                                                                          : Colors
                                                                              .black,
                                                                      width:
                                                                          1.4,
                                                                    ),
                                                                  ),
                                                                  child: Center(
                                                                    child: Text(
                                                                      '$batteryNumber',
                                                                      style:
                                                                          TextStyle(
                                                                        color: (batteryNumber == maxBattery ||
                                                                                batteryNumber == minBattery)
                                                                            ? fontColor
                                                                            : Colors.black,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        fontSize:
                                                                            16,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                Container(
                                                                  width: 8,
                                                                  height: 12,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: (batteryNumber ==
                                                                                maxBattery ||
                                                                            batteryNumber ==
                                                                                minBattery)
                                                                        ? fillColor
                                                                        : Colors
                                                                            .transparent,
                                                                    border:
                                                                        Border(
                                                                      top: BorderSide(
                                                                          color: (batteryNumber == maxBattery || batteryNumber == minBattery)
                                                                              ? fillColor
                                                                              : Colors
                                                                                  .black,
                                                                          width:
                                                                              1.8),
                                                                      right: BorderSide(
                                                                          color: (batteryNumber == maxBattery || batteryNumber == minBattery)
                                                                              ? fillColor
                                                                              : Colors
                                                                                  .black,
                                                                          width:
                                                                              1.8),
                                                                      bottom: BorderSide(
                                                                          color: (batteryNumber == maxBattery || batteryNumber == minBattery)
                                                                              ? fillColor
                                                                              : Colors
                                                                                  .black,
                                                                          width:
                                                                              1.8),
                                                                      left: BorderSide(
                                                                          color: Colors
                                                                              .transparent,
                                                                          width:
                                                                              0),
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                    width: 3),
                                                              ],
                                                            ),
                                                            Text(
                                                              voltage == 0
                                                                  ? "..."
                                                                  : '${voltage.toStringAsFixed(3)} V',
                                                              style: TextStyle(
                                                                fontSize: 15.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: (batteryNumber ==
                                                                        maxBattery)
                                                                    ? Color(
                                                                        0xff008000)
                                                                    : (batteryNumber ==
                                                                            minBattery)
                                                                        ? Color(
                                                                            0xffD41414)
                                                                        : Colors
                                                                            .black,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 5.h,
                            ),
                          ],
                        )),
            ),
            // Positioned(
            //   bottom: 0,
            //   left: 0,
            //   right: 0,
            //   child: CustomPaint(
            //     painter: WavyBackgroundPainter(
            //       _scrollOffset,
            //       _idleWaveOffset,
            //       isTopWave: false,
            //     ),
            //     size: Size(MediaQuery.of(context).size.width,
            //         150), // Bottom wave height
            //   ),
            // ),
          ],
        ),
      ),
      floatingActionButton: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Color(0xffD41414), // Changes splash effect color
          highlightColor:
              Color(0xffD41414), // Changes highlight (press) effect color
          hoverColor: Colors.black38, // Changes hover color
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.white, // Set the default background color
          elevation: 6, // Adjust elevation for better visibility
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BluetoothDevicePage(),
              ),
            );
            await _refreshConnectionStatus();
            await bluetoothProvider.refreshConnectionStatus();

            if (bluetoothProvider.selectedDevice != null) {
              await bluetoothProvider
                  .connectToDevice(bluetoothProvider.selectedDevice!);
            }
          },
          child: Consumer<BluetoothProvider>(
            builder: (context, bluetoothProvider, child) {
              return Icon(
                bluetoothProvider.selectedDevice != null
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth,
                size: 25.sp,
                color: bluetoothProvider.selectedDevice != null
                    ? Colors.green
                    : Colors.black,
              );
            },
          ),
        ),
      ),
    ));
  }
}

// ignore: must_be_immutable
class ThirdSection extends StatefulWidget {
  ThirdSection(
      {super.key, required this.img, required this.name, required this.value});

  String name, img, value;

  @override
  State<ThirdSection> createState() => _ThirdSectionState();
}

class _ThirdSectionState extends State<ThirdSection> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: [
          Image.asset(widget.img),
          Text(
            widget.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            widget.value,
            style: TextStyle(
              fontSize: 17,
              color: Color(0xffD41414),
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }
}

class SecondSection extends StatefulWidget {
  SecondSection({super.key, required this.name, required this.value});
  String name, value;
  @override
  State<SecondSection> createState() => _SecondSectionState();
}

class _SecondSectionState extends State<SecondSection> {
  @override
  String op = "";
  String getStatusName(String? value) {
    return value == "0"
        ? op = "Ideal"
        : value == "1"
            ? op = "ON"
            : value == "2"
                ? op = "OFF"
                : op = "";
  }

  Color getStatusColor(String? value) {
    return value == "0"
        ? Colors.black // Black for 0
        : value == "1"
            ? Color(0xff008000) // Green for 1
            : value == "2"
                ? Color(0xffD41414) // Red for 2
                : value == ""
                    ? Colors.grey // Grey for empty string
                    : Colors.grey; // Default Grey
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            "${widget.name}: ",
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black),
          ),
          CircleAvatar(
            backgroundColor: getStatusColor(widget.value),
            radius: 8,
          ),
          SizedBox(
            width: 2.w,
          ),
          Text(
            getStatusName(widget.value),
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: getStatusColor(widget.value)),
          )
        ],
      ),
    );
  }
}

class SecondSectionCharge extends StatefulWidget {
  SecondSectionCharge({super.key, required this.name, required this.value});
  String name, value;
  @override
  State<SecondSectionCharge> createState() => _SecondSectionChargeState();
}

class _SecondSectionChargeState extends State<SecondSectionCharge> {
  @override
  String op = "";
  String getStatusName(String? value) {
    return value == "0"
        ? op = "Ideal"
        : value == "1"
            ? op = "Chg"
            : value == "2"
                ? op = "Dischg"
                : op = "";
  }

  Color getStatusColor(String? value) {
    return value == "0"
        ? Colors.black // Black for 0
        : value == "1"
            ? Color(0xff008000) // Green for 1
            : value == "2"
                ? Color(0xffD41414) // Red for 2
                : value == ""
                    ? Colors.grey // Grey for empty string
                    : Colors.grey; // Default Grey
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            "${widget.name}: ",
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black),
          ),
          CircleAvatar(
            backgroundColor: getStatusColor(widget.value),
            radius: 8,
          ),
          SizedBox(
            width: 2.w,
          ),
          Text(
            getStatusName(widget.value),
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: getStatusColor(widget.value)),
          )
        ],
      ),
    );
  }
}

class FirstSection extends StatefulWidget {
  FirstSection(
      {super.key, required this.img, required this.name, required this.value});
  String name, value, img;

  @override
  State<FirstSection> createState() => _FirstSectionState();
}

class _FirstSectionState extends State<FirstSection> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          widget.img,
          height: 28.h,
          width: 28.w,
        ),
        SizedBox(
          width: 5.w,
        ),
        Column(
          children: [
            Text(
              widget.name,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.value,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffD41414)),
            ),
          ],
        )
      ],
    );
  }
}

class FirstSectionTemp extends StatefulWidget {
  FirstSectionTemp({
    super.key,
    required this.img,
    required this.name,
    required this.value,
    required this.allValues,
    required this.mintemp,
    required this.maxtemp,
  });
  String name, value, img;
  List<String> allValues;
  int mintemp, maxtemp; // Add these variables.

  @override
  State<FirstSectionTemp> createState() => _FirstSectionTempState();
}

class _FirstSectionTempState extends State<FirstSectionTemp> {
  Color getTextColor() {
    try {
      List<double> temps = widget.allValues
          .map((v) => double.parse(v.replaceAll("°C", "")))
          .toList();

      double currentValue = double.parse(widget.value.replaceAll("°C", ""));
      double minValue = widget.mintemp.toDouble(); // Use mintemp from widget.
      double maxValue = widget.maxtemp.toDouble(); // Use maxtemp from widget.

      if (temps.every((temp) => temp == temps[0])) {
        return Colors.black;
      }

      if (currentValue == minValue) {
        return Color(0xffD41414); // Minimum temperature
      } else if (currentValue == maxValue) {
        return Color(0xff008000); // Maximum temperature
      } else {
        return Colors.black; // Others
      }
    } catch (e) {
      return Colors.black; // Default to black in case of error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.thermostat,
          size: 35,
          color: getTextColor(),
        ),
        SizedBox(
          width: 5.w,
        ),
        Column(
          children: [
            Text(
              widget.name,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: getTextColor(), // Dynamic color based on temperature.
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _buildInfoRow(String label, String value) {
  return RichText(
    text: TextSpan(
      text: "$label ",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black,
        fontSize: 20,
      ),
      children: [
        TextSpan(
          text: value,
          style: TextStyle(
            color: Color(0xffD41414),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ],
    ),
  );
}
// class WavyBackgroundPainter extends CustomPainter {
//   final double scrollOffset;
//   final double idleWaveOffset;
//   final bool isTopWave;

//   WavyBackgroundPainter(this.scrollOffset, this.idleWaveOffset, {required this.isTopWave});

//   @override
//   void paint(Canvas canvas, Size size) {
//     // Different wave behavior for top and bottom waves
//     if (isTopWave) {
//       _drawTopWave(canvas, size);
//     } else {
//       _drawBottomWave(canvas, size);
//     }
//   }

//   // Enhanced top wave with realistic effects
//   void _drawTopWave(Canvas canvas, Size size) {
//     Paint paint = Paint()
//       ..shader = LinearGradient(
//         begin: Alignment.topLeft,
//         end: Alignment.bottomRight,
//         colors: [
//           Color(0xffD41414).withOpacity(0.4),
//           Color(0xffD41414).withOpacity(0.2),
//         ],
//         stops: [0.0, 1.0],
//       ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)); // Gradient effect

//     Path path = Path();
//     double waveHeight = 50.0 + sin(idleWaveOffset * 0.1) * 10; // Dynamic height with idle movement
//     double waveWidth = size.width / 1.5;
//     double yOffset = 0;

//     path.moveTo(0, yOffset);
//     for (double i = 0; i <= size.width; i += 10) {
//       path.lineTo(
//         i,
//         sin((i / waveWidth) * 2 * pi + (scrollOffset * 0.02) + idleWaveOffset) *
//                 waveHeight +
//             50,
//       );
//     }
//     path.lineTo(size.width, 0);
//     path.lineTo(0, 0);
//     path.close();

//     canvas.drawPath(path, paint);
//   }

//   // Enhanced bottom wave with realistic effects
//   void _drawBottomWave(Canvas canvas, Size size) {
//     Paint paint = Paint()
//       ..shader = LinearGradient(
//         begin: Alignment.topLeft,
//         end: Alignment.bottomRight,
//         colors: [
//           Color(0xffD41414).withOpacity(0.6),
//           Color(0xffD41414).withOpacity(0.3),
//         ],
//         stops: [0.0, 1.0],
//       ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)); // Gradient effect

//     Path path = Path();
//     double waveHeight = 30.0 + sin(idleWaveOffset * 0.2) * 8; // Dynamic height with idle movement
//     double waveWidth = size.width / 1.4;
//     double yOffset = size.height;

//     path.moveTo(0, yOffset);
//     for (double i = 0; i <= size.width; i += 10) {
//       path.lineTo(
//         i,
//         yOffset +
//             sin((i / waveWidth) * 2 * pi + (scrollOffset * 0.05) + idleWaveOffset) *
//                 waveHeight,
//       );
//     }
//     path.lineTo(size.width, size.height);
//     path.lineTo(0, size.height);
//     path.close();

//     canvas.drawPath(path, paint);
//   }

//   @override
//   bool shouldRepaint(covariant WavyBackgroundPainter oldDelegate) {
//     return oldDelegate.scrollOffset != scrollOffset ||
//         oldDelegate.idleWaveOffset != idleWaveOffset;
//   }
// }

class WavyBackgroundPainter extends CustomPainter {
  final double scrollOffset;
  final double idleWaveOffset;
  final bool isTopWave;

  WavyBackgroundPainter(this.scrollOffset, this.idleWaveOffset,
      {required this.isTopWave});

  @override
  void paint(Canvas canvas, Size size) {
    if (isTopWave) {
      _drawTopWave(canvas, size);
    } else {
      _drawBottomWave(canvas, size);
    }
  }

  // Top wave with Perlin noise and enhanced movement
  void _drawTopWave(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Color(0xffD41414).withOpacity(0.2);
    Path path = Path();

    double waveHeight = 50.0;
    double waveWidth = size.width / 1.5;
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

  // Bottom wave with Perlin noise and enhanced movement
  void _drawBottomWave(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Color(0xffD41414).withOpacity(0.3);
    Path path = Path();

    double waveHeight = 30.0;
    double waveWidth = size.width / 1.3;
    double yOffset = size.height;

    path.moveTo(0, yOffset);
    for (double i = 0; i <= size.width; i += 10) {
      path.lineTo(
        i,
        yOffset +
            sin((i / waveWidth) * 2 * pi +
                    (scrollOffset * 0.02 * 0.5) +
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
