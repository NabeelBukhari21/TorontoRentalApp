//
//  AIRouter.swift
//  RentalApp (RentOS)
//
//  Core — Provider selection and failover.
//
//  A single provider is a single point of failure, and the failure modes
//  are routine rather than exotic: rate limits, regional outages, a
//  model deprecated with two weeks' notice. The router turns that into a
//  degraded-but-working experience instead of a broken screen.
//
//  It deliberately does NOT retry every error. A content filter or a
//  schema the model can't satisfy will fail the same way at every vendor,
//  so retrying those just spends money to arrive at the same answer more
//  slowly — see `AIError.isWorthFailingOver`.
//

import Foundation

/// Ordered provider list with capability matching and failover.
actor AIRouter {

    /// Ordered by preference. First available provider that supports the
    /// requested capability wins.
    private let providers: [AIProviderProtocol]

    /// Providers that recently failed, with the time they may be retried.
    /// Prevents hammering a provider that is down for the next minute.
    private var cooldowns: [String: Date] = [:]
    private let cooldownDuration: TimeInterval

    init(providers: [AIProviderProtocol], cooldownDuration: TimeInterval = 60) {
        self.providers = providers
        self.cooldownDuration = cooldownDuration
    }

    /// Runs the request against the first viable provider, falling through
    /// on retryable failures.
    ///
    /// - Returns: the response, plus which provider answered so the caller
    ///   can record a fallback having happened.
    func complete(_ request: AIRequest) async throws -> AIResponse {
        let candidates = viableProviders(for: request.preference)
        guard !candidates.isEmpty else {
            // Nothing supports this capability — surface the specific
            // reason rather than a generic outage.
            throw providers.isEmpty ? AIError.notConfigured
                                    : AIError.unsupportedPreference(request.preference)
        }

        var lastError: AIError = .allProvidersFailed

        for provider in candidates {
            do {
                let response = try await provider.complete(request)
                clearCooldown(provider.id)
                return response
            } catch let error as AIError {
                lastError = error
                guard error.isWorthFailingOver else { throw error }
                markCooldown(provider.id, after: error)
            } catch is CancellationError {
                throw AIError.cancelled
            } catch {
                lastError = .transport(error.localizedDescription)
                markCooldown(provider.id, after: lastError)
            }
        }

        throw lastError
    }

    // MARK: Candidates

    private func viableProviders(for preference: AIModelPreference) -> [AIProviderProtocol] {
        let now = Date()
        let matching = providers.filter {
            $0.isAvailable && $0.supportedPreferences.contains(preference)
        }

        // Providers in cooldown go to the back rather than being dropped:
        // if every provider is cooling down, a slow answer still beats no
        // answer.
        let ready = matching.filter { (cooldowns[$0.id] ?? .distantPast) <= now }
        let cooling = matching.filter { (cooldowns[$0.id] ?? .distantPast) > now }
        return ready + cooling
    }

    private func markCooldown(_ id: String, after error: AIError) {
        let interval: TimeInterval
        if case .rateLimited(let retryAfter) = error {
            interval = retryAfter ?? cooldownDuration
        } else {
            interval = cooldownDuration
        }
        cooldowns[id] = Date().addingTimeInterval(interval)
    }

    private func clearCooldown(_ id: String) {
        cooldowns.removeValue(forKey: id)
    }

    /// Exposed for the diagnostics row in Settings → AI.
    func status() -> [AIProviderStatus] {
        let now = Date()
        return providers.map {
            AIProviderStatus(
                id: $0.id,
                isAvailable: $0.isAvailable,
                preferences: $0.supportedPreferences,
                cooldownUntil: (cooldowns[$0.id]).flatMap { $0 > now ? $0 : nil }
            )
        }
    }
}

struct AIProviderStatus: Sendable, Identifiable {
    let id: String
    let isAvailable: Bool
    let preferences: Set<AIModelPreference>
    let cooldownUntil: Date?
}
