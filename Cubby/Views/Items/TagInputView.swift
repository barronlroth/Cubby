import SwiftUI

struct TagInputView: View {
    @Binding var tags: Set<String>
    @Binding var currentInput: String
    let suggestions: [String]
    let maxTags = TagValidator.maxTags
    
    @FocusState private var inputFocus: Bool
    @State private var showingSuggestions = false
    
    var canAddMoreTags: Bool {
        tags.count < maxTags
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(tags.count)/\(maxTags) tags")
                        .font(.caption2)
                        .foregroundStyle(tags.count >= maxTags ? .red : .secondary)
                }
                
                if !tags.isEmpty {
                    TagDisplayView(tags: tags) { tag in
                        _ = withAnimation(.spring(duration: 0.3)) {
                            tags.remove(tag)
                        }
                        #if os(iOS)
                        if #available(iOS 17.0, *) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        #endif
                    }
                }
                
                if canAddMoreTags {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Add tag", text: $currentInput)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($inputFocus)
                            .onSubmit {
                                addTag()
                            }
                            .onChange(of: currentInput) { _, newValue in
                                currentInput = newValue.formatAsTag()
                                showingSuggestions = !newValue.isEmpty && !suggestions.isEmpty
                            }
                        
                        if showingSuggestions && !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            currentInput = suggestion
                                            addTag()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "tag")
                                                    .font(.caption2)
                                                Text(suggestion)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(height: 28)
                        }
                    }
                } else {
                    Text("Maximum tags reached")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    private func addTag() {
        let formatted = currentInput.formatAsTag()
        
        guard TagValidator.isValid(formatted) else { return }
        guard !tags.contains(formatted) else {
            currentInput = ""
            return
        }
        guard canAddMoreTags else { return }
        
        _ = withAnimation(.spring(duration: 0.3)) {
            tags.insert(formatted)
        }
        
        currentInput = ""
        inputFocus = true
        
        #if os(iOS)
        if #available(iOS 17.0, *) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

struct TagTextField: ViewModifier {
    @Binding var text: String
    let onSubmit: () -> Void
    
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit {
                onSubmit()
                #if os(iOS)
                if #available(iOS 17.0, *) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            }
            .onChange(of: text) { _, newValue in
                text = newValue.formatAsTag()
            }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var tags: Set<String> = ["electronics", "office"]
        @State private var input = ""
        
        var body: some View {
            TagInputView(
                tags: $tags,
                currentInput: $input,
                suggestions: ["tech", "technology", "technical"]
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}