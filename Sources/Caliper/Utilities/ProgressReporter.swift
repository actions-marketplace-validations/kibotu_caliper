import Foundation

/// Utility for reporting progress to stderr
struct ProgressReporter {
    
    /// Report a success message
    static func success(_ message: String) {
        fputs("✅ \(message)\n", stderr)
    }
    
    /// Report an error message
    static func error(_ message: String) {
        fputs("❌ \(message)\n", stderr)
    }
    
    /// Report an info message
    static func info(_ message: String) {
        fputs("ℹ️  \(message)\n", stderr)
    }
    
    /// Report a warning message
    static func warning(_ message: String) {
        fputs("⚠️  \(message)\n", stderr)
    }
    
    /// Report a general message
    static func message(_ message: String) {
        fputs("\(message)\n", stderr)
    }
    
    /// Report a section separator
    static func section(_ title: String) {
        fputs("\n\(title)\n", stderr)
    }
}

