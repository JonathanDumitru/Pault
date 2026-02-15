//
//  Attachment.swift
//  Pault
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//

import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID
    var filename: String
    var mediaType: String
    var fileSize: Int64
    var storageMode: String
    var relativePath: String?
    var bookmarkData: Data?
    var thumbnailData: Data?
    var sortOrder: Int
    var createdAt: Date
    @Relationship var prompt: Prompt?

    init(
        id: UUID = UUID(),
        filename: String,
        mediaType: String,
        fileSize: Int64,
        storageMode: String = "embedded",
        relativePath: String? = nil,
        bookmarkData: Data? = nil,
        thumbnailData: Data? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.storageMode = storageMode
        self.relativePath = relativePath
        self.bookmarkData = bookmarkData
        self.thumbnailData = thumbnailData
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
