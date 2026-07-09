import "package:flutter/material.dart";

import "../../core/app_controller.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class SmartImportPage extends StatelessWidget {
  const SmartImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = AppScope.of(context).isArabic;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(title: isAr ? "الاستيراد الذكي" : "Smart Import"),
        const SizedBox(height: 16),
        ModernCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? "ميزة قيد التحضير" : "Feature in preparation",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAr
                              ? "هذه الصفحة جاهزة كشكل داخل التطبيق، لكنها مقفلة حالياً حتى يتم تثبيت نموذج الإكسل وطريقة قراءة البيانات بدون أخطاء."
                              : "This page is prepared in the app, but locked for now until the Excel/list format and data-reading rules are finalized.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    icon: Icons.lock_rounded,
                    label: isAr ? "مقفلة حالياً" : "Locked now",
                  ),
                  _StatusChip(
                    icon: Icons.table_chart_rounded,
                    label: isAr ? "بانتظار قالب الإكسل" : "Waiting for Excel",
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final cards = [
              _ImportOptionCard(
                icon: Icons.format_list_bulleted_rounded,
                title: isAr ? "قراءة ليست" : "Read a list",
                body: isAr
                    ? "استقبال لائحة أصناف أو ديون وتحويلها لاحقاً إلى بيانات منظمة."
                    : "Receive item or debt lists and later convert them into structured records.",
              ),
              _ImportOptionCard(
                icon: Icons.image_search_rounded,
                title: isAr ? "قراءة صورة" : "Read an image",
                body: isAr
                    ? "تحليل صورة فاتورة أو ورقة وإظهار مراجعة قبل الحفظ."
                    : "Analyze an invoice or paper image and show a review before saving.",
              ),
              _ImportOptionCard(
                icon: Icons.mic_rounded,
                title: isAr ? "قراءة فويس" : "Read voice",
                body: isAr
                    ? "تحويل التسجيل الصوتي إلى عناصر أو ديون بعد التأكد من الصيغة."
                    : "Turn voice notes into items or debts after the format is confirmed.",
              ),
            ];

            if (!wide) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        ModernCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? "طريقة العمل لاحقاً" : "Planned workflow",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _StepLine(
                index: "1",
                text: isAr
                    ? "ترسل ليست، صورة، أو تسجيل صوتي."
                    : "Send a list, image, or voice note.",
              ),
              _StepLine(
                index: "2",
                text: isAr
                    ? "التطبيق يحللها ويعرض جدول مراجعة قبل الحفظ."
                    : "The app analyzes it and shows a review table before saving.",
              ),
              _StepLine(
                index: "3",
                text: isAr
                    ? "بعد موافقتك، تنضاف البيانات إلى قاعدة البيانات."
                    : "After approval, the data is saved into the database.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ImportOptionCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline_rounded),
            label: Text(AppScope.of(context).isArabic ? "قريباً" : "Soon"),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final String index;
  final String text;

  const _StepLine({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              index,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
