
# Project Brief: Vision Closet (Portable Context)

This document is a portable context for assistants. Paste the “Assistant Setup Prompt” section into any AI to quickly align it with the project goals, constraints, and conventions.

## Assistant Setup Prompt (Paste This)
You are assisting with an iOS app called “Vision Closet.” The app began as an Apple Vision example and is now being expanded into a learning project and a potential shipping product. The app’s core purpose is to allow users to:
- Take pictures of clothing items
- Recognize clothing attributes (category, color, pattern, brand when possible)
- Save items to a virtual wardrobe
- Create and manage outfits from saved items

Priorities:
- Teach and reinforce good iOS/Swift/SwiftUI/Core Data practices
- Keep the codebase approachable and well-documented
- Prefer standard Apple frameworks (SwiftUI, Photos/Camera, Vision, Core Data/SwiftData)
- Favor Swift Concurrency (async/await, actors) where appropriate
- Avoid introducing unnecessary third-party dependencies

When proposing changes:
- Provide minimal, focused edits with clear reasoning
- Use Swift and SwiftUI idioms
- Show code snippets with file names where applicable
- Maintain consistent naming and architecture
- If you’re unsure of context, ask clarifying questions

Deliverables should be production-minded but learning-friendly, with comments explaining why, not just how.

## Project Vision
- A delightful wardrobe app that can realistically ship, but is also a teaching ground for modern iOS patterns.
- Incremental development: small, shippable improvements; learning through iteration.
- Accessibility, performance, and privacy respected from the start.

## Current State (to be tailored to code)
Note: This section should reflect the real code. Replace the bullets below with accurate details after code review.
- Camera/Photo capture: [TBD – e.g., using PHPicker or AVCaptureSession]
- Vision recognition: [TBD – e.g., VNCoreMLRequest for clothing categories]
- Data layer: [TBD – Core Data/SwiftData models for ClothingItem, Outfit]
- UI: [TBD – SwiftUI views for capture, item detail, wardrobe grid, outfit builder]
- Persistence, migrations, and sample data: [TBD]
- Testing: [TBD – unit/UI tests coverage]

## Near-Term Goals
1. Solidify data model for clothing items and outfits
2. Implement robust photo capture/selection flow
3. Integrate Vision-based attribute extraction with graceful fallbacks
4. Build wardrobe list/grid with filtering and search
5. Create outfit composition UI and persistence
6. Add basic onboarding and permissions education
7. Seed with sample data for development/testing

## Non-Goals (for now)
- Cloud sync or multi-device collaboration
- Heavy third-party dependencies
- Overly complex ML models beyond Apple’s Vision/Core ML unless necessary

## Technical Stack & Constraints
- Language: Swift (prefer Swift 6+ idioms)
- UI: SwiftUI
- Concurrency: async/await, Task, actors as needed
- Persistence: Core Data or SwiftData (prefer SwiftData if the codebase is already on it)
- ML: Vision/Core ML for recognition
- Media: Photos/Camera (PHPickerViewController or AVCapture)
- Testing: Swift Testing or XCTest (use what the project already uses)
- Platforms: iOS first; consider iPadOS-friendly layouts
- Minimum iOS: [TBD based on project]

## Data Model (initial draft)
- ClothingItem
  - id (UUID)
  - createdAt (Date)
  - photo (data or asset reference)
  - category (e.g., “shirt”, “pants”, “shoes”)
  - color(s) (string or structured)
  - pattern (optional)
  - brand (optional)
  - notes (optional)
  - tags [strings]
- Outfit
  - id (UUID)
  - name (String)
  - createdAt (Date)
  - items: [ClothingItem]
  - photo/thumbnail (optional)
  - notes (optional)
- Consider normalization for colors/tags if needed later.

## UX Principles
- Clear capture flow with immediate feedback
- Respect user privacy; process on-device when possible
- Make manual corrections easy (recognition won’t be perfect)
- Empty states and onboarding that teach the workflow
- Keyboard and VoiceOver friendly

## Coding Conventions
- Swift naming conventions; modules and types in PascalCase, variables in camelCase
- Keep views small and composable; prefer MVVM-ish structure with observable view models
- Use @MainActor for UI-bound types
- Isolate Vision/ML in service types with testable interfaces
- Avoid singletons except for clearly justified services (e.g., shared persistence)
- Prefer dependency injection via initializers

## Error Handling
- Use Swift error types; bubble up with async throws
- Convert to user-facing alerts where appropriate
- Log non-fatal issues for debugging; avoid print in production code paths

## Privacy & Permissions
- Explain why camera/photos access is needed
- Fail gracefully if permissions are denied
- Keep images local unless explicitly shared

## Performance
- Defer heavy work off the main thread
- Cache derived attributes if costly to compute
- Use image thumbnails for lists/grids

## Testing Strategy
- Unit tests for data layer and recognition services (mock Vision outputs)
- Snapshot/UI tests for key flows (capture, save item, build outfit)
- Seed sample data in previews and tests

## Open Questions (fill as we learn)
- Which recognition attributes are reliable enough to auto-fill?
- How do we handle duplicate items or near-duplicates?
- Do we support multiple wardrobes or profiles?

## Roadmap (High Level)
- M1: Baseline capture + save item
- M2: Vision attribute extraction + manual editing
- M3: Wardrobe browsing + filtering
- M4: Outfit builder + persistence
- M5: Polish, accessibility, and onboarding
- M6: Beta readiness tasks (app icon, App Store assets)

## Maintainers Notes
- This document is the single source of truth for AI assistants.
- Keep it updated as architecture and features evolve.
- If the workspace changes, keep PROMPT.md in the repo root so assistants can rehydrate context quickly.
