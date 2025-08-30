import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_user_details_screen.dart'; // Make sure to import the AddUserDetailsScreen

class AccessHistoryScreen extends StatefulWidget {
  @override
  _AccessHistoryScreenState createState() => _AccessHistoryScreenState();
}

class _AccessHistoryScreenState extends State<AccessHistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;
  String errorMessage = '';

  // Function to fetch data from the API
  Future<void> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('${dotenv.env['API_BASE_URL']}/access-history'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          history = data.map((item) {
            return {
              'user': item['user'],
              'time': item['time'],
              'status': item['status'],
              'image_path': item['image_path'], // Add image path here
            };
          }).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
      print("Error: $e");
    }
  }

  // Function to remove all history
  Future<void> clearHistory() async {
    try {
      final response = await http.delete(Uri.parse('${dotenv.env['API_BASE_URL']}/historyDelete'));

      if (response.statusCode == 200) {
        setState(() {
          history.clear(); // Clear the local history list
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('All history cleared successfully'),
        ));
      } else {
        throw Exception('Failed to clear history');
      }
    } catch (e) {
      print("Error clearing history: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to clear history'),
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchHistory(); // Fetch history when screen is loaded
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access History'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () {
              // Show a confirmation dialog before clearing history
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Clear All History'),
                    content: Text('Are you sure you want to clear all history?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                        },
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                          clearHistory(); // Call the function to clear history
                        },
                        child: Text('Confirm'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(child: Text('Error: $errorMessage'))
          : ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          print("Status for ${history[index]['user']}: ${history[index]['status']}");

          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(
                  '${dotenv.env['API_BASE_URL']}/${history[index]['image_path']}',
                ),
                backgroundColor: Colors.grey[200],
              ),
              title: Text(
                history[index]['user'],
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                'Time: ${history[index]['time']}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              trailing: Icon(
                history[index]['status'] == true
                    ? Icons.check_circle
                    : Icons.block,
                color: history[index]['status'] == true
                    ? Colors.green
                    : Colors.red,
                size: 30,
              ),
              onTap: () {
                // Handle the tap here (e.g., show a popup)
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('User Details'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center, // Center the content
                        children: [
                          // Center the image
                          Center(
                            child: Image.network(
                              '${dotenv.env['API_BASE_URL']}/${history[index]['image_path']}',
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('User: ${history[index]['user']}'),
                          Text('Time: ${history[index]['time']}'),
                        ],
                      ),
                      actions: [
                        // Center the buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Show "Add" button only if status is not 'Approved'
                            if (history[index]['status'] != true)
                              TextButton(
                                onPressed: () {
                                  // Navigate to AddUserDetailsScreen and pass the image path
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddUserDetailsScreen(
                                        imagePath: '${dotenv.env['API_BASE_URL']}/${history[index]['image_path']}',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Add'),
                              ),
                            SizedBox(width: 20),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Close the dialog
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
