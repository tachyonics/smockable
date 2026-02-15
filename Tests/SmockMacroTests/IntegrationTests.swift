//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  IntegrationTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestIntegrationService {
    // Mixed sync/async/throwing functions
    func syncFunction(id: String) -> String
    func asyncFunction(id: String) async -> String
    func throwingFunction(id: String) throws -> String
    func asyncThrowingFunction(id: String) async throws -> String

    // Mixed property types
    var syncProperty: String { get set }
    var asyncProperty: String { get async }
    var throwingProperty: String { get throws }
    var asyncThrowingProperty: String { get async throws }

    // Complex parameter combinations
    func complexFunction(
        name: String,
        count: Int,
        enabled: Bool,
        data: Data,
        items: [String],
        config: [String: String],
        sendable: Sendable
    ) async throws -> String
}

@Smock
protocol TestRealWorldService {
    // Realistic API-like methods
    func authenticate(username: String, password: String) async throws -> String
    func fetchUserProfile(userId: String) async throws -> [String: String]
    func updateUserSettings(userId: String, settings: [String: String]) async throws
    func uploadFile(data: Data, filename: String, metadata: [String: String]?) async throws -> String
    func downloadFile(fileId: String) async throws -> Data

    // Properties for configuration
    var isAuthenticated: Bool { get async }
    var currentUserId: String? { get async }
    var apiBaseUrl: String { get throws }
}

enum IntegrationError: Error, Equatable {
    case authenticationFailed
    case userNotFound
    case invalidData
    case networkError
    case fileNotFound
}

struct IntegrationTests {

    // MARK: - Mixed Function and Property Integration

    @Test
    func testMixedFunctionAndPropertyWorkflow() async throws {
        var expectations = MockTestIntegrationService.Expectations()

        // Setup mixed expectations
        when(expectations.syncProperty.get(), return: "initial")
        when(expectations.syncFunction(id: .any), return: "sync result")
        when(expectations.asyncProperty.get(), return: "async value")
        when(expectations.asyncFunction(id: .any), return: "async result")
        when(expectations.throwingProperty.get(), return: "throwing value")
        when(expectations.throwingFunction(id: .any), return: "throwing result")
        when(expectations.asyncThrowingProperty.get(), return: "async throwing value")
        when(expectations.asyncThrowingFunction(id: .any), return: "async throwing result")

        let mock = MockTestIntegrationService(expectations: expectations)

        // Execute mixed workflow
        let syncProp = mock.syncProperty
        let syncFunc = mock.syncFunction(id: "test")
        let asyncProp = await mock.asyncProperty
        let asyncFunc = await mock.asyncFunction(id: "test")
        let throwingProp = try mock.throwingProperty
        let throwingFunc = try mock.throwingFunction(id: "test")
        let asyncThrowingProp = try await mock.asyncThrowingProperty
        let asyncThrowingFunc = try await mock.asyncThrowingFunction(id: "test")

        // Verify results
        #expect(syncProp == "initial")
        #expect(syncFunc == "sync result")
        #expect(asyncProp == "async value")
        #expect(asyncFunc == "async result")
        #expect(throwingProp == "throwing value")
        #expect(throwingFunc == "throwing result")
        #expect(asyncThrowingProp == "async throwing value")
        #expect(asyncThrowingFunc == "async throwing result")

        // Verify all calls
        verify(mock, times: 1).syncProperty.get()
        verify(mock, times: 1).syncFunction(id: "test")
        verify(mock, times: 1).asyncProperty.get()
        verify(mock, times: 1).asyncFunction(id: "test")
        verify(mock, times: 1).throwingProperty.get()
        verify(mock, times: 1).throwingFunction(id: "test")
        verify(mock, times: 1).asyncThrowingProperty.get()
        verify(mock, times: 1).asyncThrowingFunction(id: "test")
    }

    @Test
    func testComplexParameterIntegration() async throws {
        var expectations = MockTestIntegrationService.Expectations()

        when(
            expectations.complexFunction(
                name: "test"..."zebra",  // Comparable range
                count: 1...100,  // Comparable range
                enabled: true,  // Bool exact
                data: .any,  // Non-comparable any
                items: .any,  // Collection any
                config: .any,  // Collection any
                sendable: .any  // Generic Sendable any
            ),
            return: "complex integration success"
        )

        let mock = MockTestIntegrationService(expectations: expectations)

        let result = try await mock.complexFunction(
            name: "zebra",
            count: 50,
            enabled: true,
            data: Data([1, 2, 3]),
            items: ["item1", "item2"],
            config: ["setting": "value"],
            sendable: UUID()
        )

        #expect(result == "complex integration success")

        verify(mock, times: 1).complexFunction(
            name: "test"..."zebra",
            count: 1...100,
            enabled: true,
            data: .any,
            items: .any,
            config: .any,
            sendable: .any
        )
    }

    // MARK: - Real-World API Simulation

    @Test
    func testAuthenticationWorkflow() async throws {
        var expectations = MockTestRealWorldService.Expectations()

        let userId = "userId"

        // Setup authentication flow
        when(expectations.isAuthenticated.get(), return: false)
        when(expectations.authenticate(username: "user", password: "pass"), return: "auth-token")
        when(expectations.isAuthenticated.get(), return: true)
        when(expectations.currentUserId.get(), return: userId)

        let mock = MockTestRealWorldService(expectations: expectations)

        // Execute authentication workflow
        let initialAuth = await mock.isAuthenticated
        #expect(initialAuth == false)

        let token = try await mock.authenticate(username: "user", password: "pass")
        #expect(token == "auth-token")

        let finalAuth = await mock.isAuthenticated
        #expect(finalAuth == true)

        let currentUser = await mock.currentUserId
        #expect(currentUser == userId)

        verify(mock, times: 2).isAuthenticated.get()
        verify(mock, times: 1).authenticate(username: "user", password: "pass")
        verify(mock, times: 1).currentUserId.get()
    }

    @Test
    func testFileUploadDownloadWorkflow() async throws {
        var expectations = MockTestRealWorldService.Expectations()

        let fileId = "userId"
        let testData = Data("test file content".utf8)

        when(expectations.uploadFile(data: .any, filename: .any, metadata: .any), return: fileId)
        when(expectations.downloadFile(fileId: fileId), return: testData)

        let mock = MockTestRealWorldService(expectations: expectations)

        // Upload file
        let uploadedId = try await mock.uploadFile(
            data: testData,
            filename: "test.txt",
            metadata: ["type": "text", "size": "17"]
        )
        #expect(uploadedId == fileId)

        // Download file
        let downloadedData = try await mock.downloadFile(fileId: fileId)
        #expect(downloadedData == testData)

        verify(mock, times: 1).uploadFile(data: .any, filename: "test.txt", metadata: .any)
        verify(mock, times: 1).downloadFile(fileId: fileId)
    }

    @Test
    func testUserProfileManagement() async throws {
        var expectations = MockTestRealWorldService.Expectations()

        let userId = "userId"
        let initialProfile = ["name": "John", "email": "john@example.com"]
        let updatedSettings = ["theme": "dark", "notifications": "enabled"]

        when(expectations.fetchUserProfile(userId: userId), return: initialProfile)
        when(expectations.updateUserSettings(userId: userId, settings: .any), complete: .withSuccess)
        when(
            expectations.fetchUserProfile(userId: userId),
            return: ["name": "John", "email": "john@example.com", "theme": "dark"]
        )

        let mock = MockTestRealWorldService(expectations: expectations)

        // Fetch initial profile
        let profile = try await mock.fetchUserProfile(userId: userId)
        #expect(profile["name"] == "John")
        #expect(profile["email"] == "john@example.com")

        // Update settings
        try await mock.updateUserSettings(userId: userId, settings: updatedSettings)

        // Fetch updated profile
        let updatedProfile = try await mock.fetchUserProfile(userId: userId)
        #expect(updatedProfile["theme"] == "dark")

        verify(mock, times: 2).fetchUserProfile(userId: userId)
        verify(mock, times: 1).updateUserSettings(userId: userId, settings: .any)
    }

    // MARK: - Error Handling Integration

    @Test
    func testComplexErrorHandlingWorkflow() async throws {
        var expectations = MockTestRealWorldService.Expectations()

        when(
            expectations.authenticate(username: "invalid", password: .any),
            throw: IntegrationError.authenticationFailed
        )
        when(expectations.authenticate(username: "valid", password: "correct"), return: "token")
        when(expectations.fetchUserProfile(userId: .any), throw: IntegrationError.userNotFound)
        when(expectations.downloadFile(fileId: .any), throw: IntegrationError.fileNotFound)

        let mock = MockTestRealWorldService(expectations: expectations)

        // Test authentication failure
        await #expect(throws: IntegrationError.authenticationFailed) {
            _ = try await mock.authenticate(username: "invalid", password: "wrong")
        }

        // Test successful authentication
        let token = try await mock.authenticate(username: "valid", password: "correct")
        #expect(token == "token")

        // Test user not found
        await #expect(throws: IntegrationError.userNotFound) {
            _ = try await mock.fetchUserProfile(userId: "userId")
        }

        // Test file not found
        await #expect(throws: IntegrationError.fileNotFound) {
            _ = try await mock.downloadFile(fileId: "fileId")
        }

        verify(mock, times: 2).authenticate(username: .any, password: .any)
        verify(mock, times: 1).fetchUserProfile(userId: .any)
        verify(mock, times: 1).downloadFile(fileId: .any)
    }

    @Test
    func testMixedSuccessAndErrorScenarios() async throws {
        var expectations = MockTestRealWorldService.Expectations()

        let userId = "userId"

        // Mix success and error expectations
        when(expectations.authenticate(username: .any, password: .any), return: "success")
        when(expectations.fetchUserProfile(userId: userId), throw: IntegrationError.networkError)
        when(expectations.fetchUserProfile(userId: userId), return: ["name": "Recovery"])
        when(expectations.apiBaseUrl.get(), throw: IntegrationError.invalidData)
        when(expectations.apiBaseUrl.get(), return: "https://api.example.com")

        let mock = MockTestRealWorldService(expectations: expectations)

        // Successful auth
        let token = try await mock.authenticate(username: "user", password: "pass")
        #expect(token == "success")

        // Failed profile fetch
        await #expect(throws: IntegrationError.networkError) {
            _ = try await mock.fetchUserProfile(userId: userId)
        }

        // Successful profile fetch (retry)
        let profile = try await mock.fetchUserProfile(userId: userId)
        #expect(profile["name"] == "Recovery")

        // Failed property access
        #expect(throws: IntegrationError.invalidData) {
            _ = try mock.apiBaseUrl
        }

        // Successful property access (retry)
        let baseUrl = try mock.apiBaseUrl
        #expect(baseUrl == "https://api.example.com")

        verify(mock, times: 1).authenticate(username: .any, password: .any)
        verify(mock, times: 2).fetchUserProfile(userId: userId)
        verify(mock, times: 2).apiBaseUrl.get()
    }

    // MARK: - Concurrent Access Integration

    @Test
    func testConcurrentIntegrationScenarios() async throws {
        var expectations = MockTestIntegrationService.Expectations()

        when(expectations.asyncFunction(id: .any), times: .unbounded, return: "concurrent result")
        when(expectations.asyncProperty.get(), times: .unbounded, return: "concurrent property")
        when(expectations.asyncThrowingFunction(id: .any), times: .unbounded, return: "concurrent async throwing")

        let mock = MockTestIntegrationService(expectations: expectations)

        // Test concurrent function calls
        async let func1 = mock.asyncFunction(id: "concurrent1")
        async let func2 = mock.asyncFunction(id: "concurrent2")
        async let func3 = mock.asyncFunction(id: "concurrent3")

        let functionResults = await [func1, func2, func3]
        #expect(functionResults.allSatisfy { $0 == "concurrent result" })

        // Test concurrent property access
        async let prop1 = mock.asyncProperty
        async let prop2 = mock.asyncProperty
        async let prop3 = mock.asyncProperty

        let propertyResults = await [prop1, prop2, prop3]
        #expect(propertyResults.allSatisfy { $0 == "concurrent property" })

        // Test concurrent async throwing calls
        async let asyncThrow1 = mock.asyncThrowingFunction(id: "at1")
        async let asyncThrow2 = mock.asyncThrowingFunction(id: "at2")

        let asyncThrowingResults = try await [asyncThrow1, asyncThrow2]
        #expect(asyncThrowingResults.allSatisfy { $0 == "concurrent async throwing" })

        verify(mock, times: 3).asyncFunction(id: .any)
        verify(mock, times: 3).asyncProperty.get()
        verify(mock, times: 2).asyncThrowingFunction(id: .any)
    }

    // MARK: - Comprehensive Integration Verification

    @Test
    func testComprehensiveIntegrationVerification() async throws {
        var expectations = MockTestRealWorldService.Expectations()

        when(expectations.authenticate(username: .any, password: .any), times: .unbounded, return: "token")
        when(expectations.fetchUserProfile(userId: .any), times: .unbounded, return: ["name": "User"])
        when(expectations.updateUserSettings(userId: .any, settings: .any), times: .unbounded, complete: .withSuccess)
        when(expectations.uploadFile(data: .any, filename: .any, metadata: .any), times: .unbounded, return: "file")
        when(expectations.downloadFile(fileId: .any), times: .unbounded, return: Data())
        when(expectations.isAuthenticated.get(), times: .unbounded, return: true)
        when(expectations.currentUserId.get(), times: .unbounded, return: "currentUserId")
        when(expectations.apiBaseUrl.get(), times: .unbounded, return: "https://api.example.com")

        let mock = MockTestRealWorldService(expectations: expectations)

        // Execute comprehensive workflow
        _ = try await mock.authenticate(username: "user1", password: "pass1")
        _ = try await mock.authenticate(username: "user2", password: "pass2")

        _ = try await mock.fetchUserProfile(userId: "userId1")
        _ = try await mock.fetchUserProfile(userId: "userId2")
        _ = try await mock.fetchUserProfile(userId: "userId3")

        try await mock.updateUserSettings(userId: "userId4", settings: ["s1": "v1"])
        try await mock.updateUserSettings(userId: "userId5", settings: ["s2": "v2"])

        _ = try await mock.uploadFile(data: Data([1]), filename: "f1", metadata: nil)
        _ = try await mock.downloadFile(fileId: "fileId")

        _ = await mock.isAuthenticated
        _ = await mock.currentUserId
        _ = try mock.apiBaseUrl

        // Comprehensive verification
        verify(mock, times: 2).authenticate(username: .any, password: .any)
        verify(mock, times: 3).fetchUserProfile(userId: .any)
        verify(mock, times: 2).updateUserSettings(userId: .any, settings: .any)
        verify(mock, times: 1).uploadFile(data: .any, filename: .any, metadata: .any)
        verify(mock, times: 1).downloadFile(fileId: .any)
        verify(mock, times: 1).isAuthenticated.get()
        verify(mock, times: 1).currentUserId.get()
        verify(mock, times: 1).apiBaseUrl.get()

        // Specific parameter verification
        verify(mock, times: 1).authenticate(username: "user1", password: "pass1")
        verify(mock, times: 2).updateUserSettings(userId: .any, settings: .any)
        verify(mock, times: 1).uploadFile(data: .any, filename: "f1", metadata: .any)
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testMixedFunctionAndPropertyVerificationFailures() async {
        expectVerificationFailures(messages: [
            "Expected syncFunction(id: any) to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockTestIntegrationService.Expectations()
            when(expectations.syncProperty.get(), return: "initial")
            when(expectations.syncFunction(id: .any), return: "sync result")

            let mock = MockTestIntegrationService(expectations: expectations)

            // Execute once but verify twice - should fail
            _ = mock.syncProperty
            _ = mock.syncFunction(id: "test")

            verify(mock, times: 2).syncFunction(id: .any)
        }
    }

    @Test
    func testComplexParameterVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected complexFunction(name: any, count: any, enabled: any, data: any, items: any, config: any, sendable: any) to never be called, but was called 1 time"
        ]) {
            var expectations = MockTestIntegrationService.Expectations()
            when(
                expectations.complexFunction(
                    name: .any,
                    count: .any,
                    enabled: .any,
                    data: .any,
                    items: .any,
                    config: .any,
                    sendable: .any
                ),
                return: "result"
            )

            let mock = MockTestIntegrationService(expectations: expectations)

            // Call it but verify never called - should fail
            _ = try await mock.complexFunction(
                name: "test",
                count: 1,
                enabled: true,
                data: Data(),
                items: ["item"],
                config: ["key": "value"],
                sendable: "sendable"
            )

            verify(mock, .never).complexFunction(
                name: .any,
                count: .any,
                enabled: .any,
                data: .any,
                items: .any,
                config: .any,
                sendable: .any
            )
        }
    }

    @Test
    func testRealWorldServiceVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected authenticate(username: any, password: any) to be called at least 3 times, but was called 1 time"
        ]) {
            var expectations = MockTestRealWorldService.Expectations()
            when(expectations.authenticate(username: .any, password: .any), return: "token")
            when(expectations.fetchUserProfile(userId: .any), return: ["name": "test"])

            let mock = MockTestRealWorldService(expectations: expectations)

            // Call twice but verify at least 3 times - should fail
            _ = try await mock.authenticate(username: "user", password: "pass")
            _ = try await mock.fetchUserProfile(userId: "123")

            verify(mock, atLeast: 3).authenticate(username: .any, password: .any)
        }
    }

    @Test
    func testMixedAsyncThrowingVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected asyncThrowingFunction(id: any) to be called exactly 3 times, but was called 1 time",
            "Expected asyncThrowingProperty.get() to never be called, but was called 1 time",
        ]) {
            var expectations = MockTestIntegrationService.Expectations()
            when(expectations.asyncThrowingFunction(id: .any), times: .unbounded, return: "result")
            when(expectations.asyncThrowingProperty.get(), return: "property")

            let mock = MockTestIntegrationService(expectations: expectations)

            // Call once each
            _ = try await mock.asyncThrowingFunction(id: "test")
            _ = try await mock.asyncThrowingProperty

            // Two failing verifications
            verify(mock, times: 3).asyncThrowingFunction(id: .any)  // Fail 1
            verify(mock, .never).asyncThrowingProperty.get()  // Fail 2
        }
    }

    @Test
    func testRealWorldPropertyVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected isAuthenticated.get() to be called at most 1 time, but was called 2 times"
        ]) {
            var expectations = MockTestRealWorldService.Expectations()
            when(expectations.isAuthenticated.get(), times: 2, return: true)
            when(expectations.currentUserId.get(), return: "user123")

            let mock = MockTestRealWorldService(expectations: expectations)

            // Access properties multiple times but verify at most 1 - should fail
            _ = await mock.isAuthenticated
            _ = await mock.isAuthenticated
            _ = await mock.currentUserId

            verify(mock, atMost: 1).isAuthenticated.get()
        }
    }

    @Test
    func testFileOperationVerificationFailures() async throws {
        try await expectVerificationFailures(messages: []) {
            var expectations = MockTestRealWorldService.Expectations()
            when(
                expectations.uploadFile(data: .any, filename: .any, metadata: .any),
                times: .unbounded,
                return: "file123"
            )
            when(expectations.downloadFile(fileId: .any), times: .unbounded, return: Data())

            let mock = MockTestRealWorldService(expectations: expectations)

            // Call 4 times but verify range 1...2 - should fail
            _ = try await mock.uploadFile(data: Data(), filename: "f1", metadata: nil)
            _ = try await mock.uploadFile(data: Data(), filename: "f2", metadata: nil)
            _ = try await mock.downloadFile(fileId: "123")
            _ = try await mock.downloadFile(fileId: "456")

            verify(mock, times: 1...2).uploadFile(data: .any, filename: .any, metadata: .any)
        }
    }

    @Test
    func testThrowingPropertyIntegrationFailures() {
        expectVerificationFailures(messages: [
            "Expected apiBaseUrl.get() to be called at least once, but was never called"
        ]) {
            var expectations = MockTestRealWorldService.Expectations()
            when(expectations.apiBaseUrl.get(), return: "https://api.test.com")

            let mock = MockTestRealWorldService(expectations: expectations)

            // Don't access but verify at least once - should fail
            verify(mock, .atLeastOnce).apiBaseUrl.get()
        }
    }

    @Test
    func testErrorHandlingVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected authenticate(username: \"bad\", password: any) to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockTestRealWorldService.Expectations()
            when(
                expectations.authenticate(username: "bad", password: .any),
                throw: IntegrationError.authenticationFailed
            )
            when(expectations.fetchUserProfile(userId: .any), throw: IntegrationError.userNotFound)

            let mock = MockTestRealWorldService(expectations: expectations)

            // Call once but verify twice - should fail
            do {
                _ = try await mock.authenticate(username: "bad", password: "wrong")
            } catch {
                // Expected to throw
            }

            verify(mock, times: 2).authenticate(username: "bad", password: .any)
        }
    }

    @Test
    func testComplexWorkflowVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected authenticate(username: any, password: any) to be called exactly 2 times, but was called 1 time",
            "Expected currentUserId.get() to be called at least once, but was never called",
            "Expected isAuthenticated.get() to never be called, but was called 1 time",
        ]) {
            var expectations = MockTestRealWorldService.Expectations()
            when(expectations.authenticate(username: .any, password: .any), return: "token")
            when(expectations.isAuthenticated.get(), return: true)
            when(expectations.currentUserId.get(), return: "user123")
            when(expectations.fetchUserProfile(userId: .any), return: ["name": "test"])

            let mock = MockTestRealWorldService(expectations: expectations)

            // Execute partial workflow
            _ = try await mock.authenticate(username: "user", password: "pass")
            _ = await mock.isAuthenticated

            // Three failing verifications
            verify(mock, times: 2).authenticate(username: .any, password: .any)  // Fail 1
            verify(mock, .atLeastOnce).currentUserId.get()  // Fail 2
            verify(mock, .never).isAuthenticated.get()  // Fail 3
        }
    }
    #endif
}
