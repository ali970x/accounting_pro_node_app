import "package:flutter/material.dart";

class PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0),
    );

    if (actions.isEmpty) return titleText;

    final actionWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText,
              const SizedBox(height: 10),
              actionWrap,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: titleText),
            const SizedBox(width: 12),
            Flexible(
              flex: 3,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: actionWrap,
              ),
            ),
          ],
        );
      },
    );
  }
}
