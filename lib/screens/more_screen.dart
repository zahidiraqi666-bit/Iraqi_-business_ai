import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repo.dart';
import '../labels.dart';
import 'business_form_screen.dart';
import 'calculator_screen.dart';
import 'people_screens.dart';
import 'settings_screens.dart';

class MoreScreen extends StatelessWidget {
  final Business business;
  final List<Business> allBusinesses;
  final ValueChanged<String> onSwitch;
  final VoidCallback onChanged;

  const MoreScreen({
    super.key,
    required this.business,
    required this.allBusinesses,
    required this.onSwitch,
    required this.onChanged,
  });

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final b = business;
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storefront),
            title: Text(b.name),
            subtitle: Text(
                '${Labels.businessTypes[b.type] ?? b.type} • ${Labels.roles[b.role] ?? b.role}'),
          ),
          const Divider(),
          _tile(context, Icons.calculate_outlined, 'حاسبة الربح',
              'ربح القطعة، كلفة الاستيراد، نقطة التعادل، أثر الخصم',
              CalculatorScreen(business: b)),
          _tile(context, Icons.people_outline, 'الزبائن', null,
              CustomersScreen(business: b)),
          _tile(context, Icons.local_shipping_outlined, 'الموردون وعروض الأسعار',
              null, SuppliersScreen(business: b)),
          _tile(context, Icons.payments_outlined, 'المصاريف', null,
              ExpensesScreen(business: b)),
          _tile(context, Icons.currency_exchange, 'سعر صرف الدولار', null,
              ExchangeRateScreen(business: b)),
          _tile(context, Icons.groups_outlined, 'الفريق والصلاحيات', null,
              TeamScreen(business: b)),
          _tile(context, Icons.person_outline, 'حسابي', 'الاسم ورقم الهاتف',
              const ProfileScreen()),
          _tile(context, Icons.checklist, 'حالة الميزات', null,
              const FeaturesScreen()),
          const Divider(),
          if (allBusinesses.length > 1)
            ...allBusinesses.where((x) => x.id != b.id).map((x) => ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text('الانتقال إلى: ${x.name}'),
                  onTap: () => onSwitch(x.id),
                )),
          ListTile(
            leading: const Icon(Icons.add_business_outlined),
            title: const Text('إضافة مشروع آخر'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => BusinessFormScreen(
                  showSignOut: false,
                  onCreated: (id) {
                    Navigator.pop(ctx);
                    onSwitch(id);
                  },
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String? subtitle, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => _open(context, page),
    );
  }
}
