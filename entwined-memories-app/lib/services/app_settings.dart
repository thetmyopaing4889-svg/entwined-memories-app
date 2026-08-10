import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { myanmar, english }

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'entwined_theme_mode';
  static const _languageKey = 'entwined_language';

  ThemeMode _themeMode;
  AppLanguage _language;

  AppSettings({
    ThemeMode themeMode = ThemeMode.light,
    AppLanguage language = AppLanguage.myanmar,
  })  : _themeMode = themeMode,
        _language = language;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_themeKey);
    final language = prefs.getString(_languageKey);

    return AppSettings(
      themeMode: switch (theme) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      language: language == 'english'
          ? AppLanguage.english
          : AppLanguage.myanmar,
    );
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      switch (_themeMode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      },
    );
    await prefs.setString(
      _languageKey,
      _language == AppLanguage.english ? 'english' : 'myanmar',
    );
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope is missing above this context');
    return scope!.notifier!;
  }
}

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  static AppStrings of(BuildContext context) =>
      AppStrings(AppSettingsScope.of(context).language);

  bool get isEnglish => language == AppLanguage.english;

  String get home => isEnglish ? 'Home' : 'ပင်မ';
  String get profile => isEnglish ? 'Profile' : 'Profile';
  String get playback => isEnglish ? 'Playback' : 'ပြန်ကြည့်ရန်';
  String get settings => isEnglish ? 'Settings' : 'Settings';
  String get save => isEnglish ? 'Save' : 'သိမ်းမယ်';
  String get childName => isEnglish ? 'Child name' : 'ကလေးနာမည်';
  String get birthday => isEnglish ? 'Birthday' : 'မွေးနေ့';
  String get chooseBirthday =>
      isEnglish ? 'Choose a birthday' : 'မွေးနေ့ ရွေးပါ';
  String get profilePhoto => isEnglish ? 'Profile photo' : 'Profile photo';
  String get coverPhoto => isEnglish ? 'Cover photo' : 'Cover photo';
  String get changeCoverPhoto =>
      isEnglish ? 'Change cover photo' : 'Cover photo ပြင်မယ်';
  String get creatorName => isEnglish ? 'Your name' : 'သင့်နာမည်';
  String get creatorHint =>
      isEnglish ? 'Dad / Mom / name' : 'Dad / Mom / နာမည်';
  String get creatorHelper => isEnglish
      ? 'This name appears as “Added by” when you add a memory.'
      : 'Memory အသစ်ထည့်တဲ့အခါ ဒီနာမည်ကို “Added by” အနေနဲ့ ပြပါလိမ့်မယ်';
  String get appearance => isEnglish ? 'Appearance' : 'အသွင်အပြင်';
  String get theme => isEnglish ? 'Theme' : 'Theme';
  String get light => isEnglish ? 'Light' : 'အလင်း';
  String get dark => isEnglish ? 'Dark' : 'အမှောင်';
  String get system => isEnglish ? 'System default' : 'ဖုန်း setting အတိုင်း';
  String get language => isEnglish ? 'Language' : 'ဘာသာစကား';
  String get myanmar => isEnglish ? 'Myanmar' : 'မြန်မာ';
  String get english => isEnglish ? 'English' : 'အင်္ဂလိပ်';
  String get playbackSetting =>
      isEnglish ? 'Playback' : 'Memory story ပြန်ကြည့်ခြင်း';
  String get autoSlideshow =>
      isEnglish ? 'Auto slideshow' : 'Auto slideshow';
  String get manual => isEnglish ? 'Manual' : 'Manual';
  String get about => isEnglish ? 'About the app' : 'App အကြောင်း';
  String get versionAndStory =>
      isEnglish ? 'Version and project story' : 'Version နှင့် project အကြောင်း';
  String get appSaved => isEnglish ? 'Saved' : 'သိမ်းပြီးပြီ';
  String get profileSaved =>
      isEnglish ? 'Profile saved' : 'Profile သိမ်းပြီးပြီ';
  String get coverSaved =>
      isEnglish ? 'Cover photo saved' : 'Cover photo သိမ်းပြီးပြီ';
  String get galleryError => isEnglish
      ? 'Could not open the gallery. Check permissions.'
      : 'Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။';
  String get nameRequired =>
      isEnglish ? 'Please enter the child name' : 'ကလေးနာမည် ရေးပါ';
  String get retry => isEnglish ? 'Try again' : 'ထပ်ကြိုးစားမယ်';
}