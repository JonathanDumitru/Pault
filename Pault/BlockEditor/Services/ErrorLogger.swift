//
//  ErrorLogger.swift
//  Pault
//
//  Error logging service with file rotation (from Schemap)
//

import Foundation
import OSLog

/// Service for logging errors to file with rotation
final class ErrorLogger {
    static let shared = ErrorLogger()

    private let logger = Logger(subsystem: "com.pault.app", category: "Error")
    private let logDirectory: URL
    private let maxLogFiles = 10
    private let maxLogSize: Int64 = 1_000_000 // 1MB per file

    private init() {
        // Create log directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("Pault/Logs", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // Rotate logs on init
        rotateLogsIfNeeded()
    }

    /// Log an error with context
    func logError(_ error: Error, context: String = "", userInfo: [String: Any] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var logMessage = "[\(timestamp)] ERROR"
        if !context.isEmpty {
            logMessage += " [\(context)]"
        }
        logMessage += ": \(error.localizedDescription)\n"

        if let nsError = error as NSError? {
            logMessage += "Domain: \(nsError.domain)\n"
            logMessage += "Code: \(nsError.code)\n"
            if !nsError.userInfo.isEmpty {
                logMessage += "UserInfo: \(nsError.userInfo)\n"
            }
        }

        if !userInfo.isEmpty {
            logMessage += "Context: \(userInfo)\n"
        }

        // Log to system logger
        logger.error("\(logMessage)")

        // Write to file
        writeToFile(logMessage)
    }

    /// Log a message (non-error)
    func logMessage(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(level.rawValue.uppercased()): \(message)\n"

        switch level {
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }

        writeToFile(logMessage)
    }

    /// Write message to current log file
    private func writeToFile(_ message: String) {
        let logFile = currentLogFile()

        if let data = message.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFile)
            }

            // Check if we need to rotate
            if let attributes = try? FileManager.default.attributesOfItem(atPath: logFile.path),
               let fileSize = attributes[.size] as? Int64,
               fileSize > maxLogSize {
                rotateLogs()
            }
        }
    }

    /// Get current log file path
    private func currentLogFile() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return logDirectory.appendingPathComponent("pault-\(dateString).log")
    }

    /// Rotate logs if needed
    private func rotateLogsIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        let logFiles = files.filter { $0.pathExtension == "log" }
        if logFiles.count > maxLogFiles {
            rotateLogs()
        }
    }

    /// Rotate logs: keep only the most recent files
    private func rotateLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        let logFiles = files.filter { $0.pathExtension == "log" }
        let sortedFiles = logFiles.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }

        // Delete oldest files beyond maxLogFiles
        for file in sortedFiles.dropFirst(maxLogFiles) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Get recent log entries for debugging
    func getRecentLogs(limit: Int = 100) -> [String] {
        let logFile = currentLogFile()
        guard let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        return Array(lines.suffix(limit))
    }
}

enum LogLevel: String {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
