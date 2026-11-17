import '../config/app_brand.dart';

/// Money is integer cents everywhere. This is the only place it becomes
/// text: "$490", "$1,640", "$12.50".
String money(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  final rest = abs % 100;
  final tail = rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}${AppBrand.currencySymbol}$grouped$tail';
}
