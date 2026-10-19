/// Arabic labels for server codes. Values must match the database CHECK constraints.
class Labels {
  static const businessTypes = {
    'retail': 'بيع بالمفرد',
    'wholesale': 'بيع بالجملة',
    'import': 'استيراد',
    'restaurant': 'مطعم أو كافيه',
    'online': 'متجر أونلاين',
    'services': 'خدمات',
    'manufacturing': 'تصنيع',
    'other': 'غير ذلك',
  };

  static const goals = {
    'more_sales': 'زيادة المبيعات',
    'control_costs': 'ضبط التكاليف',
    'save_time': 'توفير الوقت',
    'marketing': 'التسويق',
  };

  static const roles = {
    'owner': 'المالك',
    'manager': 'مدير',
    'staff': 'موظف',
  };

  static const orderStatus = {
    'pending': 'قيد الانتظار',
    'paid': 'مدفوع',
    'delivered': 'تم التسليم',
    'cancelled': 'ملغي',
  };

  static const channels = {
    'shop': 'المحل',
    'whatsapp': 'واتساب',
    'instagram': 'إنستغرام',
    'facebook': 'فيسبوك',
    'tiktok': 'تيك توك',
    'phone': 'هاتف',
    'other': 'غير ذلك',
  };

  static const paymentMethods = {
    'cash': 'نقداً',
    'cod': 'الدفع عند الاستلام',
    'zaincash': 'زين كاش',
    'card': 'بطاقة',
    'transfer': 'تحويل',
    'credit': 'آجل (دين)',
  };

  static const stockReasons = {
    'purchase': 'شراء / إضافة بضاعة',
    'return': 'إرجاع من زبون',
    'adjustment': 'تصحيح جرد',
  };

  static const featureStatus = {
    'working': 'يعمل',
    'needs_setup': 'يحتاج إعداد',
    'demo': 'تجريبي',
    'not_built': 'لم يُبنَ بعد',
  };

  static const warnings = {
    'missing_cost': 'سعر الكلفة غير مُدخل، فالربح غير دقيق',
    'negative_margin': 'سعر البيع أقل من الكلفة (خسارة)',
    'missing_sell_price': 'سعر البيع غير مُدخل',
    'no_supplier_quote': 'لا يوجد عرض سعر من مورّد',
    'stale_quote': 'آخر عرض سعر أقدم من 30 يوماً',
    'missing_exchange_rate': 'سعر صرف الدولار غير مُدخل',
    'cost_differs_from_latest_quote': 'الكلفة تختلف عن آخر عرض سعر بأكثر من 5٪',
    'low_stock': 'المخزون قارب على النفاد',
    'stock_negative': 'المخزون أصبح أقل من صفر',
    'negative_gross_profit': 'الكلفة أكبر من المبيعات في هذه الفترة',
    'no_break_even_non_positive_margin': 'لا توجد نقطة تعادل لأن الربح بالقطعة صفر أو أقل',
    'invalid_quantity': 'الكمية غير صحيحة',
    'invalid_discount': 'نسبة الخصم غير صحيحة',
    'missing_input': 'بعض القيم ناقصة',
    'missing_unit_price': 'سعر القطعة ناقص',
  };

  static const errors = {
    'forbidden': 'ليست لديك صلاحية لهذا الإجراء',
    'not_authenticated': 'يجب تسجيل الدخول أولاً',
    'user_not_registered': 'لا يوجد مستخدم بهذا الرقم. يجب أن يسجّل ويضيف رقمه في الإعدادات أولاً',
    'invalid_role': 'الدور غير صحيح',
    'empty_order': 'أضف منتجاً واحداً على الأقل',
    'invalid_status': 'الحالة غير صحيحة',
    'invalid_discount': 'الخصم غير صحيح أو أكبر من المجموع',
    'not_found': 'العنصر غير موجود',
    'currency_mismatch': 'كل منتجات الطلب يجب أن تكون بنفس العملة',
    'invalid_quantity': 'الكمية غير صحيحة',
    'invalid_price': 'السعر غير صحيح',
    'order_cancelled': 'الطلب ملغي ولا يمكن تغييره',
  };

  static String warning(String code) => warnings[code] ?? code;

  /// Maps a server/auth error message to Arabic text.
  static String error(Object e) {
    final text = e.toString();
    for (final entry in errors.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    if (text.contains('Invalid login credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (text.contains('Email not confirmed')) {
      return 'البريد غير مؤكد. افتح رسالة التأكيد في بريدك';
    }
    if (text.contains('User already registered')) {
      return 'هذا البريد مسجّل مسبقاً، سجّل الدخول';
    }
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت';
    }
    if (text.contains('violates check constraint')) {
      return 'قيمة غير مسموح بها';
    }
    return 'حدث خطأ: $text';
  }
}
