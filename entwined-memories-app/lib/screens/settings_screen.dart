import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import '../models/backup_health.dart';
import '../services/app_settings.dart';
import '../services/backup_reminder_service.dart';
import '../services/memory_service.dart';
import '../services/family_memory_journal_service.dart';
import '../services/encrypted_snapshot_service.dart';
import '../services/crash_diagnostic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _exportingArchive = false;
  bool _creatingEncryptedBackup = false;
  bool _verifyingEncryptedBackup = false;
  bool _restoringEncryptedBackup = false;
  bool _activatingBackupReminder = false;
  String _encryptedBackupStatus = '';
  BackupHealthStatus _backupHealth = const BackupHealthStatus();
  String _version = '';
  String _playbackPreference = 'auto';
  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.myanmar;
  String? _latestFrameworkDiagnostic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final familySettings = await MemoryService.loadFamilySettings();
    final diagnostic = await CrashDiagnosticService.readLatest();
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
      _backupHealth = familySettings.backupHealth;
      _themeMode = settings.themeMode;
      _language = settings.language;
      _latestFrameworkDiagnostic = diagnostic;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showFrameworkDiagnostic() async {
    final diagnostic = await CrashDiagnosticService.readLatest();
    if (!mounted) return;
    if (diagnostic == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ဒီ assertion diagnostic ကိုမတွေ့သေးဘူး'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _latestFrameworkDiagnostic = diagnostic);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Documents picker diagnostic'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              diagnostic,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: diagnostic));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Diagnostic stack ကိုcopy လုပ်ပြီးပြီ'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Copy diagnostic'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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

  Future<void> _exportFamilyArchive() async {
    if (_exportingArchive) return;
    setState(() => _exportingArchive = true);
    try {
      await FamilyMemoryJournalService.ensureArchiveFolderSelected();
      final archive = await FamilyMemoryJournalService.exportPortableArchive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Family Archive export ပြီးပြီ — Journal event ${archive.eventCount} ခုပါဝင်တယ်',
        ),
        backgroundColor: const Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Family Archive export မလုပ်နိုင်သေးဘူး: $error'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _exportingArchive = false);
    }
  }

  /// A dialog's result resolves before its reverse transition necessarily
  /// removes the OverlayEntry. Platform pickers must wait for the route to be
  /// fully completed, otherwise Flutter can rebuild/deactivate that Overlay
  /// while it still has inherited dependents.
  Future<T?> _showSettledDialog<T>(WidgetBuilder builder) async {
    if (!mounted) return null;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: true,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    );
    final value = await navigator.push<T>(route);
    await route.completed;
    return value;
  }

  Future<void> _showEncryptedBackupDialog() async {
    final passphraseController = TextEditingController();
    final confirmController = TextEditingController();
    String? validationMessage;

    final passphrase = await _showSettledDialog<String>(
      (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Encrypted Backup ဖန်တီးမယ်'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dad/Mom ဖုန်းနှစ်လုံးတွင်Syncthing ကကူးထားသမျှပါအပါအဝင် Original photo/video အားလုံး၊ Journal Events နဲ့ Exports ကိုဖုန်းပေါ်မှာအရင် encrypt လုပ်မယ်။ ပထမတစ်ခါမှာ Pictures/Entwined Memories Originals folder ကိုရွေးပေးရမယ်။ ဒီ password ကို app, Firebase, TeraBox, Telegram မှာမသိမ်းဘူး။',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Archive passphrase (အနည်းဆုံး ၁၆ လုံး)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Passphrase ကိုထပ်ရိုက်ပါ',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (validationMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    validationMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('မလုပ်တော့ဘူး'),
            ),
            FilledButton(
              onPressed: () {
                final passphrase = passphraseController.text;
                if (passphrase.length < 16) {
                  setDialogState(() => validationMessage =
                      'Passphrase ကို အနည်းဆုံး ၁၆ လုံးထည့်ပါ။');
                  return;
                }
                if (passphrase != confirmController.text) {
                  setDialogState(() => validationMessage =
                      'Passphrase နှစ်ခုမတူပါ။');
                  return;
                }
                Navigator.pop(dialogContext, passphrase);
              },
              child: const Text('Encrypt လုပ်မယ်'),
            ),
          ],
        ),
      ),
    );
    passphraseController.dispose();
    confirmController.dispose();
    if (passphrase == null || !mounted) return;
    await _createEncryptedBackup(passphrase);
  }

  Future<void> _createEncryptedBackup(String passphrase) async {
    if (_creatingEncryptedBackup) return;
    setState(() {
      _creatingEncryptedBackup = true;
      _encryptedBackupStatus = 'Encrypted backup ကိုပြင်ဆင်နေတယ်...';
    });
    try {
      await FamilyMemoryJournalService.ensureArchiveFolderSelected();
      if (!mounted) return;
      setState(() => _encryptedBackupStatus =
          'Original Vault folder ကိုစစ်နေတယ်... ပထမတစ်ခါဆို Pictures/Entwined Memories Originals ကိုရွေးပါ');
      await EncryptedSnapshotService.ensureOriginalVaultFolderSelected();
      if (!mounted) return;
      setState(() => _encryptedBackupStatus =
          'Dad/Mom Originals, Journal နဲ့ Exports အားလုံးကိုencrypt လုပ်ရန်ပြင်ဆင်နေတယ်...');
      final snapshot = await EncryptedSnapshotService.createCompleteSnapshot(
        passphrase: passphrase,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _encryptedBackupStatus = progress.totalFiles == 0
                ? 'Encrypted backup ကိုပြင်ဆင်နေတယ်...'
                : 'Encrypt လုပ်နေတယ်... ${progress.completedFiles}/${progress.totalFiles}';
          });
        },
      );
      String? healthSyncWarning;
      if (snapshot.created && snapshot.snapshotId != null) {
        try {
          final actor = await _backupActorLabel();
          await MemoryService.recordEncryptedSnapshot(
            snapshotId: snapshot.snapshotId!,
            createdAtUtc: snapshot.createdAtUtc,
            fileCount: snapshot.fileCount,
            partCount: snapshot.partUris.length,
            photoCount: snapshot.coverage.photos,
            videoCount: snapshot.coverage.videos,
            journalEventCount: snapshot.coverage.journalEvents,
            exportCount: snapshot.coverage.exports,
            snapshotScope: snapshot.snapshotScope,
            createdBy: actor,
          );
          await _refreshBackupHealth();
          final dueAt = _backupHealth.nextHealthCheckDueAtUtc;
          if (dueAt != null) {
            // Permission is never requested here. This only updates a reminder
            // that the parent has already enabled from its explicit action.
            try {
              await BackupReminderService.rescheduleIfEnabled(dueAt);
            } catch (_) {
              // The shared due card remains the durable reminder fallback.
            }
          }
        } catch (_) {
          // The .emb pack has already been created locally. A temporary
          // Firestore failure must not misreport that successful backup.
          healthSyncWarning = ' · Shared health status ကိုနောက်တစ်ခါ refresh လုပ်ပါ';
        }
      }
      if (!mounted) return;
      final message = snapshot.created
          ? 'Complete encrypted backup ပြီးပြီ — ပုံ ${snapshot.coverage.photos} ခု၊ video ${snapshot.coverage.videos} ခု၊ Journal ${snapshot.coverage.journalEvents} ခု၊ Export ${snapshot.coverage.exports} ခု · part ${snapshot.partUris.length} ခုထွက်တယ်${healthSyncWarning ?? ''}'
          : 'Backup ဖန်တီးမရသေးဘူး';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Encrypted backup မလုပ်နိုင်သေးဘူး: $error'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _creatingEncryptedBackup = false;
          _encryptedBackupStatus = '';
        });
      }
    }
  }

  Future<String> _backupActorLabel() async {
    final typed = _nameController.text.trim();
    if (typed.isNotEmpty) return typed;
    final settings = await MemoryService.loadFamilySettings();
    return settings.creatorName.trim().isEmpty ? 'Dad/Mom' : settings.creatorName;
  }

  Future<void> _refreshBackupHealth() async {
    final settings = await MemoryService.loadFamilySettings();
    if (!mounted) return;
    setState(() => _backupHealth = settings.backupHealth);
  }

  Future<String?> _askForArchivePassphrase({
    required String title,
    required String description,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    String? validationMessage;
    final passphrase = await _showSettledDialog<String>(
      (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Archive passphrase',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (validationMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    validationMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('မလုပ်တော့ဘူး'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length < 16) {
                  setDialogState(() => validationMessage =
                      'Archive passphrase ကို အနည်းဆုံး ၁၆ လုံးထည့်ပါ။');
                  return;
                }
                Navigator.pop(dialogContext, controller.text);
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return passphrase;
  }

  Future<void> _verifyLatestEncryptedBackup() async {
    if (_verifyingEncryptedBackup) return;
    final passphrase = await _askForArchivePassphrase(
      title: 'Latest Encrypted Backup ကိုစစ်မယ်',
      description:
          'ဖုန်းထဲရှိ နောက်ဆုံး .emb part အားလုံးကိုဒီ passphrase ဖြင့်ဖွင့်စစ်မယ်။ AES-GCM authentication နဲ့ ZIP manifest SHA-256 hash မကိုက်လျှင် အောင်မြင်သည်ဟုမပြဘူး။ Password ကိုမသိမ်းဘူး။',
      actionLabel: 'စစ်မယ်',
    );
    if (passphrase == null || !mounted) return;
    setState(() => _verifyingEncryptedBackup = true);
    try {
      final verification =
          await EncryptedSnapshotService.verifyLatestSnapshot(
        passphrase: passphrase,
      );
      final actor = await _backupActorLabel();
      await MemoryService.recordBackupVerification(
        verifiedAtUtc: verification.verifiedAtUtc,
        verifiedBy: actor,
      );
      await _refreshBackupHealth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Integrity OK — ${verification.fileCount} file, ${verification.partCount} part ကိုစစ်ပြီးပြီ',
        ),
        backgroundColor: const Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Encrypted backup စစ်မရသေးဘူး: $error'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _verifyingEncryptedBackup = false);
    }
  }

  Future<void> _restoreEncryptedBackup() async {
    if (_restoringEncryptedBackup) return;
    final passphrase = await _askForArchivePassphrase(
      title: 'Encrypted Backup Restore',
      description:
          'အရင်ဆုံး .emb file အားလုံးရှိသည့် source folder ကိုရွေးပါ။ ပြီးလျှင် restore ထုတ်မည့် အလွတ်/new destination folder ကိုရွေးပါ။ App က snapshot folder အသစ်သာဖန်တီးပြီးရှိပြီးသား file/folder ကိုမရေးထပ်ဘူး။',
      actionLabel: 'Folder ရွေးမယ်',
    );
    if (passphrase == null || !mounted) return;
    setState(() => _restoringEncryptedBackup = true);
    try {
      final restored =
          await EncryptedSnapshotService.restoreFromSelectedFolder(
        passphrase: passphrase,
      );
      final actor = await _backupActorLabel();
      await MemoryService.recordRestoreDrill(
        restoredAtUtc: restored.restoredAtUtc,
        restoredBy: actor,
      );
      await _refreshBackupHealth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Restore ပြီးပြီ — ${restored.fileCount} file ကိုfolder အသစ်ထဲမှာပြန်ထုတ်ထားတယ်',
        ),
        backgroundColor: const Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Encrypted backup restore မလုပ်နိုင်သေးဘူး: $error'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _restoringEncryptedBackup = false);
    }
  }

  Future<void> _activateSixMonthReminder() async {
    if (_activatingBackupReminder) return;
    final dueAt = _backupHealth.nextHealthCheckDueAtUtc;
    if (dueAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Encrypted backup တစ်ခုအောင်မြင်ပြီးမှ ၆ လ reminder သတ်မှတ်လို့ရမယ်။'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _activatingBackupReminder = true);
    try {
      final enabled = await BackupReminderService.requestPermissionAndSchedule(
        dueAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled
            ? 'ဒီဖုန်းအတွက် ၆ လ health reminder ဖွင့်ပြီးပြီ'
            : 'Notification permission မပေးရသေးဘူး။ App ထဲက due card ကိုတော့ဆက်မြင်ရမယ်'),
        backgroundColor: enabled ? const Color(0xFFE8A0B4) : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reminder သတ်မှတ်မရသေးဘူး: $error'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _activatingBackupReminder = false);
    }
  }

  Future<void> _showOffsiteChecklist({required bool teraBox}) async {
    if (!_hasCompleteMediaSnapshot) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Photo/video အစစ်ပါတဲ့ Complete Encrypted Backup အသစ်ကိုအရင်လုပ်ပြီး Verify/Restore စစ်ပါ။ အဟောင်း Journal-only snapshot ကိုTeraBox/Telegram မတင်သေးပါ။',
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    var acknowledged = false;
    final title = teraBox ? 'TeraBox encrypted upload checklist' : 'Dad-only Telegram checklist';
    final completed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teraBox
                    ? '1. Documents/Entwined Memories Archive/Encrypted Backups ထဲက နောက်ဆုံး snapshot_..._part001.emb မှစ၍ part အားလုံးကိုရှာပါ။\n\n2. TeraBox app ထဲသို့ကိုယ်တိုင်ဝင်ပြီး .emb file များကို File/Document အဖြစ်တင်ပါ။ Name မပြောင်းပါနှင့်၊ part တစ်ခုတည်းမကျန်စေပါနှင့်။\n\n3. Photo/video အစစ်၊ Journal folder အစစ်၊ archive passphrase၊ recovery note တို့ကို TeraBox မတင်ပါနှင့်။ .emb encrypted parts သာတင်ပါ။\n\n4. Upload ပြီးလျှင် part အားလုံးမြင်ရကြောင်းစစ်ပါ။'
                    : '1. Dad ၏ Telegram account တစ်ခုတည်းပါဝင်သော private channel ကိုဖွင့်ပါ။ Mom/အခြား account မထည့်ပါနှင့်။\n\n2. နောက်ဆုံး .emb part အားလုံးကို attachment ရှိ File/Document အဖြစ်တင်ပါ။ Gallery/media အဖြစ်မတင်ပါနှင့်၊ file name မပြောင်းပါနှင့်။\n\n3. Photo/video အစစ်၊ Journal folder အစစ်၊ archive passphrase၊ recovery note၊ TeraBox login အချက်အလက်တစ်ခုမျှ channel ထဲမတင်ပါနှင့်။\n\n4. Upload ပြီးလျှင် part အားလုံးနှင့်file name များကိုစစ်ပါ။'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acknowledged,
                  onChanged: (value) => setDialogState(
                    () => acknowledged = value ?? false,
                  ),
                  title: const Text('အထက်ပါအဆင့်များကိုပြီးစီးပြီး encrypted .emb files သာတင်/စစ်ပြီးပြီ'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('နောက်မှလုပ်မယ်'),
            ),
            FilledButton(
              onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Completed အဖြစ်မှတ်မယ်'),
            ),
          ],
        ),
      ),
    );
    if (completed != true || !mounted) return;
    try {
      final actor = await _backupActorLabel();
      final now = DateTime.now().toUtc();
      if (teraBox) {
        await MemoryService.recordTeraBoxCheck(
          checkedAtUtc: now,
          checkedBy: actor,
        );
      } else {
        await MemoryService.recordTelegramCheck(
          checkedAtUtc: now,
          checkedBy: actor,
        );
      }
      await _refreshBackupHealth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Shared Family Backup Health status ကိုupdate လုပ်ပြီးပြီ'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Shared health status မသိမ်းနိုင်သေးဘူး: $error'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _formatHealthTime(DateTime? value) {
    if (value == null) return 'မစစ်ရသေးဘူး';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _healthLine(DateTime? value, String? actor) {
    final time = _formatHealthTime(value);
    return actor == null || actor.isEmpty ? time : '$time · $actor';
  }

  String _snapshotCoverageLine() {
    if (!_backupHealth.hasSnapshot) return 'မဖန်တီးရသေးဘူး';
    if (_backupHealth.latestSnapshotScope != 'complete') {
      return 'အဟောင်း snapshot ဖြစ်တယ် — Dad/Mom Originals အားလုံးပါသော Complete Backup အသစ်လုပ်ပါ';
    }
    return 'ပုံ ${_backupHealth.latestSnapshotPhotoCount} ခု · video ${_backupHealth.latestSnapshotVideoCount} ခု · Journal ${_backupHealth.latestSnapshotJournalEventCount} ခု · Export ${_backupHealth.latestSnapshotExportCount} ခု';
  }

  bool get _hasCompleteMediaSnapshot =>
      _backupHealth.latestSnapshotScope == 'complete' &&
      (_backupHealth.latestSnapshotPhotoCount +
              _backupHealth.latestSnapshotVideoCount) >
          0;

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
    final backupDue = _backupHealth.isDueAt(DateTime.now());
    final nextDue = _backupHealth.nextHealthCheckDueAtUtc;

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
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFFE8A0B4),
                    ),
                    title: const Text('Family Archive Export'),
                    subtitle: const Text(
                      'စာသားမှတ်တမ်းအတွက်သာပါ — caption, date, note နဲ့ Journal CSV/JSON ကိုထုတ်မယ်။ ပုံ/video ဖိုင် မပါဘူး။',
                    ),
                    trailing: _exportingArchive
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE8A0B4),
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _exportingArchive ? null : _exportFamilyArchive,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFFE8A0B4),
                    ),
                    title: const Text('Encrypted Backup ဖန်တီးမယ်'),
                    subtitle: Text(
                      _creatingEncryptedBackup
                          ? _encryptedBackupStatus
                          : 'Dad/Mom Originals အားလုံး (Syncthing ကကူးထားတာပါ) + Journal/Exports ကိုpassword နဲ့သော့ခတ်တဲ့ Complete .emb backup လုပ်မယ်',
                    ),
                    trailing: _creatingEncryptedBackup
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE8A0B4),
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _creatingEncryptedBackup
                        ? null
                        : _showEncryptedBackupDialog,
                  ),
                ),
                if (_latestFrameworkDiagnostic != null) ...[
                  Card(
                    color: const Color(0xFFFFF0F2),
                    child: ListTile(
                      leading: const Icon(Icons.bug_report_outlined,
                          color: Colors.deepOrange),
                      title: const Text('Documents picker diagnostic available'),
                      subtitle: const Text(
                        'ဒီဖုန်းတွင်ဖြစ်ခဲ့သော _dependents assertion stack ကိုသာကြည့်/copy လုပ်နိုင်တယ်။ Photo, video, password, TeraBox/Telegram login ကိုမသိမ်းဘူး။',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showFrameworkDiagnostic,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  color: backupDue
                      ? const Color(0xFFFFF0F2)
                      : Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              backupDue
                                  ? Icons.warning_amber_rounded
                                  : Icons.health_and_safety_outlined,
                              color: backupDue
                                  ? Colors.deepOrange
                                  : const Color(0xFFE8A0B4),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Family Backup Health',
                                style: TextStyle(
                                  color: onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh shared status',
                              onPressed: _refreshBackupHealth,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        Text(
                          !_backupHealth.hasSnapshot
                              ? 'အဆင့် ၁: Complete Encrypted Backup ကိုအရင်လုပ်ပါ။ အဲဒီနောက် Verify → Restore → TeraBox/Telegram အစဉ်လိုက်စစ်မယ်။'
                              : backupDue
                                  ? '၆ လ health check အချိန်ရောက်ပြီ — .emb parts, TeraBox, Telegram နဲ့ restore/verify ကိုစစ်ပါ။'
                                  : 'Backup စာရင်းကိုဒီမှာကြည့်ပြီး ၆ လနောက် ${_formatHealthTime(nextDue)} တွင်ပြန်စစ်ပါ။',
                          style: TextStyle(color: muted, height: 1.35),
                        ),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Latest encrypted snapshot'),
                          subtitle: Text(_backupHealth.hasSnapshot
                              ? '${_snapshotCoverageLine()}\nစုစုပေါင်း ${_backupHealth.latestSnapshotFileCount} file · ${_backupHealth.latestSnapshotPartCount} part · ${_healthLine(_backupHealth.latestSnapshotCreatedAtUtc, _backupHealth.latestSnapshotCreatedBy)}'
                              : 'အဆင့် ၁ — Photo/video အစစ် + Journal/Exports ပါသော Complete .emb backup ကိုဖန်တီးပါ'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: const Text('Latest local integrity verification'),
                          subtitle: Text(
                            _backupHealth.latestVerifiedAtUtc == null
                                ? 'အဆင့် ၂ — နောက်ဆုံး .emb box မပျက်ဘူးလား၊ passphrase နဲ့ဖွင့်လို့ရလားကိုစစ်ပါ'
                                : '${_healthLine(_backupHealth.latestVerifiedAtUtc, _backupHealth.latestVerifiedBy)}\nPassphrase မှန်ပြီး .emb files မပျက်ကြောင်းစစ်ပြီးပါပြီ',
                          ),
                          trailing: _verifyingEncryptedBackup
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFE8A0B4),
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _verifyingEncryptedBackup
                              ? null
                              : _verifyLatestEncryptedBackup,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.restore_page_outlined),
                          title: const Text('Restore encrypted .emb files'),
                          subtitle: Text(
                            _backupHealth.lastRestoreDrillAtUtc == null
                                ? 'အဆင့် ၃ — .emb files အားလုံးကိုရွေးပြီး folder အသစ်ထဲသို့သာပြန်ထုတ်စမ်းမယ်။ Originals ကိုမoverwrite လုပ်ဘူး'
                                : 'Last drill: ${_healthLine(_backupHealth.lastRestoreDrillAtUtc, _backupHealth.lastRestoreDrillBy)}\nဖုန်းပျက်လျှင်ပြန်ထုတ်နိုင်ကြောင်းစမ်းပြီးပါပြီ',
                          ),
                          trailing: _restoringEncryptedBackup
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFE8A0B4),
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _restoringEncryptedBackup
                              ? null
                              : _restoreEncryptedBackup,
                        ),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: const Text('TeraBox encrypted copy'),
                          subtitle: Text(
                            _backupHealth.teraBoxCheckedAtUtc == null
                                ? 'အဆင့် ၄ — Complete .emb files အားလုံးကိုTeraBox သို့File/Document အဖြစ်ကိုယ်တိုင်တင်ပါ။ Raw photo/video မတင်ပါနှင့်'
                                : '${_healthLine(_backupHealth.teraBoxCheckedAtUtc, _backupHealth.teraBoxCheckedBy)}\nEncrypted .emb files အားလုံးTeraBox မှာရှိကြောင်းစစ်ပြီးပါပြီ',
                          ),
                          trailing: const Icon(Icons.checklist_outlined),
                          onTap: () => _showOffsiteChecklist(teraBox: true),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.send_outlined),
                          title: const Text('Dad-only Telegram encrypted copy'),
                          subtitle: Text(
                            _backupHealth.telegramCheckedAtUtc == null
                                ? 'အဆင့် ၅ — Dad တစ်ယောက်တည်းရှိသောprivate Telegram channel သို့တူညီတဲ့ .emb files ကိုDocument အဖြစ်တင်ပါ'
                                : '${_healthLine(_backupHealth.telegramCheckedAtUtc, _backupHealth.telegramCheckedBy)}\nDad-only encrypted copy ကိုစစ်ပြီးပါပြီ',
                          ),
                          trailing: const Icon(Icons.checklist_outlined),
                          onTap: () => _showOffsiteChecklist(teraBox: false),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _activatingBackupReminder
                                ? null
                                : _activateSixMonthReminder,
                            icon: _activatingBackupReminder
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.notifications_active_outlined),
                            label: const Text('ဒီဖုန်းအတွက် ၆ လ Reminder ဖွင့်/Update လုပ်မယ်'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'အဆင့် ၆ — ဒီဖုန်းမှာ၆ လ reminder ဖွင့်ပါ။ Notification မပေါ်လျှင်လည်း Settings ဖွင့်ရာတွင်ဒီ shared due card ကိုမြင်ရမယ်။ Passphrase၊ TeraBox login နဲ့ Telegram login ကိုapp/Firestore ထဲမသိမ်းဘူး။',
                          style: TextStyle(color: muted, fontSize: 12, height: 1.35),
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