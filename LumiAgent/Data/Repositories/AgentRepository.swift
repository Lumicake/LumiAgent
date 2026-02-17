//
//  AgentRepository.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation
import GRDB

// MARK: - Agent Repository

final class AgentRepository: AgentRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func create(_ agent: Agent) async throws {
        try await dbQueue.write { db in
            try agent.insert(db)
        }
    }

    func update(_ agent: Agent) async throws {
        var updatedAgent = agent
        updatedAgent.updatedAt = Date()
        let agentToUpdate = updatedAgent
        _ = try await dbQueue.write { db in
            try agentToUpdate.update(db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await dbQueue.write { db in
            try Agent.deleteOne(db, key: id.uuidString)
        }
    }

    func get(id: UUID) async throws -> Agent? {
        try await dbQueue.read { db in
            try Agent.fetchOne(db, key: id.uuidString)
        }
    }

    func getAll() async throws -> [Agent] {
        try await dbQueue.read { db in
            try Agent.order(Agent.Columns.name).fetchAll(db)
        }
    }

    func getByStatus(_ status: AgentStatus) async throws -> [Agent] {
        try await dbQueue.read { db in
            try Agent
                .filter(Agent.Columns.status == status.rawValue)
                .order(Agent.Columns.name)
                .fetchAll(db)
        }
    }
}
