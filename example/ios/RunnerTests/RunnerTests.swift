import Flutter
import UIKit
import XCTest

@testable import get_native_error

class RunnerTests: XCTestCase {

  func testPeekPendingCrashWithoutFileReturnsNil() {
    let plugin = GetNativeErrorPlugin()
    let call = FlutterMethodCall(methodName: "peekPendingCrash", arguments: nil)
    let resultExpectation = expectation(description: "result block must be called.")

    plugin.handle(call) { result in
      XCTAssertNil(result)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testTakePendingCrashWithoutFileReturnsNil() {
    let plugin = GetNativeErrorPlugin()
    let call = FlutterMethodCall(methodName: "takePendingCrash", arguments: nil)
    let resultExpectation = expectation(description: "result block must be called.")

    plugin.handle(call) { result in
      XCTAssertNil(result)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testInstallSucceeds() {
    let plugin = GetNativeErrorPlugin()
    let call = FlutterMethodCall(methodName: "install", arguments: nil)
    let resultExpectation = expectation(description: "result block must be called.")

    plugin.handle(call) { result in
      XCTAssertNil(result)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testUnknownMethodIsNotImplemented() {
    let plugin = GetNativeErrorPlugin()
    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])
    let resultExpectation = expectation(description: "result block must be called.")

    plugin.handle(call) { result in
      XCTAssertTrue(result is NSObject && result as? NSObject == FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
