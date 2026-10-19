import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../labels.dart';
import '../money.dart';
import '../widgets/common.dart';

class ExpensesScreen extends StatefulWidget {
  final Business business;
  const ExpensesScreen({super.key, required this.business});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = Repo.expenses(widget.business.id);
  }

  Future<void> _reload() async {
    setState(() => _future = Repo.expenses(widget.business.id));
    await _future;
  }

  Future<void> _add() async {
    final data = await showDialog<Json>(
      context: context,
      builder: (_) => _ExpenseDialog(currency: widget.business.currency),
    );
    if (data == null) return;
    try {
      await Repo.addExpense(widget.business.id, data);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف')),
      floatingActionButton: widget.business.canManage
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
                icon: Icons.payments_outlined,
                text: 'سجّل مصاريفك الثابتة (إيجار، رواتب، كهرباء)\nحتى تعرف ربحك الحقيقي.');
          }
          final monthlyByCur = <String, int>{};
          for (final e in list) {
            if (e['period'] == 'monthly') {
              final c = e['currency'] as String;
              monthlyByCur[c] =
                  (monthlyByCur[c] ?? 0) + (e['amount'] as num).toInt();
            }
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              ...monthlyByCur.entries.map((e) => InfoRow(
                  'مجموع المصاريف الشهرية', Money.format(e.value, e.key),
                  bold: true)),
              const SizedBox(height: 8),
              ...list.map((e) => Card(
                    child: ListTile(
                      title: Text('${e['name']}'),
                      subtitle: Text(
                          '${e['period'] == 'monthly' ? 'شهري' : 'مرة واحدة'} • ${e['kind'] == 'fixed' ? 'ثابت' : 'متغير'} • ${e['expense_date']}'),
                      trailing: Text(Money.format(
                          e['amount'] as num?, e['currency'] as String)),
                      onLongPress: widget.business.canManage
                          ? () async {
                              if (!await confirm(
                                  context, 'حذف', 'حذف ${e['name']}؟')) {
                                return;
                              }
                              try {
                                await Repo.deleteExpense(e['id'] as String);
                                _reload();
                              } catch (err) {
                                if (context.mounted) showError(context, err);
                              }
                            }
                          : null,
                    ),
                  )),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('للحذف: اضغط مطولاً على المصروف.',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  final String currency;
  const _ExpenseDialog({required this.currency});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late String _currency = widget.currency;
  String _period = 'monthly';
  String _kind = 'fixed';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _ok() {
    final amount = Money.parse(_amount.text, _currency);
    if (_name.text.trim().isEmpty || amount == null) {
      setState(() => _error = 'اكتب الاسم والمبلغ');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'amount': amount,
      'currency': _currency,
      'period': _period,
      'kind': _kind,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('مصروف جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'الاسم', hintText: 'مثلاً: إيجار المحل'),
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
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'المبلغ', suffixText: Money.symbol(_currency)),
            ),
            const SizedBox(height: 12),
            CodeDropdown(
              label: 'التكرار',
              options: const {'monthly': 'شهري', 'once': 'مرة واحدة'},
              value: _period,
              onChanged: (v) => setState(() => _period = v ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            CodeDropdown(
              label: 'النوع',
              options: const {'fixed': 'ثابت', 'variable': 'متغير'},
              value: _kind,
              onChanged: (v) => setState(() => _kind = v ?? 'fixed'),
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

class ExchangeRateScreen extends StatefulWidget {
  final Business business;
  const ExchangeRateScreen({super.key, required this.business});

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen> {
  final _rate = TextEditingController();
  double? _current;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Repo.latestUsdRate(widget.business.id);
      if (mounted) setState(() => _current = r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final text = Money.normalizeDigits(_rate.text).replaceAll(',', '').trim();
    final v = double.tryParse(text);
    if (v == null || v <= 0) {
      showMessage(context, 'اكتب رقماً صحيحاً، مثلاً 1310', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Repo.saveUsdRate(widget.business.id, v);
      _rate.clear();
      await _load();
      if (mounted) showMessage(context, 'تم حفظ سعر الصرف');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سعر صرف الدولار')),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: Text(_current == null
                        ? 'لم يُدخل سعر صرف بعد'
                        : '1 \$ = ${_current!.toStringAsFixed(0)} دينار'),
                    subtitle: const Text('آخر سعر مُدخل'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'السعر الجديد (دينار مقابل 1 دولار)',
                      hintText: '1310'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || !widget.business.canManage ? null : _save,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('حفظ'),
                  ),
                ),
              ],
            ),
    );
  }
}

class TeamScreen extends StatefulWidget {
  final Business business;
  const TeamScreen({super.key, required this.business});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = Repo.team(widget.business.id);
  }

  Future<void> _reload() async {
    setState(() => _future = Repo.team(widget.business.id));
    await _future;
  }

  Future<void> _add() async {
    final data = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (data == null) return;
    try {
      await Repo.addMember(widget.business.id, data.$1, data.$2);
      if (mounted) showMessage(context, 'تمت الإضافة');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(Json m) async {
    if (!await confirm(context, 'إزالة من الفريق',
        'سيفقد هذا الشخص الوصول إلى المشروع.')) {
      return;
    }
    try {
      await Repo.removeMember(widget.business.id, m['user_id'] as String);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.business.isOwner;
    return Scaffold(
      appBar: AppBar(title: const Text('الفريق')),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: _add, child: const Icon(Icons.person_add))
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
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...snap.data!.map((m) {
                final name = (m['full_name'] ?? m['email'] ?? m['phone'] ?? 'عضو')
                    as String;
                final isMe = m['user_id'] == Repo.uid;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(isMe ? '$name (أنت)' : name),
                    subtitle: Text(Labels.roles[m['role']] ?? '${m['role']}'),
                    trailing: isOwner && m['role'] != 'owner'
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () => _remove(m))
                        : null,
                  ),
                );
              }),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'المدير: يضيف ويعدّل المنتجات والأسعار.\n'
                  'الموظف: يسجّل الطلبات ويشاهد فقط.\n'
                  'لإضافة شخص: يسجّل حساباً في التطبيق ويكتب رقم هاتفه في «حسابي»، ثم تضيفه برقمه.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _phone = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة عضو'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'رقم الهاتف كما كتبه في حسابه'),
          ),
          const SizedBox(height: 12),
          CodeDropdown(
            label: 'الدور',
            options: const {'manager': 'مدير', 'staff': 'موظف'},
            value: _role,
            onChanged: (v) => setState(() => _role = v ?? 'staff'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final phone = Money.normalizeDigits(_phone.text).trim();
            if (phone.isEmpty) return;
            Navigator.pop(context, (phone, _role));
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _hasRow = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Repo.myProfile();
      if (p != null) {
        _hasRow = true;
        _name.text = (p['full_name'] ?? '') as String;
        _phone.text = (p['phone'] ?? '') as String;
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Repo.updateMyProfile({
        'full_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'phone': _phone.text.trim().isEmpty
            ? null
            : Money.normalizeDigits(_phone.text).trim(),
      });
      if (mounted) showMessage(context, 'تم الحفظ');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Repo.db.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(email, textDirection: TextDirection.ltr),
                ),
                if (!_hasRow)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                        'أنشئ مشروعاً أو انضم إلى فريق أولاً حتى تحفظ بياناتك.'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', hintText: '07xxxxxxxxx'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy || !_hasRow ? null : _save,
                  child: const Padding(
                      padding: EdgeInsets.all(12), child: Text('حفظ')),
                ),
              ],
            ),
    );
  }
}

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حالة الميزات')),
      body: FutureBuilder<List<Json>>(
        future: Repo.features(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) return Center(child: Text(Labels.error(snap.error!)));
          final cs = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: snap.data!.map((f) {
              final status = f['status'] as String;
              final color = switch (status) {
                'working' => cs.primaryContainer,
                'not_built' => cs.surfaceContainerHighest,
                _ => cs.tertiaryContainer,
              };
              return Card(
                child: ListTile(
                  title: Text('${f['name_ar']}'),
                  subtitle: Text(
                      'المرحلة ${f['phase']}${f['note'] != null ? ' • ${f['note']}' : ''}'),
                  trailing: Chip(
                    label: Text(Labels.featureStatus[status] ?? status),
                    backgroundColor: color,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
