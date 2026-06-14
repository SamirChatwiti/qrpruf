import 'package:flutter/material.dart';

class DashboardRecentActivity extends StatelessWidget {
  final List<Map<String, dynamic>> proofs;

  const DashboardRecentActivity({super.key, required this.proofs});

  @override
  Widget build(BuildContext context) {
    if (proofs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'النشاطات الأخيرة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111111),
                ),
              ),
              TextButton(
                onPressed: () {
                   // Navigate to full list
                },
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF5BBDB1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: proofs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final proof = proofs[index];
              return _buildProofListItem(proof);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProofListItem(Map<String, dynamic> proof) {
    final title = proof['selected_type'] ?? 'دليل';
    final status = proof['status'] ?? 'pending';
    final date = proof['created_at']?.toString().split('T')[0] ?? '';

    final isVerified = status == 'valid';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified ? Icons.verified_user_outlined : Icons.pending_actions,
              color: isVerified ? const Color(0xFF2E7D32) : const Color(0xFFF57C00),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF909090),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
