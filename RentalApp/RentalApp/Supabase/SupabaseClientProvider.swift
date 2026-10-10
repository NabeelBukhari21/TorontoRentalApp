//
//  SupabaseClientProvider.swift
//  RentalApp (Purrperty)
//
//  Supabase — Configuration and the shared client.
//
//  ─────────────────────────────────────────────────────────────────
//  CREDENTIALS ARE NOT SECRETS, BUT THEY ARE NOT LITERALS EITHER
//  ─────────────────────────────────────────────────────────────────
//  The anon key is designed to ship in a client; it grants nothing on
//  its own because every table is behind RLS. It still does not belong
//  hardcoded in a source file: it differs per environment, and pasting
//  it inline is how a service-role key eventually ends up in git by
//  accident.
//
//  So it is read from Info.plist, populated from `Supabase.xcconfig`,
//  which is gitignored. A missing key is a hard crash at launch rather
//  than a mysterious 401 later.
//

import Foundation
import Supabase

// MARK: - Configuration

struct SupabaseConfig: Sendable {

    let url: URL
    let anonKey: String

    /// Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the bundle.
    ///
    /// - Note: Traps on a missing or malformed value. This is deliberate:
    ///   a build that cannot reach its backend is broken, and failing at
    ///   launch on the developer's machine is far cheaper than shipping
    ///   it and failing on a user's.
    static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfig {
        func requiredValue(_ key: String) -> String {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String,
                  !raw.trimmingCharacters(in: .whitespaces).isEmpty,
                  !raw.hasPrefix("$(") else {
                fatalError(
                    """
                    Missing \(key).

                    Create RentalApp/Supabase.xcconfig with:
                        SUPABASE_URL = https:/$()/your-project.supabase.co
                        SUPABASE_ANON_KEY = your-anon-key

                    then set it as the target's configuration file and add
                    matching Info.plist entries. See supabase/README.md.
                    """
                )
            }
            return raw.trimmingCharacters(in: .whitespaces)
        }

        let raw = requiredValue("SUPABASE_URL")
        guard let url = URL(string: raw), url.scheme == "https" else {
            fatalError("SUPABASE_URL is not a valid https URL: \(raw)")
        }
        return SupabaseConfig(url: url, anonKey: requiredValue("SUPABASE_ANON_KEY"))
    }

    /// Whether credentials are present, WITHOUT trapping.
    ///
    /// `fromBundle()` is right to trap: a build that claims to use Supabase
    /// and cannot reach it is broken. But something has to be able to *ask*
    /// the question before committing to that answer — otherwise the only
    /// way to discover the app is unconfigured is for it to die on launch,
    /// and a preview canvas or a fresh clone dies with it.
    ///
    /// `AppContainer.live()` asks this and falls back to the in-memory
    /// graph, so an unconfigured checkout runs on mock data instead of
    /// crashing.
    static func isConfigured(_ bundle: Bundle = .main) -> Bool {
        func present(_ key: String) -> Bool {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else {
                return false
            }
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            // `$(…)` is an xcconfig variable that was never defined — it
            // expands to its own literal name, which is non-empty and
            // therefore passes a naive check.
            return !trimmed.isEmpty && !trimmed.hasPrefix("$(")
        }
        return present("SUPABASE_URL") && present("SUPABASE_ANON_KEY")
    }
}

// MARK: - Client

/// Owns the single `SupabaseClient` for the process.
///
/// One client, because it also owns the auth session: a second instance
/// would keep its own copy of the tokens and the two would drift apart
/// after a refresh.
@MainActor
final class SupabaseClientProvider {

    let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                db: .init(encoder: SupabaseCoding.encoder, decoder: SupabaseCoding.decoder),
                auth: .init(
                    // The SDK stores tokens in the Keychain and refreshes
                    // them in the background. Our `SessionStore` keeps only
                    // non-sensitive launch hints — see SupabaseAuthService.
                    autoRefreshToken: true
                ),
                global: .init(headers: ["x-client-info": "rentos-ios"])
            )
        )
    }

    /// The production provider, built from bundle configuration.
    static func live() -> SupabaseClientProvider {
        SupabaseClientProvider(config: .fromBundle())
    }
}

// MARK: - Coding

/// JSON coding tuned for PostgREST.
///
/// Postgres returns `timestamptz` with a variable number of fractional
/// digits and `date` with none at all, which the stock ISO-8601 strategy
/// rejects. Handling all three shapes here means no model needs a custom
/// `init(from:)`.
enum SupabaseCoding {

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = fractional.date(from: raw) { return date }
            if let date = plain.date(from: raw) { return date }
            if let date = dateOnly.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unrecognised Postgres timestamp: \(raw)")
            )
        }
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }

    /// Postgres `date` columns (`2026-07-24`) carry no time at all.
    static func dateOnlyString(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    // ISO8601DateFormatter is documented as thread-safe for parsing and
    // formatting, so these are shared rather than rebuilt per field.
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) private static let dateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    nonisolated(unsafe) private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
