import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../money.dart';
import '../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  final Business business;
  final ValueChanged<int> onOpenTab;
  const HomeScreen(
      {super.key, required this.business, required this.onOpenTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Period { today, week, month }

class _HomeScreenState extends State<HomeScreen> {
  _Period _period = _Period.today;
  late Future<FinResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (_period) {
      _Period.today => today,
      _Period.week => today.subtract(const Duration(days: 6)),
      _Period.month => DateTime(now.year, now.month, 1),
    };
    _future = Repo.salesSummary(widget.business.id, from, today);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    return Scaffold(
      appBar: AppBar(title: Text(b.name)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<FinResult>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return ErrorView(error: snap.error!, onRetry: _refresh);
            }
            final r = snap.data!;
            final cur = r.currency;
            final orders = r.intOf('orders') ?? 0;
            final low = r.intOf('low_stock_products') ?? 0;
            final top = (r.value?['top_products'] as List?) ?? const [];
            final pct = r.numOf('gross_margin_percent');
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<_Period>(
                  segments: const [
                    ButtonSegment(value: _Period.today, label: Text('اليوم')),
                    ButtonSegment(value: _Period.week, label: Text('7 أيام')),
                    ButtonSegment(value: _Period.month, label: Text('هذا الشهر')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() {
                    _period = s.first;
                    _load();
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _Tile(
                            label: 'المبيعات',
                            value: Money.format(r.intOf('revenue'), cur))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Tile(
                            label: 'الربح الإجمالي',
                            value:
                                Money.format(r.intOf('gross_profit'), cur))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _Tile(label: 'عدد الطلبات', value: '$orders')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Tile(
                            label: 'نسبة الربح',
                            value: pct == null
                                ? '—'
                                : '${pct.toStringAsFixed(1)}٪')),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InfoRow('الكلفة', Money.format(r.intOf('cost'), cur)),
                        InfoRow('الخصومات',
                            Money.format(r.intOf('discount'), cur)),
                        InfoRow('متوسط الطلب',
                            Money.format(r.intOf('average_order'), cur)),
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'الربح هنا قبل المصاريف الثابتة (إيجار، رواتب...).',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        WarningList(r.warnings),
                      ],
                    ),
                  ),
                ),
                if (low > 0)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.inventory),
                      title: Text('$low منتج قارب على النفاد'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => widget.onOpenTab(1),
                    ),
                  ),
                const SectionTitle('الأكثر مبيعاً'),
                if (top.isEmpty)
                  const Text('لا توجد مبيعات في هذه الفترة بعد.')
                else
                  ...top.map((t) {
                    final m = Map<String, dynamic>.from(t as Map);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${m['name']}'),
                      subtitle: Text('الكمية: ${m['qty']}'),
                      trailing: Text(Money.format(m['revenue'] as num?, cur)),
                    );
                  }),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => widget.onOpenTab(2),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('تسجيل طلب جديد'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      color: t.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: t.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
