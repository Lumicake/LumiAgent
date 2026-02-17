//
//  ApprovalRepository.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation
import GRDB

// MARK: - Approval Repository

final class ApprovalRepository: ApprovalRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func create(_ request: ApprovalRequest) async throws {
        try await dbQueue.write { db in
            try request.insert(db)
        }
    }

    func update(_ request: ApprovalRequest) async throws {
        try await dbQueue.write { db in
            try request.update(db)
        }
    }

    func get(id: UUID) async throws -> ApprovalRequest? {
        try await dbQueue.read { db in
            try ApprovalRequest.fetchOne(db, key: id.uuidString)
        }
    }

    func getPending() async throws -> [ApprovalRequest] {
        try await dbQueue.read { db in
            try ApprovalRequest
                .filter(ApprovalRequest.Columns.status == ApprovalStatus.pending.rawValue)
                .order(ApprovalRequest.Columns.requestedAt)
                .fetchAll(db)
        }
    }

    func getForSession(sessionId: UUID) async throws -> [ApprovalRequest] {
        try await dbQueue.read { db in
            try ApprovalRequest
                .filter(ApprovalRequest.Columns.sessionId == sessionId.uuidString)
                .order(ApprovalRequest.Columns.requestedAt)
                .fetchAll(db)
        }
    }

    func expireOldRequests() async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE approval_requests
                SET status = ?
                WHERE status = ? AND expires_at < ?
                """,
                arguments: [
                    ApprovalStatus.expired.rawValue,
                    ApprovalStatus.pending.rawValue,
                    Date()
                ]
            )
        }
    }
}
