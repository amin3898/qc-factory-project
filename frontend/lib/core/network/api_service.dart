import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';

class ApiService {
  Future<List<dynamic>> fetchSpecs(String modelCode, String stationCode) async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.getSpecs(modelCode, stationCode)),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('خطا در دریافت استانداردهای ایستگاه');
    }
  }

  Future<Map<String, dynamic>> submitInspection(
    Map<String, dynamic> inspectionData,
  ) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.submitInspection),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(inspectionData),
    );

    if (response.statusCode == 201) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('خطا در ثبت اطلاعات بازرسی');
    }
  }
}
