//
//  AttachmentManagerFileTests.swift
//  PaultTests
//

import Testing
import Foundation
import AppKit
@testable import Pault

struct AttachmentManagerFileTests {

    private func createTempImage() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaultTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let imageURL = tempDir.appendingPathComponent("test.png")
        let pngData = createMinimalPNG()
        try pngData.write(to: imageURL)

        return imageURL
    }

    private func createMinimalPNG() -> Data {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:])
        else {
            return Data()
        }
        return pngData
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - storeFile (embedded)

    @Test func storeFileEmbeddedCopiesFile() throws {
        let imageURL = try createTempImage()
        defer { cleanup(imageURL) }

        let promptID = UUID()
        let attachment = try AttachmentManager.storeFile(at: imageURL, for: promptID)

        #expect(attachment.storageMode == "embedded")
        #expect(attachment.filename == "test.png")
        #expect(attachment.fileSize > 0)
        #expect(attachment.relativePath != nil)

        // Verify file was actually copied
        guard let relativePath = attachment.relativePath else {
            Issue.record("relativePath is nil")
            return
        }
        let copiedURL = AttachmentManager.attachmentsBaseDirectory
            .appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: copiedURL.path))

        // Cleanup
        AttachmentManager.deleteFiles(for: promptID)
    }

    // MARK: - resolveURL

    @Test func resolveURLReturnsPathForEmbedded() throws {
        let imageURL = try createTempImage()
        defer { cleanup(imageURL) }

        let promptID = UUID()
        let attachment = try AttachmentManager.storeFile(at: imageURL, for: promptID)

        let resolved = AttachmentManager.resolveURL(for: attachment)
        #expect(resolved != nil)
        #expect(FileManager.default.fileExists(atPath: resolved!.path))

        AttachmentManager.deleteFiles(for: promptID)
    }

    @Test func resolveURLReturnsNilForReferencedAttachment() throws {
        let attachment = Attachment(
            filename: "test.txt",
            mediaType: "public.plain-text",
            fileSize: 100,
            storageMode: "referenced",
            bookmarkData: nil
        )

        let resolved = AttachmentManager.resolveURL(for: attachment)
        #expect(resolved == nil)
    }

    // MARK: - deleteFiles

    @Test func deleteFilesRemovesPromptDirectory() throws {
        let imageURL = try createTempImage()
        defer { cleanup(imageURL) }

        let promptID = UUID()
        _ = try AttachmentManager.storeFile(at: imageURL, for: promptID)

        let dir = AttachmentManager.directory(for: promptID)
        #expect(FileManager.default.fileExists(atPath: dir.path))

        AttachmentManager.deleteFiles(for: promptID)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test func deleteFilesNoopForMissingDirectory() {
        let fakeID = UUID()
        AttachmentManager.deleteFiles(for: fakeID)
        // If we reach here without crashing, the test passes
    }

    // MARK: - generateThumbnail

    @Test func generateThumbnailProducesData() throws {
        let imageURL = try createTempImage()
        defer { cleanup(imageURL) }

        let data = AttachmentManager.generateThumbnail(for: imageURL)
        #expect(data != nil)
        #expect((data?.count ?? 0) > 0)
    }

    @Test func generateThumbnailReturnsNilForNonImage() {
        let textURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).txt")
        try? "hello".write(to: textURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: textURL) }

        let data = AttachmentManager.generateThumbnail(for: textURL)
        #expect(data == nil)
    }

    // MARK: - isImage

    @Test func isImageRecognizesWebP() {
        #expect(AttachmentManager.isImage("org.webmproject.webp") == true)
    }

    @Test func isImageRejectsPDF() {
        #expect(AttachmentManager.isImage("com.adobe.pdf") == false)
    }
}
