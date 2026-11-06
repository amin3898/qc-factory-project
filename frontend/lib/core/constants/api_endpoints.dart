class ApiEndpoints {
  static const String baseUrl = 'http://172.23.229.195:8000/api';

  // تغییر مسیر مدل‌ها برای هماهنگی با بک‌اند /api/models-list/
  static const String models = '$baseUrl/models-list/';
  static const String createModel = '$baseUrl/models/';

  static String getSpecs(String modelCode, String stationCode) =>
      '$baseUrl/models/$modelCode/specs/$stationCode';

  static const String submitInspection = '$baseUrl/inspections/';
  static const String evaluateValue = '$baseUrl/specs/evaluate/';
}
