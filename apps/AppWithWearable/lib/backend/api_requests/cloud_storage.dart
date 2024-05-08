import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';

AuthClient? authClient;

void authenticateGCP() async {
  var prefs = await SharedPreferences.getInstance();
  var credentialsBase64 = prefs.getString('gcpCredentials') ?? '';
  if (credentialsBase64.isEmpty) {
    debugPrint('No GCP credentials found');
    return;
  }
  final credentialsBytes = base64Decode(credentialsBase64);
  String decodedString = utf8.decode(credentialsBytes);
  final credentials = ServiceAccountCredentials.fromJson(jsonDecode(decodedString));
  var scopes = ['https://www.googleapis.com/auth/devstorage.full_control'];
  authClient = await clientViaServiceAccount(credentials, scopes);
  debugPrint('Authenticated');
}

Future<String?> uploadFile(File file) async {
  var prefs = await SharedPreferences.getInstance();
  String bucketName = prefs.getString('gcpBucketName') ?? '';
  if (bucketName.isEmpty) {
    debugPrint('No bucket name found');
    return null;
  }
  String fileName = file.path.split('/')[file.path.split('/').length - 1];
  String url = 'https://storage.googleapis.com/upload/storage/v1/b/$bucketName/o?uploadType=media&name=$fileName';

  try {
    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer ${authClient?.credentials.accessToken.data}',
        'Content-Type': 'audio/wav',
      },
      body: file.readAsBytesSync(),
    );

    if (response.statusCode == 200) {
      // var json = jsonDecode(response.body);
      debugPrint('Upload successful');
      return fileName;
    } else {
      debugPrint('Failed to upload');
    }
  } catch (e) {
    debugPrint('Error uploading file: $e');
  }
  return null;
}

// Download file method
Future<File?> downloadFile(String objectName, String saveFileName) async {
  final directory = await getApplicationDocumentsDirectory();
  String saveFilePath = '${directory.path}/$saveFileName';
  if (File(saveFilePath).existsSync()) {
    debugPrint('File already exists: $saveFileName');
    return File(saveFilePath);
  }

  var prefs = await SharedPreferences.getInstance();
  String bucketName = prefs.getString('gcpBucketName') ?? '';
  if (bucketName.isEmpty) {
    debugPrint('No bucket name found');
    return null;
  }

  try {
    var response = await http.get(
      Uri.parse('https://storage.googleapis.com/storage/v1/b/$bucketName/o/$objectName?alt=media'),
      headers: {'Authorization': 'Bearer ${authClient?.credentials.accessToken.data}'},
    );

    if (response.statusCode == 200) {
      final file = File('${directory.path}/$saveFileName');
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('Download successful: $saveFileName');
      return file;
    } else {
      debugPrint('Failed to download: ${response.body}');
    }
  } catch (e) {
    debugPrint('Error downloading file: $e');
  }
  return null;
}
