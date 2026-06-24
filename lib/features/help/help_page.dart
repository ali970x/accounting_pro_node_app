import "package:flutter/material.dart";
import "../../core/app_controller.dart";
import "../../widgets/modern_card.dart";

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final theme = Theme.of(context);
    final steps = isAr ? _arabicSteps : _englishSteps;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(isAr ? "دليل الاستخدام" : "User Guide", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        ModernCard(
          padding: const EdgeInsets.all(18),
          child: Text(
            isAr
                ? "ابدأ بهذه الخطوات بالترتيب حتى يصير daftr جاهز لإدارة المحل بدون مساعدة."
                : "Follow these steps in order to get daftr ready for the shop workflow without help.",
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < steps.length; i++) _HelpStep(index: i + 1, step: steps[i]),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _HelpStep extends StatelessWidget {
  final int index;
  final _GuideStep step;

  const _HelpStep({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(index.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(step.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final String body;

  const _GuideStep(this.title, this.body);
}

const _arabicSteps = [
  _GuideStep("الدخول والحسابات", "ما عاد في إنشاء حساب عام. المدير ينشئ الحسابات من لوحة الإدارة، ويقدر يفعّل أو يحظر أو يحذف أي مستخدم."),
  _GuideStep("أضف الموردين والزباين", "افتح الأسماء وأضف الموردين والزباين مع أرقام واتسابهم. هذا ضروري للديون والجردات والمشاركة."),
  _GuideStep("ابن المخزون", "من المخزون أضف التصنيف، التصنيف الفرعي، ونوعية الصنف. مثال: بطاطا > بطاطا حلوة > فئة أولى."),
  _GuideStep("ورّد الكمية من المورد", "افتح الصنف واضغط توريد كمية. اختر المورد، الكمية، سعر الشراء، والعملة. إذا بقي الحساب دين فعّل خيار الدين."),
  _GuideStep("نفّذ المبيع بسرعة", "من صفحة المبيع اختر الصنف ثم التصنيف الفرعي، وبعدها ابحث عن المنتج أو النوعية. الاقتراحات تظهر فقط من التصنيف المحدد."),
  _GuideStep("سجّل البضاعة التالفة", "افتح البضاعة التالفة، اختر التصنيف والتصنيف الفرعي، ابحث عن المنتج، ثم أدخل الكمية التالفة وقيمة الخسارة. خيار التصفير يرجع الكميات للمخزون."),
  _GuideStep("سجّل المصاريف", "أي مصروف للمحل سجّله من صفحة المصاريف مع العملة الصحيحة حتى يظهر بصافي الربح."),
  _GuideStep("راجع الديون", "الديون مجمعة حسب الزبون أو المورد ومفصولة حسب العملة. افتح الشخص لتشاهد الفواتير والدفعات."),
  _GuideStep("فلتر السجلات والديون", "استخدم يوم، أسبوع، شهر، أو تاريخ مخصص لعرض الفترة التي تريدها فقط."),
  _GuideStep("تابع التقارير", "التقارير تعرض المبيعات، المصاريف، الربح، الديون، التالف، والرسم الشهري. كبسة طويلة على صافي الربح تعرض الربح الفعلي بعد الديون."),
  _GuideStep("شارك الجردات والفواتير", "من المخزون شارك فاتورة الجردة العامة. ومن الأسماء شارك حركة البضاعة أو الجردة المالية عبر واتساب."),
  _GuideStep("أرسل مراجعتك", "من صفحة حول التطبيق افتح رأيك واقتراحاتك واكتب ملاحظتك. التطبيق يرسلها للسيرفر، والسيرفر يوصلها للمطور بالإيميل عند ضبط SMTP."),
  _GuideStep("تصفير الأرباح", "زر تصفير الأرباح في التقارير يبدأ حساب الربح من لحظة الضغط، من دون حذف الفواتير القديمة."),
];

const _englishSteps = [
  _GuideStep("Login and accounts", "Public registration is disabled. The admin creates accounts and can activate, block, or delete any user."),
  _GuideStep("Add contacts", "Add suppliers and customers with WhatsApp numbers. This powers debts, ledgers, and sharing."),
  _GuideStep("Build inventory", "Create category, subcategory, and item quality. Example: Potato > Sweet potato > Grade one."),
  _GuideStep("Receive stock", "Open an item and add stock. Pick supplier, quantity, cost, and currency. Mark as debt only when unpaid."),
  _GuideStep("Create sales fast", "Choose category and subcategory first, then search product or quality. Suggestions stay inside the selected filters."),
  _GuideStep("Record damaged goods", "Open Damaged Goods, choose category/subcategory, search item, enter damaged quantity and loss cost. Reset damaged data restores stock when needed."),
  _GuideStep("Record expenses", "Record shop expenses with the correct currency so net profit stays accurate."),
  _GuideStep("Review debts", "Debts are grouped by customer or supplier and separated by currency. Open a person for invoices and payments."),
  _GuideStep("Filter records and debts", "Use Day, Week, Month, or Custom Date to focus records and debts on the period you need."),
  _GuideStep("Use reports", "Reports show sales, expenses, profit, debts, damaged goods, and monthly charts. Long-press net profit to see actual profit after debts."),
  _GuideStep("Share statements", "Share the full inventory invoice from inventory, or goods/financial statements from contacts via WhatsApp."),
  _GuideStep("Send feedback", "Open About, then Feedback & Suggestions. The app sends it to the server, and the server emails it to the developer when SMTP is configured."),
  _GuideStep("Reset profits", "Reset profits starts profit calculations from that moment without deleting old invoices."),
];
