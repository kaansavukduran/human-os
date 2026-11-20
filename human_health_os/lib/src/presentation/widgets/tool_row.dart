import 'package:flutter/material.dart';

/// A way into a tool or page that is not a daily number (G001): a plain row
/// with its title and one line on what it is for, under its group's heading
/// (Today's tools, the entries of Learn).
/// No leading icon (R016, DESIGN_BRIEF anti-pattern 2): the seven pictures
/// (help, clipboard, calculator, book, figure, leaf, microscope) added no
/// meaning that the title and the group heading did not already give. The
/// chevron stays: it is the one mark that says "opens a page".
class ToolRow extends StatelessWidget {
  const ToolRow({
    super.key,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // A button for assistive technology and the browser, named by its
    // title and hint (an InkWell alone is only a tap target).
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Semantics(
        container: true,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleMedium),
                        Text(
                          hint,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
