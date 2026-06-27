import 'package:phone_numbers_parser/phone_numbers_parser.dart';

void main() {
  try {
    final iso = IsoCode.values.byName('CN');
    final pn = PhoneNumber.parse('13800138000', callerCountry: iso);
    print('isValid: ${pn.isValid(type: PhoneNumberType.mobile)}');
  } catch(e) {
    print(e);
  }
}
