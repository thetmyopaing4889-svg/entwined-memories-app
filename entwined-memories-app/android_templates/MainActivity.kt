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
        private const val JOURNAL_ROOT_DIRECTORY = "Entwined Memories Archive"
        private const val JOURNAL_EVENTS_DIRECTORY = "Journal Events"
        private const val JOURNAL_FOLDER_REQUEST_CODE = 9421
        private const val SNAPSHOT_SOURCE_FOLDER_REQUEST_CODE = 9422
        private const val SNAPSHOT_RESTORE_FOLDER_REQUEST_CODE = 9423
        private const val SNAPSHOT_CHANNEL = "entwined_memories/encrypted_snapshot"
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
                    "exportPortableArchive" -> exportPortableArchive(result)
                    else -> result.notImplemented()
                }
            }
        snapshotChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SNAPSHOT_CHANNEL)
        snapshotChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "createIncrementalSnapshot" -> createIncrementalSnapshot(call, result)
                "verifyLatestSnapshot" -> verifyLatestSnapshot(call, result)
                "restoreSnapshotFromSelectedFolder" -> restoreSnapshotFromSelectedFolder(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        activityIsPostResumed = true
        deliverPendingJournalFolderCompletionWhenSafe()
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
        if (journalTreeUri() != null) {
            result.success(mapOf("configured" to true))
            return
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

    private fun createIncrementalSnapshot(call: MethodCall, result: MethodChannel.Result) {
        val passphrase = call.argument<String>("passphrase")
        if (passphrase == null || passphrase.length < 16) {
            result.error(
                "weak_passphrase",
                "Use an archive passphrase with at least 16 characters.",
                null,
            )
            return
        }
        val treeUri = journalTreeUri()
        if (treeUri == null) {
            result.error("journal_folder_required", "Select a Family Memory Journal folder first.", null)
            return
        }

        vaultExecutor.execute {
            try {
                val snapshot = buildIncrementalSnapshot(treeUri, passphrase)
                mainHandler.post { result.success(snapshot) }
            } catch (error: Exception) {
                mainHandler.post { result.error("snapshot_failed", error.message, null) }
            }
        }
    }

    private fun buildIncrementalSnapshot(treeUri: Uri, passphrase: String): Map<String, Any> {
        val cursorMillis = snapshotPreferences().getLong(SNAPSHOT_CURSOR_KEY, 0L)
        val inputs = collectSnapshotInputs(treeUri, cursorMillis)
        if (inputs.isEmpty()) {
            return mapOf(
                "created" to false,
                "fileCount" to 0,
                "parts" to emptyList<String>(),
                "createdAtUtc" to utcTimestamp(),
            )
        }

        val generatedAt = utcTimestamp()
        val snapshotId = "snapshot_${System.currentTimeMillis()}"
        val root = treeDocumentUri(treeUri)
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
                            writeSnapshotInput(zip, input, digests)
                            notifySnapshotProgress(index + 1, inputs.size, input.archivePath)
                        }
                        val manifest = JSONObject().apply {
                            put("schemaVersion", 1)
                            put("snapshotId", snapshotId)
                            put("createdAtUtc", generatedAt)
                            put("incrementalAfterUtcMillis", cursorMillis)
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

            // MediaStore DATE_ADDED is second-granular. Keep a two-second overlap
            // so a newly created original can never be missed between snapshots.
            val completedMillis = System.currentTimeMillis()
            val nextCursorMillis = (completedMillis - 2_000L).coerceAtLeast(0L)
            snapshotPreferences().edit()
                .putLong(SNAPSHOT_CURSOR_KEY, nextCursorMillis)
                .putString(SNAPSHOT_LAST_ID_KEY, snapshotId)
                .apply()
            return mapOf(
                "created" to true,
                "snapshotId" to snapshotId,
                "fileCount" to inputs.size,
                "parts" to splitOutput.partUris.map(Uri::toString),
                "createdAtUtc" to generatedAt,
                "incrementalAfterUtcMillis" to cursorMillis,
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

    private fun collectSnapshotInputs(treeUri: Uri, afterUtcMillis: Long): List<SnapshotInput> {
        val inputs = mutableListOf<SnapshotInput>()
        inputs += collectVaultMediaInputs(VaultMediaKind.PHOTO, afterUtcMillis)
        inputs += collectVaultMediaInputs(VaultMediaKind.VIDEO, afterUtcMillis)

        val root = treeDocumentUri(treeUri)
        val archiveDirectory = ensureJournalDirectory(root, JOURNAL_ROOT_DIRECTORY)
        collectJournalDocumentInputs(
            archiveDirectory,
            "family-memory-journal",
            afterUtcMillis,
            inputs,
        )
        return inputs.sortedBy { input -> input.archivePath }
    }

    private fun collectVaultMediaInputs(
        mediaKind: VaultMediaKind,
        afterUtcMillis: Long,
    ): List<SnapshotInput> {
        val collection = mediaCollection(mediaKind)
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
        val selectionArgs = arrayOf("$VAULT_ROOT/%")
        val inputs = mutableListOf<SnapshotInput>()
        contentResolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val pathColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val dateAddedColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
            while (cursor.moveToNext()) {
                val addedMillis = cursor.getLong(dateAddedColumn) * 1000L
                if (addedMillis <= afterUtcMillis) continue
                val uri = Uri.withAppendedPath(collection, cursor.getLong(idColumn).toString())
                val relativePath = cursor.getString(pathColumn).trimEnd('/')
                val displayName = cursor.getString(nameColumn)
                val kindPath = if (mediaKind == VaultMediaKind.PHOTO) "photos" else "videos"
                inputs += SnapshotInput(
                    archivePath = "original-media/$kindPath/$relativePath/$displayName",
                    bytes = cursor.getLong(sizeColumn),
                    modifiedUtcMillis = addedMillis,
                    openInput = {
                        contentResolver.openInputStream(uri)
                            ?: throw FileNotFoundException("An Original Vault media file could not be opened.")
                    },
                )
            }
        }
        return inputs
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
    ) {
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
