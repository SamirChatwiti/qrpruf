import 'package:flutter/material.dart';

class PageTemplateWassit extends StatelessWidget {
  final Widget body;
  final Widget header;
  final Widget? footer;

  final VoidCallback? onBack;
  final VoidCallback? onNext;

  const PageTemplateWassit({
    super.key,
    required this.body,
    required this.header,
    this.footer,
    this.onBack,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final double topSafe = MediaQuery.of(context).viewPadding.top;
    final double bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    final bool showNav = onBack != null || onNext != null;

    final TextStyle baseTextStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ) ??
            const TextStyle(color: Colors.black87);

    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: DefaultTextStyle.merge(
        style: baseTextStyle,
        child: Column(
          children: [
            SizedBox(height: topSafe),
            SizedBox(
              height: 65,
              width: double.infinity,
              child: header,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: body,
                  ),
                  if (showNav)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 12, 30, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (onBack != null)
                            TextButton(
                              onPressed: onBack,
                              child: const Text(
                                '⬅️ عودة',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          if (onNext != null)
                            TextButton(
                              onPressed: onNext,
                              child: const Text(
                                'التالي ➡️',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (footer != null)
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: footer,
                    ),
                ],
              ),
            ),
            SizedBox(height: bottomSafe),
          ],
        ),
      ),
    );
  }
}
