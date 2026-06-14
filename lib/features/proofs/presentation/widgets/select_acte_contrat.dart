import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectActeContrat extends ConsumerWidget {
  const SelectActeContrat({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
               'إدارة العقود والالتزامات',
               textAlign: TextAlign.center,
               style: TextStyle(
                 fontFamily: 'Cairo',
                 fontWeight: FontWeight.bold,
                 fontSize: 18,
               ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('صفحة العقود قريبا')),
                );
              },
              icon: const Icon(Icons.description),
              label: const Text('العقود والالتزامات', style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
