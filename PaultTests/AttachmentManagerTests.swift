//
//  AttachmentManagerTests.swift
//  PaultTests
//

import Testing
import Foundation
@testable import Pault

struct AttachmentManagerTests {

    @Test func attachmentsDirectoryPath() async throws {
        let dir = AttachmentManager.attachmentsBaseDirectory
        #expect(dir.lastPathComponent == "Attachments")
        #expect(dir.pathComponents.contains("Pault"))
    }

    @Test func promptDirectoryUsesPromptID() async throws {
        let id = UUID()
        let dir = AttachmentManager.directory(for: id)
        #expect(dir.lastPathComponent == id.uuidString)
    }

    @Test func sizeThresholdIs10MB() async throws {
        #expect(AttachmentManager.embeddedSizeThreshold == 10 * 1024 * 1024)
    }

    @Test func isImageRecognizesCommonTypes() async throws {
        #expect(AttachmentManager.isImage("public.jpeg") == true)
        #expect(AttachmentManager.isImage("public.png") == true)
        #expect(AttachmentManager.isImage("public.heic") == true)
        #expect(AttachmentManager.isImage("public.mp3") == false)
        #expect(AttachmentManager.isImage("public.data") == false)
    }
}
