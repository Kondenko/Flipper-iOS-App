import Inject
import Logging
import Combine
import Foundation

public class Archive: ObservableObject {
    public static let shared: Archive = .init()
    private let logger = Logger(label: "archive")

    @Inject private var mobileArchive: MobileArchiveProtocol
    @Inject private var deletedArchive: DeletedArchiveProtocol
    @Inject private var sync: SyncProtocol

    @Published public var items: [ArchiveItem] = []
    @Published public var deletedItems: [ArchiveItem] = []

    @Published public var isSyncronizing = false

    private var disposeBag: DisposeBag = .init()

    public enum Error: String, Swift.Error {
        case alredyExists
    }

    private init() {
        sync.events
            .sink { [weak self] in
                self?.onSyncEvent($0)
            }
            .store(in: &disposeBag)

        load()
    }

    func load() {
        isSyncronizing = true
        Task {
            items = try await loadArchive()
            deletedItems = try await loadDeleted()
            isSyncronizing = false
        }
    }

    func loadArchive() async throws -> [ArchiveItem] {
        var items = [ArchiveItem]()
        for path in try await mobileArchive.manifest.paths {
            var item = try await mobileArchive.read(.init(path: path))
            item.status = try await sync.status(for: item)
            items.append(item)
        }
        return items
    }

    func loadDeleted() async throws -> [ArchiveItem] {
        var items = [ArchiveItem]()
        for path in try await deletedArchive.manifest.paths {
            let item = try await deletedArchive.read(.init(path: path))
            items.append(item)
        }
        return items
    }

    func onSyncEvent(_ event: Sync.Event) {
        Task {
            switch event {
            case .imported(let id):
                var item = try await mobileArchive.read(id)
                item.status = .synchronized
                items.removeAll { $0.id == item.id }
                items.append(item)
            case .exported(let id):
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].status = .synchronized
                }
            case .deleted(let id):
                if let index = items.firstIndex(where: { $0.id == id }) {
                    try await backup(items[index])
                    items.removeAll { $0.id == id }
                }
            }
        }
    }
}

extension Archive {
    public func get(_ id: ArchiveItem.ID) -> ArchiveItem? {
        items.first { $0.id == id }
    }

    public func upsert(_ item: ArchiveItem) async throws {
        try await mobileArchive.upsert(item)
        items.removeAll { $0.id == item.id }
        items.append(item)
    }

    public func delete(_ id: ArchiveItem.ID) async throws {
        if let item = get(id) {
            try await backup(item)
            try await mobileArchive.delete(id)
            items.removeAll { $0.id == id }
        }
    }
}

extension Archive {
    public func wipe(_ id: ArchiveItem.ID) async throws {
        try await deletedArchive.delete(id)
        deletedItems.removeAll { $0.id == id }
    }

    public func wipeAll() async throws {
        for item in deletedItems {
            try await deletedArchive.delete(item.id)
        }
        deletedItems.removeAll()
    }

    public func rename(_ id: ArchiveItem.ID, to name: ArchiveItem.Name) async throws {
        if let item = get(id) {
            let newItem = item.rename(to: name)
            guard get(newItem.id) == nil else {
                throw Error.alredyExists
            }
            try await mobileArchive.delete(id)
            items.removeAll { $0.id == item.id }
            try await mobileArchive.upsert(newItem)
            items.append(newItem)
        }
    }

    func backup(_ item: ArchiveItem) async throws {
        var item = item
        item.status = .deleted
        try await deletedArchive.upsert(item)
        deletedItems.removeAll { $0.id == item.id }
        deletedItems.append(item)
    }

    public func restore(_ item: ArchiveItem) async throws {
        let manifest = try await mobileArchive.manifest
        // TODO: resolve conflicts
        guard manifest[item.path] == nil else {
            logger.error("alredy exists")
            return
        }
        var item = item
        item.status = try await sync.status(for: item)
        try await mobileArchive.upsert(item)
        items.append(item)

        try await deletedArchive.delete(item.id)
        deletedItems.removeAll { $0.id == item.id }
    }
}

extension Archive {
    func importKey(_ item: ArchiveItem) async throws {
        if !items.contains(where: { item.id == $0.id }) {
            try await upsert(item)
        }
    }
}

extension Archive {
    func syncWithDevice() async {
        guard !isSyncronizing else { return }
        do {
            try await sync.syncWithDevice()
        } catch {
            logger.critical("syncronization error: \(error)")
        }
    }
}

extension Archive.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .alredyExists:
            return "The name is already taken. Please choose a different name."
        }
    }
}
