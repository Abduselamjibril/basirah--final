import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_service.dart';
import '../providers/auth_provider.dart';
import '../theme_provider.dart';

class AskQuestionPage extends StatefulWidget {
  const AskQuestionPage({super.key});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to ask a question.')),
        );
        return;
      }

      final httpService = AuthHttpService();
      final response = await httpService.post(
        'questions',
        {'question_text': _questionController.text.trim()},
        requireAuth: true,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question submitted successfully! Our team will review it.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final errorData = jsonDecode(response.body);
        String errorMessage = errorData['message'] ?? 'Failed to submit question.';
        
        // If there are specific validation errors, collect them
        if (errorData['errors'] != null && errorData['errors'] is Map) {
          final errors = errorData['errors'] as Map<String, dynamic>;
          final allErrors = [];
          errors.forEach((key, value) {
            if (value is List) {
              allErrors.addAll(value);
            } else {
              allErrors.add(value.toString());
            }
          });
          if (allErrors.isNotEmpty) {
            errorMessage = allErrors.join('\n');
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final primaryColor = const Color(0xFF009B77);

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ask a Question', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.white,
        foregroundColor: isNightMode ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryColor),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          'Have a question about a lesson? Ask here and it will be answered shortly.',
                          style: TextStyle(
                            color: isNightMode ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Your Question',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isNightMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _questionController,
                  maxLines: 8,
                  maxLength: 1000,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your question';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide more details (at least 10 characters)';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Type your question here...',
                    hintStyle: TextStyle(color: isNightMode ? Colors.white38 : Colors.black38),
                    filled: true,
                    fillColor: isNightMode ? Colors.black26 : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isNightMode ? Colors.white12 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF009B77), width: 2),
                    ),
                    errorMaxLines: 3,
                  ),
                  style: TextStyle(color: isNightMode ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Question',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Note: Questions are usually answered within 24-48 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isNightMode ? Colors.white38 : Colors.black45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }
}
