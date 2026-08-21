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
import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
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
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != JOURNAL_FOLDER_REQUEST_CODE) return

        val pendingResult = pendingJournalFolderResult ?: return
        pendingJournalFolderResult = null
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            pendingResult.error("journal_folder_cancelled", "No Family Memory Journal folder was selected.", null)
            return
        }

        try {
            val grantedFlags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            contentResolver.takePersistableUriPermission(treeUri, grantedFlags)
            journalPreferences().edit().putString(JOURNAL_TREE_URI_KEY, treeUri.toString()).apply()
            pendingResult.success(mapOf("configured" to true, "treeUri" to treeUri.toString()))
        } catch (error: Exception) {
            pendingResult.error("journal_folder_failed", error.message, null)
        }
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
