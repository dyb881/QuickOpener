//
//  ProjectInspector.swift
//  QuickOpener
//
//  项目元数据巡检：目录体量、文件数、Git 分支。
//
//  这些字段都必须读盘，其中目录遍历在 iCloud 路径上可能耗时数秒，
//  因此统一走后台任务 + 结果缓存，界面只负责展示（未就绪时显示骨架条）。
//

import Combine
import Foundation

/// 目录体量统计结果。
struct DirectoryStats {
    let bytes: Int64
    let files: Int
    let folders: Int
}

/// 按需巡检项目元数据，结果缓存在内存里。
///
/// 调用方只需 `inspect(path:)`，重复调用是幂等的；
/// 连续按上下键切换项目时，只有第一次会真正遍历目录。
@MainActor
final class ProjectInspector: ObservableObject {
    static let shared = ProjectInspector()

    /// 已算好的体量：path -> 统计
    @Published private(set) var stats: [String: DirectoryStats] = [:]

    /// 已读到的分支：path -> 分支名（空串表示确认不是 Git 仓库，避免反复重试）
    @Published private(set) var branches: [String: String] = [:]

    /// 正在进行的任务键，避免重复派发。
    private var inFlight: Set<String> = []

    /// 目录项上限：超大目录不必算到最后一字节，避免卡在数十万文件上。
    private let entryLimit = 20_000

    private init() {}

    func stats(for path: String) -> DirectoryStats? { stats[path] }

    func branch(for path: String) -> String? {
        guard let value = branches[path], !value.isEmpty else { return nil }
        return value
    }

    /// 请求巡检某个项目（幂等）。
    ///
    /// 必须带书签：app 开了沙盒，裸 `FileManager` 读用户目录只在本次授权内有效，
    /// 重启后不解析书签就拿不到访问权，遍历会静默失败。
    func inspect(project: ProjectModel) {
        let path = project.path
        let bookmark = project.bookmarkData

        if stats[path] == nil, !inFlight.contains(path) {
            inFlight.insert(path)
            let limit = entryLimit
            Task.detached(priority: .utility) { [weak self] in
                let result = Self.measure(path: path, bookmark: bookmark, limit: limit)
                await self?.applyStats(result, for: path)
            }
        }

        let gitKey = "git:" + path
        if branches[path] == nil, !inFlight.contains(gitKey) {
            inFlight.insert(gitKey)
            Task.detached(priority: .utility) { [weak self] in
                let name = Self.readBranch(path: path, bookmark: bookmark)
                await self?.applyBranch(name, for: path)
            }
        }
    }

    /// 项目被删除时清掉缓存，避免路径复用后显示旧数值。
    func forget(path: String) {
        stats[path] = nil
        branches[path] = nil
    }

    // MARK: - 结果回填

    private func applyStats(_ result: DirectoryStats?, for path: String) {
        stats[path] = result
        inFlight.remove(path)
    }

    private func applyBranch(_ name: String?, for path: String) {
        branches[path] = name ?? ""
        inFlight.remove("git:" + path)
    }

    // MARK: - 后台工作

    /// 在安全作用域内执行读盘操作（沙盒必需）。
    nonisolated private static func withScopedAccess<T>(
        path: String,
        bookmark: Data?,
        _ body: (String) -> T
    ) -> T {
        var scopedURL: URL?
        var accessing = false

        if let bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                scopedURL = url
                accessing = url.startAccessingSecurityScopedResource()
            }
        }

        defer {
            if accessing { scopedURL?.stopAccessingSecurityScopedResource() }
        }

        // 书签解析成功就用它解析出来的路径（iCloud 路径可能已迁移）
        return body(scopedURL?.path ?? path)
    }

    /// 遍历目录累计字节数与条目数。返回 nil 表示路径不存在或不可读。
    nonisolated private static func measure(path: String, bookmark: Data?, limit: Int) -> DirectoryStats? {
        withScopedAccess(path: path, bookmark: bookmark) { resolved in
            measureUnscoped(path: resolved, limit: limit)
        }
    }

    nonisolated private static func measureUnscoped(path: String, limit: Int) -> DirectoryStats? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = fm.enumerator(atPath: path) else { return nil }

        var bytes: Int64 = 0
        var files = 0
        var folders = 0
        var visited = 0

        for case let item as String in enumerator {
            visited += 1
            if visited > limit { break }

            let full = (path as NSString).appendingPathComponent(item)
            guard let attributes = try? fm.attributesOfItem(atPath: full) else { continue }

            if (attributes[.type] as? FileAttributeType) == .typeDirectory {
                folders += 1
            } else {
                files += 1
                bytes += (attributes[.size] as? NSNumber)?.int64Value ?? 0
            }
        }

        return DirectoryStats(bytes: bytes, files: files, folders: folders)
    }

    /// 读 `.git/HEAD` 拿分支名；detached HEAD 时退回短 hash。
    nonisolated private static func readBranch(path: String, bookmark: Data?) -> String? {
        withScopedAccess(path: path, bookmark: bookmark) { resolved in
            readBranchUnscoped(path: resolved)
        }
    }

    nonisolated private static func readBranchUnscoped(path: String) -> String? {
        let headPath = (path as NSString).appendingPathComponent(".git/HEAD")
        guard let text = try? String(contentsOfFile: headPath, encoding: .utf8) else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let refPrefix = "ref: refs/heads/"
        if trimmed.hasPrefix(refPrefix) {
            return String(trimmed.dropFirst(refPrefix.count))
        }
        return trimmed.isEmpty ? nil : String(trimmed.prefix(7))
    }

    // MARK: - 展示

    /// 字节数格式化，如 `12.4 MB`。
    nonisolated static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }
}
