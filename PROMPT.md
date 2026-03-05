# FashionApp - Portable Project Context

Use this document as the single handoff context for new AI assistants.

## Assistant Setup Prompt (Paste This)
You are assisting with an iOS app named `FashionApp`.

Primary product direction:
- Photo-based clothing detection (Vision/Core ML)
- Persist detected clothing items to a local wardrobe (SwiftData)
- Show saved wardrobe items with thumbnails and details
- Keep implementation learning-friendly, production-minded, and TDD-oriented

Engineering priorities:
- Prefer standard Apple frameworks (SwiftUI, PhotosUI/Photos, Vision/Core ML, SwiftData)
- Prefer async/await and clean DI
- Keep architecture layered and testable
- Avoid third-party dependencies unless necessary
- Use focused edits with clear reasoning

When changing behavior:
- Add or update tests first for non-trivial logic
- Keep code changes narrow and explicit
- Preserve current architecture and naming
- Call out migration risks when SwiftData models change

## Current State (accurate as of March 5, 2026)

### App Composition
- App entry: `FashionApp.swift`
- Root injects DI container and SwiftData model container:
  - `.environment(\.container, DIContainer.shared)`
  - `.modelContainer(for: [ClothingItemRecord.self])`
- Navigation root: `Presentation/Views/ContentView.swift` -> `container.makeClothingDetectionView(modelContext:)`

### Architecture
- Layered flow is in use:
  - DataSource -> Repository -> UseCase -> ViewModel -> SwiftUI View
- DI container is centralized in `Core/DependencyInjection/Container.swift`

### Detection Pipeline
- Input via `PhotosPicker` in `ClothingDetectionView`
- Selected image is loaded as `Data` and downscaled (`ImageProcessor.downscaleImage`)
- Detection uses Core ML model `best.mlmodel` through Vision
- Domain mapping from observations to `ClothingItem` happens in `ClothingDetectionUseCase`
- Confidence threshold filtering is in use case (`ImageProcessingRequest.confidenceThreshold`, default `0.4`)

### Cropping Pipeline
- Crop logic in `CoreImageCroppingDataSource`
- Bounding box coordinate conversion is centralized in `Core/Utils/BoundingBoxMapper.swift`
- Detection still runs on a downscaled image for speed, but crop/thumbnail generation now prefers the original-resolution source image for quality.
- Supports:
  - Crop selected detected item
  - Crop all detected items
  - Show cropped images sheet (`CroppedImagesView`)

### Wardrobe Persistence
- SwiftData model: `ClothingItemRecord`
- Repository: `SwiftDataClothingItemRepository`
- Persisted fields currently include:
  - `id`, `createdAt`, `photoAssetIdentifier`
  - `label`, `confidence`
  - bounding box + image size
  - `thumbnailData` (small persisted thumbnail blob)

### Saved Items UX (Implemented)
- `ClothingDetectionViewModel` persists detected items after successful detection
- Saved items are loaded into `savedItems` and shown as cards in `ClothingDetectionView`
- Saved cards are tappable; tapping opens detail sheet with:
  - cropped preview
  - label, confidence, timestamp, asset identifier
- Thumbnail strategy:
  - Generate and persist thumbnail data at detection-save time
  - Prefer persisted `thumbnailData` for saved cards
  - Fallback to Photos-based crop when needed
  - Fallback to placeholder image when source unavailable
- Source-availability handling:
  - Missing `PhotosPickerItem.itemIdentifier` falls back to synthetic `unavailable:<uuid>` identifier for persistence continuity
  - Saved-item loading errors are surfaced via non-blocking status messaging, not global detection failure

## Core Domain Model Snapshot
- `ClothingItem` currently contains:
  - `id: UUID`
  - `label: String`
  - `confidence: Float`
  - `boundingBox: CGRect`
  - `imageSize: CGSize`
  - `createdAt: Date`
  - `photoAssetIdentifier: String?`
  - `thumbnailData: Data?`

## Testing State
- Test framework: Swift Testing (`import Testing`, `@Test`, `#expect`)
- Active test target currently discovers 13 tests
- Covered areas:
  - Repository save/fetch/delete, ordering, metadata mapping, uniqueness semantics
  - ViewModel persistence and error-state flow assertions
  - Image cropping use case behavior and datasource clamping
  - Bounding box mapper coordinate conversion and clamping behavior
  - Image downscaling behavior

### Test Discovery
- Canonical test path:
  - `FashionApp/FashionApp/FashionAppTests/...`
- Active test plan currently runs tests from that path only.
- Always verify discovery with `GetTestList` before assuming a new test file is running.

## Known Risks / Constraints
- SwiftData model changes (like added `thumbnailData`) can require local data reset if migration fails on existing installs.
- Photos-backed source images can become unavailable if user deletes originals; UI should continue to degrade gracefully.
- Thumbnail persistence is intentionally bounded and lossy (small JPEG) for performance/storage.

## Near-Term Next Work (Suggested)
1. Add explicit thumbnail size/quality constants and centralize them for tuning/telemetry.
2. Add migration-safe handling strategy for SwiftData schema evolution.
3. Add tests around thumbnail generation bounds/quality and fallback behavior.
4. Add relink/replace flow for source-unavailable saved items.
5. Begin wardrobe browsing/search/filtering and outfit model/persistence.

## Non-Goals (Current)
- Cloud sync/collaboration
- Heavy third-party dependencies
- Large/full-resolution image persistence in SwiftData

## Working Rules for Assistants
- Keep this file up to date whenever architecture or behavior changes.
- Prefer editing existing files over introducing parallel implementations.
- If test behavior is surprising, confirm active tests with `GetTestList`.
- If uncertain about runtime state, validate with tests/build before declaring completion.
