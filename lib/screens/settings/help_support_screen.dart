import 'package:flutter/material.dart';

// PLACEHOLDER: replace the content below with your real FAQ / contact
// details. Structure is left simple on purpose so it's easy to extend.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Help and Support'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.email_outlined, color: Colors.deepPurple),
                  title: Text('Contact Support'),
                  subtitle: Text('support@powertrackergh.com'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.question_answer_outlined,
                    color: Colors.deepPurple,
                  ),
                  title: Text('Frequently Asked Questions'),
                  subtitle: Text('Answers to common questions coming soon'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
