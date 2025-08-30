import 'package:flutter/material.dart';

class UserDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<String> pictures;
  final String? currentUserId;

  const UserDetailsScreen({
    required this.user,
    required this.pictures,
    required this.currentUserId,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = currentUserId == user['userId'];

    return Scaffold(
      appBar: AppBar(title: Text('${user['name'] ?? 'User'} Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${user['name'] ?? 'N/A'}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Email: ${user['email'] ?? 'N/A'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Role: ${user['role'] ?? 'N/A'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Pictures:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child:
                  pictures.isNotEmpty
                      ? ListView.builder(
                        itemCount: pictures.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Image.network(
                              pictures[index],
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      )
                      : Center(child: Text('No pictures available')),
            ),
            if (isCurrentUser) ...[
              SizedBox(height: 16),
              Text(
                'This is the current user.',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
