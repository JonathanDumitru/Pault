//
//  AttachmentTests.swift
//  PaultTests
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//

import Testing
import SwiftData
@testable import Pault

private typealias FileAttachment = Pault.Attachment

struct AttachmentTests {

    @Test func attachmentInitDefaults() async throws {
        let attachment = FileAttachment(filename: "photo.jpg", mediaType: "public.jpeg", fileSize: 1024)
        #expect(attachment.filename == "photo.jpg")
        #expect(attachment.mediaType == "public.jpeg")
        #expect(attachment.fileSize == 1024)
        #expect(attachment.storageMode == "embedded")
        #expect(attachment.relativePath == nil)
        #expect(attachment.bookmarkData == nil)
        #expect(attachment.thumbnailData == nil)
        #expect(attachment.sortOrder == 0)
    }

    @Test func promptStartsWithNoAttachments() async throws {
        let prompt = Prompt(title: "Test", content: "Content")
        #expect(prompt.attachments.isEmpty)
    }

    @Test func cascadeDeleteRemovesAttachments() async throws {
        let container = try ModelContainer(
            for: Prompt.self, FileAttachment.self, Tag.self, TemplateVariable.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let prompt = Prompt(title: "Test", content: "Content")
        context.insert(prompt)

        let attachment = FileAttachment(filename: "test.png", mediaType: "public.png", fileSize: 512)
        context.insert(attachment)
        prompt.attachments = [attachment]
        try context.save()

        context.delete(prompt)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<FileAttachment>())
        #expect(remaining.isEmpty)
    }
}
