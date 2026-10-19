import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

class Business {
  final String id;
  final String name;
  final String type;
  final String? city;
  final String currency;
  final String role;

  Business({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.currency,
    required this.role,
  });

  bool get canManage => role == 'owner' || role == 'manager';
  bool get isOwner => role == 'owner';
}

/// Result of a server financial function: {value, currency, warnings}.
class FinResult {
  final Json? value;
  final String currency;
  final List<String> warnings;

  FinResult(this.value, this.currency, this.warnings);

  factory FinResult.from(dynamic json) {
    final m = Map<String, dynamic>.from(json as Map);
    final v = m['value'];
    return FinResult(
      v == null ? null : Map<String, dynamic>.from(v as Map),
      (m['currency'] ?? 'IQD') as String,
      ((m['warnings'] ?? const []) as List).map((e) => e.toString()).toList(),
    );
  }

  int? intOf(String key) {
    final x = value?[key];
    if (x == null) return null;
    if (x is num) return x.round();
    return int.tryParse(x.toString());
  }

  double? numOf(String key) {
    final x = value?[key];
    if (x == null) return null;
    if (x is num) return x.toDouble();
    return double.tryParse(x.toString());
  }
}

/// All data access. Tables are protected by RLS; money logic lives in SQL functions.
class Repo {
  static SupabaseClient get db => Supabase.instance.client;
  static String? get uid => db.auth.currentUser?.id;

  // ---------- Businesses ----------
  static Future<List<Business>> myBusinesses() async {
    final user = uid;
    if (user == null) return [];
    final members = await db
        .from('memberships')
        .select('business_id, role')
        .eq('user_id', user);
    if (members.isEmpty) return [];
    final roles = {
      for (final m in members) m['business_id'] as String: m['role'] as String
    };
    final rows = await db
        .from('businesses')
        .select()
        .inFilter('id', roles.keys.toList())
        .order('created_at');
    return rows
        .map((r) => Business(
              id: r['id'] as String,
              name: r['name'] as String,
              type: r['business_type'] as String,
              city: r['city'] as String?,
              currency: (r['currency'] ?? 'IQD') as String,
              role: roles[r['id']] ?? 'staff',
            ))
        .toList();
  }

  static Future<String> createBusiness({
    required String name,
    required String type,
    String? city,
    String? products,
    String? goal,
  }) async {
    final id = await db.rpc('create_business', params: {
      'p_name': name,
      'p_type': type,
      'p_city': city,
      'p_products': products,
      'p_goal': goal,
    });
    return id as String;
  }

  static Future<void> updateBusiness(String id, Json data) async {
    await db.from('businesses').update(data).eq('id', id);
  }

  // ---------- Products ----------
  static Future<List<Json>> products(String businessId,
      {bool activeOnly = true}) async {
    var q = db.from('products').select().eq('business_id', businessId);
    if (activeOnly) q = q.eq('is_active', true);
    return await q.order('name');
  }

  /// Inserts or updates a product; returns its id.
  static Future<String> saveProduct(String businessId, Json data,
      {String? id}) async {
    if (id == null) {
      final row = await db
          .from('products')
          .insert({...data, 'business_id': businessId})
          .select('id')
          .single();
      return row['id'] as String;
    }
    await db.from('products').update(data).eq('id', id);
    return id;
  }

  /// Soft delete: keeps order history intact.
  static Future<void> archiveProduct(String id) async {
    await db.from('products').update({'is_active': false}).eq('id', id);
  }

  static Future<int> adjustStock(
      String productId, int change, String reason, String? note) async {
    final r = await db.rpc('adjust_stock', params: {
      'p_product': productId,
      'p_qty_change': change,
      'p_reason': reason,
      'p_note': note,
    });
    return (r as num).toInt();
  }

  static Future<FinResult> productEconomics(String productId) async {
    final r =
        await db.rpc('product_economics', params: {'p_product': productId});
    return FinResult.from(r);
  }

  // ---------- Customers ----------
  static Future<List<Json>> customers(String businessId) async {
    return await db
        .from('customers')
        .select()
        .eq('business_id', businessId)
        .order('name');
  }

  static Future<void> saveCustomer(String businessId, Json data,
      {String? id}) async {
    if (id == null) {
      await db.from('customers').insert({...data, 'business_id': businessId});
    } else {
      await db.from('customers').update(data).eq('id', id);
    }
  }

  static Future<void> deleteCustomer(String id) async {
    await db.from('customers').delete().eq('id', id);
  }

  // ---------- Suppliers & quotes ----------
  static Future<List<Json>> suppliers(String businessId) async {
    return await db
        .from('suppliers')
        .select()
        .eq('business_id', businessId)
        .order('name');
  }

  static Future<void> saveSupplier(String businessId, Json data,
      {String? id}) async {
    if (id == null) {
      await db.from('suppliers').insert({...data, 'business_id': businessId});
    } else {
      await db.from('suppliers').update(data).eq('id', id);
    }
  }

  static Future<void> deleteSupplier(String id) async {
    await db.from('suppliers').delete().eq('id', id);
  }

  static Future<List<Json>> quotes(String supplierId) async {
    return await db
        .from('supplier_quotes')
        .select()
        .eq('supplier_id', supplierId)
        .order('quote_date', ascending: false);
  }

  static Future<void> addQuote(String businessId, Json data) async {
    await db
        .from('supplier_quotes')
        .insert({...data, 'business_id': businessId});
  }

  static Future<void> deleteQuote(String id) async {
    await db.from('supplier_quotes').delete().eq('id', id);
  }

  // ---------- Orders ----------
  static Future<List<Json>> orders(String businessId, {int limit = 100}) async {
    return await db
        .from('orders')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  static Future<List<Json>> orderItems(String orderId) async {
    return await db.from('order_items').select().eq('order_id', orderId);
  }

  static Future<Json> createOrder({
    required String businessId,
    required List<Json> items,
    String? customerId,
    int discount = 0,
    String status = 'pending',
    String channel = 'shop',
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    final r = await db.rpc('create_order', params: {
      'p_business': businessId,
      'p_items': items,
      'p_customer': customerId,
      'p_discount': discount,
      'p_status': status,
      'p_channel': channel,
      'p_payment_method': paymentMethod,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<void> setOrderStatus(String orderId, String status) async {
    await db.rpc('set_order_status',
        params: {'p_order': orderId, 'p_status': status});
  }

  static Future<FinResult> salesSummary(
      String businessId, DateTime from, DateTime to) async {
    final r = await db.rpc('sales_summary', params: {
      'p_business': businessId,
      'p_from': _date(from),
      'p_to': _date(to),
    });
    return FinResult.from(r);
  }

  // ---------- Expenses ----------
  static Future<List<Json>> expenses(String businessId) async {
    return await db
        .from('expenses')
        .select()
        .eq('business_id', businessId)
        .order('expense_date', ascending: false);
  }

  static Future<void> addExpense(String businessId, Json data) async {
    await db.from('expenses').insert({...data, 'business_id': businessId});
  }

  static Future<void> deleteExpense(String id) async {
    await db.from('expenses').delete().eq('id', id);
  }

  // ---------- Exchange rate ----------
  /// Latest USD -> IQD rate (IQD per 1 USD), or null.
  static Future<double?> latestUsdRate(String businessId) async {
    final rows = await db
        .from('exchange_rates')
        .select('rate')
        .eq('business_id', businessId)
        .eq('base_currency', 'USD')
        .eq('quote_currency', 'IQD')
        .order('rate_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return (rows.first['rate'] as num).toDouble();
  }

  static Future<void> saveUsdRate(String businessId, double rate) async {
    await db.from('exchange_rates').insert({
      'business_id': businessId,
      'base_currency': 'USD',
      'quote_currency': 'IQD',
      'rate': rate,
      'source': 'manual',
    });
  }

  // ---------- Financial calculator (server functions) ----------
  static Future<FinResult> unitMargin(int sell, int cost, String cur) async =>
      FinResult.from(await db.rpc('fin_unit_margin',
          params: {'p_sell': sell, 'p_cost': cost, 'p_currency': cur}));

  static Future<FinResult> breakEven(
          int fixed, int sell, int variable, String cur) async =>
      FinResult.from(await db.rpc('fin_break_even_units', params: {
        'p_fixed_costs': fixed,
        'p_sell': sell,
        'p_variable_cost': variable,
        'p_currency': cur,
      }));

  static Future<FinResult> discountImpact(
          int price, int discountBp, int cost, String cur) async =>
      FinResult.from(await db.rpc('fin_discount_impact', params: {
        'p_price': price,
        'p_discount_bp': discountBp,
        'p_cost': cost,
        'p_currency': cur,
      }));

  static Future<FinResult> landedCost({
    required int unitPrice,
    required int quantity,
    required int shipping,
    required int customs,
    required int other,
    required String currency,
    String? target,
    double? rate,
  }) async =>
      FinResult.from(await db.rpc('fin_landed_cost', params: {
        'p_unit_price': unitPrice,
        'p_quantity': quantity,
        'p_shipping_total': shipping,
        'p_customs_total': customs,
        'p_other_total': other,
        'p_currency': currency,
        'p_target_currency': target,
        'p_rate': rate,
      }));

  // ---------- Team ----------
  static Future<List<Json>> team(String businessId) async {
    final members = await db
        .from('memberships')
        .select('user_id, role')
        .eq('business_id', businessId);
    final ids = members.map((m) => m['user_id'] as String).toList();
    final users = ids.isEmpty
        ? <Json>[]
        : await db
            .from('users')
            .select('id, phone, email, full_name')
            .inFilter('id', ids);
    final byId = {for (final u in users) u['id'] as String: u};
    return members
        .map((m) => <String, dynamic>{
              'user_id': m['user_id'],
              'role': m['role'],
              ...?byId[m['user_id']],
            })
        .toList();
  }

  static Future<void> addMember(
      String businessId, String phone, String role) async {
    await db.rpc('add_member',
        params: {'p_business': businessId, 'p_phone': phone, 'p_role': role});
  }

  static Future<void> removeMember(String businessId, String userId) async {
    await db.rpc('remove_member',
        params: {'p_business': businessId, 'p_user': userId});
  }

  static Future<Json?> myProfile() async {
    final user = uid;
    if (user == null) return null;
    final rows = await db.from('users').select().eq('id', user).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> updateMyProfile(Json data) async {
    final user = uid;
    if (user == null) return;
    await db.from('users').update(data).eq('id', user);
  }

  static Future<List<Json>> features() async {
    return await db.from('feature_status').select().order('phase');
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
