import SwiftUI
import UniformTypeIdentifiers

// Helper extension to hide the keyboard.
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

// MARK: - Editor View Model for Undo Support
class EditorViewModel: ObservableObject {
    @Published var codeText: String = ""
    var undoManager: UndoManager?

    /// Updates the text and registers an inverse action for undo.
    func updateText(_ newText: String) {
        let oldText = codeText
        guard newText != oldText else { return }
        if let um = undoManager, !um.isUndoing, !um.isRedoing {
            um.registerUndo(withTarget: self) { target in
                target.updateText(oldText)
            }
        }
        codeText = newText
    }
}

struct ContentView: View {
    @StateObject private var viewModel = EditorViewModel()
    @State private var fileName = ""
    @State private var fileURL: URL? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSavePicker = false
    @State private var showingOpenPicker = false
    @State private var securityBookmark: Data? = nil

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.undoManager) var undoManager

    var textEditorBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95)
    }

    var textEditorForeground: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Top bar with Save and Trash buttons.
                HStack {
                    // Save button.
                    Button(action: saveFile) {
                        Image(systemName: "square.and.arrow.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Trash button resets text, filename, fileURL, and bookmark.
                    Button(action: {
                        viewModel.updateText("")
                        fileURL = nil
                        fileName = ""
                        securityBookmark = nil
                    }) {
                        Image(systemName: "trash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Filename text field.
                ZStack(alignment: .leading) {
                    if fileName.isEmpty {
                        Text("Enter filename (any extension)")
                            .padding(8)
                            .foregroundColor(.gray)
                    }
                    TextField("", text: $fileName)
                        .padding(8)
                        .background(textEditorBackground)
                        .cornerRadius(8)
                        .foregroundColor(textEditorForeground)
                }
                .padding(.horizontal)
                
                // Code editor using our custom binding.
                TextEditor(text: Binding(
                    get: { viewModel.codeText },
                    set: { newText in viewModel.updateText(newText) }
                ))
                .onAppear {
                    viewModel.undoManager = undoManager
                }
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)
                .background(textEditorBackground)
                .foregroundColor(textEditorForeground)
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Centered Open File button.
                HStack {
                    Spacer()
                    
                    Button(action: { showingOpenPicker = true }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Open File")
                        }
                        .foregroundColor(.white)
                        .frame(width: 140, height: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Message"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            // Document Picker for saving files.
            .sheet(isPresented: $showingSavePicker) {
                DocumentPicker(codeText: viewModel.codeText, fileName: fileName) { success, url in
                    if success {
                        alertMessage = "File saved successfully!"
                        if let url = url {
                            fileURL = url
                            createNewBookmark(for: url)
                        }
                        showingAlert = true
                    }
                }
            }
            // Document Picker for opening files.
            .sheet(isPresented: $showingOpenPicker) {
                OpenFilePicker { text, name, url, bookmark in
                    if let text = text {
                        viewModel.updateText(text)
                        fileName = name
                        fileURL = url
                        securityBookmark = bookmark
                    } else {
                        alertMessage = "Failed to open file"
                        showingAlert = true
                    }
                }
            }
            // Updated keyboard accessory toolbar with 5 equally spaced buttons
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Group {
                        Spacer()
                        
                        // Open File Button
                        Button(action: { showingOpenPicker = true }) {
                            Image(systemName: "folder")
                        }
                        
                        Spacer()
                        
                        // Trash Button
                        Button(action: {
                            viewModel.updateText("")
                            fileURL = nil
                            fileName = ""
                            securityBookmark = nil
                        }) {
                            Image(systemName: "trash")
                        }
                        
                        Spacer()
                        
                        // Hide Keyboard Button
                        Button(action: { UIApplication.shared.hideKeyboard() }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                        
                        Spacer()
                        
                        // Save Button
                        Button(action: saveFile) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        Spacer()
                        
                        // Undo Button
                        Button(action: { undoManager?.undo() }) {
                            Image(systemName: "arrow.uturn.left")
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - File Saving Logic
    private func saveFile() {
        if let url = fileURL {
            if let bookmark = securityBookmark {
                var isStale = false
                do {
                    let resolvedURL = try URL(resolvingBookmarkData: bookmark,
                                              bookmarkDataIsStale: &isStale)
                    if isStale || resolvedURL != url {
                        createNewBookmark(for: url)
                    }
                    
                    guard url.startAccessingSecurityScopedResource() else {
                        alertMessage = "Failed to access file"
                        showingAlert = true
                        return
                    }
                    
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    try viewModel.codeText.write(to: url, atomically: true, encoding: .utf8)
                    alertMessage = "File saved successfully!"
                } catch {
                    alertMessage = "Failed to save file: \(error.localizedDescription)"
                }
            } else {
                do {
                    try viewModel.codeText.write(to: url, atomically: true, encoding: .utf8)
                    alertMessage = "File saved successfully!"
                } catch {
                    alertMessage = "Failed to save file: \(error.localizedDescription)"
                }
            }
            showingAlert = true
        } else {
            guard !fileName.isEmpty else {
                alertMessage = "Please enter a filename"
                showingAlert = true
                return
            }
            // Allow saving even if the text is empty.
            showingSavePicker = true
        }
    }

    // MARK: - Bookmark Creation Helper
    private func createNewBookmark(for url: URL) {
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            securityBookmark = bookmark
        } catch {
            print("Failed to create bookmark: \(error.localizedDescription)")
        }
    }
}

// MARK: - DocumentPicker for Saving Files
struct DocumentPicker: UIViewControllerRepresentable {
    let codeText: String
    let fileName: String
    let completion: (Bool, URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try codeText.write(to: tempFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating temporary file: \(error.localizedDescription)")
            completion(false, nil)
        }
        
        let picker = UIDocumentPickerViewController(forExporting: [tempFileURL])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Bool, URL?) -> Void

        init(completion: @escaping (Bool, URL?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(true, urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(false, nil)
        }
    }
}

// MARK: - OpenFilePicker for Opening Files (Fixed Security Access)
struct OpenFilePicker: UIViewControllerRepresentable {
    let completion: (String?, String, URL?, Data?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.plainText,
            UTType.pythonScript,
            UTType.sourceCode
        ])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (String?, String, URL?, Data?) -> Void

        init(completion: @escaping (String?, String, URL?, Data?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                completion(nil, "", nil, nil)
                return
            }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                completion(nil, "", nil, nil)
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                // Create bookmark for persistent access
                let bookmark = try url.bookmarkData(options: .minimalBookmark,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil)
                let text = try String(contentsOf: url, encoding: .utf8)
                completion(text, url.lastPathComponent, url, bookmark)
            } catch {
                completion(nil, "", nil, nil)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil, "", nil, nil)
        }
    }
}

#Preview {
    ContentView()
}
