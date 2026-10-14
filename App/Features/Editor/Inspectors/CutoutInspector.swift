import SwiftUI

struct CutoutInspector: View {
    @Bindable var model: CreateViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cut out")
                .font(.headline)
            Text("Go back to pick different subjects or refine the mask with the brush.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Edit cutout") { model.step = .cutout }
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
