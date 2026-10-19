import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../labels.dart';
import '../money.dart';
import '../widgets/common.dart';

class OrdersScreen extends StatefulWidget {
  final Business business;
  final VoidCallback onChanged;
  const OrdersScreen(
      {super.key, required this.business, required this.onChanged});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = Repo.orders(widget.business.id);
  }

  Future<void> _reload() async {
    setState(() => _future = Repo.orders(widget.business.id));
    await _future;
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => page));
    if (changed == true) {
      widget.onChanged();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(NewOrderScreen(business: widget.business)),
        icon: const Icon(Icons.add),
        label: const Text('طلب جديد'),
      ),
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
                icon: Icons.receipt_long_outlined,
                text: 'لا توجد طلبات بعد.\nسجّل أول بيعة من زر «طلب جديد».');
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final o = list[i];
                final cur = o['currency'] as String;
                final status = o['status'] as String;
                return Card(
                  child: ListTile(
                    onTap: () => _push(
                        OrderDetailScreen(business: widget.business, order: o)),
                    leading: CircleAvatar(child: Text('${o['order_no']}')),
                    title: Text(Money.format(o['total'] as num?, cur)),
                    subtitle: Text(
                        '${_date(o['created_at'] as String)} • ${Labels.channels[o['channel']] ?? ''}'),
                    trailing: _StatusChip(status),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _date(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status) {
      'paid' || 'delivered' => cs.primaryContainer,
      'cancelled' => cs.errorContainer,
      _ => cs.surfaceContainerHighest,
    };
    return Chip(
      label: Text(Labels.orderStatus[status] ?? status),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final Business business;
  final Json order;
  const OrderDetailScreen(
      {super.key, required this.business, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<List<Json>> _items;
  late String _status;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order['status'] as String;
    _items = Repo.orderItems(widget.order['id'] as String);
  }

  Future<void> _setStatus(String s) async {
    if (s == 'cancelled') {
      final ok = await confirm(context, 'إلغاء الطلب',
          'سيتم إرجاع الكميات إلى المخزون. لا يمكن التراجع عن الإلغاء.');
      if (!ok) return;
    }
    try {
      await Repo.setOrderStatus(widget.order['id'] as String, s);
      setState(() {
        _status = s;
        _changed = true;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final cur = o['currency'] as String;
    final subtotal = (o['subtotal'] as num).toInt();
    final total = (o['total'] as num).toInt();
    final cost = (o['total_cost'] as num).toInt();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('طلب رقم ${o['order_no']}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_date(o['created_at'] as String)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              Chip(label: Text(Labels.channels[o['channel']] ?? '${o['channel']}')),
              Chip(
                  label: Text(Labels.paymentMethods[o['payment_method']] ??
                      '${o['payment_method']}')),
              _StatusChip(_status),
            ]),
            const SectionTitle('المنتجات'),
            FutureBuilder<List<Json>>(
              future: _items,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snap.hasError) return Text(Labels.error(snap.error!));
                return Column(
                  children: snap.data!
                      .map((it) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${it['product_name']}'),
                            subtitle: Text(
                                '${it['qty']} × ${Money.format(it['unit_price'] as num?, cur)}'),
                            trailing:
                                Text(Money.format(it['line_total'] as num?, cur)),
                          ))
                      .toList(),
                );
              },
            ),
            const Divider(),
            InfoRow('المجموع', Money.format(subtotal, cur)),
            InfoRow('الخصم', Money.format(o['discount'] as num?, cur)),
            InfoRow('الإجمالي', Money.format(total, cur), bold: true),
            InfoRow('الكلفة', Money.format(cost, cur)),
            InfoRow('الربح الإجمالي', Money.format(total - cost, cur), bold: true),
            if (o['notes'] != null) ...[
              const SectionTitle('ملاحظات'),
              Text('${o['notes']}'),
            ],
            if (_status != 'cancelled') ...[
              const SectionTitle('تغيير الحالة'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ['pending', 'paid', 'delivered'])
                    ChoiceChip(
                      label: Text(Labels.orderStatus[s]!),
                      selected: _status == s,
                      onSelected: (_) => _setStatus(s),
                    ),
                  if (widget.business.canManage)
                    ActionChip(
                      avatar: const Icon(Icons.cancel_outlined),
                      label: const Text('إلغاء الطلب'),
                      onPressed: () => _setStatus('cancelled'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line {
  final Json product;
  int qty;
  _Line(this.product, this.qty);
  int get price => (product['sell_price'] as num).toInt();
  int get total => price * qty;
}

class NewOrderScreen extends StatefulWidget {
  final Business business;
  const NewOrderScreen({super.key, required this.business});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late Future<List<Json>> _products;
  late Future<List<Json>> _customers;
  final List<_Line> _lines = [];
  final _discount = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _status = 'paid';
  String _channel = 'shop';
  String _payment = 'cash';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _products = Repo.products(widget.business.id);
    _customers = Repo.customers(widget.business.id);
  }

  @override
  void dispose() {
    _discount.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _currency => _lines.isEmpty
      ? widget.business.currency
      : _lines.first.product['currency'] as String;

  int get _subtotal => _lines.fold(0, (s, l) => s + l.total);

  Future<void> _pickProduct(List<Json> products) async {
    final available = products
        .where((p) => _lines.isEmpty || p['currency'] == _currency)
        .toList();
    final picked = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPicker(available),
    );
    if (picked == null) return;
    setState(() {
      final existing =
          _lines.where((l) => l.product['id'] == picked['id']).toList();
      if (existing.isNotEmpty) {
        existing.first.qty++;
      } else {
        _lines.add(_Line(picked, 1));
      }
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      showMessage(context, Labels.errors['empty_order']!, error: true);
      return;
    }
    final discount = _discount.text.trim().isEmpty
        ? 0
        : Money.parse(_discount.text, _currency);
    if (discount == null || discount > _subtotal) {
      showMessage(context, Labels.errors['invalid_discount']!, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Repo.createOrder(
        businessId: widget.business.id,
        items: _lines
            .map((l) => <String, dynamic>{
                  'product_id': l.product['id'],
                  'qty': l.qty,
                })
            .toList(),
        customerId: _customerId,
        discount: discount,
        status: _status,
        channel: _channel,
        paymentMethod: _payment,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      final warnings = ((r['warnings'] ?? const []) as List)
          .map((e) => Labels.warning(e.toString()))
          .toList();
      if (!mounted) return;
      if (warnings.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('تم حفظ الطلب رقم ${r['order_no']}'),
            content: Text('انتبه:\n• ${warnings.join('\n• ')}'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً')),
            ],
          ),
        );
      } else {
        showMessage(context, 'تم حفظ الطلب رقم ${r['order_no']}');
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
    final cur = _currency;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب جديد')),
      body: FutureBuilder<List<Json>>(
        future: _products,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(
                error: snap.error!,
                onRetry: () => setState(
                    () => _products = Repo.products(widget.business.id)));
          }
          final products = snap.data!;
          if (products.isEmpty) {
            return const EmptyView(
                icon: Icons.inventory_2_outlined,
                text: 'أضف منتجات أولاً من تبويب «المنتجات».');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._lines.map((l) => Card(
                    child: ListTile(
                      title: Text('${l.product['name']}'),
                      subtitle: Text(Money.format(l.price, cur)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() {
                              if (l.qty > 1) {
                                l.qty--;
                              } else {
                                _lines.remove(l);
                              }
                            }),
                          ),
                          Text('${l.qty}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => l.qty++),
                          ),
                        ],
                      ),
                    ),
                  )),
              OutlinedButton.icon(
                onPressed: () => _pickProduct(products),
                icon: const Icon(Icons.add),
                label: const Text('إضافة منتج'),
              ),
              const SizedBox(height: 12),
              InfoRow('المجموع', Money.format(_subtotal, cur), bold: true),
              const SizedBox(height: 12),
              TextField(
                controller: _discount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'خصم (مبلغ، اختياري)',
                    suffixText: Money.symbol(cur)),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Json>>(
                future: _customers,
                builder: (context, cs) {
                  final customers = cs.data ?? const <Json>[];
                  return CodeDropdown(
                    label: 'الزبون (اختياري)',
                    options: {
                      '': 'بدون زبون',
                      for (final c in customers)
                        c['id'] as String: '${c['name']}',
                    },
                    value: _customerId ?? '',
                    onChanged: (v) => setState(
                        () => _customerId = (v == null || v.isEmpty) ? null : v),
                  );
                },
              ),
              const SizedBox(height: 12),
              CodeDropdown(
                label: 'الحالة',
                options: {
                  for (final s in ['pending', 'paid', 'delivered'])
                    s: Labels.orderStatus[s]!,
                },
                value: _status,
                onChanged: (v) => setState(() => _status = v ?? 'paid'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: CodeDropdown(
                    label: 'القناة',
                    options: Labels.channels,
                    value: _channel,
                    onChanged: (v) => setState(() => _channel = v ?? 'shop'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CodeDropdown(
                    label: 'الدفع',
                    options: Labels.paymentMethods,
                    value: _payment,
                    onChanged: (v) => setState(() => _payment = v ?? 'cash'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ الطلب'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  final List<Json> products;
  const _ProductPicker(this.products);

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.products
        : widget.products
            .where((p) => '${p['name']}'.toLowerCase().contains(q))
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'ابحث عن منتج'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: list
                    .map((p) => ListTile(
                          title: Text('${p['name']}'),
                          subtitle: Text(Money.format(
                              p['sell_price'] as num?, p['currency'] as String)),
                          trailing: p['track_stock'] == true
                              ? Text('المتوفر: ${p['stock_qty']}')
                              : null,
                          onTap: () => Navigator.pop(context, p),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
