import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'custom_flag.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'pin_screen.dart';
import 'models.dart';
import 'edit_number_page.dart';
import 'settings_page.dart';
import 'l10n.dart';
import 'notification_manager.dart';
import 'keep_alive_page.dart';

final SettingsManager globalSettings = SettingsManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationManager().init();
  await globalSettings.loadSettings();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    globalSettings.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIMVault',
      debugShowCheckedModeBanner: false,
      themeMode: globalSettings.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: globalSettings.themeColor,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: globalSettings.themeColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    // Since settings are now loaded before runApp, we can just check it directly.
    if (!globalSettings.appLockEnabled) {
      _isUnlocked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!globalSettings.appLockEnabled || _isUnlocked) {
      return const HomePage();
    } else {
      return PinScreen(
        mode: PinMode.unlock,
        settingsManager: globalSettings,
        onUnlocked: () {
          setState(() {
            _isUnlocked = true;
          });
        },
      );
    }
  }
}



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum SortMode { expiration, name, added }

class _HomePageState extends State<HomePage> {
  final PhoneNumberManager _manager = PhoneNumberManager();
  bool _isSearching = false;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.expiration;
  Timer? _timer;

  void _onGlobalSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    globalSettings.addListener(_onGlobalSettingsChanged);
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {});
    });
    _manager.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager().requestPermissions();
      if (globalSettings.isFirstLaunch) {
        NotificationManager().showWelcomeNotification();
      }
    });
  }

  @override
  void dispose() {
    globalSettings.removeListener(_onGlobalSettingsChanged);
    _timer?.cancel();
    _manager.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'copied'), style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _maskNumber(String number) {
    if (number.length < 5) return number;
    final int start = 3;
    final int end = number.length - 2;
    return number.replaceRange(start, end, '*' * (end - start));
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: globalSettings.gradientIndex >= 0 
                          ? AppGradients.presets[globalSettings.gradientIndex] 
                          : null,
                      color: globalSettings.gradientIndex < 0 
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.security_rounded, size: 36, color: globalSettings.gradientIndex >= 0 ? Colors.white : Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SIMVault',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(context, 'subtitle'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(Icons.cloud_sync_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text(tr(context, 'sync_settings'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SyncSettingsPage(
                      settingsManager: globalSettings,
                      phoneManager: _manager,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('通知保活设置', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KeepAlivePage()),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text(tr(context, 'theme_settings'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ThemeSettingsPage(
                      settingsManager: globalSettings,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(Icons.language_rounded, color: Theme.of(context).colorScheme.onSurface),
              title: Text(tr(context, 'lang_settings'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LanguageSettingsPage(
                      settingsManager: globalSettings,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text(tr(context, 'general_settings'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GeneralSettingsPage(
                      settingsManager: globalSettings,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onSurface),
              title: Text(tr(context, 'recycle_bin'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecycleBinPage(manager: _manager),
                  ),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                tr(context, 'version'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredItems = _manager.items.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.label.toLowerCase().contains(query) ||
             item.number.contains(query) ||
             item.remark.toLowerCase().contains(query) ||
             item.country.name.toLowerCase().contains(query);
    }).toList();

    filteredItems.sort((a, b) {
      if (_sortMode == SortMode.name) {
        return a.label.compareTo(b.label);
      } else if (_sortMode == SortMode.added) {
        return a.id.compareTo(b.id);
      } else {
        return a.expireDate.compareTo(b.expireDate);
      }
    });

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: tr(context, 'search_hint'),
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('SIMVault'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (SortMode result) {
              setState(() { _sortMode = result; });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortMode>>[
              PopupMenuItem<SortMode>(
                value: SortMode.expiration,
                child: Text(tr(context, 'sort_default'), style: TextStyle(fontWeight: _sortMode == SortMode.expiration ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<SortMode>(
                value: SortMode.name,
                child: Text(tr(context, 'sort_name'), style: TextStyle(fontWeight: _sortMode == SortMode.name ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<SortMode>(
                value: SortMode.added,
                child: Text(tr(context, 'sort_added'), style: TextStyle(fontWeight: _sortMode == SortMode.added ? FontWeight.bold : FontWeight.normal)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: filteredItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sim_card_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, 'no_data'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, 'add_first'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildListItem(item, context);
              },
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: globalSettings.gradientIndex >= 0 ? AppGradients.presets[globalSettings.gradientIndex] : null,
          color: globalSettings.gradientIndex < 0 ? Theme.of(context).colorScheme.primary : null,
          boxShadow: [
            BoxShadow(
              color: (globalSettings.gradientIndex >= 0 ? AppGradients.presets[globalSettings.gradientIndex].colors.first : Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditNumberPage(manager: _manager),
              ),
            );
          },
          elevation: 0,
          backgroundColor: Colors.transparent,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(tr(context, 'add_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }

  Widget _buildListItem(PhoneNumberItem item, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = item.expireDate;
    final expDate = DateTime(exp.year, exp.month, exp.day);
    final difference = expDate.difference(today);
    final days = difference.inDays;
    
    final int maxReminder = item.remindBeforeDays.isNotEmpty 
        ? item.remindBeforeDays.reduce((a, b) => a > b ? a : b) 
        : 7;
    final isReminding = days <= maxReminder;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget countryIndicator;
    switch (globalSettings.countryDisplayMode) {
      case CountryDisplayMode.code:
        countryIndicator = Text(item.country.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
        break;
      case CountryDisplayMode.both:
        countryIndicator = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomFlag(isoCode: item.country.code, height: 16, width: 22, borderRadius: 2),
            const SizedBox(width: 6),
            Text(item.country.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        );
        break;
      case CountryDisplayMode.flag:
      default:
        countryIndicator = CustomFlag(isoCode: item.country.code, height: 20, width: 28, borderRadius: 3);
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Slidable(
        key: ValueKey(item.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.65,
          children: [
            const SizedBox(width: 8),
            SlidableAction(
              onPressed: (context) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditNumberPage(manager: _manager, existingItem: item),
                  ),
                );
              },
              backgroundColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
              foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              icon: Icons.edit_rounded,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 8),
            SlidableAction(
              onPressed: (context) {
                _manager.resetCycle(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr(context, 'reset_success'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              backgroundColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
              foregroundColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              icon: Icons.refresh_rounded,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 8),
            SlidableAction(
              onPressed: (context) {
                _manager.removeItem(item.id);
              },
              backgroundColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
              foregroundColor: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
              icon: Icons.delete_outline_rounded,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _copyToClipboard(globalSettings.copyIncludeDialCode ? '${item.country.dialCode} ${item.number}' : item.number),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            countryIndicator,
                            const SizedBox(width: 10),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isReminding)
                              Container(
                                margin: const EdgeInsets.only(left: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tr(context, 'expiring'),
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${item.country.dialCode} ${globalSettings.privacyMask ? _maskNumber(item.number) : item.number}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        if (item.remark.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              item.remark,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), 
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildCountdown(days, item.cycleDays, context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown(int days, int maxDays, BuildContext context) {
    double progress = days / (maxDays > 0 ? maxDays : 1);
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    Color color = Colors.green;
    if (days <= 7) {
      color = Colors.redAccent;
    } else if (days <= 30) {
      color = Colors.orangeAccent;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.5,
            strokeCap: StrokeCap.round,
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              days > 0 ? '$days' : '0',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              tr(context, 'days'),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        )
      ],
    );
  }
}

class RecycleBinPage extends StatelessWidget {
  final PhoneNumberManager manager;

  const RecycleBinPage({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'recycle_bin'))),
          body: manager.deletedItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        tr(context, 'empty_recycle_bin'),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: manager.deletedItems.length,
                  itemBuilder: (context, index) {
                    final item = manager.deletedItems[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.country.dialCode} ${item.number}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_rounded, color: Colors.green),
                              tooltip: tr(context, 'restore_item'),
                              onPressed: () {
                                manager.restoreItem(item.id);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                              tooltip: tr(context, 'permanent_delete'),
                              onPressed: () {
                                manager.permanentlyDeleteItem(item.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      }
    );
  }
}
