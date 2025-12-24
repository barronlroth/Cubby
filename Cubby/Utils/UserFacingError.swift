import Foundation

struct UserFacingError {
    let title: String
    let message: String

    static func persistence(action: String, error: Error) -> UserFacingError {
        let message = (error as NSError).localizedDescription
        return UserFacingError(title: "Couldn’t \(action)", message: message)
    }
}

