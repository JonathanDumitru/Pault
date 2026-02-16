//
//  EditPromptView.swift
//  Pault
//
//  Wrapper view for the edit prompt window. Receives a Prompt.ID
//  via openWindow(value:), fetches the prompt from SwiftData,
//  and renders the existing PromptDetailView for editing.
//

import SwiftUI
import SwiftData

struct EditPromptView: View {
    let promptID: Prompt.ID

    @State private var showInspector: Bool = false
    @Query private var matchingPrompts: [Prompt]

    init(promptID: Prompt.ID) {
        self.promptID = promptID
        _matchingPrompts = Query(
            filter: #Predicate<Prompt> { $0.id == promptID }
        )
    }

    var body: some View {
        if let prompt = matchingPrompts.first {
            PromptDetailView(prompt: prompt, showInspector: $showInspector)
                .navigationTitle(prompt.title.isEmpty ? "Untitled" : prompt.title)
                .frame(minWidth: 600, minHeight: 500)
        } else {
            ContentUnavailableView(
                "Prompt Not Found",
                systemImage: "doc.questionmark",
                description: Text("This prompt may have been deleted.")
            )
            .frame(minWidth: 400, minHeight: 300)
        }
    }
}
