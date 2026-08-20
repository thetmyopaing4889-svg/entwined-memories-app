package com.entwinedmemories.entwined_memories

import android.content.ContentResolver
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Android-only bridge for preserving parents' selected source photos and videos.
 * It writes byte-for-byte copies to shared Pictures storage so Syncthing-Fork can
 * sync one dedicated family-vault folder. It never enumerates or copies the
 * device's full gallery.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val VAULT_CHANNEL = "entwined_memories/original_vault"
        private const val VAULT_ROOT = "Pictures/Entwined Memories Originals"
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
        vaultExecutor.shutdownNow()
        super.onDestroy()
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
