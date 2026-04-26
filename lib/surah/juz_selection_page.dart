import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/content_detail_services/api_service.dart';
import 'surah_page.dart';

class JuzSelectionPage extends StatefulWidget {
  const JuzSelectionPage({super.key});

  @override
  State<JuzSelectionPage> createState() => _JuzSelectionPageState();
}

class _JuzSelectionPageState extends State<JuzSelectionPage> {
  List<int> availableJuz = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchAvailableJuz();
  }

  Future<void> _fetchAvailableJuz() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();
    final token = authProvider.token;

    if (token == null) {
      setState(() {
        isLoading = false;
        error = "Please log in to view Juz list.";
      });
      return;
    }

    try {
      final response = await apiService.get('surahs', token: token);
      final List<dynamic> surahs = response['data'];
      
      // Extract unique juz numbers that are not null
      final Set<int> juzSet = {};
      for (var surah in surahs) {
        if (surah['juz'] != null) {
          juzSet.add(int.parse(surah['juz'].toString()));
        }
      }

      final List<int> sortedJuz = juzSet.toList()..sort();

      setState(() {
        availableJuz = sortedJuz;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = "Failed to load Juz list. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    const Color primaryColor = Color(0xFF009B77);

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xFF002147) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isNightMode ? Colors.grey[900] : primaryColor,
        elevation: 0,
        title: const Text('Select Juz',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _buildBody(isNightMode, primaryColor),
    );
  }

  Widget _buildBody(bool isNightMode, Color primaryColor) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF009B77)),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, style: TextStyle(color: isNightMode ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  error = null;
                });
                _fetchAvailableJuz();
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (availableJuz.isEmpty) {
      return Center(
        child: Text(
          'No Juz content available yet.',
          style: TextStyle(color: isNightMode ? Colors.white70 : Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: availableJuz.length,
      itemBuilder: (context, index) {
        final juzNumber = availableJuz[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            color: isNightMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isNightMode ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SurahPage(filterJuz: juzNumber),
                  ),
                );
              },
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isNightMode ? Colors.teal.shade800 : Colors.teal.shade50,
                  radius: 24,
                  child: Text(
                    '$juzNumber',
                    style: TextStyle(
                      color: isNightMode ? Colors.white : primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  'Juz $juzNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isNightMode ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'View surahs in this juz',
                  style: TextStyle(
                    color: isNightMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isNightMode ? Colors.white38 : Colors.grey[400],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
