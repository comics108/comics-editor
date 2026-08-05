package net.nativemind.comics.editor

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID

class IncomingDocumentCopier(private val context: Context) {
    fun copy(intent: Intent): PendingDocumentEntry {
        if (intent.action != Intent.ACTION_VIEW) {
            return PendingDocumentEntry.error("Unsupported external document action")
        }
        val uri = intent.data
            ?: return PendingDocumentEntry.error("External Comics document has no URI")
        if (uri.scheme != "content" && uri.scheme != "file") {
            return PendingDocumentEntry.error("Unsupported external document URI")
        }

        val displayName = resolveDisplayName(uri)
            ?: return PendingDocumentEntry.error("External Comics document has no filename")
        if (!DocumentOpenBroker.isComicsName(displayName)) {
            return PendingDocumentEntry.error("Unsupported external document: $displayName")
        }

        val directory = File(context.cacheDir, "incoming-comics")
        if (!directory.exists() && !directory.mkdirs()) {
            return PendingDocumentEntry.error("Unable to create private Comics cache")
        }
        val identifier = UUID.randomUUID().toString()
        val staging = File(directory, "$identifier.part")
        val target = File(directory, "$identifier.comics")

        return try {
            val input = context.contentResolver.openInputStream(uri)
                ?: return PendingDocumentEntry.error("Unable to read external Comics document")
            input.use { source ->
                FileOutputStream(staging).use { destination ->
                    source.copyTo(destination)
                    destination.fd.sync()
                }
            }
            moveCompletedCopy(staging, target)
            PendingDocumentEntry.path(target.absolutePath)
        } catch (error: Exception) {
            staging.delete()
            target.delete()
            PendingDocumentEntry.error(
                "Unable to copy external Comics document: ${error.message ?: error.javaClass.simpleName}",
            )
        }
    }

    fun pruneStaleCopies(pendingPaths: Set<String>) {
        val directory = File(context.cacheDir, "incoming-comics")
        val cutoff = System.currentTimeMillis() - STALE_COPY_AGE_MS
        directory.listFiles()?.forEach { file ->
            if (file.absolutePath !in pendingPaths && file.lastModified() < cutoff) {
                file.delete()
            }
        }
    }

    private fun resolveDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (column >= 0) return cursor.getString(column)
            }
        }
        return uri.lastPathSegment
    }

    private fun moveCompletedCopy(staging: File, target: File) {
        try {
            Files.move(
                staging.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
            )
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(
                staging.toPath(),
                target.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
    }

    private companion object {
        const val STALE_COPY_AGE_MS = 7L * 24L * 60L * 60L * 1000L
    }
}
