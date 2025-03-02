import SwiftUI
import UniformTypeIdentifiers
import Combine
import UIKit

// Helper extension to hide the keyboard.
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

// Extension to get file type from extension
extension String {
    func fileType() -> String {
        let fileExtension = (self as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "md": return "Markdown"
        case "txt": return "Text"
        case "cpp", "c++", "cc": return "C++"
        case "c": return "C"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "go": return "Go"
        case "rb": return "Ruby"
        case "php": return "PHP"
        case "sh": return "Shell"
        case "xml": return "XML"
        case "sql": return "SQL"
        case "yaml", "yml": return "YAML"
        case "dart": return "Dart"
        case "ts": return "TypeScript"
        default: return fileExtension.isEmpty ? "New File" : fileExtension.uppercased()
        }
    }
}

// MARK: - Syntax Highlighting Support
// Text storage that applies syntax highlighting
class SyntaxHighlightingTextStorage: NSTextStorage {
    let backingStore = NSMutableAttributedString()
    
    // Basic syntax highlighting rules
    let keywords = ["import", "func", "var", "let", "if", "else", "for", "while", "switch", "case", "struct", "class", "enum", "return", "guard", "public", "private", "static", "extension"]
    let numberPattern = "\\b[0-9]+\\b"
    let stringPattern = "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\""
    let commentPattern = "\\/\\/.*$"
    
    // Colors for different syntax elements
    var keywordColor: UIColor { UIColor(red: 0.7, green: 0.2, blue: 0, alpha: 1) }
    var numberColor: UIColor { UIColor(red: 0.1, green: 0.6, blue: 0.5, alpha: 1) }
    var stringColor: UIColor { UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1) }
    var commentColor: UIColor { UIColor(red: 0.4, green: 0.6, blue: 0.4, alpha: 1) }
    
    override var string: String {
        return backingStore.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    // Apply syntax highlighting
    func applyHighlighting() {
        let wholeRange = NSRange(location: 0, length: string.count)
        
        // Default font and color
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        
        // Reset all formatting
        self.setAttributes(defaultAttributes, range: wholeRange)
        
        // Apply keyword highlighting
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: string, options: [], range: wholeRange)
                for match in matches {
                    addAttribute(.foregroundColor, value: keywordColor, range: match.range)
                }
            }
        }
        
        // Highlight numbers
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: wholeRange)
            for match in matches {
                addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
        }
        
        // Highlight strings
        if let regex = try? NSRegularExpression(pattern: stringPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: string, options: [], range: wholeRange)
            for match in matches {
                addAttribute(.foregroundColor, value: stringColor, range: match.range)
            }
        }
        
        // Highlight comments
        if let regex = try? NSRegularExpression(pattern: commentPattern, options: [.anchorsMatchLines]) {
            let matches = regex.matches(in: string, options: [], range: wholeRange)
            for match in matches {
                addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }
    }
    
    override func processEditing() {
        applyHighlighting()
        super.processEditing()
    }
}

// MARK: - Custom Text Editor with Horizontal Scrolling and Syntax Highlighting
struct SyntaxHighlightingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onTextChange: (String) -> Void
    
    // Additional closures for accessory view actions.
    var onOpen: (() -> Void)?
    var onTrash: (() -> Void)?
    var onSave: (() -> Void)?
    // We'll use the built-in undo manager from the UITextView, so no onUndo closure is needed.
    
    func makeUIView(context: Context) -> UITextView {
        let textStorage = SyntaxHighlightingTextStorage()
        let layoutManager = NSLayoutManager()
        
        let textContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        let textView = UITextView(frame: .zero, textContainer: textContainer)
        
        // Configure the text view for horizontal scrolling
        textView.isScrollEnabled = true
        textView.alwaysBounceHorizontal = true
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.backgroundColor = UIColor.clear
        
        // Disable line wrapping
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainer.widthTracksTextView = false
        textView.isScrollEnabled = true
        
        // Add input accessory view explicitly to ensure toolbar appears
        textView.inputAccessoryView = context.coordinator.createInputAccessoryView()
        
        textView.delegate = context.coordinator
        textView.text = text
        textStorage.applyHighlighting()
        
        // Store a reference to this textView in the coordinator so we can call its undo manager.
        context.coordinator.textView = textView
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            (uiView.textStorage as? SyntaxHighlightingTextStorage)?.applyHighlighting()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text,
                    onTextChange: onTextChange,
                    onOpen: onOpen,
                    onTrash: onTrash,
                    onSave: onSave)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onTextChange: (String) -> Void
        
        // Action closures
        var onOpen: (() -> Void)?
        var onTrash: (() -> Void)?
        var onSave: (() -> Void)?
        
        // A weak reference to the UITextView so we can use its built-in undo manager.
        weak var textView: UITextView?
        
        init(text: Binding<String>,
             onTextChange: @escaping (String) -> Void,
             onOpen: (() -> Void)?,
             onTrash: (() -> Void)?,
             onSave: (() -> Void)?) {
            self._text = text
            self.onTextChange = onTextChange
            self.onOpen = onOpen
            self.onTrash = onTrash
            self.onSave = onSave
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            onTextChange(textView.text)
        }
        
        // Create the input accessory view programmatically
        func createInputAccessoryView() -> UIView {
            let toolbar = UIToolbar()
            toolbar.barStyle = .default
            toolbar.isTranslucent = true
            toolbar.sizeToFit()
            
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            // Open button
            let openButton = UIBarButtonItem(image: UIImage(systemName: "folder"), style: .plain, target: self, action: #selector(openButtonTapped))
            // Trash button
            let trashButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(trashButtonTapped))
            // Hide keyboard button
            let hideKeyboardButton = UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .plain, target: self, action: #selector(hideKeyboardTapped))
            // Save button
            let saveButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(saveButtonTapped))
            // Undo button: call the built-in undo manager on the textView.
            let undoButton = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.left"), style: .plain, target: self, action: #selector(undoButtonTapped))
            
            toolbar.setItems([flexSpace, openButton, flexSpace, trashButton, flexSpace, hideKeyboardButton, flexSpace, saveButton, flexSpace, undoButton, flexSpace], animated: false)
            toolbar.isUserInteractionEnabled = true
            
            return toolbar
        }
        
        @objc func openButtonTapped() {
            onOpen?()
        }
        
        @objc func trashButtonTapped() {
            onTrash?()
        }
        
        @objc func hideKeyboardTapped() {
            UIApplication.shared.hideKeyboard()
        }
        
        @objc func saveButtonTapped() {
            onSave?()
        }
        
        @objc func undoButtonTapped() {
            // Use the UITextView's built-in undo manager.
            textView?.undoManager?.undo()
        }
    }
}

// MARK: - Editor View Model (No manual undo registration)
class EditorViewModel: ObservableObject {
    @Published var codeText: String = ""
    
    // Simply update text; rely on UITextView’s built-in undo handling.
    func updateText(_ newText: String) {
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

    var textEditorBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95)
    }

    var textEditorForeground: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    // Calculate file type from filename.
    // Return an empty string if fileName is blank.
    var fileType: String {
        fileName.isEmpty ? "" : fileName.fileType()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Top bar with Save, File Type, and Trash buttons
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
                    
                    // File type label in the middle (shown only if not empty)
                    if !fileType.isEmpty {
                        Text(fileType)
                            .font(.headline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(textEditorBackground)
                            .foregroundColor(textEditorForeground)
                            .cornerRadius(8)
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
                
                // Custom syntax highlighting code editor
                SyntaxHighlightingTextEditor(
                    text: $viewModel.codeText,
                    onTextChange: { viewModel.updateText($0) },
                    onOpen: { showingOpenPicker = true },
                    onTrash: {
                        viewModel.updateText("")
                        fileURL = nil
                        fileName = ""
                        securityBookmark = nil
                    },
                    onSave: saveFile
                )
                .frame(minHeight: 300)
                .background(textEditorBackground)
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
            
            guard url.startAccessingSecurityScopedResource() else {
                completion(nil, "", nil, nil)
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
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
