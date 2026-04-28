# Privacy Policy for Pault

Last updated: 2026-04-27

## Overview

Pault is a macOS app for saving, organizing, and reusing prompts. This policy explains what data Pault handles and how that data is used.

## Data We Collect

Pault is designed to run locally on your Mac. We do not operate a hosted user account system for Pault and we do not require sign-in to use core features.

Data you create in the app may include:
- Prompt titles and prompt content.
- Rich-text content, template variables, tags, favorites, archive state, and timestamps.
- Attachments and attachment metadata.
- Prompt versions, prompt runs, copy-history events, templates, smart collections, custom blocks, and local app preferences.

Data you enter in Settings may also include AI provider API keys, which are stored in your macOS Keychain rather than in the main app data store.

## How Data Is Stored

Prompt library data is stored on-device using local app storage on macOS. Data remains under your control on your machine unless you choose to share or back it up through your own tools.

## Permissions and System Access

Pault currently relies on standard macOS system services for:
- Clipboard writes when you copy prompt content.
- User-approved file access through open/save panels and drag-and-drop.
- Outbound network requests when you use optional AI provider features.
- Keychain access for storing AI provider API keys.

The current copy workflow does not rely on Accessibility-driven paste automation.

## AI Proxy Service

When you use AI Assist or API Runner features, prompt text is transmitted over an encrypted HTTPS connection to an AI proxy service operated by Pault. The proxy forwards your prompt to a third-party AI provider (such as Anthropic Claude or OpenAI) on your behalf. Pault's proxy does not store prompt content or AI responses server-side. Requests are authenticated using your active Pault Pro subscription via StoreKit subscription verification.

By using AI features, you acknowledge that your prompt content will be transmitted to the applicable third-party AI provider and processed under that provider's terms of service and privacy policy.

### Bring Your Own Key (BYOK)

Pault Pro users may optionally configure their own AI provider API keys in Settings. These keys are stored exclusively in your macOS Keychain and are never transmitted to or stored by Pault's servers. When BYOK mode is active, Pault routes your request directly to the AI provider using your key; the Pault proxy is bypassed. You are solely responsible for your own API key usage, including associated costs and compliance with the third-party provider's terms of service.

## App Store Privacy Labels

For transparency, the following data type classifications apply to Pault's App Store privacy nutrition label:

| Data Type | Linked to Identity | Used for Tracking | Purpose |
|-----------|-------------------|-------------------|---------|
| Other User Content (prompt text transmitted to AI proxy) | No | No | App Functionality |
| Other Data Types (local app data) | No | No | App Functionality |

## Data Sharing

We do not sell personal information. We do not share your prompt library data with third parties for advertising.

## Data Retention

Because Pault stores data locally, retention is controlled by you. You can edit, archive, or delete your prompts at any time.

## Children's Privacy

Pault is not directed to children under 13, and we do not knowingly collect personal information from children.

## Changes to This Policy

We may update this policy from time to time. If material changes are made, we will update the "Last updated" date on this page.

## Contact

For privacy questions: privacy@pault.app

For support: support@pault.app

For general inquiries: hello@pault.app
