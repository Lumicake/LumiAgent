//
//  AgentRepositoryProtocol.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation

// MARK: - Agent Repository Protocol

protocol AgentRepositoryProtocol {
    func create(_ agent: Agent) async throws
    func update(_ agent: Agent) async throws
    func delete(id: UUID) async throws
    func get(id: UUID) async throws -> Agent?
    func getAll() async throws -> [Agent]
    func getByStatus(_ status: AgentStatus) async throws -> [Agent]
}

// MARK: - Session Repository Protocol

protocol SessionRepositoryProtocol {
    func create(_ session: ExecutionSession) async throws
    func update(_ session: ExecutionSession) async throws
    func get(id: UUID) async throws -> ExecutionSession?
    func getForAgent(agentId: UUID, limit: Int) async throws -> [ExecutionSession]
    func getRecent(limit: Int) async throws -> [ExecutionSession]
}

// MARK: - Approval Repository Protocol

protocol ApprovalRepositoryProtocol {
    func create(_ request: ApprovalRequest) async throws
    func update(_ request: ApprovalRequest) async throws
    func get(id: UUID) async throws -> ApprovalRequest?
    func getPending() async throws -> [ApprovalRequest]
    func getForSession(sessionId: UUID) async throws -> [ApprovalRequest]
    func expireOldRequests() async throws
}

// MARK: - Audit Repository Protocol

protocol AuditRepositoryProtocol {
    func log(_ entry: AuditLog) async throws
    func query(_ query: AuditQuery) async throws -> [AuditLog]
    func export(query: AuditQuery) async throws -> URL
}
