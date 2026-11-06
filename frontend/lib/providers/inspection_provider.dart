import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InspectionProvider with ChangeNotifier {
  String _serverIp = '127.0.0.1';
  String _serverPort = '8000';

  bool _isLoading = false;
  Map<String, List<String>> _modelStationsMap = {};
  List<String> _availableModels = [];
  List<String> _currentAvailableStations = [];
  List<dynamic> _currentSpecs = [];

  // Getterها
  String get baseUrl => 'http://$_serverIp:$_serverPort/api';
  String get serverIp => _serverIp;
  String get serverPort => _serverPort;
  bool get isLoading => _isLoading;
  Map<String, List<String>> get modelStationsMap => _modelStationsMap;
  List<String> get availableModels => _availableModels;
  List<String> get currentAvailableStations => _currentAvailableStations;
  List<dynamic> get currentSpecs => _currentSpecs;

  InspectionProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIp = prefs.getString('server_ip') ?? '127.0.0.1';
    _serverPort = prefs.getString('server_port') ?? '8000';
    notifyListeners();
    fetchModelsAndStations();
  }

  Future<void> updateServerConfig(String ip, String port) async {
    _serverIp = ip;
    _serverPort = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('server_port', port);
    notifyListeners();
    fetchModelsAndStations();
  }

  Future<void> fetchModelsAndStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl/models-list/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        Map<String, List<String>> map = {};
        for (var item in data) {
          String modelCode = item['code'] ?? item['model_code'] ?? '';
          var stations = item['stations'] ?? item['station_code'];

          if (modelCode.isNotEmpty) {
            if (!map.containsKey(modelCode)) {
              map[modelCode] = [];
            }
            if (stations is List) {
              for (var st in stations) {
                if (!map[modelCode]!.contains(st.toString())) {
                  map[modelCode]!.add(st.toString());
                }
              }
            } else if (stations is String && stations.isNotEmpty) {
              if (!map[modelCode]!.contains(stations)) {
                map[modelCode]!.add(stations);
              }
            }
          }
        }
        _modelStationsMap = map;
        _availableModels = map.keys.toList();
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateStationsForModel(String? modelCode) {
    if (modelCode != null && _modelStationsMap.containsKey(modelCode)) {
      _currentAvailableStations = _modelStationsMap[modelCode]!;
    } else {
      _currentAvailableStations = [];
    }
    _currentSpecs = [];
    notifyListeners();
  }

  Future<void> loadStationSpecs(String modelCode, String stationCode) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models/$modelCode/specs/$stationCode'),
      );
      if (response.statusCode == 200) {
        _currentSpecs = json.decode(utf8.decode(response.bodyBytes));
      } else {
        _currentSpecs = [];
      }
    } catch (e) {
      _currentSpecs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ذخیره مشخصات و استانداردهای ایستگاه در سرور
  Future<bool> saveStationSpecs(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/station-specs'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchModelsAndStations(); // به‌روزرسانی لیست مدل‌ها پس از ذخیره موفق
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error saving specs: $e');
      return false;
    }
  }

  // حذف کامل یک مدل به همراه تمامی ایستگاه‌ها و استانداردهای آن
  Future<bool> deleteEntireModel(String modelCode) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/models/$modelCode'),
      );
      if (response.statusCode == 200) {
        await fetchModelsAndStations();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting model: $e');
      return false;
    }
  }

  Future<bool> deleteStationFromModel(
    String modelCode,
    String stationCode,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/models/$modelCode/stations/$stationCode'),
      );
      if (response.statusCode == 200) {
        await fetchModelsAndStations();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendInspection(Map<String, dynamic> inspectionData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inspections'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(inspectionData),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteInspection(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/inspections/$id'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateInspection(int id, String auditor, String shift) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inspections/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'auditor_name': auditor, 'shift': shift}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}