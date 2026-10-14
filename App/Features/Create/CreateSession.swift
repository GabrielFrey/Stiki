import Foundation
import StikiCore

/// The in-memory document the Create flow carries from import to save.
///
/// Nothing here is persisted until the user taps Save in the editor. That is
/// what makes Cancel cheap and what keeps a half-finished cutout from
/// polluting the library.
struct CreateSession: Identifiable, Hashable {
    var id: UUID
    /// Existing library sticker being re-edited, if any.
    var editingStickerID: UUID?
    var recipe: EditRecipe
    var sourcePreview: Data
    var analysis: SubjectAnalysis?
    var selectedInstances: Set<Int>
    var videoData: Data?
    var isBusy: Bool
    var progress: Double
    var error: StikiError?

    init(
        id: UUID = UUID(),
        editingStickerID: UUID? = nil,
        recipe: EditRecipe,
        sourcePreview: Data,
        analysis: SubjectAnalysis? = nil,
        selectedInstances: Set<Int> = [],
        videoData: Data? = nil
    ) {
        self.id = id
        self.editingStickerID = editingStickerID
        self.recipe = recipe
        self.sourcePreview = sourcePreview
        self.analysis = analysis
        self.selectedInstances = selectedInstances
        self.videoData = videoData
        self.isBusy = false
        self.progress = 0
        self.error = nil
    }
}

enum CreateStep: Hashable {
    case importSource
    case cutout
    case editor
}
