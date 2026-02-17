//
//  SessionRepository.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation
import GRDB

// MARK: - Session Repository

final class SessionRepository: SessionRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func create(_ session: ExecutionSession) async throws {
        try await dbQueue.write { db in
            try session.insert(db)
        }
    }

    func update(_ session: ExecutionSession) async throws {
        try await dbQueue.write { db in
            try session.update(db)
        }
    }

    func get(id: UUID) async throws -> ExecutionSession? {
        try await dbQueue.read { db in
            try ExecutionSession.fetchOne(db, key: id.uuidString)
        }
    }

    func getForAgent(agentId: UUID, limit: Int = 50) async throws -> [ExecutionSession] {
        try await dbQueue.read { db in
            try ExecutionSession
                .filter(ExecutionSession.Columns.agentId == agentId.uuidString)
                .order(ExecutionSession.Columns.startedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func getRecent(limit: Int = 50) async throws -> [ExecutionSession] {
        try await dbQueue.read { db in
            try ExecutionSession
                .order(ExecutionSession.Columns.startedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
