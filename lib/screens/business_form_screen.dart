import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repo.dart';
import '../labels.dart';
import '../widgets/common.dart';

/// Five-question onboarding that creates a business (caller becomes owner).
class BusinessFormScreen extends StatefulWidget {
  final ValueChanged<String> onCreated;
  final bool showSignOut;
  const BusinessFormScreen(
      {super.key, required this.onCreated, this.showSignOut = true});

  @override
  State<BusinessFormScreen> createState() => _BusinessFormScreenState();
}

class _BusinessFormScreenState extends State<BusinessFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _products = TextEditingController();
  String _type = 'retail';
  String? _goal = 'more_sales';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _products.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final id = await Repo.createBusiness(
        name: _name.text.trim(),
        type: _type,
        city: _clean(_city),
        products: _clean(_products),
        goal: _goal,
      );
      widget.onCreated(id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ابدأ بمشروعك'),
        actions: [
          if (widget.showSignOut)
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('خمسة أسئلة بسيطة حتى نجهّز حسابك.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '1. اسم المشروع'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب اسم المشروع' : null,
            ),
            const SizedBox(height: 12),
            CodeDropdown(
              label: '2. نوع النشاط',
              options: Labels.businessTypes,
              value: _type,
              onChanged: (v) => setState(() => _type = v ?? 'retail'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration:
                  const InputDecoration(labelText: '3. المدينة (اختياري)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _products,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: '4. شنو تبيع؟ (اختياري)',
                  hintText: 'مثلاً: ملابس أطفال، إكسسوارات موبايل'),
            ),
            const SizedBox(height: 12),
            CodeDropdown(
              label: '5. أهم هدف لك',
              options: Labels.goals,
              value: _goal,
              onChanged: (v) => setState(() => _goal = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_busy ? 'جارٍ الحفظ...' : 'إنشاء المشروع'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
