import SwiftUI

struct TopicRowView: View {
    @Binding var topic: EditableTopic
    var isLocked: Bool
    var onDelete: (() -> Void)?

    var body: some View {
        HStack {
            if !isLocked, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove topic")
            }

            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("", text: $topic.name, prompt: Text("topic"))
                .textFieldStyle(.plain)
                .disabled(isLocked)

            Spacer()

            Toggle("Fetch", isOn: Binding(
                get: { topic.fetchMissed ?? false },
                set: { topic.fetchMissed = $0 ? true : nil }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(isLocked)
        }
    }
}
