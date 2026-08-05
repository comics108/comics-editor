package net.nativemind.comics.editor

class PendingDocumentEntry private constructor(
    val path: String?,
    val error: String?,
) {
    companion object {
        fun path(path: String) = PendingDocumentEntry(path = path, error = null)

        fun error(error: String) = PendingDocumentEntry(path = null, error = error)
    }

    fun asChannelValue(): Map<String, String> =
        if (path != null) mapOf("path" to path) else mapOf("error" to requireNotNull(error))
}

class DocumentOpenBroker {
    private val pending = ArrayDeque<PendingDocumentEntry>()

    @Volatile
    var notificationHandler: (() -> Unit)? = null

    fun enqueue(entry: PendingDocumentEntry) {
        synchronized(pending) {
            pending.addLast(entry)
        }
        notificationHandler?.invoke()
    }

    fun takePendingDocuments(): List<Map<String, String>> =
        synchronized(pending) {
            buildList {
                while (pending.isNotEmpty()) {
                    add(pending.removeFirst().asChannelValue())
                }
            }
        }

    fun pendingPaths(): Set<String> =
        synchronized(pending) {
            pending.mapNotNullTo(mutableSetOf()) { it.path }
        }

    companion object {
        fun isComicsName(name: String): Boolean = name.lowercase().endsWith(".comics")
    }
}
