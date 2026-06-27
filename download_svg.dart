import 'dart:io';

void main() async {
  final request = await HttpClient().getUrl(Uri.parse('https://upload.wikimedia.org/wikipedia/commons/7/77/Flag_of_Chinese_Taipei_for_Olympic_Games.svg'));
  request.headers.set(HttpHeaders.userAgentHeader, 'SIMVaultApp/1.0 (https://example.com) Flutter/3.0');
  final response = await request.close();
  if (response.statusCode == 200) {
    final bytes = <int>[];
    await for (var chunk in response) {
      bytes.addAll(chunk);
    }
    await File('assets/tw_flag.svg').writeAsBytes(bytes);
    print('Success downloaded ${bytes.length} bytes');
  } else {
    print('Failed: ${response.statusCode}');
  }
}
