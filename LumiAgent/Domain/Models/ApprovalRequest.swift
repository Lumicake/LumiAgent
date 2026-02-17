//
//  ApprovalRequest.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation

// MARK: - Approval Request

/// Represents a request for user approval before executing an operation
struct ApprovalRequest: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let agentId: UUID
    var toolCall: ToolCall
    var riskLevel: RiskLevel
    var reasoning: String
    var estimatedImpact: String?
    var status: ApprovalStatus
    var userDecision: UserDecision?
    var requestedAt: Date
    var decidedAt: Date?
    var expiresAt: Date

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        agentId: UUID,
        toolCall: ToolCall,
        riskLevel: RiskLevel,
        reasoning: String,
        estimatedImpact: String? = nil,
        status: ApprovalStatus = .pending,
        userDecision: UserDecision? = nil,
        requestedAt: Date = Date(),
        decidedAt: Date? = nil,
        timeout: TimeInterval = 60 // default 60 seconds
    ) {
        self.id = id
        self.sessionId = sessionId
        self.agentId = agentId
        self.toolCall = toolCall
        self.riskLevel = riskLevel
        self.reasoning = reasoning
        self.estimatedImpact = estimatedImpact
        self.status = status
        self.userDecision = userDecision
        self.requestedAt = requestedAt
        self.decidedAt = decidedAt
        self.expiresAt = requestedAt.addingTimeInterval(timeout)
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
}

// MARK: - Approval Status

/// Status of an approval request
enum ApprovalStatus: String, Codable {
    case pending
    case approved
    case denied
    case expired
    case modified

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .expired: return "timer"
        case .modified: return "pencil.circle.fill"
        }
    }
}

// MARK: - User Decision

/// User's decision on an approval request
struct UserDecision: Codable {
    var approved: Bool
    var justification: String?
    var modifiedCommand: String? // If user modified the command
    var timestamp: Date

    init(
        approved: Bool,
        justification: String? = nil,
        modifiedCommand: String? = nil,
        timestamp: Date = Date()
    ) {
        self.approved = approved
        self.justification = justification
        self.modifiedCommand = modifiedCommand
        self.timestamp = timestamp
    }
}

// MARK: - Approval Notification

/// Notification for real-time approval requests
struct ApprovalNotification {
    let requestId: UUID
    let title: String
    let message: String
    let riskLevel: RiskLevel
    let urgency: NotificationUrgency

    init(
        requestId: UUID,
        title: String,
        message: String,
        riskLevel: RiskLevel,
        urgency: NotificationUrgency = .normal
    ) {
        self.requestId = requestId
        self.title = title
        self.message = message
        self.riskLevel = riskLevel
        self.urgency = urgency
    }
}

// MARK: - Notification Urgency

/// Urgency level for notifications
enum NotificationUrgency {
    case low
    case normal
    case high
    case critical

    var soundName: String? {
        switch self {
        case .low: return nil
        case .normal: return "default"
        case .high: return "urgent"
        case .critical: return "critical"
        }
    }
}
