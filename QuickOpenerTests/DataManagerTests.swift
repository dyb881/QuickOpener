//
//  DataManagerTests.swift
//  QuickOpenerTests
//
//  DataManager 核心逻辑的单元测试（使用内存 ModelContainer，不触碰真实数据）。
//

import SwiftData
import XCTest
@testable import QuickOpener

@MainActor
final class DataManagerTests: XCTestCase {
    /// 每个用例一份干净的内存数据库。
    private func makeManager() throws -> DataManager {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ApplicationModel.self, ProjectModel.self,
            configurations: configuration
        )
        return DataManager(modelContext: container.mainContext)
    }

    private var finderPath: String { ApplicationModel.defaultApplicationPath }

    // MARK: - 初始化

    func testSeedsDefaultFinderApplication() throws {
        let manager = try makeManager()
        XCTAssertEqual(manager.applications.filter { $0.path == finderPath }.count, 1)
        XCTAssertEqual(manager.currentApplication.path, finderPath)
        XCTAssertTrue(manager.projects.isEmpty)
    }

    // MARK: - 添加项目

    func testAddProjectsAssignsIncreasingWeights() throws {
        let manager = try makeManager()
        manager.addProjects(urls: [
            URL(fileURLWithPath: "/tmp/qo-a"),
            URL(fileURLWithPath: "/tmp/qo-b"),
        ])
        XCTAssertEqual(manager.projects.count, 2)

        let weights = manager.projects.map { $0.weight }.sorted()
        XCTAssertEqual(weights.count, 2)
        XCTAssertEqual(weights[1], weights[0] + 1) // 以现有最大权重为基准递增
    }

    func testAddProjectsSkipsDuplicatePaths() throws {
        let manager = try makeManager()
        let url = URL(fileURLWithPath: "/tmp/qo-dup")
        manager.addProjects(urls: [url])
        manager.addProjects(urls: [url])
        XCTAssertEqual(manager.projects.filter { $0.path == url.path }.count, 1)
    }

    func testNewProjectsSortToTop() throws {
        let manager = try makeManager()
        manager.addProjects(urls: [URL(fileURLWithPath: "/tmp/qo-first")])
        manager.addProjects(urls: [URL(fileURLWithPath: "/tmp/qo-second")])
        XCTAssertEqual(manager.renderProjects.first?.path, "/tmp/qo-second")
    }

    // MARK: - 时间衰减排序

    func testRenderProjectsDecaysStaleWeights() throws {
        let manager = try makeManager()
        manager.addProjects(urls: [
            URL(fileURLWithPath: "/tmp/qo-old"),
            URL(fileURLWithPath: "/tmp/qo-fresh"),
        ])
        let old = try XCTUnwrap(manager.projects.first { $0.path == "/tmp/qo-old" })
        let fresh = try XCTUnwrap(manager.projects.first { $0.path == "/tmp/qo-fresh" })

        old.weight = 10
        old.lastOpenedAt = Date().addingTimeInterval(-30 * 24 * 3600) // 30 天前，衰减到约 5%
        fresh.weight = 2
        fresh.lastOpenedAt = Date()

        XCTAssertEqual(manager.renderProjects.first?.path, "/tmp/qo-fresh")
    }

    // MARK: - 删除应用时的引用回退

    func testRemoveApplicationFallsBackBoundProjects() throws {
        let manager = try makeManager()
        manager.addApplication(path: "/Applications/TextEdit.app")
        manager.addProjects(urls: [URL(fileURLWithPath: "/tmp/qo-bound")])

        let app = try XCTUnwrap(manager.applications.first { $0.path == "/Applications/TextEdit.app" })
        let project = try XCTUnwrap(manager.projects.first)
        XCTAssertEqual(project.applicationPath, app.path) // 新项目继承当前应用

        manager.removeApplication(app)

        XCTAssertEqual(project.applicationPath, finderPath) // 回退到 Finder，不是悬空路径
        XCTAssertEqual(manager.currentApplication.path, finderPath) // 当前应用也回退
        XCTAssertFalse(manager.applications.contains { $0.path == "/Applications/TextEdit.app" })
    }

    func testFinderCannotBeRemoved() throws {
        let manager = try makeManager()
        let finder = try XCTUnwrap(manager.applications.first { $0.path == finderPath })
        manager.removeApplication(finder)
        XCTAssertTrue(manager.applications.contains { $0.path == finderPath })
    }

    // MARK: - 导入 / 导出

    func testExportImportRoundTripSkipsDuplicates() throws {
        let source = try makeManager()
        source.addProjects(urls: [
            URL(fileURLWithPath: "/tmp/qo-exp-1"),
            URL(fileURLWithPath: "/tmp/qo-exp-2"),
        ])
        let data = try XCTUnwrap(source.exportPayload())

        let target = try makeManager()
        let first = try XCTUnwrap(target.importPayload(from: data))
        XCTAssertEqual(first.added, 2)
        XCTAssertEqual(first.skipped, 0)
        XCTAssertEqual(target.projects.count, 2)

        let second = try XCTUnwrap(target.importPayload(from: data))
        XCTAssertEqual(second.added, 0)
        XCTAssertEqual(second.skipped, 2)
        XCTAssertEqual(target.projects.count, 2)
    }

    func testImportRejectsInvalidPayload() throws {
        let manager = try makeManager()
        let bad = Data("not json".utf8)
        XCTAssertNil(manager.importPayload(from: bad))
        XCTAssertTrue(manager.projects.isEmpty)
    }

    // MARK: - 键盘选中索引

    func testSelectionClampsWithinBounds() throws {
        let manager = try makeManager()
        manager.addProjects(urls: [
            URL(fileURLWithPath: "/tmp/qo-sel-1"),
            URL(fileURLWithPath: "/tmp/qo-sel-2"),
        ])

        manager.selectedIndex = 0
        manager.moveSelection(by: -1)
        XCTAssertEqual(manager.selectedIndex, 0) // 顶部不越界

        manager.moveSelection(by: 1)
        manager.moveSelection(by: 5)
        XCTAssertEqual(manager.selectedIndex, 1) // 底部不越界
        XCTAssertNotNil(manager.selectedProject)
    }

    func testClearCacheResetsFilterAndKeepsFinder() throws {
        let manager = try makeManager()
        manager.addProjects(urls: [URL(fileURLWithPath: "/tmp/qo-cache")])
        manager.filterText = "qo-cache"
        manager.clearCache()

        XCTAssertTrue(manager.projects.isEmpty)
        XCTAssertEqual(manager.filterText, "")
        XCTAssertEqual(manager.applications.count, 1)
        XCTAssertEqual(manager.applications.first?.path, finderPath)
        XCTAssertNil(manager.selectedProject)
    }
}
