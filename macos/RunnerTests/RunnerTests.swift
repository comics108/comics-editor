import Cocoa
import FlutterMacOS
import XCTest
@testable import comics_editor

class RunnerTests: XCTestCase {
  func testQueueDrainsOnceInDeliveryOrder() {
    let queue = DocumentOpenQueue()
    queue.enqueue(path: "/cache/first.comics")
    queue.enqueue(error: "copy failed")

    XCTAssertEqual(queue.takeAll(), [
      ["path": "/cache/first.comics"],
      ["error": "copy failed"],
    ])
    XCTAssertTrue(queue.takeAll().isEmpty)
  }

  func testComicsURLFilteringIsNarrowAndCaseInsensitive() {
    XCTAssertTrue(DocumentOpenBroker.isComicsURL(URL(fileURLWithPath: "/tmp/story.COMICS")))
    XCTAssertFalse(DocumentOpenBroker.isComicsURL(URL(fileURLWithPath: "/tmp/story.puzzle")))
  }
}
