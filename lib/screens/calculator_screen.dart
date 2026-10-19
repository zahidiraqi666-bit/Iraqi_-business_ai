import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../money.dart';
import '../widgets/common.dart';

/// Every number here is computed by tested SQL functions on the server.
class CalculatorScreen extends StatelessWidget {
  final Business business;
  const CalculatorScreen({super.key, required this.business});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حاسبة الربح'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'ربح القطعة'),
              Tab(text: 'كلفة الاستيراد'),
              Tab(text: 'نقطة التعادل'),
              Tab(text: 'أثر الخصم'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _MarginTab(business.currency),
          _LandedTab(business),
          _BreakEvenTab(business.currency),
          _DiscountTab(business.currency),
        ]),
      ),
    );
  }
}

/// Shared scaffold for a calculator tab: fields, a button, and the result.
abstract class _CalcState<T extends StatefulWidget> extends State<T> {
  String currency = 'IQD';
  FinResult? result;
  bool busy = false;
  String? error;

  Future<FinResult?> compute();
  List<Widget> fields();
  List<Widget> resultRows(FinResult r);

  Widget currencyPicker() => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'IQD', label: Text('دينار')),
          ButtonSegment(value: 'USD', label: Text('دولار')),
        ],
        selected: {currency},
        onSelectionChanged: (s) => setState(() {
          currency = s.first;
          result = null;
        }),
      );

  Widget moneyField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: label, suffixText: Money.symbol(currency)),
        ),
      );

  Widget intField(TextEditingController c, String label, {String? suffix}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        ),
      );

  int? money(TextEditingController c, {bool optional = false}) {
    if (optional && c.text.trim().isEmpty) return 0;
    return Money.parse(c.text, currency);
  }

  Future<void> run() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await compute();
      setState(() {
        result = r;
        if (r == null) error = 'تأكد من إدخال كل الأرقام بشكل صحيح';
      });
    } catch (e) {
      setState(() => error = 'تعذر الحساب: ${e.toString()}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...fields(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : run,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(busy ? 'جارٍ الحساب...' : 'احسب'),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (r != null)
          Card(
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.value != null) ...resultRows(r),
                  WarningList(r.warnings),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MarginTab extends StatefulWidget {
  final String currency;
  const _MarginTab(this.currency);
  @override
  State<_MarginTab> createState() => _MarginTabState();
}

class _MarginTabState extends _CalcState<_MarginTab> {
  final _sell = TextEditingController();
  final _cost = TextEditingController();

  @override
  void initState() {
    super.initState();
    currency = widget.currency;
  }

  @override
  void dispose() {
    _sell.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Future<FinResult?> compute() async {
    final s = money(_sell), c = money(_cost);
    if (s == null || c == null) return null;
    return Repo.unitMargin(s, c, currency);
  }

  @override
  List<Widget> fields() => [
        currencyPicker(),
        moneyField(_cost, 'سعر الكلفة للقطعة'),
        moneyField(_sell, 'سعر البيع للقطعة'),
      ];

  @override
  List<Widget> resultRows(FinResult r) {
    final pct = r.numOf('margin_percent');
    return [
      InfoRow('الربح بالقطعة', Money.format(r.intOf('unit_margin'), r.currency),
          bold: true),
      InfoRow('نسبة الربح من سعر البيع',
          pct == null ? '—' : '${pct.toStringAsFixed(2)}٪'),
    ];
  }
}

class _LandedTab extends StatefulWidget {
  final Business business;
  const _LandedTab(this.business);
  @override
  State<_LandedTab> createState() => _LandedTabState();
}

class _LandedTabState extends _CalcState<_LandedTab> {
  final _unit = TextEditingController();
  final _qty = TextEditingController();
  final _ship = TextEditingController();
  final _customs = TextEditingController();
  final _other = TextEditingController();
  bool _toIqd = false;
  double? _rate;

  @override
  void initState() {
    super.initState();
    currency = 'USD';
    Repo.latestUsdRate(widget.business.id).then((r) {
      if (mounted) setState(() => _rate = r);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_unit, _qty, _ship, _customs, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Future<FinResult?> compute() async {
    final unit = money(_unit);
    final qty = Money.parseInt(_qty.text);
    final ship = money(_ship, optional: true);
    final customs = money(_customs, optional: true);
    final other = money(_other, optional: true);
    if (unit == null || qty == null || ship == null || customs == null || other == null) {
      return null;
    }
    final convert = _toIqd && currency == 'USD';
    return Repo.landedCost(
      unitPrice: unit,
      quantity: qty,
      shipping: ship,
      customs: customs,
      other: other,
      currency: currency,
      target: convert ? 'IQD' : null,
      rate: convert ? _rate : null,
    );
  }

  @override
  List<Widget> fields() => [
        currencyPicker(),
        moneyField(_unit, 'سعر القطعة من المورّد'),
        intField(_qty, 'الكمية'),
        moneyField(_ship, 'الشحن (المجموع)'),
        moneyField(_customs, 'الكمرك (المجموع)'),
        moneyField(_other, 'مصاريف أخرى (المجموع)'),
        if (currency == 'USD')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('اعرض النتيجة بالدينار'),
            subtitle: Text(_rate == null
                ? 'أدخل سعر الصرف أولاً من «المزيد ← سعر صرف الدولار»'
                : 'سعر الصرف: ${_rate!.toStringAsFixed(0)} دينار للدولار'),
            value: _toIqd,
            onChanged: (v) => setState(() => _toIqd = v),
          ),
      ];

  @override
  List<Widget> resultRows(FinResult r) => [
        InfoRow('كلفة القطعة واصلة',
            Money.format(r.intOf('unit_landed_cost'), r.currency),
            bold: true),
        InfoRow('الكلفة الكلية',
            Money.format(r.intOf('total_landed_cost'), r.currency)),
      ];
}

class _BreakEvenTab extends StatefulWidget {
  final String currency;
  const _BreakEvenTab(this.currency);
  @override
  State<_BreakEvenTab> createState() => _BreakEvenTabState();
}

class _BreakEvenTabState extends _CalcState<_BreakEvenTab> {
  final _fixed = TextEditingController();
  final _sell = TextEditingController();
  final _var = TextEditingController();

  @override
  void initState() {
    super.initState();
    currency = widget.currency;
  }

  @override
  void dispose() {
    _fixed.dispose();
    _sell.dispose();
    _var.dispose();
    super.dispose();
  }

  @override
  Future<FinResult?> compute() async {
    final f = money(_fixed), s = money(_sell), v = money(_var);
    if (f == null || s == null || v == null) return null;
    return Repo.breakEven(f, s, v, currency);
  }

  @override
  List<Widget> fields() => [
        currencyPicker(),
        moneyField(_fixed, 'المصاريف الثابتة الشهرية (إيجار، رواتب...)'),
        moneyField(_sell, 'سعر بيع القطعة'),
        moneyField(_var, 'كلفة القطعة'),
      ];

  @override
  List<Widget> resultRows(FinResult r) => [
        InfoRow('تحتاج تبيع شهرياً', '${r.intOf('break_even_units')} قطعة',
            bold: true),
        InfoRow('يعني مبيعات بقيمة',
            Money.format(r.intOf('break_even_revenue'), r.currency)),
        InfoRow('ربح القطعة',
            Money.format(r.intOf('contribution_margin_per_unit'), r.currency)),
      ];
}

class _DiscountTab extends StatefulWidget {
  final String currency;
  const _DiscountTab(this.currency);
  @override
  State<_DiscountTab> createState() => _DiscountTabState();
}

class _DiscountTabState extends _CalcState<_DiscountTab> {
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _pct = TextEditingController();

  @override
  void initState() {
    super.initState();
    currency = widget.currency;
  }

  @override
  void dispose() {
    _price.dispose();
    _cost.dispose();
    _pct.dispose();
    super.dispose();
  }

  @override
  Future<FinResult?> compute() async {
    final p = money(_price), c = money(_cost);
    final pctText = Money.normalizeDigits(_pct.text).replaceAll('٫', '.').trim();
    final pct = double.tryParse(pctText);
    if (p == null || c == null || pct == null || pct < 0 || pct > 100) {
      return null;
    }
    return Repo.discountImpact(p, (pct * 100).round(), c, currency);
  }

  @override
  List<Widget> fields() => [
        currencyPicker(),
        moneyField(_price, 'سعر البيع الحالي'),
        moneyField(_cost, 'كلفة القطعة'),
        intField(_pct, 'نسبة الخصم', suffix: '٪'),
      ];

  @override
  List<Widget> resultRows(FinResult r) {
    final mult = r.numOf('sales_multiplier_to_keep_profit');
    return [
      InfoRow('السعر بعد الخصم', Money.format(r.intOf('new_price'), r.currency),
          bold: true),
      InfoRow('الربح بالقطعة قبل',
          Money.format(r.intOf('old_unit_margin'), r.currency)),
      InfoRow('الربح بالقطعة بعد',
          Money.format(r.intOf('new_unit_margin'), r.currency)),
      if (mult != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              'حتى يبقى ربحك نفسه، لازم تبيع ${mult.toStringAsFixed(2)} ضعف الكمية الحالية.'),
        ),
    ];
  }
}
