import 'dart:math';

Map<String, dynamic> convertToObj(String data) {
  List<String> parts = data.split(',');
  return {
    'latitude': double.parse(parts[0].trim()),
    'longitude': double.parse(parts[1].trim()),
    'timestamp': parts[2].trim(),
  };
}

List<Map<String, dynamic>> convertToList(List<String> dataList) {
  return dataList.map((item) => convertToObj(item)).toList();
}
