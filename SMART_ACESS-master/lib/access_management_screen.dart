import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AccessManagementScreen extends StatefulWidget {
  @override
  _AccessManagementScreenState createState() => _AccessManagementScreenState();
}

class _AccessManagementScreenState extends State<AccessManagementScreen> {
  final String _baseUrl = '${dotenv.env['API_BASE_URL']}'; // Replace with your real API
  List<dynamic> _pictures = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserPictures();
  }

  Future<void> _loadUserPictures() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    if (_userId == null) return;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/pictures/$_userId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pictures = data['pictures'];
        });
      } else {
        print('Failed to load pictures: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _deletePicture(String pictureId) async {
    final response = await http.delete(Uri.parse('$_baseUrl/pictures/$pictureId'));
    print(response);
    if (response.statusCode == 200) {
      setState(() {
        _pictures.removeWhere((pic) => pic['_id'] == pictureId);
      });
    } else {
      print('Delete failed: ${response.statusCode}');
    }
  }

  void _showPictureDetails(Map<String, dynamic> picture) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  '$_baseUrl/${picture['picture']}',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // If the image fails to load, show a default image
                    return Image.asset(
                      'assets/unknown.png',  // Provide the fallback image here
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              Text(
                picture['name'] ?? 'No Name',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Access Level: ${picture['accessLevel'] ?? 'N/A'}',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _deletePicture(picture['_id']);
                  Navigator.pop(context); // Close the dialog after deleting
                },
                icon: Icon(Icons.delete, color: Colors.white),
                label: Text("Delete", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context), // Close button
                icon: Icon(Icons.close, color: Colors.white),
                label: Text("Close", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Access Management')),
      body: _pictures.isEmpty
          ? Center(child: Text('No users found'))
          : ListView.builder(
        itemCount: _pictures.length,
        itemBuilder: (context, index) {
          final pic = _pictures[index];

          final imageUrl = '$_baseUrl/${pic['picture']}';

          return GestureDetector(
            onTap: () => _showPictureDetails(pic),
            child: Card(
              margin: EdgeInsets.all(8.0),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    imageUrl, // Replace with your actual URL
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // If the image fails to load, show a default image
                      return Image.asset(
                        'assets/unknown.png',  // Provide the fallback image here
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),

                title: Text(pic['name'] ?? 'Unknown'),
                subtitle: Text('Access: ${pic['accessLevel'] ?? 'N/A'}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePicture(pic['_id']),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
