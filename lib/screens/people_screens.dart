import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../money.dart';
import '../widgets/common.dart';

/// Simple dialog with text fields; returns the trimmed values or null.
Future<Map<String, String?>?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
  Map<String, String?> initial = const {},
  String requiredKey = 'name',
}) {
  return showDialog<Map<String, String?>>(
    context: context,
    builder: (_) => _FieldsDialog(
        title: title, fields: fields, initial: initial, requiredKey: requiredKey),
  );
}

class _FieldsDialog extends StatefulWidget {
  final String title;
  final Map<String, String> fields;
  final Map<String, String?> initial;
  final String requiredKey;
  const _FieldsDialog({
    required this.title,
    required this.fields,
    required this.initial,
    required this.requiredKey,
  });

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final Map<String, TextEditingController> _c = {
    for (final k in widget.fields.keys)
      k: TextEditingController(text: widget.initial[k] ?? ''),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    if (_c[widget.requiredKey]!.text.trim().isEmpty) {
      setState(() => _error = 'هذا الحقل مطلوب');
      return;
    }
    Navigator.pop(context, {
      for (final e in _c.entries)
        e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.fields.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _c[e.key],
                      keyboardType: e.key == 'phone'
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: e.value,
                        errorText: e.key == widget.requiredKey ? _error : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _ok, child: const Text('حفظ')),
      ],
    );
  }
}

class CustomersScreen extends StatefulWidget {
  final Business business;
  const CustomersScreen({super.key, required this.business});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Json>> _future;
  static const _fields = {
    'name': 'الاسم',
    'phone': 'الهاتف',
    'city': 'المدينة',
    'notes': 'ملاحظات',
  };

  @override
  void initState() {
    super.initState();
    _future = Repo.customers(widget.business.id);
  }

  Future<void> _reload() async {
    setState(() => _future = Repo.customers(widget.business.id));
    await _future;
  }

  Future<void> _edit([Json? c]) async {
    final v = await showFieldsDialog(context,
        title: c == null ? 'زبون جديد' : 'تعديل الزبون',
        fields: _fields,
        initial: c == null
            ? const {}
            : {for (final k in _fields.keys) k: c[k] as String?});
    if (v == null) return;
    try {
      await Repo.saveCustomer(widget.business.id, v, id: c?['id'] as String?);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Json c) async {
    if (!await confirm(context, 'حذف الزبون', 'حذف ${c['name']}؟')) return;
    try {
      await Repo.deleteCustomer(c['id'] as String);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _edit(), child: const Icon(Icons.person_add)),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyView(
                icon: Icons.people_outline, text: 'لا يوجد زبائن بعد.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: list
                .map((c) => Card(
                      child: ListTile(
                        title: Text('${c['name']}'),
                        subtitle: Text([c['phone'], c['city']]
                            .whereType<String>()
                            .join(' • ')),
                        onTap: () => _edit(c),
                        trailing: widget.business.canManage
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(c))
                            : null,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class SuppliersScreen extends StatefulWidget {
  final Business business;
  const SuppliersScreen({super.key, required this.business});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late Future<List<Json>> _future;
  static const _fields = {
    'name': 'اسم المورّد',
    'phone': 'الهاتف',
    'city': 'المدينة',
    'country': 'البلد',
    'notes': 'ملاحظات',
  };

  @override
  void initState() {
    super.initState();
    _future = Repo.suppliers(widget.business.id);
  }

  Future<void> _reload() async {
    setState(() => _future = Repo.suppliers(widget.business.id));
    await _future;
  }

  Future<void> _add() async {
    final v = await showFieldsDialog(context,
        title: 'مورّد جديد', fields: _fields);
    if (v == null) return;
    try {
      await Repo.saveSupplier(widget.business.id, v);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.business.canManage;
    return Scaffold(
      appBar: AppBar(title: const Text('الموردون')),
      floatingActionButton: canManage
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyView(
                icon: Icons.local_shipping_outlined,
                text: 'لا يوجد موردون بعد.\nأضف مورّداً لتسجيل عروض أسعاره.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: list
                .map((s) => Card(
                      child: ListTile(
                        title: Text('${s['name']}'),
                        subtitle: Text([s['phone'], s['city'], s['country']]
                            .whereType<String>()
                            .join(' • ')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SupplierDetailScreen(
                                    business: widget.business, supplier: s)),
                          );
                          _reload();
                        },
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class SupplierDetailScreen extends StatefulWidget {
  final Business business;
  final Json supplier;
  const SupplierDetailScreen(
      {super.key, required this.business, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late Future<List<Json>> _quotes;
  late Future<List<Json>> _products;

  @override
  void initState() {
    super.initState();
    _quotes = Repo.quotes(widget.supplier['id'] as String);
    _products = Repo.products(widget.business.id);
  }

  void _reload() =>
      setState(() => _quotes = Repo.quotes(widget.supplier['id'] as String));

  Future<void> _addQuote() async {
    final products = await _products;
    if (!mounted) return;
    final data = await showDialog<Json>(
      context: context,
      builder: (_) => _QuoteDialog(products: products),
    );
    if (data == null) return;
    try {
      await Repo.addQuote(widget.business.id,
          {...data, 'supplier_id': widget.supplier['id'], 'source': 'manual'});
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteSupplier() async {
    if (!await confirm(context, 'حذف المورّد',
        'سيتم حذف المورّد وكل عروض أسعاره.')) {
      return;
    }
    try {
      await Repo.deleteSupplier(widget.supplier['id'] as String);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.business.canManage;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supplier['name']}'),
        actions: [
          if (canManage)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteSupplier),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _addQuote,
              icon: const Icon(Icons.add),
              label: const Text('عرض سعر'))
          : null,
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_quotes, _products]),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final quotes = snap.data![0] as List<Json>;
          final products = snap.data![1] as List<Json>;
          final names = {for (final p in products) p['id']: p['name']};
          if (quotes.isEmpty) {
            return const EmptyView(
                icon: Icons.request_quote_outlined,
                text: 'لا توجد عروض أسعار من هذا المورّد بعد.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: quotes.map((q) {
              final cur = q['currency'] as String;
              final landed = (q['unit_price'] as num) +
                  (q['shipping_per_unit'] as num) +
                  (q['customs_per_unit'] as num);
              return Card(
                child: ListTile(
                  title: Text('${names[q['product_id']] ?? 'منتج غير محدد'}'),
                  subtitle: Text(
                      'السعر: ${Money.format(q['unit_price'] as num?, cur)} • واصل: ${Money.format(landed, cur)}\n'
                      'التاريخ: ${q['quote_date']}${q['moq'] != null ? ' • أقل كمية: ${q['moq']}' : ''}'),
                  isThreeLine: true,
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await Repo.deleteQuote(q['id'] as String);
                              _reload();
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          })
                      : null,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _QuoteDialog extends StatefulWidget {
  final List<Json> products;
  const _QuoteDialog({required this.products});

  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<_QuoteDialog> {
  String? _productId;
  String _currency = 'USD';
  final _price = TextEditingController();
  final _ship = TextEditingController();
  final _customs = TextEditingController();
  final _moq = TextEditingController();
  final _lead = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_price, _ship, _customs, _moq, _lead]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _m(TextEditingController c) =>
      c.text.trim().isEmpty ? 0 : Money.parse(c.text, _currency);

  void _ok() {
    final price = Money.parse(_price.text, _currency);
    final ship = _m(_ship), customs = _m(_customs);
    final moq = Money.parseInt(_moq.text);
    final lead = Money.parseInt(_lead.text);
    if (price == null || ship == null || customs == null) {
      setState(() => _error = 'تأكد من الأسعار');
      return;
    }
    if (moq != null && moq <= 0) {
      setState(() => _error = 'أقل كمية يجب أن تكون أكبر من صفر');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'product_id': _productId,
      'currency': _currency,
      'unit_price': price,
      'shipping_per_unit': ship,
      'customs_per_unit': customs,
      'moq': moq,
      'lead_time_days': lead,
    });
  }

  Widget _money(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: label, suffixText: Money.symbol(_currency)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('عرض سعر جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CodeDropdown(
              label: 'المنتج',
              options: {
                '': 'بدون تحديد',
                for (final p in widget.products) p['id'] as String: '${p['name']}',
              },
              value: _productId ?? '',
              onChanged: (v) => setState(
                  () => _productId = (v == null || v.isEmpty) ? null : v),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'USD', label: Text('دولار')),
                ButtonSegment(value: 'IQD', label: Text('دينار')),
              ],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            _money(_price, 'سعر القطعة'),
            _money(_ship, 'شحن القطعة'),
            _money(_customs, 'كمرك القطعة'),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _moq,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'أقل كمية للطلب (اختياري)'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _lead,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'مدة التوصيل بالأيام (اختياري)'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _ok, child: const Text('حفظ')),
      ],
    );
  }
}
