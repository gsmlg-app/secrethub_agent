import Flutter
import UIKit
import XCTest

@testable import secrethub_agent

class RunnerTests: XCTestCase {
  func testGetPlatformVersion() {
    let plugin = SecrethubAgentPlugin()
    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: nil)
    let completed = expectation(description: "native diagnostic completes")
    plugin.handle(call) { result in
      XCTAssertEqual(result as? String, "iOS " + UIDevice.current.systemVersion)
      completed.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testUnknownMethodIsNotImplemented() {
    let plugin = SecrethubAgentPlugin()
    let call = FlutterMethodCall(methodName: "runtime.request", arguments: nil)
    let completed = expectation(description: "unknown operation is rejected")
    plugin.handle(call) { result in
      XCTAssertTrue((result as? NSObject) === FlutterMethodNotImplemented)
      completed.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
