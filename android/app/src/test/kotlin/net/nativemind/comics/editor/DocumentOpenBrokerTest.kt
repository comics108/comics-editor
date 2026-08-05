package net.nativemind.comics.editor

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DocumentOpenBrokerTest {
    @Test
    fun `take drains entries once in delivery order`() {
        val broker = DocumentOpenBroker()
        broker.enqueue(PendingDocumentEntry.path("/cache/first.comics"))
        broker.enqueue(PendingDocumentEntry.error("copy failed"))

        assertEquals(
            listOf(
                mapOf("path" to "/cache/first.comics"),
                mapOf("error" to "copy failed"),
            ),
            broker.takePendingDocuments(),
        )
        assertTrue(broker.takePendingDocuments().isEmpty())
    }

    @Test
    fun `enqueue notifies only after an entry is queued`() {
        val broker = DocumentOpenBroker()
        val observedSizes = mutableListOf<Int>()
        broker.notificationHandler = {
            observedSizes += broker.pendingPaths().size
        }

        broker.enqueue(PendingDocumentEntry.path("/cache/open.comics"))

        assertEquals(listOf(1), observedSizes)
    }

    @Test
    fun `Comics filename matching is case insensitive and narrow`() {
        assertTrue(DocumentOpenBroker.isComicsName("story.comics"))
        assertTrue(DocumentOpenBroker.isComicsName("STORY.COMICS"))
        assertFalse(DocumentOpenBroker.isComicsName("story.puzzle"))
        assertFalse(DocumentOpenBroker.isComicsName("archive.zip"))
        assertFalse(DocumentOpenBroker.isComicsName("story.comics.zip"))
    }
}
