import 'package:flutter/material.dart';

class DashboardEmptyState extends StatelessWidget {
  final VoidCallback onAddProofPressed;

  const DashboardEmptyState({super.key, required this.onAddProofPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Illustration Image (Using existing asset)
          Image.asset(
            'assets/images/sans_preuve/1.png', 
            height: 200,
            errorBuilder: (context, error, stackTrace) => 
               const Icon(Icons.shield_outlined, size: 100, color: Color(0xFF5BBDB1)),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'لا توجد أدلة مسجلة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF111111),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            'ابدأ الآن بتوثيق لحظاتك أو اجتماعاتك المهمة.\nستكون آمنة وموثقة قانونياً.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF909090),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onAddProofPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BBDB1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text(
                'توثيق دليل جديد',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
