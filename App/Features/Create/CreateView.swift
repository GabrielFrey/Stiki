import SwiftUI

/// Create tab: import → cutout → editor.
struct CreateView: View {
    @Environment(\.stiki) private var environment
    @State private var model: CreateViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    switch model.step {
                    case .importSource:
                        ImportView(model: model)
                    case .cutout:
                        CutoutView(model: model)
                    case .editor:
                        EditorView(model: model)
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            if model == nil {
                model = CreateViewModel(environment: environment)
            }
        }
    }
}

#Preview {
    CreateView()
        .environment(\.stiki, .preview())
}
