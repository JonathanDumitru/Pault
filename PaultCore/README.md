# PaultCore

Shared framework scaffolding for Pault prompt management applications.

## Overview
PaultCore currently provides SwiftData model definitions for prompts, categories, tags, versions, workflows, variables, and usage logs. Service layers and utilities referenced in earlier drafts are not present in the codebase yet.

## Architecture

```
PaultCore/
├── Models/          # SwiftData model definitions
└── PaultCore.swift  # Module entry point
```

## Usage

Import PaultCore in your SwiftUI app:

```swift
import PaultCore
```

## Requirements

- macOS 14.0+ / iOS 17.0+
- Swift 5.9+
