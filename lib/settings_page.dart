import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flag/flag.dart';
import 'custom_flag.dart';
import 'models.dart';
import 'l10n.dart';
import 'pin_screen.dart';

class SyncSettingsPage extends StatefulWidget {
  final SettingsManager settingsManager;
  final PhoneNumberManager phoneManager;

  const SyncSettingsPage({super.key, required this.settingsManager, required this.phoneManager});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  late TextEditingController _urlController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _isLoading = false;

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.settingsManager.addListener(_onSettingsChanged);
    _urlController = TextEditingController(text: widget.settingsManager.webDavUrl);
    _userController = TextEditingController(text: widget.settingsManager.webDavUser);
    _passController = TextEditingController(text: widget.settingsManager.webDavPass);
  }

  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await widget.settingsManager.saveWebDav(
      _urlController.text.trim(),
      _userController.text.trim(),
      _passController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'settings_saved'), style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )
    );
  }

  Future<void> _syncToWebDav() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await widget.settingsManager.saveWebDav(
        _urlController.text.trim(),
        _userController.text.trim(),
        _passController.text.trim(),
      );
      
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('phone_data') ?? '[]';
      final deletedData = prefs.getString('deleted_phone_data') ?? '[]';
      
      final url = _urlController.text.endsWith('/') 
          ? '${_urlController.text}simvault_data.json' 
          : '${_urlController.text}/simvault_data.json';
          
      final deletedUrl = _urlController.text.endsWith('/') 
          ? '${_urlController.text}simvault_deleted_data.json' 
          : '${_urlController.text}/simvault_deleted_data.json';

      final basicAuth = 'Basic ${base64Encode(utf8.encode('${_userController.text}:${_passController.text}'))}';
      
      final response = await http.put(
        Uri.parse(url),
        headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
        body: data,
      );
      
      // Upload recycle bin silently, ignore errors as it's not strictly critical
      try {
        await http.put(
          Uri.parse(deletedUrl),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: deletedData,
        );
      } catch (e) {
        debugPrint('Recycle bin upload failed: $e');
      }
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'sync_success') ?? 'Backup Successful!', style: const TextStyle(fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      } else if (response.statusCode == 404) {
        throw Exception('HTTP 404 Not Found.\nURL: $url\nPlease ensure the URL is correct (e.g. ends with /dav/) and if you specified a subfolder, it MUST exist on the server first!');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr(context, 'sync_fail') ?? 'Backup failed: '}$e', style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.redAccent,
        )
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncFromWebDav() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await widget.settingsManager.saveWebDav(
        _urlController.text.trim(),
        _userController.text.trim(),
        _passController.text.trim(),
      );

      final url = _urlController.text.endsWith('/') 
          ? '${_urlController.text}simvault_data.json' 
          : '${_urlController.text}/simvault_data.json';
          
      final deletedUrl = _urlController.text.endsWith('/') 
          ? '${_urlController.text}simvault_deleted_data.json' 
          : '${_urlController.text}/simvault_deleted_data.json';

      final basicAuth = 'Basic ${base64Encode(utf8.encode('${_userController.text}:${_passController.text}'))}';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': basicAuth},
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_data', response.body);
        
        // Try downloading recycle bin as well
        try {
          final delResponse = await http.get(
            Uri.parse(deletedUrl),
            headers: {'Authorization': basicAuth},
          );
          if (delResponse.statusCode >= 200 && delResponse.statusCode < 300) {
            await prefs.setString('deleted_phone_data', delResponse.body);
          }
        } catch (e) {
          debugPrint('Failed to download recycle bin: $e');
        }

        await widget.phoneManager.load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'restore_success'), style: const TextStyle(fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      } else if (response.statusCode == 404) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'restore_404'), style: const TextStyle(fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.redAccent,
          )
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr(context, 'restore_fail')}$e', style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.redAccent,
        )
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String url = _urlController.text.endsWith('/') 
          ? _urlController.text
          : '${_urlController.text}/';
          
      final basicAuth = 'Basic ${base64Encode(utf8.encode('${_userController.text}:${_passController.text}'))}';
      
      http.Response? finalResponse;
      int redirects = 0;

      while (redirects < 5) {
        final request = http.Request('PROPFIND', Uri.parse(url))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '0';
          
        final streamedResponse = await request.send();
        finalResponse = await http.Response.fromStream(streamedResponse);

        if (finalResponse.statusCode == 301 || finalResponse.statusCode == 302 || 
            finalResponse.statusCode == 307 || finalResponse.statusCode == 308) {
          final location = finalResponse.headers['location'];
          if (location != null) {
            url = location;
            if (!url.startsWith('http')) {
              // Handle relative redirects
              final originalUri = Uri.parse(_urlController.text);
              url = '${originalUri.scheme}://${originalUri.host}$location';
            }
            redirects++;
            continue;
          }
        }
        break; // No redirect or no location header
      }
      
      if (finalResponse != null) {
        if (finalResponse.statusCode == 207) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(context, 'test_success') ?? 'Connection successful!', style: const TextStyle(fontWeight: FontWeight.bold)),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.green,
            )
          );
        } else if (finalResponse.statusCode == 200) {
          throw Exception('The server returned 200 OK, which means it is a regular website, not a WebDAV endpoint. For Jianguoyun, the URL MUST be exactly: https://dav.jianguoyun.com/dav/');
        } else {
          throw Exception('HTTP ${finalResponse.statusCode}');
        }
      } else {
        throw Exception('No response from server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr(context, 'test_fail') ?? 'Connection failed: '}$e', style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.redAccent,
        )
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _modernDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'sync_title'))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(strokeCap: StrokeCap.round))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(tr(context, 'webdav_config'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(tr(context, 'webdav_desc'), 
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13, height: 1.5)),
              const SizedBox(height: 20),
              TextField(
                controller: _urlController,
                decoration: _modernDecoration(tr(context, 'url'), hintText: 'https://dav.jianguoyun.com/dav/'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userController,
                decoration: _modernDecoration(tr(context, 'user')),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                decoration: _modernDecoration(tr(context, 'pass')),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'auto_sync') ?? 'Auto Sync on Save', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(tr(context, 'auto_sync_desc') ?? 'Automatically backup to WebDAV when adding or editing a number', style: TextStyle(fontSize: 12)),
                value: widget.settingsManager.webDavAutoSync,
                onChanged: (val) {
                  widget.settingsManager.setWebDavAutoSync(val);
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: widget.settingsManager.gradientIndex >= 0 ? AppGradients.presets[widget.settingsManager.gradientIndex] : null,
                        color: widget.settingsManager.gradientIndex < 0 ? Theme.of(context).colorScheme.primary : null,
                      ),
                      child: FilledButton.icon(
                        onPressed: _syncToWebDav,
                        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        label: Text(tr(context, 'backup'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _syncFromWebDav,
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: Text(tr(context, 'restore'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.wifi_protected_setup_rounded),
                label: Text(tr(context, 'test_connection') ?? 'Test Connection', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _saveSettings,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(tr(context, 'save_only'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 40),
            ],
          ),
    );
  }
}

class ThemeSettingsPage extends StatelessWidget {
  final SettingsManager settingsManager;

  const ThemeSettingsPage({super.key, required this.settingsManager});

  Widget _buildColorDot(BuildContext context, Color color) {
    final isSelected = settingsManager.gradientIndex == -1 && settingsManager.themeColor.value == color.value;
    return GestureDetector(
      onTap: () => settingsManager.setThemeColor(color),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
      ),
    );
  }

  Widget _buildGradientDot(BuildContext context, int index, LinearGradient gradient) {
    final isSelected = settingsManager.gradientIndex == index;
    return GestureDetector(
      onTap: () => settingsManager.setThemeGradient(index, gradient.colors.first),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color pickerColor = settingsManager.themeColor;
        return AlertDialog(
          title: Text(tr(context, 'custom_color')),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                settingsManager.setThemeColor(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsManager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'theme_title'))),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr(context, 'appearance'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ThemeMode>(
                        value: settingsManager.themeMode,
                        focusColor: Colors.transparent,
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: Theme.of(context).cardColor,
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Row(
                              children: [
                                const Icon(Icons.brightness_auto_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(tr(context, 'sys_default'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Row(
                              children: [
                                const Icon(Icons.light_mode_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(tr(context, 'light'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Row(
                              children: [
                                const Icon(Icons.dark_mode_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(tr(context, 'dark'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) settingsManager.setThemeMode(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr(context, 'country_display'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CountryDisplayMode>(
                        value: settingsManager.countryDisplayMode,
                        focusColor: Colors.transparent,
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: Theme.of(context).cardColor,
                        items: [
                          DropdownMenuItem(
                            value: CountryDisplayMode.flag,
                            child: CustomFlag(isoCode: 'CN', height: 20, width: 28, borderRadius: 3),
                          ),
                          const DropdownMenuItem(
                            value: CountryDisplayMode.code,
                            child: Text('CN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          DropdownMenuItem(
                            value: CountryDisplayMode.both,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomFlag(isoCode: 'CN', height: 16, width: 22, borderRadius: 2),
                                const SizedBox(width: 8),
                                const Text('CN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) settingsManager.setCountryDisplayMode(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(tr(context, 'theme_color'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'presets'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildColorDot(context, Colors.blueAccent),
                        _buildColorDot(context, Colors.green),
                        _buildColorDot(context, Colors.orange),
                        _buildColorDot(context, Colors.pink),
                        for (int i = 0; i < AppGradients.presets.length; i++)
                          _buildGradientDot(context, i, AppGradients.presets[i]),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(context, 'custom_color'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: settingsManager.gradientIndex == -1 ? settingsManager.themeColor : settingsManager.themeColor,
                          gradient: settingsManager.gradientIndex >= 0 ? AppGradients.presets[settingsManager.gradientIndex] : null,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
                        ),
                      ),
                      onTap: () => _showColorPicker(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class LanguageSettingsPage extends StatelessWidget {
  final SettingsManager settingsManager;

  const LanguageSettingsPage({super.key, required this.settingsManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsManager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'lang_title'))),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(tr(context, 'language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [

                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(tr(context, 'zh_cn'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      leading: const Text('中', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      onTap: () => settingsManager.setLocale('zh'),
                      trailing: settingsManager.localeStr == 'zh' ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
                    ),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(tr(context, 'en_us'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      leading: const Text('EN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      onTap: () => settingsManager.setLocale('en'),
                      trailing: settingsManager.localeStr == 'en' ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class GeneralSettingsPage extends StatelessWidget {
  final SettingsManager settingsManager;

  const GeneralSettingsPage({super.key, required this.settingsManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsManager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'general_settings'))),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(tr(context, 'general_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(tr(context, 'copy_with_dial_code'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(tr(context, 'copy_with_dial_code_desc')),
                      value: settingsManager.copyIncludeDialCode,
                      onChanged: (val) => settingsManager.setCopyIncludeDialCode(val),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(tr(context, 'privacy_mask'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(tr(context, 'privacy_mask_desc')),
                      value: settingsManager.privacyMask,
                      onChanged: (val) => settingsManager.setPrivacyMask(val),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(tr(context, 'app_lock'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(tr(context, 'app_lock_desc')),
                      value: settingsManager.appLockEnabled,
                      onChanged: (val) {
                        if (val) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PinScreen(
                                mode: PinMode.setup,
                                settingsManager: settingsManager,
                              ),
                            ),
                          );
                        } else {
                          settingsManager.setAppLock(false, '');
                        }
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    if (settingsManager.appLockEnabled)
                      SwitchListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text(tr(context, 'biometric_auth'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(tr(context, 'biometric_auth_desc')),
                        value: settingsManager.biometricEnabled,
                        onChanged: (val) async {
                          if (val) {
                            final auth = LocalAuthentication();
                            try {
                              final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
                              if (canAuthenticate) {
                                final bool didAuthenticate = await auth.authenticate(
                                  localizedReason: tr(context, 'biometric_auth_desc'),
                                  biometricOnly: true,
                                  persistAcrossBackgrounding: true,
                                );
                                if (didAuthenticate) {
                                  settingsManager.setBiometricEnabled(true);
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'biometric_not_supported') ?? 'Biometrics not supported on this device')));
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          } else {
                            settingsManager.setBiometricEnabled(false);
                          }
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
