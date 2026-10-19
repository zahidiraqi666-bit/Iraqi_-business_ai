import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../labels.dart';
import '../money.dart';
import '../widgets/common.dart';

class ProductsScreen extends StatefulWidget {
  final Business business;
  final VoidCallback onChanged;
  const ProductsScreen(
      {super.key, required this.business, required this.onChanged});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Json>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = Repo.products(widget.business.id);
  }

  Future<void> _reload() async {
    setState(() => _future = Repo.products(widget.business.id));
    await _future;
  }

  Future<void> _open({Json? product}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => product == null
            ? ProductFormScreen(business: widget.business)
            : ProductDetailScreen(business: widget.business, product: product),
      ),
    );
    if (changed == true) {
      widget.onChanged();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات')),
      floatingActionButton: widget.business.canManage
          ? FloatingActionButton.extended(
              onPressed: () => _open(),
              icon: const Icon(Icons.add),
              label: const Text('منتج جديد'),
            )
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
          final all = snap.data!;
          if (all.isEmpty) {
            return const EmptyView(
                icon: Icons.inventory_2_outlined,
                text: 'لا توجد منتجات بعد.\nأضف أول منتج مع سعر الكلفة وسعر البيع.');
          }
          final q = _query.trim().toLowerCase();
          final list = q.isEmpty
              ? all
              : all
                  .where((p) =>
                      '${p['name']} ${p['sku'] ?? ''} ${p['category'] ?? ''}'
                          .toLowerCase()
                          .contains(q))
                  .toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), hintText: 'بحث'),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                ...list.map((p) => _ProductTile(p, onTap: () => _open(product: p))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Json p;
  final VoidCallback onTap;
  const _ProductTile(this.p, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cur = (p['currency'] ?? 'IQD') as String;
    final stock = (p['stock_qty'] as num?)?.toInt() ?? 0;
    final low = (p['low_stock_threshold'] as num?)?.toInt() ?? 0;
    final tracks = p['track_stock'] == true;
    final isLow = tracks && stock <= low;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('${p['name']}'),
        subtitle: Text(
            'بيع: ${Money.format(p['sell_price'] as num?, cur)}  •  كلفة: ${Money.format(p['cost_price'] as num?, cur)}'),
        trailing: tracks
            ? Chip(
                label: Text('$stock'),
                backgroundColor: isLow ? cs.errorContainer : null,
              )
            : null,
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final Business business;
  final Json product;
  const ProductDetailScreen(
      {super.key, required this.business, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Json _p;
  late Future<FinResult> _econ;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _p = widget.product;
    _econ = Repo.productEconomics(_p['id'] as String);
  }

  String get _cur => (_p['currency'] ?? 'IQD') as String;

  Future<void> _edit() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ProductFormScreen(business: widget.business, product: _p)),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _archive() async {
    final ok = await confirm(context, 'حذف المنتج',
        'سيختفي المنتج من القوائم، وتبقى الطلبات القديمة كما هي.');
    if (!ok) return;
    try {
      await Repo.archiveProduct(_p['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _adjustStock() async {
    final result = await showDialog<(int, String, String?)>(
      context: context,
      builder: (_) => const _StockDialog(),
    );
    if (result == null) return;
    try {
      final newQty =
          await Repo.adjustStock(_p['id'] as String, result.$1, result.$2, result.$3);
      setState(() {
        _p = {..._p, 'stock_qty': newQty};
        _changed = true;
      });
      if (mounted) showMessage(context, 'المخزون الآن: $newQty');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.business.canManage;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_p['name']}'),
          actions: [
            if (canManage)
              IconButton(
                  tooltip: 'تعديل', icon: const Icon(Icons.edit), onPressed: _edit),
            if (canManage)
              IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _archive),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  InfoRow('سعر البيع', Money.format(_p['sell_price'] as num?, _cur),
                      bold: true),
                  InfoRow('سعر الكلفة', Money.format(_p['cost_price'] as num?, _cur)),
                  if (_p['sku'] != null) InfoRow('الرمز (SKU)', '${_p['sku']}'),
                  if (_p['category'] != null) InfoRow('الصنف', '${_p['category']}'),
                  InfoRow('الوحدة', '${_p['unit'] ?? 'piece'}'),
                ]),
              ),
            ),
            const SectionTitle('الربح (محسوب في السيرفر)'),
            FutureBuilder<FinResult>(
              future: _econ,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(16), child: LoadingView());
                }
                if (snap.hasError) return Text(Labels.error(snap.error!));
                final r = snap.data!;
                final pct = r.numOf('margin_percent');
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InfoRow('الربح بالقطعة',
                            Money.format(r.intOf('unit_margin'), _cur),
                            bold: true),
                        InfoRow('نسبة الربح',
                            pct == null ? '—' : '${pct.toStringAsFixed(1)}٪'),
                        if (r.intOf('latest_quote_landed_cost') != null)
                          InfoRow('كلفة آخر عرض مورّد',
                              Money.format(r.intOf('latest_quote_landed_cost'), _cur)),
                        WarningList(r.warnings),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SectionTitle('المخزون'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: Text(_p['track_stock'] == true
                    ? 'الكمية الحالية: ${_p['stock_qty']}'
                    : 'لا يتم تتبع المخزون لهذا المنتج'),
                subtitle: _p['track_stock'] == true
                    ? Text('تنبيه عند: ${_p['low_stock_threshold']} أو أقل')
                    : null,
                trailing: canManage && _p['track_stock'] == true
                    ? FilledButton.tonal(
                        onPressed: _adjustStock, child: const Text('تعديل'))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog();

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  String _reason = 'purchase';
  bool _decrease = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  void _ok() {
    final n = Money.parseInt(_qty.text);
    if (n == null || n <= 0) {
      setState(() => _error = 'اكتب عدداً أكبر من صفر');
      return;
    }
    final change = _decrease ? -n : n;
    final note = _note.text.trim();
    Navigator.pop(context, (change, _reason, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل المخزون'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CodeDropdown(
              label: 'السبب',
              options: Labels.stockReasons,
              value: _reason,
              onChanged: (v) => setState(() {
                _reason = v ?? 'purchase';
                if (_reason != 'adjustment') _decrease = false;
              }),
            ),
            if (_reason == 'adjustment')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إنقاص الكمية'),
                value: _decrease,
                onChanged: (v) => setState(() => _decrease = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'الكمية', errorText: _error),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
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

class ProductFormScreen extends StatefulWidget {
  final Business business;
  final Json? product;
  const ProductFormScreen({super.key, required this.business, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _sku, _category, _cost, _sell, _low, _stock;
  late String _currency;
  late bool _track;
  bool _busy = false;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product ?? const {};
    _currency = (p['currency'] ?? widget.business.currency) as String;
    _track = (p['track_stock'] ?? true) as bool;
    _name = TextEditingController(text: (p['name'] ?? '') as String);
    _sku = TextEditingController(text: (p['sku'] ?? '') as String);
    _category = TextEditingController(text: (p['category'] ?? '') as String);
    _cost = TextEditingController(
        text: Money.toInput((p['cost_price'] as num?)?.toInt(), _currency));
    _sell = TextEditingController(
        text: Money.toInput((p['sell_price'] as num?)?.toInt(), _currency));
    _low = TextEditingController(text: '${p['low_stock_threshold'] ?? 5}');
    _stock = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _category, _cost, _sell, _low, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _moneyValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return Money.parse(v, _currency) == null ? 'رقم غير صحيح' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'sku': opt(_sku),
      'category': opt(_category),
      'currency': _currency,
      'cost_price': Money.parse(_cost.text, _currency) ?? 0,
      'sell_price': Money.parse(_sell.text, _currency) ?? 0,
      'low_stock_threshold': Money.parseInt(_low.text) ?? 5,
      'track_stock': _track,
    };
    try {
      if (_isNew) {
        final id = await Repo.saveProduct(widget.business.id, data);
        final opening = Money.parseInt(_stock.text) ?? 0;
        if (_track && opening > 0) {
          // Opening stock goes through the stock ledger, not a direct write.
          await Repo.adjustStock(id, opening, 'purchase', 'رصيد افتتاحي');
        }
      } else {
        await Repo.saveProduct(widget.business.id, data,
            id: widget.product!['id'] as String);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'منتج جديد' : 'تعديل المنتج')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم المنتج'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'IQD', label: Text('دينار')),
                ButtonSegment(value: 'USD', label: Text('دولار')),
              ],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'سعر الكلفة', suffixText: Money.symbol(_currency)),
                  validator: _moneyValidator,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _sell,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'سعر البيع', suffixText: Money.symbol(_currency)),
                  validator: _moneyValidator,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _sku,
                  decoration: const InputDecoration(labelText: 'الرمز (اختياري)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'الصنف (اختياري)'),
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تتبّع المخزون'),
              value: _track,
              onChanged: (v) => setState(() => _track = v),
            ),
            if (_track)
              Row(children: [
                if (_isNew)
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'الكمية الحالية'),
                    ),
                  ),
                if (_isNew) const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _low,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'نبّهني عند كمية'),
                  ),
                ),
              ]),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
