/// API `phone_number` maydoni: raqamlar, odatda `998901234567` (Postman).
String normalizeUzbekPhoneForApi(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('998')) {
    return d;
  }
  if (d.startsWith('0') && d.length >= 10) {
    d = d.substring(1);
  }
  if (d.length == 9) {
    return '998$d';
  }
  return d;
}
