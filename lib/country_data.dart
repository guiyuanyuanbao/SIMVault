import 'package:country_picker/country_picker.dart' as cp;

class Country {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });
}

List<Country> _getAllCountries() {
  final List<cp.Country> rawList = cp.CountryService().getAll();
  List<Country> result = [];

  for (var c in rawList) {
    String name = c.name;
    // 覆盖名称，确保政治正确
    if (c.countryCode == 'TW') {
      name = '中国台湾 (Taiwan, China)';
    } else if (c.countryCode == 'HK') {
      name = '中国香港 (Hong Kong, China)';
    } else if (c.countryCode == 'MO') {
      name = '中国澳门 (Macau, China)';
    } else if (c.countryCode == 'CN') {
      name = '中国 (China)';
    }

    result.add(Country(
      name: name,
      code: c.countryCode,
      dialCode: '+${c.phoneCode}',
      flag: c.flagEmoji,
    ));
  }

  // 排序，把中国以及港澳台放在最前面，其他按字母排序
  final topCodes = ['CN', 'HK', 'MO', 'TW'];
  result.sort((a, b) {
    int indexA = topCodes.indexOf(a.code);
    int indexB = topCodes.indexOf(b.code);
    if (indexA != -1 && indexB != -1) {
      return indexA.compareTo(indexB);
    }
    if (indexA != -1) return -1;
    if (indexB != -1) return 1;
    return a.name.compareTo(b.name);
  });

  return result;
}

final List<Country> countriesAndRegions = _getAllCountries();
