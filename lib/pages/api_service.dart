import 'dart:convert';
import 'package:flutter_foreground/pages/utils.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://kt-location.vercel.app/api";

  // Register User
  static Future<Map<String, dynamic>?> registerUser(
      String name, String phoneNumber, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "phone_number": phoneNumber,
        "email_id": email,
        "password": password
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // Login User
  static Future<Map<String, dynamic>?> loginUser(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email_id": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // Fetch User Locations
  static Future<List<dynamic>?> getUserLocations(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/location?userId=$userId'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // Update Location
  static Future<bool> updateLocation(String locationId, String newName) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/location/$locationId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"locationName": newName}),
    );

    return response.statusCode == 200;
  }

  // Delete Location
  static Future<bool> deleteLocation(String locationId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/location/$locationId'),
      headers: {"Content-Type": "application/json"},
    );

    return response.statusCode == 200;
  }

  // Get Geo Location
  static Future<Map<String, dynamic>?> getGeoLocation(
      String locationId, String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/location/$locationId?userId=$userId'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // Save Location
  static Future<bool> saveLocation(
      String userId, String locationName, List<String> locations) async {
    List geoAxis = convertToList(locations);
    final response = await http.post(
      Uri.parse('$baseUrl/location'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "locationName": locationName,
        "geoaxis": geoAxis,
      }),
    );

    // print();

    return response.statusCode == 201;
  }
}
