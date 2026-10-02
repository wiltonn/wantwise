import Foundation

/// Status changes, as plain functions. See DATA_MODEL.md → Transitions.
///
/// ```
/// captured  ──finishReflection──▶ waiting
/// waiting   ──stillWant─────────▶ stillWant
/// waiting   ──waitLonger────────▶ waiting (new revisitAt)
/// waiting   ──noLongerWant──────▶ noLongerWant
/// stillWant ──purchased─────────▶ purchased
/// ```
public enum TransitionError: Error, Equatable, Sendable {
    case notAllowed(from: WantStatus, kind: DecisionKind)
    case notCaptured(WantStatus)
    case revisitNotInFuture
    case missingRevisitDate
}

/// The result of a decision: the updated Want and the history entry to append.
public struct DecisionOutcome: Sendable, Equatable {
    public var want: Want
    public var decision: WantDecision
}

extension Want {
    /// Which decisions the UI should offer right now. Reconsidering early is allowed for a waiting Want.
    public var allowedDecisions: [DecisionKind] {
        switch status {
        case .captured: return [.noLongerWant]
        case .waiting: return [.stillWant, .waitLonger, .noLongerWant]
        case .stillWant: return [.purchased, .waitLonger, .noLongerWant]
        case .purchased, .noLongerWant: return []
        }
    }

    /// `captured` → `waiting`, once the child has picked a waiting period (e.g. after a quick screenshot capture).
    public func finishingReflection(
        reason: String?,
        similarItemAnswer: SimilarItemAnswer?,
        revisitAt: Date,
        now: Date
    ) throws -> Want {
        guard status == .captured else { throw TransitionError.notCaptured(status) }
        guard revisitAt > now else { throw TransitionError.revisitNotInFuture }
        var want = self
        want.reason = reason.nilIfBlank ?? self.reason
        want.similarItemAnswer = similarItemAnswer ?? self.similarItemAnswer
        want.status = .waiting
        want.revisitAt = revisitAt
        want.waitStartedAt = now
        want.updatedAt = now
        return want
    }

    /// Applies a decision and produces the history entry for it.
    ///
    /// - Parameter newRevisitAt: required for `.waitLonger`, ignored otherwise.
    public func deciding(
        _ kind: DecisionKind,
        note: String? = nil,
        newRevisitAt: Date? = nil,
        decisionId: UUID = UUID(),
        now: Date
    ) throws -> DecisionOutcome {
        guard allowedDecisions.contains(kind) else {
            throw TransitionError.notAllowed(from: status, kind: kind)
        }

        var want = self
        let note = note.nilIfBlank
        var decision = WantDecision(id: decisionId, wantId: id, kind: kind, note: note, decidedAt: now)

        switch kind {
        case .waitLonger:
            guard let newRevisitAt else { throw TransitionError.missingRevisitDate }
            guard newRevisitAt > now else { throw TransitionError.revisitNotInFuture }
            decision.previousRevisitAt = revisitAt
            decision.newRevisitAt = newRevisitAt
            want.status = .waiting
            want.revisitAt = newRevisitAt
            want.waitStartedAt = now
            // Waiting again isn't a final answer.
            want.decidedAt = nil
            want.decisionReason = nil
        case .stillWant:
            want.status = .stillWant
            want.decidedAt = now
            want.decisionReason = note
        case .noLongerWant:
            want.status = .noLongerWant
            want.decidedAt = now
            want.decisionReason = note
        case .purchased:
            want.status = .purchased
            want.decidedAt = now
            want.decisionReason = note
        }

        want.updatedAt = now
        return DecisionOutcome(want: want, decision: decision)
    }

    /// True if the child chose "Wait longer" at least once.
    public func hasWaitedLonger(history: [WantDecision]) -> Bool {
        history.contains { $0.wantId == id && $0.kind == .waitLonger }
    }
}
