package com.entwinedmemories.entwined_memories

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.InputStream
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.spec.KeySpec
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import org.json.JSONArray
import org.json.JSONObject

/**
 * Android-only bridge for preserving parents' selected source photos and videos.
 * It writes byte-for-byte copies to shared Pictures storage so Syncthing-Fork can
 * sync one dedicated family-vault folder. It never enumerates or copies the
 * device's full gallery.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val VAULT_CHANNEL = "entwined_memories/original_vault"
        private const val JOURNAL_CHANNEL = "entwined_memories/family_journal"
        private const val VAULT_ROOT = "Pictures/Entwined Memories Originals"
        private const val JOURNAL_PREFERENCES = "family_memory_journal"
        private const val JOURNAL_TREE_URI_KEY = "archive_tree_uri"
        private const val ORIGINAL_VAULT_PREFERENCES = "original_vault_snapshot"
        private const val ORIGINAL_VAULT_TREE_URI_KEY = "original_vault_tree_uri"
        private const val JOURNAL_ROOT_DIRECTORY = "Entwined Memories Archive"
        private const val JOURNAL_EVENTS_DIRECTORY = "Journal Events"
        private const val JOURNAL_FOLDER_REQUEST_CODE = 9421
        private const val SNAPSHOT_SOURCE_FOLDER_REQUEST_CODE = 9422
        private const val SNAPSHOT_RESTORE_FOLDER_REQUEST_CODE = 9423
        private const val ORIGINAL_VAULT_FOLDER_REQUEST_CODE = 9424
        private const val SNAPSHOT_CHANNEL = "entwined_memories/encrypted_snapshot"
        private const val DIAGNOSTIC_CHANNEL = "entwined_memories/crash_diagnostics"
        private const val DIAGNOSTIC_FILE_NAME = "latest_flutter_framework_diagnostic.txt"
        private const val BACKUP_DIAGNOSTIC_FILE_NAME = "latest_encrypted_backup_diagnostic.txt"
        private const val PREPARED_RECOVERY_CATALOG_FILE_NAME = "prepared_recovery_catalog.json"
        private const val MAX_RECOVERY_CATALOG_BYTES = 25 * 1024 * 1024
        private const val SNAPSHOT_PREFERENCES = "encrypted_snapshot"
        private const val SNAPSHOT_CURSOR_KEY = "last_completed_snapshot_utc_millis"
        private const val SNAPSHOT_LAST_ID_KEY = "last_completed_snapshot_id"
        private const val ENCRYPTED_BACKUPS_DIRECTORY = "Encrypted Backups"
        private const val ENCRYPTED_BACKUP_MAGIC = "EMBACKUP1"
        private const val ENCRYPTED_BACKUP_VERSION = 1
        private const val PBKDF2_ITERATIONS = 210_000
        private const val ENCRYPTED_PACK_TARGET_BYTES = 1_250_000_000L
    }

    private enum class VaultMediaKind(
        val channelMethod: String,
        val subdirectory: String,
        val filePrefix: String,
    ) {
        PHOTO("archiveOriginalPhoto", "", "EMP"),
        VIDEO("archiveOriginalVideo", "Videos", "EMV"),
    }

    private val vaultExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingJournalFolderResult: MethodChannel.Result? = null
    private data class PendingJournalFolderCompletion(
        val result: MethodChannel.Result,
        val payload: Map<String, Any?>? = null,
        val errorCode: String? = null,
        val errorMessage: String? = null,
    )
    private var pendingJournalFolderCompletion: PendingJournalFolderCompletion? = null
    private var pendingOriginalVaultFolderResult: MethodChannel.Result? = null
    private var pendingOriginalVaultFolderCompletion: PendingJournalFolderCompletion? = null
    private var activityIsPostResumed = false
    private data class PendingSnapshotRestore(
        val passphrase: String,
        val result: MethodChannel.Result,
        var sourceTreeUri: Uri? = null,
    )
    private var pendingSnapshotRestore: PendingSnapshotRestore? = null
    private var snapshotChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VAULT_CHANNEL)
            .setMethodCallHandler { call, result ->
                val mediaKind = VaultMediaKind.values().firstOrNull {
                    it.channelMethod == call.method
                }
                if (mediaKind == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                archive(call, result, mediaKind)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, JOURNAL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isArchiveFolderSelected" -> result.success(journalTreeUri() != null)
                    "ensureArchiveFolderSelected" -> ensureJournalFolderSelected(result)
                    "appendJournalEvent" -> appendJournalEvent(call, result)
                    "writeRecoveryCatalog" -> writeRecoveryCatalog(call, result)
                    "prepareRestoredRecoveryCatalog" -> prepareRestoredRecoveryCatalog(call, result)
                    "exportPortableArchive" -> exportPortableArchive(result)
                    else -> result.notImplemented()
                }
            }
        snapshotChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SNAPSHOT_CHANNEL)
        snapshotChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isOriginalVaultFolderSelected" -> result.success(originalVaultTreeUri() != null)
                "ensureOriginalVaultFolderSelected" -> ensureOriginalVaultFolderSelected(result)
                                    "createJournalSnapshot" -> createJournalSnapshot(call, result)
                    "checkRestoredVaultReferences" -> checkRestoredVaultReferences(call, result)
                    "readLatestBackupDiagnostic" -> readLatestBackupDiagnostic(result)

                "verifyLatestSnapshot" -> verifyLatestSnapshot(call, result)
                "restoreSnapshotFromSelectedFolder" -> restoreSnapshotFromSelectedFolder(call, result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIAGNOSTIC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recordFlutterDiagnostic" -> recordFlutterDiagnostic(call, result)
                    "readLatestFlutterDiagnostic" -> readLatestFlutterDiagnostic(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun recordFlutterDiagnostic(call: MethodCall, result: MethodChannel.Result) {
        val kind = call.argument<String>("kind") ?: "flutter_framework_error"
        val exception = call.argument<String>("exception") ?: ""
        val stack = call.argument<String>("stack") ?: ""
        val context = call.argument<String>("context") ?: ""
        val library = call.argument<String>("library") ?: ""
        val recordedAtUtc = call.argument<String>("recordedAtUtc") ?: ""
        if (!exception.contains("_dependents.isEmpty")) {
            result.success(false)
            return
        }

        try {
            val body = buildString {
                appendLine("Entwined Memories local diagnostic")
                appendLine("kind: ${truncateDiagnostic(kind, 120)}")
                appendLine("recordedAtUtc: ${truncateDiagnostic(recordedAtUtc, 120)}")
                appendLine("library: ${truncateDiagnostic(library, 500)}")
                appendLine("context: ${truncateDiagnostic(context, 1_000)}")
                appendLine("exception:")
                appendLine(truncateDiagnostic(exception, 4_000))
                appendLine("stack:")
                appendLine(truncateDiagnostic(stack, 24_000))
            }
            File(filesDir, DIAGNOSTIC_FILE_NAME).writeText(body, Charsets.UTF_8)
            result.success(true)
        } catch (error: Exception) {
            result.error("diagnostic_write_failed", error.message, null)
        }
    }

    private fun readLatestFlutterDiagnostic(result: MethodChannel.Result) {
        try {
            val file = File(filesDir, DIAGNOSTIC_FILE_NAME)
            result.success(if (file.exists()) file.readText(Charsets.UTF_8) else null)
        } catch (error: Exception) {
            result.error("diagnostic_read_failed", error.message, null)
        }
    }

    private fun truncateDiagnostic(value: String, limit: Int): String {
        return if (value.length <= limit) value else value.take(limit) + "\n[truncated]"
    }

    /**
     * Records only backup execution stages and numeric counts in app-private
     * storage. It never records media names, paths, content, passphrases, or
     * remote-account details. A successful backup clears this temporary record.
     */
    private fun recordBackupDiagnostic(stage: String, details: Map<String, Any> = emptyMap()) {
        runCatching {
            val body = buildString {
                appendLine("Entwined Memories encrypted-backup diagnostic")
                appendLine("recordedAtUtc: ${utcTimestamp()}")
                appendLine("stage: ${truncateDiagnostic(stage, 120)}")
                details.toSortedMap().forEach { (key, value) ->
                    appendLine("${truncateDiagnostic(key, 80)}: ${truncateDiagnostic(value.toString(), 80)}")
                }
            }
            File(filesDir, BACKUP_DIAGNOSTIC_FILE_NAME).writeText(body, Charsets.UTF_8)
        }
    }

    private fun clearBackupDiagnostic() {
        runCatching { File(filesDir, BACKUP_DIAGNOSTIC_FILE_NAME).delete() }
    }

    private fun readLatestBackupDiagnostic(result: MethodChannel.Result) {
        try {
            val file = File(filesDir, BACKUP_DIAGNOSTIC_FILE_NAME)
            result.success(if (file.exists()) file.readText(Charsets.UTF_8) else null)
        } catch (error: Exception) {
            result.error("backup_diagnostic_read_failed", error.message, null)
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        activityIsPostResumed = true
        deliverPendingJournalFolderCompletionWhenSafe()
        deliverPendingOriginalVaultFolderCompletionWhenSafe()
    }

    override fun onPause() {
        activityIsPostResumed = false
        super.onPause()
    }

    private fun deliverPendingJournalFolderCompletionWhenSafe() {
        if (!activityIsPostResumed || pendingJournalFolderCompletion == null) return
        // The system document activity is fully closed only after this point.
        // Posting once more ensures Dart cannot rebuild while Android is still
        // in the onActivityResult transaction. If another pause begins first,
        // the completion stays queued for the next onPostResume.
        mainHandler.post {
            if (!activityIsPostResumed) return@post
            val completion = pendingJournalFolderCompletion ?: return@post
            pendingJournalFolderCompletion = null
            if (completion.payload != null) {
                completion.result.success(completion.payload)
            } else {
                completion.result.error(
                    completion.errorCode ?: "journal_folder_failed",
                    completion.errorMessage,
                    null,
                )
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            JOURNAL_FOLDER_REQUEST_CODE -> handleJournalFolderResult(resultCode, data)
            ORIGINAL_VAULT_FOLDER_REQUEST_CODE -> handleOriginalVaultFolderResult(resultCode, data)
            SNAPSHOT_SOURCE_FOLDER_REQUEST_CODE -> handleSnapshotSourceFolderResult(resultCode, data)
            SNAPSHOT_RESTORE_FOLDER_REQUEST_CODE -> handleSnapshotRestoreFolderResult(resultCode, data)
        }
    }

    /// Activity results arrive while Android is still unwinding the external
    /// Documents UI. Completing a MethodChannel call synchronously from this
    /// callback can let Dart rebuild/dispose dependent widgets inside that
    /// transaction. Always enqueue the reply after onActivityResult returns.
    private fun postChannelSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun postChannelError(
        result: MethodChannel.Result,
        code: String,
        message: String?,
    ) {
        mainHandler.post { result.error(code, message, null) }
    }

    private fun handleJournalFolderResult(resultCode: Int, data: Intent?) {
        val pendingResult = pendingJournalFolderResult ?: return
        pendingJournalFolderResult = null
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            pendingJournalFolderCompletion = PendingJournalFolderCompletion(
                result = pendingResult,
                errorCode = "journal_folder_cancelled",
                errorMessage = "No Family Memory Journal folder was selected.",
            )
            deliverPendingJournalFolderCompletionWhenSafe()
            return
        }

        try {
            takeTreePermission(treeUri, data.flags)
            journalPreferences().edit().putString(JOURNAL_TREE_URI_KEY, treeUri.toString()).apply()
            pendingJournalFolderCompletion = PendingJournalFolderCompletion(
                result = pendingResult,
                payload = mapOf("configured" to true, "treeUri" to treeUri.toString()),
            )
        } catch (error: Exception) {
            pendingJournalFolderCompletion = PendingJournalFolderCompletion(
                result = pendingResult,
                errorCode = "journal_folder_failed",
                errorMessage = error.message,
            )
        }
        deliverPendingJournalFolderCompletionWhenSafe()
    }

    private fun handleSnapshotSourceFolderResult(resultCode: Int, data: Intent?) {
        val pending = pendingSnapshotRestore ?: return
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            pendingSnapshotRestore = null
            postChannelError(
                pending.result,
                "snapshot_restore_cancelled",
                "No encrypted backup source folder was selected.",
            )
            return
        }
        try {
            takeTreePermission(treeUri, data.flags)
            pending.sourceTreeUri = treeUri
            // Start the second external picker after the first result callback
            // completes, for the same lifecycle reason as channel delivery.
            mainHandler.post {
                openDocumentTree(SNAPSHOT_RESTORE_FOLDER_REQUEST_CODE)
            }
        } catch (error: Exception) {
            pendingSnapshotRestore = null
            postChannelError(pending.result, "snapshot_restore_failed", error.message)
        }
    }

    private fun handleSnapshotRestoreFolderResult(resultCode: Int, data: Intent?) {
        val pending = pendingSnapshotRestore ?: return
        pendingSnapshotRestore = null
        val destinationTreeUri = data?.data
        val sourceTreeUri = pending.sourceTreeUri
        if (resultCode != RESULT_OK || destinationTreeUri == null || sourceTreeUri == null) {
            postChannelError(
                pending.result,
                "snapshot_restore_cancelled",
                "No restore destination folder was selected.",
            )
            return
        }
        try {
            takeTreePermission(destinationTreeUri, data.flags)
            vaultExecutor.execute {
                try {
                    val restored = restoreSnapshotFromTree(
                        sourceTreeUri,
                        destinationTreeUri,
                        pending.passphrase,
                    )
                    postChannelSuccess(pending.result, restored)
                } catch (error: Exception) {
                    postChannelError(
                        pending.result,
                        "snapshot_restore_failed",
                        error.message,
                    )
                }
            }
        } catch (error: Exception) {
            postChannelError(pending.result, "snapshot_restore_failed", error.message)
        }
    }

    private fun takeTreePermission(treeUri: Uri, flags: Int) {
        val grantedFlags = flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
        contentResolver.takePersistableUriPermission(treeUri, grantedFlags)
    }

    private fun openDocumentTree(requestCode: Int) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, requestCode)
    }

    private fun archive(
        call: MethodCall,
        result: MethodChannel.Result,
        mediaKind: VaultMediaKind,
    ) {
        val sourcePath = call.argument<String>("sourcePath")
        val year = call.argument<Int>("year")
        val month = call.argument<Int>("month")
        val mimeHint = call.argument<String>("mimeType")

        if (sourcePath.isNullOrBlank() || year == null || month == null) {
            result.error("invalid_arguments", "Original vault arguments are incomplete.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "unsupported_android",
                "Original Vault requires Android 10 or later.",
                null,
            )
            return
        }

        vaultExecutor.execute {
            try {
                val archived = archiveOriginal(
                    source = File(sourcePath),
                    mimeHint = mimeHint,
                    year = year,
                    month = month,
                    mediaKind = mediaKind,
                )
                mainHandler.post { result.success(archived) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("original_vault_failed", error.message, null)
                }
            }
        }
    }

    override fun onDestroy() {
        pendingJournalFolderResult?.error(
            "journal_folder_interrupted",
            "Family Memory Journal folder selection was interrupted.",
            null,
        )
        pendingJournalFolderResult = null
        pendingJournalFolderCompletion?.result?.error(
            "journal_folder_interrupted",
            "Family Memory Journal folder selection was interrupted.",
            null,
        )
        pendingJournalFolderCompletion = null
        pendingOriginalVaultFolderResult?.error(
            "original_vault_folder_interrupted",
            "Original Vault folder selection was interrupted.",
            null,
        )
        pendingOriginalVaultFolderResult = null
        pendingOriginalVaultFolderCompletion?.result?.error(
            "original_vault_folder_interrupted",
            "Original Vault folder selection was interrupted.",
            null,
        )
        pendingOriginalVaultFolderCompletion = null
        pendingSnapshotRestore?.result?.error(
            "snapshot_restore_interrupted",
            "Encrypted backup restore was interrupted.",
            null,
        )
        pendingSnapshotRestore = null
        snapshotChannel = null
        vaultExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun journalPreferences() = getSharedPreferences(JOURNAL_PREFERENCES, MODE_PRIVATE)

    private fun journalTreeUri(): Uri? {
        val raw = journalPreferences().getString(JOURNAL_TREE_URI_KEY, null) ?: return null
        return runCatching { Uri.parse(raw) }.getOrNull()
    }

    private fun ensureJournalFolderSelected(result: MethodChannel.Result) {
        val selectedTree = journalTreeUri()
        if (selectedTree != null) {
            // A previous app version asked for this picker before Original Vault.
            // Keep only the intended Documents root so a mistakenly selected media
            // folder cannot later be reused as the journal/output location.
            val selectedName = runCatching { selectedTreeDisplayName(selectedTree) }.getOrNull()
            if (selectedName == "Documents") {
                result.success(mapOf("configured" to true))
                return
            }
            journalPreferences().edit().remove(JOURNAL_TREE_URI_KEY).apply()
        }
        if (pendingJournalFolderResult != null) {
            result.error("journal_folder_busy", "Family Memory Journal folder picker is already open.", null)
            return
        }

        pendingJournalFolderResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            }
            startActivityForResult(intent, JOURNAL_FOLDER_REQUEST_CODE)
        } catch (error: Exception) {
            pendingJournalFolderResult = null
            result.error("journal_folder_failed", error.message, null)
        }
    }

    private fun originalVaultPreferences() = getSharedPreferences(ORIGINAL_VAULT_PREFERENCES, MODE_PRIVATE)

    private fun originalVaultTreeUri(): Uri? {
        val raw = originalVaultPreferences().getString(ORIGINAL_VAULT_TREE_URI_KEY, null) ?: return null
        return runCatching { Uri.parse(raw) }.getOrNull()
    }

    private fun ensureOriginalVaultFolderSelected(result: MethodChannel.Result) {
        if (originalVaultTreeUri() != null) {
            result.success(mapOf("configured" to true))
            return
        }
        if (pendingOriginalVaultFolderResult != null) {
            result.error("original_vault_folder_busy", "Original Vault folder picker is already open.", null)
            return
        }
        pendingOriginalVaultFolderResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            }
            startActivityForResult(intent, ORIGINAL_VAULT_FOLDER_REQUEST_CODE)
        } catch (error: Exception) {
            pendingOriginalVaultFolderResult = null
            result.error("original_vault_folder_failed", error.message, null)
        }
    }

    private fun handleOriginalVaultFolderResult(resultCode: Int, data: Intent?) {
        val pendingResult = pendingOriginalVaultFolderResult ?: return
        pendingOriginalVaultFolderResult = null
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            pendingOriginalVaultFolderCompletion = PendingJournalFolderCompletion(
                result = pendingResult,
                errorCode = "original_vault_folder_cancelled",
                errorMessage = "No Original Vault folder was selected.",
            )
            deliverPendingOriginalVaultFolderCompletionWhenSafe()
            return
        }
        try {
            // Do not query or persist the tree inside the picker callback. The
            // temporary URI grant remains available after this Activity result;
            // validation and persistence are deferred until the host is resumed.
            pendingOriginalVaultFolderCompletion = PendingJournalFolderCompletion(
                result = pendingResult,
                payload = mapOf("treeUri" to treeUri.toString(), "grantFlags" to data.flags),
            )
        } catch (error: Exception) {
            pendingOriginalVaultFolderCompletion = PendingJournalFolderCompletion(
                result = pendingResult,
                errorCode = "original_vault_folder_failed",
                errorMessage = error.message,
            )
        }
        deliverPendingOriginalVaultFolderCompletionWhenSafe()
    }

    private fun selectedTreeDisplayName(treeUri: Uri): String? {
        val root = treeDocumentUri(treeUri)
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        return contentResolver.query(root, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    private fun validateOriginalVaultTree(treeUri: Uri): String {
        // This runs only after DocumentsUI has completely returned to the host
        // Activity. Some providers use volume-specific document IDs, so verify the
        // provider's actual display name rather than assuming a device-ID format.
        val displayName = try {
            selectedTreeDisplayName(treeUri)
        } catch (error: Exception) {
            throw IllegalStateException(
                "Android could not inspect the selected Original Vault folder after the picker closed (${error.javaClass.simpleName}).",
            )
        }
        if (displayName != "Entwined Memories Originals") {
            val returnedName = displayName?.take(80) ?: "no folder name"
            throw IllegalArgumentException(
                "Android returned '$returnedName'. Select the Entwined Memories Originals folder itself, not Pictures or another folder.",
            )
        }
        return displayName
    }

    private fun deliverPendingOriginalVaultFolderCompletionWhenSafe() {
        if (!activityIsPostResumed || pendingOriginalVaultFolderCompletion == null) return
        mainHandler.post {
            if (!activityIsPostResumed) return@post
            val completion = pendingOriginalVaultFolderCompletion ?: return@post
            pendingOriginalVaultFolderCompletion = null
            val treeUriText = completion.payload?.get("treeUri") as? String
            val grantFlags = completion.payload?.get("grantFlags") as? Int
            if (treeUriText != null && grantFlags != null) {
                // Wait until the external picker has returned and run provider I/O
                // off the UI thread. This keeps the validation strict without the
                // Android-specific crash/mismatch seen during the result callback.
                vaultExecutor.execute {
                    try {
                        val treeUri = Uri.parse(treeUriText)
                        val displayName = validateOriginalVaultTree(treeUri)
                        takeTreePermission(treeUri, grantFlags)
                        originalVaultPreferences().edit()
                            .putString(ORIGINAL_VAULT_TREE_URI_KEY, treeUri.toString())
                            .apply()
                        mainHandler.post {
                            completion.result.success(
                                mapOf("configured" to true, "folderName" to displayName),
                            )
                        }
                    } catch (error: Exception) {
                        mainHandler.post {
                            completion.result.error(
                                "original_vault_folder_failed",
                                error.message,
                                null,
                            )
                        }
                    }
                }
            } else if (completion.payload != null) {
                completion.result.success(completion.payload)
            } else {
                completion.result.error(
                    completion.errorCode ?: "original_vault_folder_failed",
                    completion.errorMessage,
                    null,
                )
            }
        }
    }

    private fun appendJournalEvent(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")
        val json = call.argument<String>("json")
        if (fileName.isNullOrBlank() || json == null) {
            result.error("invalid_journal_arguments", "Journal event arguments are incomplete.", null)
            return
        }
        if (!fileName.matches(Regex("event_[0-9]+_[0-9a-f-]{36}\\.json"))) {
            result.error("invalid_journal_filename", "Journal event filename is invalid.", null)
            return
        }
        val treeUri = journalTreeUri()
        if (treeUri == null) {
            result.error("journal_folder_required", "Select a Family Memory Journal folder first.", null)
            return
        }

        vaultExecutor.execute {
            try {
                val uri = writeJournalEvent(treeUri, fileName, json)
                mainHandler.post { result.success(mapOf("fileName" to fileName, "uri" to uri.toString())) }
            } catch (error: Exception) {
                mainHandler.post { result.error("journal_write_failed", error.message, null) }
            }
        }
    }

    /**
     * Writes a current active-post catalog before the Journal-only encrypted
     * snapshot starts. The caller supplies only Firestore post metadata; no raw
     * original media, passphrase, or external account credential is accepted.
     */
    private fun writeRecoveryCatalog(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")
        val json = call.argument<String>("json")
        if (fileName.isNullOrBlank() || json == null) {
            result.error("invalid_recovery_catalog_arguments", "Recovery Catalog arguments are incomplete.", null)
            return
        }
        if (!fileName.matches(Regex("family_recovery_catalog_[0-9]+\\.json"))) {
            result.error("invalid_recovery_catalog_filename", "Recovery Catalog filename is invalid.", null)
            return
        }
        val treeUri = journalTreeUri()
        if (treeUri == null) {
            result.error("journal_folder_required", "Select a Family Memory Journal folder first.", null)
            return
        }
        vaultExecutor.execute {
            try {
                val root = treeDocumentUri(treeUri)
                val archiveDirectory = ensureJournalDirectory(root, JOURNAL_ROOT_DIRECTORY)
                val exportsDirectory = ensureJournalDirectory(archiveDirectory, "Exports")
                val uri = writeNewJournalDocument(
                    exportsDirectory,
                    fileName,
                    "application/json",
                    json,
                )
                mainHandler.post { result.success(mapOf("fileName" to fileName, "uri" to uri.toString())) }
            } catch (error: Exception) {
                mainHandler.post { result.error("recovery_catalog_write_failed", error.message, null) }
            }
        }
    }

    /**
     * Finds and stages the latest current-post catalog from an already validated
     * encrypted restore folder. This prepares a preview only; it never writes to
     * Firestore and it rejects malformed/unexpected catalog structures.
     */
    private fun prepareRestoredRecoveryCatalog(call: MethodCall, result: MethodChannel.Result) {
        val restoreFolderUriText = call.argument<String>("restoreFolderUri")
        if (restoreFolderUriText.isNullOrBlank()) {
            result.error("invalid_restore_folder", "A restored Family Archive folder is required.", null)
            return
        }
        val restoreFolderUri = runCatching { Uri.parse(restoreFolderUriText) }.getOrNull()
        if (restoreFolderUri == null) {
            result.error("invalid_restore_folder", "The restored Family Archive folder is invalid.", null)
            return
        }
        vaultExecutor.execute {
            try {
                val journalDirectory = findJournalChild(restoreFolderUri, "family-memory-journal")
                    ?: throw FileNotFoundException("The restored archive has no Family Journal folder.")
                val exportsDirectory = findJournalChild(journalDirectory, "Exports")
                    ?: throw FileNotFoundException("The restored archive has no Exports folder.")
                val catalog = findLatestRecoveryCatalog(exportsDirectory)
                    ?: throw FileNotFoundException("No current Family Recovery Catalog was found in this archive.")
                if (catalog.bytes !in 1..MAX_RECOVERY_CATALOG_BYTES.toLong()) {
                    throw IllegalStateException("The Family Recovery Catalog size is invalid.")
                }
                val catalogBytes = contentResolver.openInputStream(catalog.uri)?.use { input ->
                    input.readBytes()
                } ?: throw FileNotFoundException("The Family Recovery Catalog could not be opened.")
                if (catalogBytes.size.toLong() != catalog.bytes) {
                    throw IllegalStateException("The Family Recovery Catalog changed while being prepared.")
                }
                val validated = validateRecoveryCatalog(catalogBytes)
                val staged = File(filesDir, PREPARED_RECOVERY_CATALOG_FILE_NAME)
                val temporary = File(filesDir, "$PREPARED_RECOVERY_CATALOG_FILE_NAME.tmp")
                temporary.writeBytes(catalogBytes)
                if (staged.exists() && !staged.delete()) {
                    throw IllegalStateException("The previous prepared Recovery Catalog could not be replaced.")
                }
                if (!temporary.renameTo(staged)) {
                    temporary.delete()
                    throw IllegalStateException("The Recovery Catalog could not be prepared for preview.")
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "catalogPath" to staged.absolutePath,
                            "memoryCount" to validated.memoryCount,
                            "generatedAtUtc" to validated.generatedAtUtc,
                        ),
                    )
                }
            } catch (error: Exception) {
                mainHandler.post { result.error("recovery_catalog_prepare_failed", error.message, null) }
            }
        }
    }

    private data class RecoveryCatalogFile(
        val uri: Uri,
        val fileName: String,
        val bytes: Long,
    )

    private data class ValidatedRecoveryCatalog(
        val memoryCount: Int,
        val generatedAtUtc: String,
    )

    private fun findLatestRecoveryCatalog(parentUri: Uri): RecoveryCatalogFile? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        val candidates = mutableListOf<RecoveryCatalogFile>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
            while (cursor.moveToNext()) {
                val fileName = cursor.getString(nameColumn)
                val mimeType = cursor.getString(mimeColumn)
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR ||
                    !fileName.matches(Regex("family_recovery_catalog_[0-9]+\\.json"))
                ) continue
                candidates += RecoveryCatalogFile(
                    uri = DocumentsContract.buildDocumentUriUsingTree(parentUri, cursor.getString(idColumn)),
                    fileName = fileName,
                    bytes = cursor.getLong(sizeColumn).coerceAtLeast(0L),
                )
            }
        }
        return candidates.maxByOrNull { catalog -> catalog.fileName }
    }

    private fun validateRecoveryCatalog(bytes: ByteArray): ValidatedRecoveryCatalog {
        val root = JSONObject(bytes.toString(Charsets.UTF_8))
        if (root.optInt("schemaVersion", -1) != 1 ||
            root.optString("kind") != "active-memory-catalog"
        ) {
            throw IllegalStateException("The Family Recovery Catalog format is not supported.")
        }
        val generatedAtUtc = root.optString("generatedAtUtc").trim()
        if (generatedAtUtc.isBlank() || generatedAtUtc.length > 80) {
            throw IllegalStateException("The Family Recovery Catalog timestamp is invalid.")
        }
        val memories = root.optJSONArray("memories")
            ?: throw IllegalStateException("The Family Recovery Catalog has no post list.")
        if (memories.length() > 100_000) {
            throw IllegalStateException("The Family Recovery Catalog contains too many posts.")
        }
        val ids = mutableSetOf<String>()
        for (index in 0 until memories.length()) {
            val memory = memories.optJSONObject(index)
                ?: throw IllegalStateException("The Family Recovery Catalog contains an invalid post.")
            val id = memory.optString("id").trim()
            val dateUtc = memory.optString("dateUtc").trim()
            if (id.isBlank() || id.length > 200 || dateUtc.isBlank() || dateUtc.length > 80 || !ids.add(id)) {
                throw IllegalStateException("The Family Recovery Catalog contains an invalid or duplicate post.")
            }
        }
        return ValidatedRecoveryCatalog(memories.length(), generatedAtUtc)
    }

    /**
     * Checks only the explicitly selected Original Vault tree after an archive
     * restore. It uses the deterministic EMP/EMV hash-prefix filenames and byte
     * counts from Journal event metadata; it never scans the phone's gallery or
     * reads media contents.
     */
    private fun checkRestoredVaultReferences(call: MethodCall, result: MethodChannel.Result) {
        val restoreFolderUriText = call.argument<String>("restoreFolderUri")
        val restoreFolderUri = restoreFolderUriText?.let { text -> runCatching { Uri.parse(text) }.getOrNull() }
        if (restoreFolderUri == null) {
            result.error("invalid_restore_folder", "A restored Family Archive folder is required.", null)
            return
        }
        val vaultUri = originalVaultTreeUri()
        if (vaultUri == null) {
            result.success(
                mapOf(
                    "vaultSelected" to false,
                    "expectedReferences" to 0,
                    "matchedReferences" to 0,
                    "missingReferences" to 0,
                    "ambiguousReferences" to 0,
                ),
            )
            return
        }
        vaultExecutor.execute {
            try {
                val expected = collectRestoredVaultReferences(restoreFolderUri)
                val available = mutableMapOf<String, Int>()
                collectOriginalVaultReferenceKeys(treeDocumentUri(vaultUri), available)
                var matched = 0
                var missing = 0
                var ambiguous = 0
                expected.forEach { key ->
                    when (available[key] ?: 0) {
                        0 -> missing++
                        1 -> matched++
                        else -> ambiguous++
                    }
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "vaultSelected" to true,
                            "expectedReferences" to expected.size,
                            "matchedReferences" to matched,
                            "missingReferences" to missing,
                            "ambiguousReferences" to ambiguous,
                        ),
                    )
                }
            } catch (error: Exception) {
                mainHandler.post { result.error("vault_reference_check_failed", error.message, null) }
            }
        }
    }

    private fun collectRestoredVaultReferences(restoreFolderUri: Uri): Set<String> {
        val journalDirectory = findJournalChild(restoreFolderUri, "family-memory-journal")
            ?: throw FileNotFoundException("The restored archive has no Family Journal folder.")
        val eventsDirectory = findJournalChild(journalDirectory, JOURNAL_EVENTS_DIRECTORY)
            ?: throw FileNotFoundException("The restored archive has no Journal Events folder.")
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            eventsDirectory,
            DocumentsContract.getDocumentId(eventsDirectory),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        val references = mutableSetOf<String>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameColumn)
                if (cursor.getString(mimeColumn) == DocumentsContract.Document.MIME_TYPE_DIR ||
                    !name.matches(Regex("event_[0-9]+_[0-9a-f-]{36}\\.json")) ||
                    cursor.getLong(sizeColumn) !in 1..1_048_576L
                ) continue
                val eventUri = DocumentsContract.buildDocumentUriUsingTree(
                    eventsDirectory,
                    cursor.getString(idColumn),
                )
                val event = contentResolver.openInputStream(eventUri)?.use { input ->
                    runCatching { JSONObject(input.readBytes().toString(Charsets.UTF_8)) }.getOrNull()
                } ?: continue
                val archives = event.optJSONArray("vaultArchives") ?: continue
                for (index in 0 until archives.length()) {
                    val archive = archives.optJSONObject(index) ?: continue
                    val hash = archive.optString("sha256").lowercase(Locale.US)
                    val bytes = archive.optLong("bytes", -1L)
                    if (hash.matches(Regex("[0-9a-f]{64}")) && bytes > 0L) {
                        references += "${hash.take(24)}:$bytes"
                    }
                }
            }
        }
        return references
    }

    private fun collectOriginalVaultReferenceKeys(parentUri: Uri, destination: MutableMap<String, Int>) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
            while (cursor.moveToNext()) {
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(parentUri, cursor.getString(idColumn))
                val name = cursor.getString(nameColumn)
                if (name.startsWith(".st")) continue
                if (cursor.getString(mimeColumn) == DocumentsContract.Document.MIME_TYPE_DIR) {
                    collectOriginalVaultReferenceKeys(documentUri, destination)
                    continue
                }
                val match = Regex("^(?:EMP|EMV)_([0-9a-f]{24})\\.[A-Za-z0-9]{1,12}$").matchEntire(name)
                    ?: continue
                val bytes = cursor.getLong(sizeColumn).coerceAtLeast(0L)
                if (bytes <= 0L) continue
                val key = "${match.groupValues[1]}:$bytes"
                destination[key] = (destination[key] ?: 0) + 1
            }
        }
    }

    private fun writeJournalEvent(treeUri: Uri, fileName: String, json: String): Uri {
        val root = treeDocumentUri(treeUri)
        val archiveDirectory = ensureJournalDirectory(root, JOURNAL_ROOT_DIRECTORY)
        val eventsDirectory = ensureJournalDirectory(archiveDirectory, JOURNAL_EVENTS_DIRECTORY)
        val eventUri = DocumentsContract.createDocument(
            contentResolver,
            eventsDirectory,
            "application/json",
            fileName,
        ) ?: throw IllegalStateException("Android could not create the Family Memory Journal event file.")

        try {
            contentResolver.openOutputStream(eventUri, "w")?.bufferedWriter(Charsets.UTF_8).use { writer ->
                if (writer == null) {
                    throw IllegalStateException("Android could not write the Family Memory Journal event file.")
                }
                writer.write(json)
                writer.flush()
            }
            return eventUri
        } catch (error: Exception) {
            contentResolver.delete(eventUri, null, null)
            throw error
        }
    }

    private fun treeDocumentUri(treeUri: Uri): Uri = DocumentsContract.buildDocumentUriUsingTree(
        treeUri,
        DocumentsContract.getTreeDocumentId(treeUri),
    )

    private fun ensureJournalDirectory(parentUri: Uri, displayName: String): Uri {
        findJournalChild(parentUri, displayName)?.let { child -> return child }
        return DocumentsContract.createDocument(
            contentResolver,
            parentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            displayName,
        ) ?: throw IllegalStateException("Android could not create the Family Memory Journal directory.")
    }

    private fun findJournalChild(parentUri: Uri, displayName: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            while (cursor.moveToNext()) {
                if (cursor.getString(nameColumn) == displayName) {
                    return DocumentsContract.buildDocumentUriUsingTree(parentUri, cursor.getString(idColumn))
                }
            }
        }
        return null
    }

    private fun deleteDocumentTree(documentUri: Uri) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            documentUri,
            DocumentsContract.getDocumentId(documentUri),
        )
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
        val children = mutableListOf<Uri>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            while (cursor.moveToNext()) {
                children += DocumentsContract.buildDocumentUriUsingTree(
                    documentUri,
                    cursor.getString(idColumn),
                )
            }
        }
        children.forEach { child -> deleteDocumentTree(child) }
        contentResolver.delete(documentUri, null, null)
    }

    private fun exportPortableArchive(result: MethodChannel.Result) {
        val treeUri = journalTreeUri()
        if (treeUri == null) {
            result.error("journal_folder_required", "Select a Family Memory Journal folder first.", null)
            return
        }

        vaultExecutor.execute {
            try {
                val exported = buildPortableArchive(treeUri)
                mainHandler.post { result.success(exported) }
            } catch (error: Exception) {
                mainHandler.post { result.error("journal_export_failed", error.message, null) }
            }
        }
    }

    private fun buildPortableArchive(treeUri: Uri): Map<String, Any> {
        val root = treeDocumentUri(treeUri)
        val archiveDirectory = ensureJournalDirectory(root, JOURNAL_ROOT_DIRECTORY)
        val eventsDirectory = ensureJournalDirectory(archiveDirectory, JOURNAL_EVENTS_DIRECTORY)
        val exportsDirectory = ensureJournalDirectory(archiveDirectory, "Exports")
        val events = readJournalEvents(eventsDirectory)
        val generatedAt = utcTimestamp()
        val timestamp = System.currentTimeMillis()

        val manifestEntries = JSONArray()
        events.forEach { event ->
            manifestEntries.put(JSONObject().apply {
                put("fileName", event.fileName)
                put("sha256", event.sha256)
                put("bytes", event.byteCount)
                put("validJson", event.json != null)
            })
        }

        val index = JSONObject().apply {
            put("schemaVersion", 1)
            put("generatedAtUtc", generatedAt)
            put("eventCount", events.size)
            put("events", manifestEntries)
        }
        val manifest = JSONObject().apply {
            put("algorithm", "SHA-256")
            put("generatedAtUtc", generatedAt)
            put("journalEventFiles", manifestEntries)
        }
        val readme = buildArchiveReadme(generatedAt, events.size)
        val csv = buildJournalCsv(events)

        val writtenFiles = listOf(
            writeNewJournalDocument(exportsDirectory, "README_$timestamp.md", "text/markdown", readme),
            writeNewJournalDocument(exportsDirectory, "Family_Memory_Archive_$timestamp.csv", "text/csv", csv),
            writeNewJournalDocument(exportsDirectory, "archive-index_$timestamp.json", "application/json", index.toString(2)),
            writeNewJournalDocument(exportsDirectory, "integrity-manifest_$timestamp.json", "application/json", manifest.toString(2)),
        )

        return mapOf(
            "eventCount" to events.size,
            "generatedAtUtc" to generatedAt,
            "files" to writtenFiles.map { uri -> uri.toString() },
        )
    }

    private data class JournalEventFile(
        val fileName: String,
        val byteCount: Int,
        val sha256: String,
        val json: JSONObject?,
    )

    private fun readJournalEvents(eventsDirectory: Uri): List<JournalEventFile> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            eventsDirectory,
            DocumentsContract.getDocumentId(eventsDirectory),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val events = mutableListOf<JournalEventFile>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                val fileName = cursor.getString(nameColumn)
                val mimeType = cursor.getString(mimeColumn)
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR || !fileName.endsWith(".json")) continue
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                    eventsDirectory,
                    cursor.getString(idColumn),
                )
                val bytes = contentResolver.openInputStream(documentUri)?.use { input -> input.readBytes() }
                    ?: throw IllegalStateException("Android could not read a Family Memory Journal event file.")
                val json = runCatching { JSONObject(bytes.toString(Charsets.UTF_8)) }.getOrNull()
                events += JournalEventFile(fileName, bytes.size, sha256(bytes), json)
            }
        }
        return events.sortedBy { event -> event.fileName }
    }

    private fun buildArchiveReadme(generatedAt: String, eventCount: Int): String = """
# Entwined Memories — Family Archive Export

Generated (UTC): $generatedAt
Journal event files included: $eventCount

## What this folder contains

- `Journal Events/` is the append-only local history created by Entwined Memories.
- `Exports/Family_Memory_Archive_*.csv` is a human-readable event summary.
- `Exports/archive-index_*.json` lists event files and metadata for future software imports.
- `Exports/integrity-manifest_*.json` stores SHA-256 hashes for the Journal Events files.

## Recovery rule

Keep this whole `Entwined Memories Archive` folder. Do not delete `Journal Events` even when a Memory was deleted inside the app; deletion events are part of the family history. The original photos and videos remain separately in `Pictures/Entwined Memories Originals`.

## How to verify later

Open a recent CSV in any spreadsheet application, open a recent JSON file in a text editor, and compare a Journal Events file hash with `integrity-manifest_*.json` using a future verification tool.
""".trimIndent() + "\n"

    private fun buildJournalCsv(events: List<JournalEventFile>): String {
        val rows = mutableListOf(
            listOf(
                "Event file", "Event type", "Occurred UTC", "Memory ID", "Memory date", "Created by",
                "Mood", "Note", "Photo count", "YouTube video ID", "Video processing", "Vault SHA-256",
                "Event SHA-256", "Status",
            ).joinToString(",") { csvValue(it) },
        )
        events.forEach { event ->
            val json = event.json
            val memory = json?.optJSONObject("memory")
            val archives = json?.optJSONArray("vaultArchives") ?: JSONArray()
            val vaultHashes = buildList {
                for (index in 0 until archives.length()) {
                    archives.optJSONObject(index)?.optString("sha256")?.takeIf { it.isNotBlank() }?.let(::add)
                }
            }.joinToString(";")
            val values = listOf(
                event.fileName,
                json?.optString("eventType") ?: "",
                json?.optString("occurredAtUtc") ?: "",
                memory?.optString("id") ?: "",
                memory?.optString("dateLocal") ?: "",
                memory?.optString("createdBy") ?: "",
                memory?.optString("mood") ?: "",
                memory?.optString("note") ?: "",
                memory?.optJSONArray("photos")?.length()?.toString() ?: "0",
                memory?.optJSONObject("video")?.optString("youtubeVideoId") ?: "",
                memory?.optJSONObject("video")?.optString("processingStatus") ?: "",
                vaultHashes,
                event.sha256,
                if (json == null) "CORRUPT_JSON" else "OK",
            )
            rows += values.joinToString(",") { csvValue(it) }
        }
        return rows.joinToString("\n", postfix = "\n")
    }

    private fun csvValue(value: String): String = "\"${value.replace("\"", "\"\"").replace("\n", " ").replace("\r", " ")}\""

    private fun writeNewJournalDocument(
        parentUri: Uri,
        fileName: String,
        mimeType: String,
        contents: String,
    ): Uri {
        val documentUri = DocumentsContract.createDocument(contentResolver, parentUri, mimeType, fileName)
            ?: throw IllegalStateException("Android could not create a Family Archive export file.")
        try {
            contentResolver.openOutputStream(documentUri, "w")?.bufferedWriter(Charsets.UTF_8).use { writer ->
                if (writer == null) throw IllegalStateException("Android could not write a Family Archive export file.")
                writer.write(contents)
                writer.flush()
            }
            return documentUri
        } catch (error: Exception) {
            contentResolver.delete(documentUri, null, null)
            throw error
        }
    }

    private fun utcTimestamp(): String {
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date())
    }

    private fun sha256(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }

    private fun snapshotPreferences() = getSharedPreferences(SNAPSHOT_PREFERENCES, MODE_PRIVATE)

    private data class SnapshotInput(
        val archivePath: String,
        val bytes: Long,
        val modifiedUtcMillis: Long,
        val openInput: () -> InputStream,
    )

    private data class SnapshotDigest(
        val archivePath: String,
        val bytes: Long,
        val sha256: String,
    )

    private fun createJournalSnapshot(call: MethodCall, result: MethodChannel.Result) {
        val passphrase = call.argument<String>("passphrase")
        if (passphrase == null || passphrase.length < 16) {
            result.error(
                "weak_passphrase",
                "Use an archive passphrase with at least 16 characters.",
                null,
            )
            return
        }
        val journalUri = journalTreeUri()
        if (journalUri == null) {
            result.error("journal_folder_required", "Select a Family Memory Journal folder first.", null)
            return
        }
        clearBackupDiagnostic()
        recordBackupDiagnostic("journal_backup_request_accepted")
        vaultExecutor.execute {
            try {
                val snapshot = buildJournalSnapshot(journalUri, passphrase)
                mainHandler.post { result.success(snapshot) }
            } catch (error: Exception) {
                recordBackupDiagnostic(
                    "backup_exception_caught",
                    mapOf("exceptionType" to error.javaClass.simpleName),
                )
                mainHandler.post { result.error("snapshot_failed", error.message, null) }
            }
        }
    }

    /**
     * Every Journal snapshot is intentionally standalone. It protects the Family
     * Archive metadata/history only; original photo/video bytes stay in the
     * separately synced Pictures Original Vault and are never read here.
     */
    private fun buildJournalSnapshot(
        journalUri: Uri,
        passphrase: String,
    ): Map<String, Any> {
        recordBackupDiagnostic("collecting_journal_backup_inputs")
        val inputs = collectJournalSnapshotInputs(journalUri)
        val coverage = snapshotCoverage(inputs)
        val inputBytes = inputs.fold(0L) { total, input -> total + input.bytes }
        recordBackupDiagnostic(
            "backup_inputs_collected",
            mapOf(
                "totalFiles" to inputs.size,
                "totalBytes" to inputBytes,
                "photos" to (coverage["photos"] ?: 0),
                "videos" to (coverage["videos"] ?: 0),
                "journalEvents" to (coverage["journalEvents"] ?: 0),
                "exports" to (coverage["exports"] ?: 0),
            ),
        )
        if ((coverage["journalEvents"] ?: 0) == 0) {
            throw IllegalStateException("No Family Memory Journal events were found for encrypted backup.")
        }
        if (inputs.isEmpty()) {
            throw IllegalStateException("No family archive files were found for encrypted backup.")
        }

        val generatedAt = utcTimestamp()
        val snapshotId = "snapshot_${System.currentTimeMillis()}"
        val root = treeDocumentUri(journalUri)
        val archiveDirectory = ensureJournalDirectory(root, JOURNAL_ROOT_DIRECTORY)
        val backupsDirectory = ensureJournalDirectory(archiveDirectory, ENCRYPTED_BACKUPS_DIRECTORY)
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val derived = deriveSnapshotKey(passphrase, salt)
        val splitOutput = SplitDocumentOutputStream(backupsDirectory, snapshotId)

        try {
            DataOutputStream(splitOutput).use { header ->
                header.writeUTF(ENCRYPTED_BACKUP_MAGIC)
                header.writeInt(ENCRYPTED_BACKUP_VERSION)
                header.writeUTF(derived.algorithm)
                header.writeInt(PBKDF2_ITERATIONS)
                header.writeInt(salt.size)
                header.write(salt)
                header.writeInt(iv.size)
                header.write(iv)
                header.flush()

                val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                    init(Cipher.ENCRYPT_MODE, SecretKeySpec(derived.key, "AES"), GCMParameterSpec(128, iv))
                }
                val digests = mutableListOf<SnapshotDigest>()
                CipherOutputStream(header, cipher).use { encrypted ->
                    ZipOutputStream(BufferedOutputStream(encrypted)).use { zip ->
                        inputs.forEachIndexed { index, input ->
                            writeSnapshotInput(zip, input, digests, index + 1, inputs.size)
                            notifySnapshotProgress(index + 1, inputs.size, input.archivePath)
                        }
                        recordBackupDiagnostic(
                            "writing_snapshot_manifest",
                            mapOf("totalFiles" to inputs.size),
                        )
                        val manifest = JSONObject().apply {
                            put("schemaVersion", 1)
                            put("snapshotId", snapshotId)
                            put("createdAtUtc", generatedAt)
                            put("snapshotScope", "journal-only")
                            put("coverage", JSONObject(coverage))
                            put("encryption", JSONObject().apply {
                                put("container", ENCRYPTED_BACKUP_MAGIC)
                                put("cipher", "AES-256-GCM")
                                put("kdf", derived.algorithm)
                                put("iterations", PBKDF2_ITERATIONS)
                            })
                            put("files", JSONArray().apply {
                                digests.forEach { digest ->
                                    put(JSONObject().apply {
                                        put("path", digest.archivePath)
                                        put("bytes", digest.bytes)
                                        put("sha256", digest.sha256)
                                    })
                                }
                            })
                        }
                        zip.putNextEntry(ZipEntry("snapshot-manifest.json"))
                        zip.write(manifest.toString(2).toByteArray(Charsets.UTF_8))
                        zip.closeEntry()
                    }
                }
            }

            snapshotPreferences().edit()
                .putString(SNAPSHOT_LAST_ID_KEY, snapshotId)
                .apply()
            clearBackupDiagnostic()
            return mapOf(
                "created" to true,
                "snapshotId" to snapshotId,
                "fileCount" to inputs.size,
                "parts" to splitOutput.partUris.map(Uri::toString),
                "createdAtUtc" to generatedAt,
                "snapshotScope" to "journal-only",
                "coverage" to coverage,
            )
        } catch (error: Exception) {
            splitOutput.deleteParts()
            throw error
        } finally {
            splitOutput.closeQuietly()
            derived.key.fill(0)
        }
    }

    private data class DerivedSnapshotKey(val algorithm: String, val key: ByteArray)

    private fun deriveSnapshotKey(passphrase: String, salt: ByteArray): DerivedSnapshotKey {
        val keySpec: KeySpec = PBEKeySpec(passphrase.toCharArray(), salt, PBKDF2_ITERATIONS, 256)
        val algorithm = runCatching {
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
            "PBKDF2WithHmacSHA256"
        }.getOrElse { "PBKDF2WithHmacSHA1" }
        val factory = SecretKeyFactory.getInstance(algorithm)
        return try {
            DerivedSnapshotKey(algorithm, factory.generateSecret(keySpec).encoded)
        } finally {
            (keySpec as PBEKeySpec).clearPassword()
        }
    }

    private fun collectJournalSnapshotInputs(
        journalTreeUri: Uri,
    ): List<SnapshotInput> {
        val inputs = mutableListOf<SnapshotInput>()
        val journalRoot = treeDocumentUri(journalTreeUri)
        val archiveDirectory = ensureJournalDirectory(journalRoot, JOURNAL_ROOT_DIRECTORY)
        // Long.MIN_VALUE intentionally includes the whole journal tree. A complete
        // snapshot must restore by itself and must not depend on earlier packs.
        collectJournalDocumentInputs(
            archiveDirectory,
            "family-memory-journal",
            Long.MIN_VALUE,
            inputs,
        )
        return inputs.sortedBy { input -> input.archivePath }
    }

    private fun collectOriginalVaultDocumentInputs(
        parentUri: Uri,
        relativePath: String,
        destination: MutableList<SnapshotInput>,
    ) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
            val modifiedColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            while (cursor.moveToNext()) {
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(parentUri, cursor.getString(idColumn))
                val name = cursor.getString(nameColumn)
                val mime = cursor.getString(mimeColumn)
                if (name.startsWith(".st")) continue // Syncthing metadata, never family media.
                val childPath = if (relativePath.isBlank()) name else "$relativePath/$name"
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    collectOriginalVaultDocumentInputs(documentUri, childPath, destination)
                    continue
                }
                val isVideo = childPath == "Videos" || childPath.startsWith("Videos/")
                val archivePath = if (isVideo) {
                    "original-media/videos/${childPath.removePrefix("Videos/")}"
                } else {
                    "original-media/photos/$childPath"
                }
                destination += SnapshotInput(
                    archivePath = archivePath,
                    bytes = cursor.getLong(sizeColumn).coerceAtLeast(0L),
                    modifiedUtcMillis = cursor.getLong(modifiedColumn).coerceAtLeast(0L),
                    openInput = {
                        contentResolver.openInputStream(documentUri)
                            ?: throw FileNotFoundException("An Original Vault media file could not be opened.")
                    },
                )
            }
        }
    }

    private fun snapshotCoverage(inputs: List<SnapshotInput>): Map<String, Int> {
        fun count(prefix: String) = inputs.count { input -> input.archivePath.startsWith(prefix) }
        return linkedMapOf(
            "photos" to count("original-media/photos/"),
            "videos" to count("original-media/videos/"),
            "journalEvents" to count("family-memory-journal/Journal Events/"),
            "exports" to count("family-memory-journal/Exports/"),
        )
    }

    private fun collectJournalDocumentInputs(
        parentUri: Uri,
        relativePath: String,
        afterUtcMillis: Long,
        destination: MutableList<SnapshotInput>,
    ) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
            val modifiedColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            while (cursor.moveToNext()) {
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(parentUri, cursor.getString(idColumn))
                val name = cursor.getString(nameColumn)
                val mime = cursor.getString(mimeColumn)
                val childPath = "$relativePath/$name"
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    // Encrypted Backups are snapshot outputs, never snapshot inputs.
                    // Including them would create an ever-growing recursive archive.
                    if (name != ENCRYPTED_BACKUPS_DIRECTORY) {
                        collectJournalDocumentInputs(documentUri, childPath, afterUtcMillis, destination)
                    }
                    continue
                }
                val modifiedMillis = cursor.getLong(modifiedColumn).coerceAtLeast(0L)
                if (modifiedMillis <= afterUtcMillis) continue
                destination += SnapshotInput(
                    archivePath = childPath,
                    bytes = cursor.getLong(sizeColumn).coerceAtLeast(0L),
                    modifiedUtcMillis = modifiedMillis,
                    openInput = {
                        contentResolver.openInputStream(documentUri)
                            ?: throw FileNotFoundException("A Family Memory Journal file could not be opened.")
                    },
                )
            }
        }
    }

    private fun writeSnapshotInput(
        zip: ZipOutputStream,
        input: SnapshotInput,
        digests: MutableList<SnapshotDigest>,
        position: Int,
        total: Int,
    ) {
        recordBackupDiagnostic(
            "writing_backup_input",
            mapOf(
                "position" to position,
                "totalFiles" to total,
                "category" to snapshotInputCategory(input.archivePath),
                "expectedBytes" to input.bytes,
            ),
        )
        zip.putNextEntry(ZipEntry(input.archivePath))
        val digest = MessageDigest.getInstance("SHA-256")
        var copied = 0L
        input.openInput().buffered().use { source ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = source.read(buffer)
                if (read < 0) break
                zip.write(buffer, 0, read)
                digest.update(buffer, 0, read)
                copied += read
            }
        }
        zip.closeEntry()
        digests += SnapshotDigest(
            archivePath = input.archivePath,
            bytes = copied,
            sha256 = digest.digest().joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) },
        )
        recordBackupDiagnostic(
            "backup_input_written",
            mapOf(
                "position" to position,
                "totalFiles" to total,
                "category" to snapshotInputCategory(input.archivePath),
                "writtenBytes" to copied,
            ),
        )
    }

    private fun snapshotInputCategory(archivePath: String): String = when {
        archivePath.startsWith("original-media/photos/") -> "photo"
        archivePath.startsWith("original-media/videos/") -> "video"
        archivePath.startsWith("family-memory-journal/Journal Events/") -> "journal"
        archivePath.startsWith("family-memory-journal/Exports/") -> "export"
        else -> "other"
    }

    private fun notifySnapshotProgress(completed: Int, total: Int, currentPath: String) {
        mainHandler.post {
            snapshotChannel?.invokeMethod(
                "snapshotProgress",
                mapOf("completedFiles" to completed, "totalFiles" to total, "currentPath" to currentPath),
            )
        }
    }

    private inner class SplitDocumentOutputStream(
        private val parentUri: Uri,
        private val snapshotId: String,
    ) : java.io.OutputStream() {
        val partUris = mutableListOf<Uri>()
        private var activeStream: java.io.OutputStream? = null
        private var activeBytes = 0L
        private var closed = false

        override fun write(oneByte: Int) {
            write(byteArrayOf(oneByte.toByte()), 0, 1)
        }

        override fun write(bytes: ByteArray, offset: Int, length: Int) {
            var writeOffset = offset
            var remaining = length
            while (remaining > 0) {
                ensureActivePart()
                val available = ENCRYPTED_PACK_TARGET_BYTES - activeBytes
                val count = minOf(remaining.toLong(), available).toInt()
                activeStream!!.write(bytes, writeOffset, count)
                activeBytes += count
                writeOffset += count
                remaining -= count
                if (activeBytes >= ENCRYPTED_PACK_TARGET_BYTES) rotatePart()
            }
        }

        override fun flush() {
            activeStream?.flush()
        }

        override fun close() {
            if (closed) return
            closed = true
            activeStream?.close()
            activeStream = null
        }

        fun closeQuietly() = runCatching { close() }

        fun deleteParts() {
            partUris.forEach { uri -> runCatching { contentResolver.delete(uri, null, null) } }
        }

        private fun ensureActivePart() {
            if (activeStream == null) startPart()
        }

        private fun rotatePart() {
            activeStream?.close()
            activeStream = null
            activeBytes = 0L
        }

        private fun startPart() {
            val partNumber = partUris.size + 1
            val displayName = String.format(Locale.US, "%s_part%03d.emb", snapshotId, partNumber)
            val documentUri = DocumentsContract.createDocument(
                contentResolver,
                parentUri,
                "application/octet-stream",
                displayName,
            ) ?: throw IllegalStateException("Android could not create an encrypted backup part.")
            val output = contentResolver.openOutputStream(documentUri, "w")
                ?: throw IllegalStateException("Android could not write an encrypted backup part.")
            partUris += documentUri
            activeStream = BufferedOutputStream(output)
        }
    }

    private fun restoreSnapshotFromSelectedFolder(call: MethodCall, result: MethodChannel.Result) {
        val passphrase = call.argument<String>("passphrase")
        if (passphrase == null || passphrase.length < 16) {
            result.error("weak_passphrase", "Use an archive passphrase with at least 16 characters.", null)
            return
        }
        if (pendingSnapshotRestore != null) {
            result.error("snapshot_restore_busy", "An encrypted backup restore is already in progress.", null)
            return
        }
        pendingSnapshotRestore = PendingSnapshotRestore(passphrase, result)
        try {
            openDocumentTree(SNAPSHOT_SOURCE_FOLDER_REQUEST_CODE)
        } catch (error: Exception) {
            pendingSnapshotRestore = null
            result.error("snapshot_restore_failed", error.message, null)
        }
    }

    private fun verifyLatestSnapshot(call: MethodCall, result: MethodChannel.Result) {
        val passphrase = call.argument<String>("passphrase")
        if (passphrase == null || passphrase.length < 16) {
            result.error("weak_passphrase", "Use an archive passphrase with at least 16 characters.", null)
            return
        }
        val treeUri = journalTreeUri()
        val snapshotId = snapshotPreferences().getString(SNAPSHOT_LAST_ID_KEY, null)
        if (treeUri == null || snapshotId.isNullOrBlank()) {
            result.error("snapshot_not_found", "No encrypted backup is available for verification.", null)
            return
        }
        vaultExecutor.execute {
            try {
                val verification = verifySnapshot(treeUri, snapshotId, passphrase)
                mainHandler.post { result.success(verification) }
            } catch (error: Exception) {
                mainHandler.post { result.error("snapshot_verification_failed", error.message, null) }
            }
        }
    }

    private fun verifySnapshot(treeUri: Uri, snapshotId: String, passphrase: String): Map<String, Any> {
        val root = treeDocumentUri(treeUri)
        val archiveDirectory = ensureJournalDirectory(root, JOURNAL_ROOT_DIRECTORY)
        val backupsDirectory = ensureJournalDirectory(archiveDirectory, ENCRYPTED_BACKUPS_DIRECTORY)
        val partUris = snapshotPartUris(backupsDirectory, snapshotId)
        if (partUris.isEmpty()) {
            throw FileNotFoundException("The latest encrypted backup parts are no longer available.")
        }

        MultiDocumentInputStream(partUris).use { combined ->
            DataInputStream(BufferedInputStream(combined)).use { header ->
                val magic = header.readUTF()
                if (magic != ENCRYPTED_BACKUP_MAGIC) {
                    throw IllegalStateException("This backup does not use the Entwined Memories encrypted archive format.")
                }
                val version = header.readInt()
                if (version != ENCRYPTED_BACKUP_VERSION) {
                    throw IllegalStateException("This encrypted archive format is not supported by this app version.")
                }
                val algorithm = header.readUTF()
                val iterations = header.readInt()
                if (iterations < 10_000 || iterations > 5_000_000) {
                    throw IllegalStateException("This encrypted archive has an invalid key-derivation setting.")
                }
                val saltLength = header.readInt()
                if (saltLength !in 8..64) throw IllegalStateException("This encrypted archive has an invalid salt.")
                val salt = ByteArray(saltLength)
                header.readFully(salt)
                val ivLength = header.readInt()
                if (ivLength !in 12..32) throw IllegalStateException("This encrypted archive has an invalid initialization vector.")
                val iv = ByteArray(ivLength)
                header.readFully(iv)

                val derived = deriveSnapshotKey(passphrase, salt, algorithm, iterations)
                try {
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                        init(Cipher.DECRYPT_MODE, SecretKeySpec(derived.key, "AES"), GCMParameterSpec(128, iv))
                    }
                    val actual = mutableMapOf<String, SnapshotDigest>()
                    var manifest: JSONObject? = null
                    CipherInputStream(header, cipher).use { decrypted ->
                        java.util.zip.ZipInputStream(BufferedInputStream(decrypted)).use { zip ->
                            while (true) {
                                val entry = zip.nextEntry ?: break
                                if (entry.isDirectory) continue
                                if (entry.name == "snapshot-manifest.json") {
                                    val bytes = zip.readBytes()
                                    manifest = JSONObject(bytes.toString(Charsets.UTF_8))
                                } else {
                                    actual[entry.name] = readSnapshotZipEntry(zip, entry.name)
                                }
                                zip.closeEntry()
                            }
                        }
                    }
                    val parsedManifest = manifest
                        ?: throw IllegalStateException("Encrypted archive manifest is missing.")
                    val files = parsedManifest.optJSONArray("files")
                        ?: throw IllegalStateException("Encrypted archive manifest file list is missing.")
                    if (files.length() != actual.size) {
                        throw IllegalStateException("Encrypted archive file count does not match its manifest.")
                    }
                    for (index in 0 until files.length()) {
                        val expected = files.optJSONObject(index)
                            ?: throw IllegalStateException("Encrypted archive manifest is invalid.")
                        val path = expected.optString("path")
                        val actualDigest = actual[path]
                            ?: throw IllegalStateException("Encrypted archive is missing $path.")
                        if (actualDigest.bytes != expected.optLong("bytes") ||
                            actualDigest.sha256 != expected.optString("sha256")) {
                            throw IllegalStateException("Encrypted archive integrity check failed for $path.")
                        }
                    }
                    return mapOf(
                        "verified" to true,
                        "snapshotId" to snapshotId,
                        "fileCount" to actual.size,
                        "partCount" to partUris.size,
                        "verifiedAtUtc" to utcTimestamp(),
                    )
                } finally {
                    derived.key.fill(0)
                }
            }
        }
    }

    private fun restoreSnapshotFromTree(
        sourceTreeUri: Uri,
        destinationTreeUri: Uri,
        passphrase: String,
    ): Map<String, Any> {
        val sourceRoot = treeDocumentUri(sourceTreeUri)
        val snapshotGroups = snapshotPartGroups(sourceRoot)
        if (snapshotGroups.isEmpty()) {
            throw FileNotFoundException("No Entwined Memories .emb backup parts were found in the selected source folder.")
        }
        val snapshotId = snapshotGroups.keys.maxOrNull()
            ?: throw FileNotFoundException("No encrypted backup snapshot was found.")
        val partUris = snapshotGroups[snapshotId]
            ?: throw FileNotFoundException("Encrypted backup parts are missing.")

        val destinationRoot = treeDocumentUri(destinationTreeUri)
        val restoreDirectoryName = "Entwined Memories Restore $snapshotId"
        if (findJournalChild(destinationRoot, restoreDirectoryName) != null) {
            throw IllegalStateException(
                "Restore stopped: $restoreDirectoryName already exists. Choose a new empty destination folder so no files are overwritten."
            )
        }
        val restoreRoot = DocumentsContract.createDocument(
            contentResolver,
            destinationRoot,
            DocumentsContract.Document.MIME_TYPE_DIR,
            restoreDirectoryName,
        ) ?: throw IllegalStateException("Android could not create the restore folder.")

        try {
            val actual = mutableMapOf<String, SnapshotDigest>()
            var manifest: JSONObject? = null
            MultiDocumentInputStream(partUris).use { combined ->
                DataInputStream(BufferedInputStream(combined)).use { header ->
                    val magic = header.readUTF()
                    if (magic != ENCRYPTED_BACKUP_MAGIC) {
                        throw IllegalStateException("This backup does not use the Entwined Memories encrypted archive format.")
                    }
                    val version = header.readInt()
                    if (version != ENCRYPTED_BACKUP_VERSION) {
                        throw IllegalStateException("This encrypted archive format is not supported by this app version.")
                    }
                    val algorithm = header.readUTF()
                    val iterations = header.readInt()
                    if (iterations < 10_000 || iterations > 5_000_000) {
                        throw IllegalStateException("This encrypted archive has an invalid key-derivation setting.")
                    }
                    val saltLength = header.readInt()
                    if (saltLength !in 8..64) throw IllegalStateException("This encrypted archive has an invalid salt.")
                    val salt = ByteArray(saltLength)
                    header.readFully(salt)
                    val ivLength = header.readInt()
                    if (ivLength !in 12..32) throw IllegalStateException("This encrypted archive has an invalid initialization vector.")
                    val iv = ByteArray(ivLength)
                    header.readFully(iv)

                    val derived = deriveSnapshotKey(passphrase, salt, algorithm, iterations)
                    try {
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                            init(Cipher.DECRYPT_MODE, SecretKeySpec(derived.key, "AES"), GCMParameterSpec(128, iv))
                        }
                        CipherInputStream(header, cipher).use { decrypted ->
                            java.util.zip.ZipInputStream(BufferedInputStream(decrypted)).use { zip ->
                                while (true) {
                                    val entry = zip.nextEntry ?: break
                                    if (entry.isDirectory) {
                                        zip.closeEntry()
                                        continue
                                    }
                                    if (entry.name == "snapshot-manifest.json") {
                                        if (manifest != null) {
                                            throw IllegalStateException("Encrypted archive contains more than one manifest.")
                                        }
                                        manifest = JSONObject(zip.readBytes().toString(Charsets.UTF_8))
                                    } else {
                                        val archivePath = validatedSnapshotArchivePath(entry.name)
                                        if (actual.containsKey(archivePath)) {
                                            throw IllegalStateException("Encrypted archive contains the same file twice: $archivePath")
                                        }
                                        actual[archivePath] = writeRestoredSnapshotEntry(
                                            zip,
                                            restoreRoot,
                                            archivePath,
                                        )
                                    }
                                    zip.closeEntry()
                                }
                            }
                        }
                    } finally {
                        derived.key.fill(0)
                    }
                }
            }
            validateSnapshotManifest(manifest, actual)
            return mapOf(
                "restored" to true,
                "snapshotId" to snapshotId,
                "fileCount" to actual.size,
                "partCount" to partUris.size,
                "restoreFolderUri" to restoreRoot.toString(),
                "restoredAtUtc" to utcTimestamp(),
            )
        } catch (error: Exception) {
            // An authentication or manifest failure must never leave a partial
            // recovery pretending to be a valid archive.
            runCatching { deleteDocumentTree(restoreRoot) }
            throw error
        }
    }

    private fun validateSnapshotManifest(
        manifest: JSONObject?,
        actual: Map<String, SnapshotDigest>,
    ) {
        val parsedManifest = manifest
            ?: throw IllegalStateException("Encrypted archive manifest is missing.")
        val files = parsedManifest.optJSONArray("files")
            ?: throw IllegalStateException("Encrypted archive manifest file list is missing.")
        if (files.length() != actual.size) {
            throw IllegalStateException("Encrypted archive file count does not match its manifest.")
        }
        for (index in 0 until files.length()) {
            val expected = files.optJSONObject(index)
                ?: throw IllegalStateException("Encrypted archive manifest is invalid.")
            val path = validatedSnapshotArchivePath(expected.optString("path"))
            val actualDigest = actual[path]
                ?: throw IllegalStateException("Encrypted archive is missing $path.")
            if (actualDigest.bytes != expected.optLong("bytes") ||
                actualDigest.sha256 != expected.optString("sha256")) {
                throw IllegalStateException("Encrypted archive integrity check failed for $path.")
            }
        }
    }

    private fun validatedSnapshotArchivePath(value: String): String {
        if (value.isBlank() || value.length > 1_000 || value.contains('\\')) {
            throw IllegalStateException("Encrypted archive contains an invalid file path.")
        }
        val segments = value.split("/")
        if (segments.any { it.isBlank() || it == "." || it == ".." || it.length > 180 }) {
            throw IllegalStateException("Encrypted archive contains an unsafe file path.")
        }
        return value
    }

    private fun writeRestoredSnapshotEntry(
        zip: java.util.zip.ZipInputStream,
        restoreRoot: Uri,
        archivePath: String,
    ): SnapshotDigest {
        val segments = archivePath.split("/")
        var parent = restoreRoot
        for (segment in segments.dropLast(1)) {
            parent = ensureJournalDirectory(parent, segment)
        }
        val fileName = segments.last()
        if (findJournalChild(parent, fileName) != null) {
            throw IllegalStateException("Restore stopped because a destination file already exists: $archivePath")
        }
        val destination = DocumentsContract.createDocument(
            contentResolver,
            parent,
            "application/octet-stream",
            fileName,
        ) ?: throw IllegalStateException("Android could not create restored file $archivePath.")
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            var bytes = 0L
            contentResolver.openOutputStream(destination, "w")?.buffered().use { output ->
                if (output == null) throw IllegalStateException("Android could not write restored file $archivePath.")
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = zip.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    digest.update(buffer, 0, read)
                    bytes += read
                }
                output.flush()
            }
            SnapshotDigest(
                archivePath = archivePath,
                bytes = bytes,
                sha256 = digest.digest().joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) },
            )
        } catch (error: Exception) {
            runCatching { contentResolver.delete(destination, null, null) }
            throw error
        }
    }

    private fun snapshotPartGroups(parentUri: Uri): Map<String, List<Uri>> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val pattern = Regex("""(snapshot_[0-9]+)_part([0-9]{3})\.emb""")
        val grouped = mutableMapOf<String, MutableList<Pair<Int, Uri>>>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                if (cursor.getString(mimeColumn) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                val match = pattern.matchEntire(cursor.getString(nameColumn)) ?: continue
                val snapshotId = match.groupValues[1]
                val number = match.groupValues[2].toInt()
                val uri = DocumentsContract.buildDocumentUriUsingTree(
                    parentUri,
                    cursor.getString(idColumn),
                )
                grouped.getOrPut(snapshotId) { mutableListOf() } += number to uri
            }
        }
        return grouped.mapValues { (snapshotId, parts) ->
            val sorted = parts.sortedBy { it.first }
            val expected = (1..sorted.size).toList()
            val actual = sorted.map { it.first }
            if (actual != expected) {
                throw IllegalStateException("Encrypted backup $snapshotId is missing or has duplicate part files.")
            }
            sorted.map { it.second }
        }
    }

    private fun deriveSnapshotKey(
        passphrase: String,
        salt: ByteArray,
        algorithm: String,
        iterations: Int,
    ): DerivedSnapshotKey {
        if (algorithm !in setOf("PBKDF2WithHmacSHA256", "PBKDF2WithHmacSHA1")) {
            throw IllegalStateException("This encrypted archive uses an unsupported key-derivation algorithm.")
        }
        val keySpec: KeySpec = PBEKeySpec(passphrase.toCharArray(), salt, iterations, 256)
        val factory = SecretKeyFactory.getInstance(algorithm)
        return try {
            DerivedSnapshotKey(algorithm, factory.generateSecret(keySpec).encoded)
        } finally {
            (keySpec as PBEKeySpec).clearPassword()
        }
    }

    private fun snapshotPartUris(backupsDirectory: Uri, snapshotId: String): List<Uri> {
        return snapshotPartGroups(backupsDirectory)[snapshotId] ?: emptyList()
    }

    private fun readSnapshotZipEntry(
        zip: java.util.zip.ZipInputStream,
        archivePath: String,
    ): SnapshotDigest {
        val digest = MessageDigest.getInstance("SHA-256")
        var bytes = 0L
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val read = zip.read(buffer)
            if (read < 0) break
            digest.update(buffer, 0, read)
            bytes += read
        }
        return SnapshotDigest(
            archivePath = archivePath,
            bytes = bytes,
            sha256 = digest.digest().joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) },
        )
    }

    private inner class MultiDocumentInputStream(
        private val partUris: List<Uri>,
    ) : InputStream() {
        private var partIndex = 0
        private var active: InputStream? = null

        override fun read(): Int {
            val one = ByteArray(1)
            return if (read(one, 0, 1) < 0) -1 else one[0].toInt() and 0xff
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            if (length == 0) return 0
            while (partIndex < partUris.size) {
                if (active == null) {
                    active = contentResolver.openInputStream(partUris[partIndex])
                        ?: throw FileNotFoundException("An encrypted backup part could not be opened.")
                }
                val read = active!!.read(buffer, offset, length)
                if (read >= 0) return read
                active!!.close()
                active = null
                partIndex += 1
            }
            return -1
        }

        override fun close() {
            active?.close()
            active = null
        }
    }

    private fun archiveOriginal(
        source: File,
        mimeHint: String?,
        year: Int,
        month: Int,
        mediaKind: VaultMediaKind,
    ): Map<String, Any> {
        if (!source.isFile || !source.canRead()) {
            throw FileNotFoundException("The selected original media is no longer readable.")
        }

        val hash = sha256(source)
        val extension = sourceExtension(source.name, mimeHint, mediaKind)
        val mimeType = mediaMimeType(mimeHint, extension, mediaKind)
        val displayName = "${mediaKind.filePrefix}_${hash.take(24)}.$extension"
        val relativePath = relativeVaultPath(mediaKind, year, month)
        val resolver = applicationContext.contentResolver
        val collection = mediaCollection(mediaKind)

        findExisting(
            resolver = resolver,
            collection = collection,
            displayName = displayName,
            relativePath = relativePath,
        )?.let { existing ->
            return mapOf(
                "uri" to existing.toString(),
                "sha256" to hash,
                "bytes" to source.length(),
                "alreadyExists" to true,
            )
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            when (mediaKind) {
                VaultMediaKind.PHOTO -> {
                    put(MediaStore.Images.Media.DATE_TAKEN, source.lastModified())
                }
                VaultMediaKind.VIDEO -> {
                    put(MediaStore.Video.Media.DATE_TAKEN, source.lastModified())
                }
            }
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        var destination: Uri? = null
        try {
            destination = resolver.insert(collection, values)
                ?: throw IllegalStateException("Android could not create the Original Vault file.")
            source.inputStream().buffered().use { input ->
                resolver.openOutputStream(destination, "w")?.buffered().use { output ->
                    if (output == null) {
                        throw IllegalStateException("Android could not write the Original Vault file.")
                    }
                    input.copyTo(output)
                }
            }
            resolver.update(
                destination,
                ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                },
                null,
                null,
            )
            return mapOf(
                "uri" to destination.toString(),
                "sha256" to hash,
                "bytes" to source.length(),
                "alreadyExists" to false,
            )
        } catch (error: Exception) {
            destination?.let { resolver.delete(it, null, null) }
            throw error
        }
    }

    private fun mediaCollection(mediaKind: VaultMediaKind): Uri = when (mediaKind) {
        VaultMediaKind.PHOTO -> MediaStore.Images.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        VaultMediaKind.VIDEO -> MediaStore.Video.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
    }

    private fun relativeVaultPath(
        mediaKind: VaultMediaKind,
        year: Int,
        month: Int,
    ): String {
        val middle = if (mediaKind.subdirectory.isBlank()) "" else "${mediaKind.subdirectory}/"
        return String.format(
            Locale.US,
            "$VAULT_ROOT/$middle%04d/%02d/",
            year,
            month,
        )
    }

    private fun findExisting(
        resolver: ContentResolver,
        collection: Uri,
        displayName: String,
        relativePath: String,
    ): Uri? {
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND " +
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ?"
        resolver.query(collection, projection, selection, arrayOf(displayName, relativePath), null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                    return Uri.withAppendedPath(collection, id.toString())
                }
            }
        return null
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }

    private fun sourceExtension(
        fileName: String,
        mimeHint: String?,
        mediaKind: VaultMediaKind,
    ): String {
        val fromName = fileName.substringAfterLast('.', "").lowercase(Locale.US)
        val supportedExtensions = when (mediaKind) {
            VaultMediaKind.PHOTO -> setOf("jpg", "jpeg", "png", "webp", "heic", "heif", "gif")
            VaultMediaKind.VIDEO -> setOf("mp4", "m4v", "mov", "webm", "3gp", "3gpp", "avi", "mkv")
        }
        if (fromName in supportedExtensions) return fromName

        return when (mimeHint?.lowercase(Locale.US)) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/heic" -> "heic"
            "image/heif" -> "heif"
            "image/gif" -> "gif"
            "video/quicktime" -> "mov"
            "video/webm" -> "webm"
            "video/3gpp" -> "3gp"
            "video/x-matroska" -> "mkv"
            else -> if (mediaKind == VaultMediaKind.PHOTO) "jpg" else "mp4"
        }
    }

    private fun mediaMimeType(
        mimeHint: String?,
        extension: String,
        mediaKind: VaultMediaKind,
    ): String {
        val expectedPrefix = if (mediaKind == VaultMediaKind.PHOTO) "image/" else "video/"
        if (mimeHint?.startsWith(expectedPrefix) == true) return mimeHint

        return when (extension) {
            "png" -> "image/png"
            "webp" -> "image/webp"
            "heic" -> "image/heic"
            "heif" -> "image/heif"
            "gif" -> "image/gif"
            "m4v" -> "video/x-m4v"
            "mov" -> "video/quicktime"
            "webm" -> "video/webm"
            "3gp", "3gpp" -> "video/3gpp"
            "avi" -> "video/x-msvideo"
            "mkv" -> "video/x-matroska"
            else -> if (mediaKind == VaultMediaKind.PHOTO) "image/jpeg" else "video/mp4"
        }
    }
}
