//
//  CrashReportingService.swift
//  Pault
//
//  Installs uncaught exception and fatal signal handlers that write structured
//  crash logs to ~/Library/Logs/Pault/ before the process exits. On the next
//  launch, PaultApp reads any pending crash report and offers the user an
//  opt-in "Send Diagnostic Report" sheet.
//
//  No external dependencies. App Store safe.
//

import Foundation
import os

private let crashLogger = Logger(subsystem: "com.pault.app", category: "CrashReporting")

// MARK: - Top-level handlers (must be outside the enum to work as C function pointers)

private func uncaughtExceptionHandler(_ exception: NSException) {
    let report = CrashReportingService.buildExceptionReport(exception)
    CrashReportingService.writeCrashReport(report)
}

private func signalHandler(_ receivedSignal: Int32) {
    let sigName = CrashReportingService.signalName(receivedSignal)
    let report = CrashReportingService.buildSignalReport(sigName)
    CrashReportingService.writeCrashReport(report)
    // Restore default handler and re-raise so the OS gets a proper exit code
    signal(receivedSignal, SIG_DFL)
    raise(receivedSignal)
}

// MARK: - CrashReportingService

enum CrashReportingService {

    // MARK: Public API

    /// Install exception + signal handlers. Call once from PaultApp.init().
    static func install() {
        createLogsDirectoryIfNeeded()
        installExceptionHandler()
        installSignalHandlers()
        crashLogger.info("Crash reporting installed")
    }

    /// Returns the URL of a pending crash report written in a prior session,
    /// or nil if no report exists. Call on launch to decide whether to prompt.
    static func pendingCrashReport() -> URL? {
        guard let url = latestCrashLogURL(), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Deletes the pending crash report after the user has acted on it.
    static func clearPendingCrashReport() {
        guard let url = latestCrashLogURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Reads the pending crash report contents as a plain string.
    static func pendingCrashReportText() -> String? {
        guard let url = pendingCrashReport() else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: Paths

    static var logsDirectory: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Logs/Pault", isDirectory: true)
    }

    private static func latestCrashLogURL() -> URL? {
        logsDirectory.appendingPathComponent("crash-pending.log")
    }

    // MARK: Setup

    private static func createLogsDirectoryIfNeeded() {
        let dir = logsDirectory
        guard !FileManager.default.fileExists(atPath: dir.path) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: Exception Handler

    private static func installExceptionHandler() {
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
    }

    fileprivate static func buildExceptionReport(_ exception: NSException) -> String {
        var lines: [String] = []
        lines.append("=== Pault Crash Report ===")
        lines.append("Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        lines.append("Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("")
        lines.append("Type: UncaughtException")
        lines.append("Name: \(exception.name.rawValue)")
        lines.append("Reason: \(exception.reason ?? "(none)")")
        lines.append("")
        lines.append("Call Stack:")
        lines.append(contentsOf: exception.callStackSymbols)
        return lines.joined(separator: "\n")
    }

    // MARK: Signal Handlers

    /// Signal numbers to intercept (fatal signals only).
    private static let fatalSignals: [Int32] = [SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGTRAP]

    private static func installSignalHandlers() {
        for sig in fatalSignals {
            signal(sig, signalHandler)
        }
    }

    fileprivate static func buildSignalReport(_ signalName: String) -> String {
        var lines: [String] = []
        lines.append("=== Pault Crash Report ===")
        lines.append("Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        lines.append("Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("")
        lines.append("Type: FatalSignal")
        lines.append("Signal: \(signalName)")
        lines.append("")
        lines.append("Thread Backtrace:")
        Thread.callStackSymbols.forEach { lines.append($0) }
        return lines.joined(separator: "\n")
    }

    // MARK: Writing

    /// Must be async-signal-safe in signal context — uses low-level write().
    fileprivate static func writeCrashReport(_ report: String) {
        guard let url = latestCrashLogURL() else { return }
        // In a signal handler we cannot use Foundation file APIs safely;
        // write via C open/write/close instead.
        let path = url.path
        let data = report.utf8CString
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        data.withUnsafeBufferPointer { ptr in
            _ = write(fd, ptr.baseAddress, ptr.count - 1) // exclude NUL terminator
        }
        close(fd)
    }

    // MARK: Helpers

    fileprivate static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGSEGV: return "SIGSEGV (Segmentation Fault)"
        case SIGABRT: return "SIGABRT (Abort)"
        case SIGBUS:  return "SIGBUS (Bus Error)"
        case SIGILL:  return "SIGILL (Illegal Instruction)"
        case SIGTRAP: return "SIGTRAP (Trap)"
        default:      return "SIG\(sig)"
        }
    }
}
