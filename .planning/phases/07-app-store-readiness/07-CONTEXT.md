# Phase 7: App Store Readiness - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Finalize everything needed for App Store submission: metadata, screenshots, signing verification, legal documents, privacy manifest updates, and distribution tooling. All technical compliance (sandbox, Hardened Runtime, privacy manifest base) was completed in Phase 1. This phase produces the remaining artifacts and verifies archive readiness without uploading to ASC.

</domain>

<decisions>
## Implementation Decisions

### Screenshot strategy
- Lead with Pro features: 1. AI Assist (streaming rewrite), 2. Block editor canvas, 3. API Runner, 4. Library split view, 5. Menu bar popover with desktop context, 6. Analytics dashboard
- Clean app-only screenshots — no device frames, no text overlays
- Light mode only
- Target resolution: 2560×1600
- Automated capture via XCUITest with realistic seed data (8-10 prompts, tags, versions, analytics events)
- No App Preview video for v1.0
- AI Assist hero shot shows the Improve tab mid-stream
- Library shot shows full split view (sidebar + list + detail)
- Menu bar shot shows popover floating above visible desktop

### Website & legal content
- Site built in Framer (outside codebase scope) — Phase 7 produces content only
- Legal docs live in docs/legal/ as source-of-truth Markdown
- Updated privacy policy: make AI proxy data handling explicit (prompts sent to external APIs via proxy, not stored server-side)
- New Terms of Service: subscription terms, AI acceptable use clause, BYOK API key liability clause
- Support page: mailto: link to support@pault.app
- Separate email addresses: privacy@pault.app (legal), support@pault.app (support), hello@pault.app (about/general)
- Domain registration (pault.app) handled separately by user before submission
- Privacy nutrition labels pre-documented for ASC copy-paste
- Fixed effective date on legal docs (set to actual launch date)

### Privacy & compliance updates
- Update PrivacyInfo.xcprivacy to add NSPrivacyCollectedDataTypeOtherUserContent for prompts sent to AI proxy
- Verify and update in-app links in AboutView.swift and PaywallView (URLs, emails match final site structure)
- Copyright string kept as-is: © 2025–2026

### Metadata & keywords
- Subtitle changed to: "AI Prompt Studio" (from "Local Prompt Library for macOS")
- Description rewritten to lead with Pro features (AI Assist, API Runner, versioning, analytics)
- Keywords optimized to fill 100 chars — add: llm, chatgpt, prompt engineering, workflow, developer, automation; drop: notes
- Promotional text highlights 7-day free trial: "Try Pault Pro free for 7 days — AI rewrites, prompt execution, version history, and analytics. Your prompts stay local."
- Primary category: Productivity; Secondary: Developer Tools
- Age rating: 4+
- Bundle identifier kept: Jonathan-Hines-Dumitru.Pault
- What's New text prepared for v1.0 release
- ASC questionnaire answers pre-documented (encryption: yes/HTTPS, IDFA: no, third-party content: no, content rights: yes)

### Distribution & signing
- Verify archive-ready only — do not upload to ASC
- Also prepare notarized DMG for direct distribution
- Branded DMG with custom background image + arrow to Applications
- Same sandbox entitlements for both App Store and DMG builds
- Single scripts/build-release.sh with --appstore and --dmg flags
- Notarization via xcrun notarytool with Apple ID + app-specific password (Keychain profile)
- Test suite runs as safety gate before archive step

### Claude's Discretion
- Exact XCUITest navigation and seed data implementation
- DMG background image design
- Keyword order and exact 100-char optimization
- Description copy and What's New text wording
- ASC questionnaire answer formatting
- Build script implementation details (error handling, logging, cleanup)

</decisions>

<specifics>
## Specific Ideas

- AI Assist screenshot should show mid-stream text appearing — the visual motion communicates "AI-powered" even in a static image
- Menu bar screenshot should show the popover floating above a real desktop — "works alongside other apps" narrative
- Promotional text leads with free trial to drive trial starts at launch
- Privacy policy must be explicit about BYOK model: Pault proxies user-provided API keys, never stores them server-side

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/app-store/app-store-connect.md`: Existing metadata draft to update (not rewrite from scratch)
- `docs/app-store/research/appstore-submission.md`: 469-line research doc with risk assessment and pre-submission checklist
- `docs/app-store/screenshot-capture.md`: Existing screenshot structure to update with new lineup
- `docs/app-store/dmg-installer.md`: DMG distribution docs already started
- `docs/legal/privacy-policy.md`: Existing privacy policy to update (not rewrite)
- `Pault/PrivacyInfo.xcprivacy`: Existing privacy manifest to update
- `Pault/AboutView.swift`: Contains in-app privacy link and contact email
- `Pault/Assets.xcassets/AppIcon.appiconset/`: Complete icon set (all macOS sizes)

### Established Patterns
- Automatic code signing with Team ID 93QQU293YD
- Hardened Runtime enabled for both Debug and Release
- Sandbox entitlements: app-sandbox, network.client, files.user-selected.read-write
- MARKETING_VERSION = 1.0, CURRENT_PROJECT_VERSION = 1

### Integration Points
- PaywallView references pault.app/privacy and pault.app/terms — must match deployed URLs
- AboutView references hello@pault.app — verify still correct
- ProStatusManager JWS token auth — relevant to privacy policy AI proxy disclosure
- StoreKit configuration file (Pault.storekit) — subscription product used in promo text

</code_context>

<deferred>
## Deferred Ideas

- Marketing landing page on pault.app — post-launch effort, not needed for ASC submission
- App Preview video — revisit post-launch based on conversion data
- Dark mode screenshot set — add later if conversion warrants
- Fastlane automation — evaluate if build frequency justifies the setup cost
- ASC API key for notarytool — switch from Apple ID auth if CI is set up later

</deferred>

---

*Phase: 07-app-store-readiness*
*Context gathered: 2026-04-18*
