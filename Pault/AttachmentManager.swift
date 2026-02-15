//
//  AttachmentManager.swift
//  Pault
//

import AppKit
import Foundation
import os
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "com.pault.app", category: "AttachmentManager")

enum AttachmentManager {

    static let embeddedSizeThreshold: Int64 = 10 * 1024 * 1024

    static var attachmentsBaseDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Pault/Attachments", isDirectory: true)
    }

    static func directory(for promptID: UUID) -> URL {
        attachmentsBaseDirectory.appendingPathComponent(promptID.uuidString, isDirectory: true)
    }

    // MARK: - Storage

    /// Store a file for a prompt. Returns a configured `Attachment` that has not been inserted into a model context.
    static func storeFile(at sourceURL: URL, for promptID: UUID) throws -> Attachment {
        let filename = sourceURL.lastPathComponent
        let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = Int64(attrs[.size] as? UInt64 ?? 0)
        let mediaType = UTType(filenameExtension: sourceURL.pathExtension)?.identifier ?? "public.data"

        if fileSize <= embeddedSizeThreshold {
            return try storeEmbedded(
                sourceURL: sourceURL,
                promptID: promptID,
                filename: filename,
                mediaType: mediaType,
                fileSize: fileSize
            )
        } else {
            return try storeReferenced(
                sourceURL: sourceURL,
                filename: filename,
                mediaType: mediaType,
                fileSize: fileSize
            )
        }
    }

    private static func storeEmbedded(
        sourceURL: URL,
        promptID: UUID,
        filename: String,
        mediaType: String,
        fileSize: Int64
    ) throws -> Attachment {
        let destDir = directory(for: promptID)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let attachmentID = UUID()
        let ext = sourceURL.pathExtension
        let destURL = destDir.appendingPathComponent("\(attachmentID.uuidString).\(ext)")
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        logger.info("Embedded file: \(filename) (\(fileSize) bytes)")

        let relativePath = "\(promptID.uuidString)/\(attachmentID.uuidString).\(ext)"
        return Attachment(
            id: attachmentID,
            filename: filename,
            mediaType: mediaType,
            fileSize: fileSize,
            storageMode: "embedded",
            relativePath: relativePath
        )
    }

    private static func storeReferenced(
        sourceURL: URL,
        filename: String,
        mediaType: String,
        fileSize: Int64
    ) throws -> Attachment {
        let bookmarkData = try sourceURL.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        logger.info("Referenced file: \(filename) (\(fileSize) bytes)")

        return Attachment(
            filename: filename,
            mediaType: mediaType,
            fileSize: fileSize,
            storageMode: "referenced",
            bookmarkData: bookmarkData
        )
    }

    // MARK: - Resolution

    /// Resolve the on-disk URL for an attachment.
    static func resolveURL(for attachment: Attachment) -> URL? {
        switch attachment.storageMode {
        case "embedded":
            guard let relativePath = attachment.relativePath else { return nil }
            return attachmentsBaseDirectory.appendingPathComponent(relativePath)

        case "referenced":
            guard let bookmarkData = attachment.bookmarkData else { return nil }
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return nil
            }
            if isStale {
                logger.warning("Stale bookmark for: \(attachment.filename)")
            }
            _ = url.startAccessingSecurityScopedResource()
            return url

        default:
            return nil
        }
    }

    // MARK: - Deletion

    /// Delete all embedded files for a prompt from disk.
    static func deleteFiles(for promptID: UUID) {
        let dir = directory(for: promptID)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Delete a single embedded attachment file from disk.
    static func deleteFile(for attachment: Attachment) {
        guard attachment.storageMode == "embedded",
              let relativePath = attachment.relativePath
        else { return }

        let url = attachmentsBaseDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Thumbnails

    /// Generate a JPEG thumbnail for an image file.
    static func generateThumbnail(for url: URL, maxSize: CGFloat = 120) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumbnail.unlockFocus()

        guard let tiffData = thumbnail.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData)
        else { return nil }

        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }

    // MARK: - Type Checks

    /// Check if a UTI represents an image type.
    static func isImage(_ mediaType: String) -> Bool {
        guard let uti = UTType(mediaType) else { return false }
        return uti.conforms(to: .image)
    }
}
