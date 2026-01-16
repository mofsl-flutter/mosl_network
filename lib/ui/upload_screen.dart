import 'dart:io';
import 'package:base_network/models/api_enums.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mosl_network/network/dio_impl.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart';
import 'package:mosl_network/network/helper/constants.dart' show Constants;
import 'package:mosl_network/network/models/User/UserProfileModels.pb.dart'
    show ProfilePictureResponse;
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' show basename;

class CameraUploadScreen extends StatefulWidget {
  const CameraUploadScreen({super.key});

  static const routeName = '/upload';

  @override
  _CameraUploadScreenState createState() => _CameraUploadScreenState();
}

class _CameraUploadScreenState extends State<CameraUploadScreen> {
  File? _imageFile;
  bool _uploading = false;

  Future<void> _captureAndUpload() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera permission denied")),
      );
      return;
    }

    // Capture image
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    // Optional: Crop image
    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop'),
      ],
    );

    if (cropped == null) return;

    final file = File(cropped.path);

    setState(() => _imageFile = file);

    // Upload
    await _uploadFile(file);
  }

  Future<void> _uploadFile(File file) async {
    setState(() => _uploading = true);

    try {
      final fileName = basename(file.path);
      final formData = FormData.fromMap(
        {
          'file': MultipartFile.fromBytes(
            file.readAsBytesSync(),
            filename: fileName,
            contentType: MediaType("image", "png"),
          ),
        },
      );

      final apiRequest = ApiRequestBuilder()
          .apiVersion(Constants.apiV3_0)
          .request(formData)
          .url('api/UserProfile/ProfilePictureUpload')
          .apiIdentifier(ApiIdentifier.trader)
          .requestType(HttpMethod.upload)
          .build();

      final response = await DioImpl()
          .callApiWithDioClient(apiRequest, ProfilePictureResponse());
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text("Upload success: ${response.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Camera Capture & Upload")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _imageFile != null
                ? Image.file(_imageFile!, height: 200)
                : Text("No image captured"),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploading ? null : _captureAndUpload,
              child: Text(_uploading ? "Uploading..." : "Capture & Upload"),
            ),
          ],
        ),
      ),
    );
  }
}
