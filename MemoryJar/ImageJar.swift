//
//  Memory.swift
//  MemoryJar
//  Inspired by the Parse SDK.
//  Created by Anthony Persaud on 12/21/18.
//

import Foundation
#if !os(macOS)
    import Combine
    import UIKit
#endif

public
typealias ImageCompletion = (UIImage) -> Void

@available(macOS, unavailable)
public final class ImageJar {
    /// Shared singleton with default cache location.
    public static let shared = { ImageJar() }()

    // Object to hold in memory. NSCache is not Swift compat, therefore must
    // inheirt from NSObject.
    private class Memo: NSObject {
        let creationDate: Date
        let value: UIImage

        init(value: UIImage, creationDate: Date = Date()) {
            self.value = value
            self.creationDate = creationDate
            super.init()
        }
    }

    // Track meta data objects in memory of items stored on the disk. We use modificationDate as our LRU date.
    private struct ContentRef {
        let key: String
        let modificationDate: Date
        let fileSize: Int
    }

    public static var defaultCacheDirectory: URL = {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            preconditionFailure("Failed to acquire cachesDirectory for application.")
        }
        return dir.appendingPathComponent("_imagejar", isDirectory: true)
    }()

    // advanced players only. We can turn in var in the future for dynamic rebalancing.
    public var maxDiskCacheRecords = 10000
    public var maxMemoryCacheRecordSizeBytes = 10.MBs
    public var maxDiskCacheRecordSizeBytes: Int = 512.MBs
    public static var defaultMaxAge: TimeInterval = 86400 * 7 // 7.days
    // Apple HFS+ level of accuracy in seconds
    private let fileSystemLevelAccuracy: TimeInterval = 1

    // trackers
    private var lastDiskCacheUpdatedDate: Date?
    private var currentDisckCacheSize: Int = 0
    private var currentMetaRefs = [ContentRef]()
    // Default FileManager is thread-safe
    private let fileManager = FileManager.default
    public let cacheDirectoryURL: URL

    // In-memory cache which will auto-purge entries on low memory warnings.
    // NSCache is thread-safe, no need to wrap queue.sync
    private var memoryCache = NSCache<NSString, Memo>()

    // write/read queue
    private let queue = DispatchQueue(label: "image.jar", attributes: .concurrent)

    public var cacheDirectoryPath: String {
        // ok
        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        return cacheDirectoryURL.path
    }

    public init(cacheDirectoryURL: URL = defaultCacheDirectory) {
        self.cacheDirectoryURL = cacheDirectoryURL
    }

    public subscript(key: String) -> UIImage? {
        get { get(forKey: key, maxAge: .infinity) }
        set(newValue) {
            if let newValue = newValue {
                set(value: newValue, forKey: key)
            } else {
                removeObject(forKey: key)
            }
        }
    }

    public func hasValue(forKey key: String, maxAge: TimeInterval = defaultMaxAge) -> Bool {
        // memory pointer returned, not full cost retrieval.
        if let memo = memoryCache.object(forKey: key as NSString),
           Date().timeIntervalSince(memo.creationDate) < maxAge
        {
            return true
        }
        // maybe use the meta references dictionary?
        let url = cacheURL(forKey: key)

        guard let modificationDate = modificationDateOfCacheEntry(at: url),
              Date().timeIntervalSince(modificationDate) < maxAge
        else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    public func get(forKey key: String, maxAge: TimeInterval = defaultMaxAge) -> UIImage? {
        let url = cacheURL(forKey: key)
        // Check memory cache first
        if let memo = memoryCache.object(forKey: key as NSString) {
            // if outdated, delete
            if Date().timeIntervalSince(memo.creationDate) > maxAge {
                removeObject(forKey: key)
                return nil
            }
            // LRU update
            queue.async(flags: .barrier) { [weak self] in
                self?.touch(at: url)
            }
//            return memo.value
        }
        /** No memory entry? Then try disk cache
         Because another (or the same) thread could be accessing
         the same data, we need to wait for all outstanding operations before continuing, as
         another thread could be writing to disk.
         */

        // if we don't have a mod date, then make it expire
        guard let modificationDate = modificationDateOfCacheEntry(at: url) else { return nil }
        if Date().timeIntervalSince(modificationDate) > maxAge {
            removeObject(forKey: key)
            return nil
        }

        var value: UIImage?
        // reference block assignment
        queue.sync {
            // Memory cache misses here
            // If we have a disk cache item, then also put it in memory cache
            if let contents = diskCacheItem(for: url) {
                let memo = Memo(value: contents, creationDate: modificationDate)
                memoryCache.setObject(memo, forKey: key as NSString)
                value = contents
            }
        }
        return value
    }

    public func set(value: UIImage, forKey key: String) {
        set(value: value, forKey: key, completion: nil)
    }

    public func set(value: UIImage, forKey key: String, completion: ImageCompletion? = nil) {
        let totalBytes = value.pngData()?.count ?? 0
        // write to memory if within limits
        if totalBytes < maxMemoryCacheRecordSizeBytes {
            memoryCache.setObject(Memo(value: value), forKey: key as NSString)
        } else {
            // otherwise proactively free memory
            memoryCache.removeObject(forKey: key as NSString)
        }
        // write to disk in the background

        let cacheURL = cacheURL(forKey: key)
        queue.async(flags: .barrier) { [weak self] in
            // heavy duty method should block all disk reads until done
            self?.writeDiskCacheItem(value: value, at: cacheURL)
            completion?(value)
        }
    }

    private func cacheURL(forKey key: String) -> URL {
        cacheDirectoryURL.appendingPathComponent(key.sha1)
    }

    public func removeObject(forKey key: String) {
        // remove from memory
        memoryCache.removeObject(forKey: key as NSString)
        // remove from disk cache
        let f = fileManager
        let cacheURLKey = cacheURL(forKey: key)
        queue.async(flags: .barrier) { [weak self] in
            do {
                try f.removeItem(at: cacheURLKey)
            } catch {
                self?.err(error.localizedDescription)
            }
        }
    }

    public func removeAllObjects() {
        // remove all cache items in memory
        memoryCache.removeAllObjects()

        // remove disk cache
        let f = fileManager
        let url = cacheDirectoryURL
        queue.async(flags: .barrier) { [weak self] in
            do {
                try f.removeItem(at: url)
            } catch {
                self?.err(error.localizedDescription)
            }
        }
    }

    private func err(_ str: String) {
        #if DEBUG
            print("[ImageJar 🔥]: \(str)")
        #endif
    }

    // Forces thread to pause while queue flushes tasks
    // Useful for testing
    public func sync() {
        queue.sync { /* Wait, do nothing */ }
    }

    private func diskCacheItem(for url: URL) -> UIImage? {
        guard let data = fileManager.contents(atPath: url.path) else { return nil }
        touch(at: url)
        return UIImage(data: data)
    }

    private func touch(at url: URL) {
        do {
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } catch {
            err(error.localizedDescription)
        }
    }

    private func modificationDateOfCacheEntry(at url: URL) -> Date? {
        do {
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let atts = try fileManager.attributesOfItem(atPath: url.path)
            return atts[.modificationDate] as? Date
        } catch {
            err(error.localizedDescription)
        }
        return nil
    }

    // All methods below should be called synchronously and preferrably within a barrier

    /// synchronous
    private func writeDiskCacheItem(value: UIImage, at url: URL) {
        defer { rebalance() }

        guard let contents = value.pngData() else {
            #if DEBUG
                err("Unable to content for value.")
            #endif
            return
        }
        let creationDate = Date()
        let key = url.path
        // ignore error if already created
        do {
            try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        } catch {
            err(error.localizedDescription)
        }

        do {
            try contents.write(to: url, options: [.atomic])
            try fileManager.setAttributes([.modificationDate: creationDate, .creationDate: creationDate], ofItemAtPath: key)
        } catch {
            #if DEBUG
                err("[ImageJar] Failed to write image to file: \(url.path)")
            #endif
        }

        guard referencesNeedRefresh else {
            lastDiskCacheUpdatedDate = creationDate
            currentDisckCacheSize += contents.count
            updateMetadata(key: key, modificationDate: creationDate, fileSize: contents.count)
            return
        }
        invalidateDiskCache()
    }

    private var referencesNeedRefresh: Bool {
        guard let lastModDate = lastDiskCacheUpdatedDate,
              let lastCacheDirectoryModDate = modificationDateOfCacheEntry(at: cacheDirectoryURL)
        else { return true }

        // Most file systems can only store up to 1 second of precision
        return (lastCacheDirectoryModDate.timeIntervalSinceReferenceDate - lastModDate.timeIntervalSinceReferenceDate) >= fileSystemLevelAccuracy
    }

    private func invalidateDiskCache() {
        currentDisckCacheSize = 0
        lastDiskCacheUpdatedDate = nil
        currentMetaRefs.removeAll(keepingCapacity: true)
    }

    /// Update the metadata reference for our garbage collector. `O(log n)`
    private func updateMetadata(key: String, modificationDate: Date, fileSize: Int) {
        let ref = ContentRef(key: key, modificationDate: modificationDate, fileSize: fileSize)
        // We use a binarySearch on a sorted list of current files in LRU. We keep it sorted so that our
        // Removal algorithm is almost constant time (see rebalance() )
        let insertionIndex = currentMetaRefs.binarySearch { $0.modificationDate < ref.modificationDate }
        currentMetaRefs.insert(ref, at: insertionIndex)
    }

    /// Rebalance our memory and disk capacity limits based on LRU through modificationDate. `O(1)`
    private func rebalance() {
        if referencesNeedRefresh { rebuildDiskCache() }

        while currentMetaRefs.count > maxDiskCacheRecords || currentDisckCacheSize > maxDiskCacheRecordSizeBytes,
              let ref = currentMetaRefs.first
        {
            let url = cacheURL(forKey: ref.key)
            try? fileManager.removeItem(at: url)
            currentDisckCacheSize -= ref.fileSize
            currentMetaRefs.removeFirst()
        }
    }

    // Rebuild the meta list at startup and if an external
    // thread modified the same directory cache within an off-set time period.
    private func rebuildDiskCache() {
        do {
            let dirAttrs = try fileManager.attributesOfItem(atPath: cacheDirectoryURL.path)
            lastDiskCacheUpdatedDate = dirAttrs[.modificationDate] as? Date
            currentDisckCacheSize = 0
            currentMetaRefs.removeAll(keepingCapacity: true)
            guard let enumerator = fileManager.enumerator(atPath: cacheDirectoryURL.path) else { return }
            while let key = enumerator.nextObject() as? String {
                enumerator.skipDescendants()
                if let attrs = enumerator.fileAttributes,
                   let modDate = attrs[.modificationDate] as? Date,
                   let fileSize = attrs[.size] as? Int
                {
                    currentDisckCacheSize += fileSize
                    updateMetadata(key: key, modificationDate: modDate, fileSize: fileSize)
                }
            }
        } catch {
            err(error.localizedDescription)
        }
    }
}

public extension ImageJar {
    subscript(url: URL) -> UIImage? {
        self[url.absoluteString]
    }

    func hasValue(forURL url: URL, maxAge: TimeInterval = defaultMaxAge) -> Bool {
        hasValue(forKey: url.absoluteString, maxAge: maxAge)
    }

    func fetchIfNeeded(url: URL, maxAge: TimeInterval = defaultMaxAge) -> AnyPublisher<UIImage, Never> {
        if let image = get(forKey: url.absoluteString, maxAge: maxAge) {
            return CurrentValueSubject<UIImage, Never>(image).eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<UIImage, Never>()
        var cancellable: AnyCancellable?

        cancellable = fetchAndStore(url: url)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                cancellable?.cancel()
                publisher.send(completion: .finished)
            } receiveValue: { image in
                publisher.send(image)
            }

        return publisher.eraseToAnyPublisher()
    }

    func fetchAndStore(url: URL) -> AnyPublisher<UIImage, Never> {
        let publisher = PassthroughSubject<UIImage, Never>()
        var cancellable: AnyCancellable?
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .retry(3)
            .map(\.data)
            .receive(on: DispatchQueue.main)
            .compactMap { UIImage(data: $0) }
            .sink { _ in
                cancellable?.cancel()
            } receiveValue: { image in
                ImageJar.shared.set(value: image, forURL: url) { image in
                    DispatchQueue.main.async {
                        publisher.send(image)
                        publisher.send(completion: .finished)
                    }
                }
            }
        return publisher.eraseToAnyPublisher()
    }

    func get(forURL url: URL, maxAge: TimeInterval = defaultMaxAge) -> UIImage? {
        get(forKey: url.absoluteString, maxAge: maxAge)
    }

    func set(value: UIImage, forURL url: URL, completion: ImageCompletion? = nil) {
        set(value: value, forKey: url.absoluteString, completion: completion)
    }

    func removeObject(forURL url: URL) {
        removeObject(forKey: url.absoluteString)
    }
}
