import Foundation

/// Utility for reporting progress to stderr
enum ProgressReporter {
    static func success(_ message: String) {
        fputs("✅ \(message)\n", stderr)
    }
    
    static func error(_ message: String) {
        fputs("❌ \(message)\n", stderr)
    }
    
    static func info(_ message: String) {
        fputs("ℹ️  \(message)\n", stderr)
    }
    
    static func warning(_ message: String) {
        fputs("⚠️  \(message)\n", stderr)
    }
    
    static func message(_ message: String) {
        fputs("\(message)\n", stderr)
    }
    
    static func section(_ title: String) {
        fputs("\n\(title)\n", stderr)
    }
}
