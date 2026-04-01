import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadImagePage extends StatefulWidget {
  @override
  _UploadImagePageState createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final picker = ImagePicker();

  Future<XFile?> pickImage() async {
    return await picker.pickImage(source: ImageSource.camera);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Upload Image")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            XFile? image = await pickImage();
            print(image?.path);
          },
          child: Text("Capture Image"),
        ),
      ),
    );
  }
}