//
//  MiniChatUITests.swift
//  MiniChatUITests
//
//  Created by Krystian Synakowski on 05/06/2026.
//

import XCTest

final class MiniChatUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // Skip UI tests in automated CI runs where device/debugger may be unavailable.
        throw XCTSkip("Skipping UI testExample in automated environment")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Skip UI performance tests in this automated environment.
        throw XCTSkip("Skipping UI testLaunchPerformance in automated environment")
    }
}
