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

// MARK: - ApprovalRequest + GRDB

extension ApprovalRequest: FetchableRecord, PersistableRecord {
    static let databaseTableName = "approval_requests"

    enum Columns {
        static let id = Column("id")
        static let sessionId = Column("session_id")
        static let agentId = Column("agent_id")
        static let toolCall = Column("tool_call")
        static let riskLevel = Column("risk_level")
        static let reasoning = Column("reasoning")
        static let estimatedImpact = Column("estimated_impact")
        static let status = Column("status")
        static let userDecision = Column("user_decision")
        static let requestedAt = Column("requested_at")
        static let decidedAt = Column("decided_at")
        static let expiresAt = Column("expires_at")
    }

    init(row: Row) throws {
        let toolCallData = row[Columns.toolCall] as String
        guard let toolCall = try? JSONDecoder().decode(
            ToolCall.self,
            from: toolCallData.data(using: .utf8)!
        ) else {
            throw DatabaseError(message: "Failed to decode tool call")
        }

        var userDecision: UserDecision?
        if let decisionData = row[Columns.userDecision] as String? {
            userDecision = try? JSONDecoder().decode(
                UserDecision.self,
                from: decisionData.data(using: .utf8)!
            )
        }

        self.init(
            id: UUID(uuidString: row[Columns.id])!,
            sessionId: UUID(uuidString: row[Columns.sessionId])!,
            agentId: UUID(uuidString: row[Columns.agentId])!,
            toolCall: toolCall,
            riskLevel: RiskLevel(rawValue: row[Columns.riskLevel])!,
            reasoning: row[Columns.reasoning],
            estimatedImpact: row[Columns.estimatedImpact],
            status: ApprovalStatus(rawValue: row[Columns.status])!,
            userDecision: userDecision,
            requestedAt: row[Columns.requestedAt],
            decidedAt: row[Columns.decidedAt]
        )
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.sessionId] = sessionId.uuidString
        container[Columns.agentId] = agentId.uuidString
        container[Columns.toolCall] = try String(
            data: JSONEncoder().encode(toolCall),
            encoding: .utf8
        )
        container[Columns.riskLevel] = riskLevel.rawValue
        container[Columns.reasoning] = reasoning
        container[Columns.estimatedImpact] = estimatedImpact
        container[Columns.status] = status.rawValue
        if let userDecision = userDecision {
            container[Columns.userDecision] = try String(
                data: JSONEncoder().encode(userDecision),
                encoding: .utf8
            )
        }
        container[Columns.requestedAt] = requestedAt
        container[Columns.decidedAt] = decidedAt
        container[Columns.expiresAt] = expiresAt
    }
}

// MARK: - AuditLog + GRDB

extension AuditLog: FetchableRecord, PersistableRecord {
    static let databaseTableName = "audit_logs"

    enum Columns {
        static let id = Column("id")
        static let eventType = Column("event_type")
        static let severity = Column("severity")
        static let timestamp = Column("timestamp")
        static let agentId = Column("agent_id")
        static let sessionId = Column("session_id")
        static let userId = Column("user_id")
        static let action = Column("action")
        static let target = Column("target")
        static let result = Column("result")
        static let details = Column("details")
        static let ipAddress = Column("ip_address")
        static let hostname = Column("hostname")
    }

    init(row: Row) throws {
        var details: [String: String]?
        if let detailsData = row[Columns.details] as String? {
            details = try? JSONDecoder().decode(
                [String: String].self,
                from: detailsData.data(using: .utf8)!
            )
        }

        self.init(
            id: UUID(uuidString: row[Columns.id])!,
            eventType: AuditEventType(rawValue: row[Columns.eventType])!,
            severity: AuditSeverity(rawValue: row[Columns.severity])!,
            timestamp: row[Columns.timestamp],
            agentId: (row[Columns.agentId] as String?).flatMap { UUID(uuidString: $0) },
            sessionId: (row[Columns.sessionId] as String?).flatMap { UUID(uuidString: $0) },
            userId: row[Columns.userId],
            action: row[Columns.action],
            target: row[Columns.target],
            result: AuditResult(rawValue: row[Columns.result])!,
            details: details,
            ipAddress: row[Columns.ipAddress],
            hostname: row[Columns.hostname]
        )
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.eventType] = eventType.rawValue
        container[Columns.severity] = severity.rawValue
        container[Columns.timestamp] = timestamp
        container[Columns.agentId] = agentId?.uuidString
        container[Columns.sessionId] = sessionId?.uuidString
        container[Columns.userId] = userId
        container[Columns.action] = action
        container[Columns.target] = target
        container[Columns.result] = result.rawValue
        if let details = details {
            container[Columns.details] = try String(
                data: JSONEncoder().encode(details),
                encoding: .utf8
            )
        }
        container[Columns.ipAddress] = ipAddress
        container[Columns.hostname] = hostname
    }
}

// MARK: - Database Error

struct DatabaseError: Error {
    let message: String
}
