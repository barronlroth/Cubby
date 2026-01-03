import CloudKit
import Testing
@testable import Cubby

struct CloudKitAvailabilityTests {
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
}
