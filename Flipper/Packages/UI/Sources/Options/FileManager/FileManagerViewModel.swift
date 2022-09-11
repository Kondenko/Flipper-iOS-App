import Core
import Inject
import Analytics
import Peripheral
import Combine
import Logging
import UIKit
import UniformTypeIdentifiers

import struct Foundation.Date

@MainActor
class FileManagerViewModel: ObservableObject {
    private let logger = Logger(label: "file-manager-vm")

    @Inject var rpc: RPC
    @Inject var analytics: Analytics

    @Published var content: Content? {
        didSet {
            if case .file(let text) = content {
                self.text = text
            }
        }
    }
    @Published var text: String = ""
    @Published var name: String = ""
    @Published var isFilePickerDisplayed: Bool = false

    var supportedExtensions: [String] = [
        ".ibtn", ".nfc", ".shd", ".sub", ".rfid", ".ir", ".fmf", ".txt"
    ]
    var allowedContentTypes: [UTType] {
        supportedExtensions.compactMap { UTType(filenameExtension: String($0.dropFirst(1)), conformingTo: .text) }
    }

    enum Content {
        case list([Element])
        case file(String)
        case create(isDirectory: Bool)
        case forceDelete(Path)
        case error(String)
    }

    enum PathMode {
        case list
        case edit
        case error
    }

    let path: Path
    let mode: PathMode

    var title: String {
        path.string
    }

    convenience init() {
        self.init(path: .init(string: "/"), mode: .list)
    }

    init(path: Path, mode: PathMode) {
        self.path = path
        self.mode = mode
        recordFileManager()
    }

    func update() {
        Task {
            switch self.mode {
            case .list: await listDirectory()
            case .edit: await readFile()
            default: break
            }
        }
    }

    // MARK: Directory

    func listDirectory() async {
        content = nil
        do {
            let items = try await rpc.listDirectory(at: path)
            self.content = .list(items)
        } catch {
            logger.error("list directory: \(error)")
            self.content = .error(String(describing: error))
        }
    }

    // MARK: File

    func canRead(_ file: File) -> Bool {
        supportedExtensions.contains {
            file.name.hasSuffix($0)
        }
    }

    func readFile() async {
        do {
            let bytes = try await rpc.readFile(at: path)
            self.content = .file(.init(decoding: bytes, as: UTF8.self))
        } catch {
            logger.error("read file: \(error)")
            self.content = .error(String(describing: error))
        }
    }

    func save() {
        Task {
            let text = text
            self.content = nil
            do {
                try await rpc.writeFile(at: path, string: text)
                self.content = .file(text)
            } catch {
                logger.error("save file: \(error)")
                self.content = .error(String(describing: error))
            }
        }
    }

    // MARK: Import

    func importFile(url: URL?) {
        Task {
            do {
                guard let url = url else {
                    fatalError("url is nil")
                }
                guard let name = url.pathComponents.last else {
                    fatalError("couldn't extract file name from \(url)")
                }
                guard url.startAccessingSecurityScopedResource() else {
                    fatalError("unable to access scoped resouce via \(url)")
                }

                let data = try Data(contentsOf: url)
                let path = path.appending(name)
                var bytes = [UInt8](repeating: 0, count: data.count)
                data.copyBytes(to: &bytes, count: data.count)
            
                try await rpc.writeFile(at: path, bytes: bytes)
                await listDirectory()
            
                do {
                    url.stopAccessingSecurityScopedResource()
                }
            } catch {
                logger.error("import file: \(error)")
                self.content = .error(String(describing: error))
            }
        }
    }

    // Create

    func newElement(isDirectory: Bool) {
        content = .create(isDirectory: isDirectory)
    }

    func cancel() {
        Task {
            await listDirectory()
        }
    }

    func create() {
        Task {
            guard !name.isEmpty else { return }
            guard case .create(let isDirectory) = content else {
                return
            }

            content = nil

            let path = path.appending(name)
            name = ""

            do {
                try await rpc.createFile(at: path, isDirectory: isDirectory)
                await listDirectory()
            } catch {
                logger.error("create file: \(error)")
                self.content = .error(String(describing: error))
            }
        }
    }

    // Delete

    func delete(at index: Int) {
        Task {
            guard case .list(var elements) = content else {
                return
            }

            let element = elements.remove(at: index)
            self.content = .list(elements)
            let elementPath = path.appending(element.name)

            do {
                try await rpc.deleteFile(at: elementPath, force: false)
                self.content = .list(elements)
            } catch let error as Peripheral.Error where error == .storage(.notEmpty) {
                self.content = .forceDelete(elementPath)
            } catch {
                logger.error("delete file: \(error)")
                self.content = .error(String(describing: error))
            }
        }
    }

    func forceDelete() {
        Task {
            guard case .forceDelete(let path) = content else {
                return
            }
            do {
                try await rpc.deleteFile(at: path, force: true)
                await listDirectory()
            } catch {
                logger.error("force delete: \(error)")
                self.content = .error(String(describing: error))
            }
        }
    }

    // Analytics

    func recordFileManager() {
        analytics.appOpen(target: .fileManager)
    }
}
