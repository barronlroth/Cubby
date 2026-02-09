import CloudKit
import Testing
@testable import Cubby

struct CloudKitAvailabilityTests {
    final class CallCountingProvider: CloudKitAccountStatusProviding {
        var callCount = 0
        let result: Result<CKAccountStatus, Error>

        init(result: Result<CKAccountStatus, Error>) {
            self.result = result
        }

        func accountStatus() async throws -> CKAccountStatus {
            callCount += 1
            return try result.get()
        }
    }

    struct StubAccountStatusProvider: CloudKitAccountStatusProviding {
        let result: Result<CKAccountStatus, Error>

        func accountStatus() async throws -> CKAccountStatus {
            try result.get()
        }
    }

    enum StubError: Error {
        case example
    }

    @Test func testAvailabilityWhenAccountAvailable() async {
        let provider = StubAccountStatusProvider(result: .success(.available))
        let availability = await CloudKitAvailabilityChecker.check(using: provider)

        #expect(availability == .available)
        #expect(availability.isAvailable == true)
    }

    @Test func testAvailabilityWhenNoAccount() async {
        let provider = StubAccountStatusProvider(result: .success(.noAccount))
        let availability = await CloudKitAvailabilityChecker.check(using: provider)

        #expect(availability == .unavailable(reason: .noAccount))
        #expect(availability.isAvailable == false)
    }

    @Test func testAvailabilityWhenRestricted() async {
        let provider = StubAccountStatusProvider(result: .success(.restricted))
        let availability = await CloudKitAvailabilityChecker.check(using: provider)

        #expect(availability == .unavailable(reason: .restricted))
        #expect(availability.isAvailable == false)
    }

    @Test func testAvailabilityWhenStatusUnknown() async {
        let provider = StubAccountStatusProvider(result: .success(.couldNotDetermine))
        let availability = await CloudKitAvailabilityChecker.check(using: provider)

        #expect(availability == .unavailable(reason: .couldNotDetermine))
        #expect(availability.isAvailable == false)
    }

    @Test func testAvailabilityWhenTemporarilyUnavailable() async {
        let provider = StubAccountStatusProvider(result: .success(.temporarilyUnavailable))
        let availability = await CloudKitAvailabilityChecker.check(using: provider)

        #expect(availability == .unavailable(reason: .temporarilyUnavailable))
        #expect(availability.isAvailable == false)
    }

    @Test func testAvailabilityWhenErrorOccurs() async {
        let provider = StubAccountStatusProvider(result: .failure(StubError.example))
        let availability = await CloudKitAvailabilityChecker.check(using: provider)

        #expect(availability == .unavailable(reason: .error))
        #expect(availability.isAvailable == false)
    }

    @Test func testDefaultProviderUsesExplicitContainerIdentifier() {
        let provider = CloudKitAccountStatusProvider()
        #expect(provider.container.containerIdentifier == CloudKitSyncSettings.containerIdentifier)
    }

    @Test func testForcedAvailabilityBypassesProvider() async {
        let provider = CallCountingProvider(result: .success(.available))
        let availability = await CloudKitAvailabilityChecker.check(
            forcedAvailability: .noAccount,
            using: provider
        )

        #expect(availability == .unavailable(reason: .noAccount))
        #expect(provider.callCount == 0)
    }

    @Test func testForcedAvailabilityAvailableMapping() async {
        let provider = StubAccountStatusProvider(result: .success(.noAccount))
        let availability = await CloudKitAvailabilityChecker.check(
            forcedAvailability: .available,
            using: provider
        )

        #expect(availability == .available)
    }

    @Test func testForcedAvailabilityErrorMapping() async {
        let provider = StubAccountStatusProvider(result: .success(.available))
        let availability = await CloudKitAvailabilityChecker.check(
            forcedAvailability: .error,
            using: provider
        )

        #expect(availability == .unavailable(reason: .error))
    }
}
