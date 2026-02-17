//
//  ApprovalFlow.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  Manages approval request queue and notifications
//

import Foundation
import Combine

// MARK: - Approval Flow

/// Coordinates approval requests and user notifications
@MainActor
final class ApprovalFlow: ObservableObject {
    // MARK: - Published Properties

    @Published var pendingRequests: [ApprovalRequest] = []
    @Published var currentRequest: ApprovalRequest?

    // MARK: - Properties

    private let approvalRepository: ApprovalRepositoryProtocol
    private let authorizationManager: AuthorizationManager
    private var expirationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.approvalRepository = ApprovalRepository()
        self.authorizationManager = AuthorizationManager.shared
        startExpirationTimer()
    }

    deinit {
        expirationTimer?.invalidate()
    }

    // MARK: - Request Management

    /// Submit a new approval request
    func submitRequest(
        _ request: ApprovalRequest
    ) async {
        pendingRequests.append(request)

        // If no current request, show this one
        if currentRequest == nil {
            currentRequest = request
        }

        // Send notification
        sendNotification(for: request)
    }

    /// Approve the current request
    func approveCurrent(
        justification: String? = nil,
        modifiedCommand: String? = nil
    ) async throws {
        guard let request = currentRequest else { return }

        try await authorizationManager.approve(
            requestId: request.id,
            justification: justification,
            modifiedCommand: modifiedCommand
        )

        // Remove from pending
        removeCurrent()
    }

    /// Deny the current request
    func denyCurrent(
        justification: String? = nil
    ) async throws {
        guard let request = currentRequest else { return }

        try await authorizationManager.deny(
            requestId: request.id,
            justification: justification
        )

        // Remove from pending
        removeCurrent()
    }

    /// Skip to next request
    func skipToNext() {
        removeCurrent()
    }

    // MARK: - Private Methods

    private func removeCurrent() {
        guard let request = currentRequest else { return }

        // Remove from pending list
        pendingRequests.removeAll { $0.id == request.id }

        // Show next pending request
        currentRequest = pendingRequests.first
    }

    /// Refresh pending requests from database
    func refreshPendingRequests() async {
        do {
            let requests = try await approvalRepository.getPending()
            pendingRequests = requests
            if currentRequest == nil {
                currentRequest = requests.first
            }
        } catch {
            print("Error refreshing pending requests: \(error)")
        }
    }

    /// Start timer to check for expired requests
    private func startExpirationTimer() {
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkExpiredRequests()
            }
        }
    }

    /// Check and expire old requests
    private func checkExpiredRequests() async {
        // Update expired requests in database
        try? await approvalRepository.expireOldRequests()

        // Remove expired from pending list
        pendingRequests.removeAll { $0.isExpired }

        // If current request expired, move to next
        if let current = currentRequest, current.isExpired {
            removeCurrent()
        }
    }

    /// Send system notification for approval request
    private func sendNotification(for request: ApprovalRequest) {
        // TODO: Implement macOS notification using UserNotifications framework
        // For now, just log
        print("🔔 Approval Required: \(request.toolCall.name) - Risk: \(request.riskLevel.displayName)")
    }
}

// MARK: - Approval Decision

struct ApprovalDecision {
    let approved: Bool
    let justification: String?
    let modifiedCommand: String?
    let timestamp: Date

    init(
        approved: Bool,
        justification: String? = nil,
        modifiedCommand: String? = nil
    ) {
        self.approved = approved
        self.justification = justification
        self.modifiedCommand = modifiedCommand
        self.timestamp = Date()
    }
}
