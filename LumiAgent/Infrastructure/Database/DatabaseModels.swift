//
//  DatabaseModels.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  GRDB persistence extensions for domain models
//

import Foundation
import GRDB

// MARK: - Agent + GRDB

extension Agent: FetchableRecord, PersistableRecord {
    static let databaseTableName = "agents"

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let configuration = Column("configuration")
        static let capabilities = Column("capabilities")
        static let status = Column("status")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    init(row: Row) throws {
        let configData = row[Columns.configuration] as String
        let capabilitiesData = row[Columns.capabilities] as String

        guard let configuration = try? JSONDecoder().decode(
            AgentConfiguration.self,
            from: configData.data(using: .utf8)!
        ) else {
            throw DatabaseError(message: "Failed to decode agent configuration")
        }

        guard let capabilities = try? JSONDecoder().decode(
            [AgentCapability].self,
            from: capabilitiesData.data(using: .utf8)!
        ) else {
            throw DatabaseError(message: "Failed to decode agent capabilities")
        }

        self.init(
            id: UUID(uuidString: row[Columns.id])!,
            name: row[Columns.name],
            configuration: configuration,
            capabilities: capabilities,
            status: AgentStatus(rawValue: row[Columns.status])!,
            createdAt: row[Columns.createdAt],
            updatedAt: row[Columns.updatedAt]
        )
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.name] = name
        container[Columns.configuration] = try String(
            data: JSONEncoder().encode(configuration),
            encoding: .utf8
        )
        container[Columns.capabilities] = try String(
            data: JSONEncoder().encode(capabilities),
            encoding: .utf8
        )
        container[Columns.status] = status.rawValue
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
}

// MARK: - ExecutionSession + GRDB

extension ExecutionSession: FetchableRecord, PersistableRecord {
    static let databaseTableName = "execution_sessions"

    enum Columns {
        static let id = Column("id")
        static let agentId = Column("agent_id")
        static let userPrompt = Column("user_prompt")
        static let steps = Column("steps")
        static let result = Column("result")
        static let status = Column("status")
        static let startedAt = Column("started_at")
        static let completedAt = Column("completed_at")
    }

    init(row: Row) throws {
        let stepsData = row[Columns.steps] as String
        guard let steps = try? JSONDecoder().decode(
            [ExecutionStep].self,
            from: stepsData.data(using: .utf8)!
        ) else {
            throw DatabaseError(message: "Failed to decode execution steps")
        }

        var result: ExecutionResult?
        if let resultData = row[Columns.result] as String? {
            result = try? JSONDecoder().decode(
                ExecutionResult.self,
                from: resultData.data(using: .utf8)!
            )
        }

        self.init(
            id: UUID(uuidString: row[Columns.id])!,
            agentId: UUID(uuidString: row[Columns.agentId])!,
            userPrompt: row[Columns.userPrompt],
            steps: steps,
            result: result,
            status: ExecutionStatus(rawValue: row[Columns.status])!,
            startedAt: row[Columns.startedAt],
            completedAt: row[Columns.completedAt]
        )
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.agentId] = agentId.uuidString
        container[Columns.userPrompt] = userPrompt
        container[Columns.steps] = try String(
            data: JSONEncoder().encode(steps),
            encoding: .utf8
        )
        if let result = result {
            container[Columns.result] = try String(
                data: JSONEncoder().encode(result),
                encoding: .utf8
            )
        }
        container[Columns.status] = status.rawValue
        container[Columns.startedAt] = startedAt
        container[Columns.completedAt] = completedAt
    }
}


// MARK: - Database Error

struct DatabaseError: Error {
    let message: String
}
