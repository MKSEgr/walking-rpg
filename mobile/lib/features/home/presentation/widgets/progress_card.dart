import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final double progress;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(subtitle),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}
