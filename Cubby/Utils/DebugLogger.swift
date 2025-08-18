import Foundation
import os

struct DebugLogger {
    private static let subsystem = "com.barronroth.Cubby"
    private static let logger = Logger(subsystem: subsystem, category: "Debug")
    
    static func log(_ message: String, type: OSLogType = .debug) {
        logger.log(level: type, "\(message, privacy: .public)")
        #if DEBUG
        print(message)
        #endif
    }
    
    static func error(_ message: String) {
        logger.error("❌ \(message, privacy: .public)")
        #if DEBUG
        print("❌ \(message)")
        #endif
    }
    
    static func warning(_ message: String) {
        logger.warning("⚠️ \(message, privacy: .public)")
        #if DEBUG
        print("⚠️ \(message)")
        #endif
    }
    
    static func success(_ message: String) {
        logger.info("✅ \(message, privacy: .public)")
        #if DEBUG
        print("✅ \(message)")
        #endif
    }
    
    static func info(_ message: String) {
        logger.info("🔍 \(message, privacy: .public)")
        #if DEBUG
        print("🔍 \(message)")
        #endif
    }
}