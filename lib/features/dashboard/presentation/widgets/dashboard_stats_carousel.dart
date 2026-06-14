import 'package:flutter/material.dart';

class DashboardStatsCarousel extends StatelessWidget {
  final int totalProofs;
  final int verifiedProofs;

  const DashboardStatsCarousel({
    super.key,
    required this.totalProofs,
    required this.verifiedProofs,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: PageView(
        children: [
          _buildStatCard(
            title: 'إجمالي الأدلة',
            count: totalProofs.toString(),
            icon: Icons.shield_outlined,
            color: const Color(0xFF5BBDB1),
          ),
          _buildStatCard(
            title: 'الأدلة الصالحة',
            count: verifiedProofs.toString(),
            icon: Icons.verified_user_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const Spacer(),
            Text(
              count,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
