import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddUserDetailsScreen extends StatefulWidget {
  final String imagePath;

  const AddUserDetailsScreen({super.key, required this.imagePath});

  @override
  _AddUserDetailsScreenState createState() => _AddUserDetailsScreenState();
}

class _AddUserDetailsScreenState extends State<AddUserDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accessLevelController = TextEditingController();

  Future<void> _uploadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    print("image = ${widget.imagePath}");

    if (userId.isEmpty) {
      print('No userId found in SharedPreferences');
      return;
    }

    final uri = Uri.parse('${dotenv.env['API_BASE_URL']}/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = userId
      ..fields['name'] = _nameController.text
      ..fields['accessLevel'] = _accessLevelController.text;

    if (widget.imagePath.startsWith('http://') || widget.imagePath.startsWith('https://')) {
      request.fields['imageUrl'] = widget.imagePath;
    } else {
      final mimeType = lookupMimeType(widget.imagePath);
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        widget.imagePath,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));
    }

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        print('Image uploaded successfully');
      } else {
        print('Image upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during image upload: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = widget.imagePath.startsWith('http://') || widget.imagePath.startsWith('https://')
        ? Image.network(widget.imagePath, height: 200)
        : Image.file(File(widget.imagePath), height: 200);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add User Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            imageWidget,
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accessLevelController,
              decoration: const InputDecoration(labelText: "Access Level"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newUser = {
                  'name': _nameController.text,
                  'accessLevel': _accessLevelController.text,
                  'imagePath': widget.imagePath,
                };

                await _uploadImage();

                Navigator.pop(context, newUser);
              },
              child: const Text("Save User"),
            ),
          ],
        ),
      ),
    );
  }
}
