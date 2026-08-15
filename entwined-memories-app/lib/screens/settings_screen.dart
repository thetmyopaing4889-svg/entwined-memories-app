import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/app_settings.dart';
import '../services/memory_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _version = '';
  String _playbackPreference = 'auto';
  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.myanmar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final familySettings = await MemoryService.loadFamilySettings();
    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = 'v${info.version} (${info.buildNumber})';
    } catch (_) {
      version = '';
    }
    if (!mounted) return;
    final settings = AppSettingsScope.of(context);
    setState(() {
      _nameController.text = familySettings.creatorName;
      _version = version;
      _playbackPreference = familySettings.playbackPreference;
      _themeMode = settings.themeMode;
      _language = settings.language;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await MemoryService.saveFamilySettings(
          creatorName: _nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.of(context).appSaved),
          backgroundColor: const Color(0xFFE8A0B4),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Setting သိမ်းမရသေးဘူး: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePlaybackPreference(String? value) async {
    if (value == null) return;
    setState(() => _playbackPreference = value);
    try {
      await MemoryService.saveFamilySettings(playbackPreference: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(context).isEnglish
            ? 'Playback setting saved'
            : 'Playback setting သိမ်းပြီးပြီ'),
        backgroundColor: const Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Playback setting သိမ်းမရသေးဘူး: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _saveTheme(ThemeMode? value) async {
    if (value == null) return;
    setState(() => _themeMode = value);
    try {
      await AppSettingsScope.of(context).setThemeMode(value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Theme သိမ်းမရသေးဘူး: $error')),
        );
      }
    }
  }

  Future<void> _saveLanguage(AppLanguage? value) async {
    if (value == null) return;
    setState(() => _language = value);
    try {
      await AppSettingsScope.of(context).setLanguage(value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language သိမ်းမရသေးဘူး: $error')),
        );
      }
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Entwined Memories',
      applicationVersion: _version.isEmpty ? null : _version,
      applicationIcon: const Icon(
        Icons.favorite_rounded,
        color: Color(0xFFE8A0B4),
        size: 34,
      ),
      children: const [
        Text(
          'A quiet memory home for the moments a family never wants to lose.',
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(strings.settings)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Color(0xFFE8A0B4),
                    ),
                    title: Text(strings.about),
                    subtitle: Text(strings.versionAndStory),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showAbout,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.appearance,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.theme,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          value: ThemeMode.light,
                          groupValue: _themeMode,
                          title: Text(strings.light),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _saveTheme,
                        ),
                        RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          value: ThemeMode.dark,
                          groupValue: _themeMode,
                          title: Text(strings.dark),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _saveTheme,
                        ),
                        RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          value: ThemeMode.system,
                          groupValue: _themeMode,
                          title: Text(strings.system),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _saveTheme,
                        ),
                        const Divider(),
                        Text(
                          strings.language,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        RadioListTile<AppLanguage>(
                          contentPadding: EdgeInsets.zero,
                          value: AppLanguage.myanmar,
                          groupValue: _language,
                          title: Text(strings.myanmar),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _saveLanguage,
                        ),
                        RadioListTile<AppLanguage>(
                          contentPadding: EdgeInsets.zero,
                          value: AppLanguage.english,
                          groupValue: _language,
                          title: Text(strings.english),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _saveLanguage,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.playbackSetting,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.isEnglish
                              ? 'Choose automatic or manual story playback'
                              : 'Memory story ကို အလိုအလျောက် ပြမလား၊ ကိုယ်တိုင် swipe လုပ်မလား',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: 'auto',
                          groupValue: _playbackPreference,
                          title: Text(strings.autoSlideshow),
                          subtitle: Text(strings.isEnglish
                              ? 'Show each memory for four seconds'
                              : 'Memory တစ်ခုကို ၄ စက္ကန့်ပြမယ်'),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _savePlaybackPreference,
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: 'manual',
                          groupValue: _playbackPreference,
                          title: Text(strings.manual),
                          subtitle: Text(strings.isEnglish
                              ? 'Swipe through memories yourself'
                              : 'ကိုယ်တိုင် swipe လုပ်မယ်'),
                          activeColor: const Color(0xFFE8A0B4),
                          onChanged: _savePlaybackPreference,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  strings.creatorName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: strings.creatorHint,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.creatorHelper,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A0B4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            strings.save,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.info_outline,
                    color: Color(0xFFE8A0B4),
                  ),
                  title: const Text('Entwined Memories'),
                  subtitle: Text(
                    _version.isEmpty
                        ? 'For My Baby 💕'
                        : '$_version · For My Baby 💕',
                  ),
                ),
                 const SizedBox(height: 16),
                 OutlinedButton.icon(
                   onPressed: _signOut,
                   icon: const Icon(Icons.logout_rounded),
                   label: const Text('Sign out'),
                   style: OutlinedButton.styleFrom(
                     foregroundColor: const Color(0xFF8B3A52),
                     side: const BorderSide(color: Color(0xFFFFC6D5)),
                     padding: const EdgeInsets.symmetric(vertical: 13),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(14),
                     ),
                   ),
                 ),
              ],
            ),
    );
  }
}