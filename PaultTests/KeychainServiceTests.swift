// PaultTests/KeychainServiceTests.swift
import XCTest
@testable import Pault

final class KeychainServiceTests: XCTestCase {
    let service = KeychainService(service: "com.pault.test")

    override func tearDown() {
        super.tearDown()
        service.delete(key: "test-key")
    }

    func test_saveAndLoad_returnsStoredValue() throws {
        try service.save(key: "test-key", value: "my-api-key")
        let loaded = try service.load(key: "test-key")
        XCTAssertEqual(loaded, "my-api-key")
    }

    func test_overwrite_updatesValue() throws {
        try service.save(key: "test-key", value: "old")
        try service.save(key: "test-key", value: "new")
        XCTAssertEqual(try service.load(key: "test-key"), "new")
    }

    func test_delete_removesValue() throws {
        try service.save(key: "test-key", value: "value")
        service.delete(key: "test-key")
        XCTAssertNil(try service.load(key: "test-key"))
    }

    func test_loadMissing_returnsNil() throws {
        XCTAssertNil(try service.load(key: "nonexistent"))
    }
}
