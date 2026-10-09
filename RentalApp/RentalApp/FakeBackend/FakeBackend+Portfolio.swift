//
//  FakeBackend+Portfolio.swift
//  RentalApp (RentOS)
//
//  Fake Backend — Staff, vendors, and the physical portfolio.
//

import Foundation

extension FakeBackend {

    // MARK: - Users

    static func makeUsers(
        orgID: Domain.Identifier<Domain.Organization>,
        rng: inout SeededRandom
    ) -> [Domain.User] {
        TorontoSeeds.staff.enumerated().map { index, member in
            let role: Domain.User.Role = switch member.role {
            case "Owner": .owner
            case "Maintenance Coordinator": .maintenanceCoordinator
            case "Accountant": .viewer
            default: .propertyManager
            }
            return Domain.User(
                id: .init(rng.uuid()),
                organizationID: orgID,
                email: member.email,
                fullName: member.name,
                phone: "(416) 555-0\(100 + index * 7)",
                jobTitle: member.role,
                role: role,
                status: index == 3 ? .invited : .active,
                lastSeenAt: rng.date(daysAgo: 0...4)
            )
        }
    }

    // MARK: - Vendors

    static func makeVendors(
        orgID: Domain.Identifier<Domain.Organization>,
        rng: inout SeededRandom
    ) -> [Domain.Vendor] {
        TorontoSeeds.vendors.map { seed in
            let jobs = rng.int(28...340)
            return Domain.Vendor(
                id: .init(rng.uuid()),
                organizationID: orgID,
                companyName: seed.company,
                contactName: seed.contact,
                email: Self.email(for: seed.contact, domain: Self.domain(for: seed.company)),
                phone: "(\(rng.pick([416, 647, 905]))) 555-0\(rng.int(100...999))",
                trades: [seed.trade],
                responseTimeHours: rng.weighted([(2, 3), (4, 5), (6, 4), (12, 2), (24, 2)]),
                hourlyRate: .init(Decimal(rng.int(75...165))),
                handlesEmergencies: rng.chance(0.45),
                rating: Decimal(Double(rng.int(41...50)) / 10.0),
                completedJobCount: jobs,
                isInsured: true,
                insuranceExpiresAt: rng.date(daysAhead: -20...400),
                isPreferred: jobs > 180 && rng.chance(0.6)
            )
        }
    }

    // MARK: - Portfolio

    static func makePortfolio(
        orgID: Domain.Identifier<Domain.Organization>,
        users: [Domain.User],
        rng: inout SeededRandom
    ) -> (properties: [Domain.Property],
          buildings: [Domain.Building],
          units: [Domain.Unit]) {

        var properties: [Domain.Property] = []
        var buildings: [Domain.Building] = []
        var units: [Domain.Unit] = []

        let managers = users.filter { $0.role.canManagePortfolio }
        // One property per neighbourhood keeps the map spread across the city.
        let hoods = rng.sample(TorontoSeeds.neighbourhoods, count: 14)

        for hood in hoods {
            // Shape drives everything downstream: unit count, rent, layout.
            let kind: Domain.Property.Kind = rng.weighted([
                (.multiUnit, 4), (.condo, 3), (.house, 2), (.mixedUse, 1), (.commercial, 0.5)
            ])

            let unitCount: Int = switch kind {
            case .condo: rng.int(1...3)
            case .house: rng.int(1...2)
            case .duplex, .triplex: rng.int(2...3)
            case .commercial: rng.int(2...6)
            default: rng.int(4...26)
            }

            let name = "\(rng.pick(TorontoSeeds.propertyPrefixes)) \(rng.pick(TorontoSeeds.propertySuffixes))"
            let street = rng.pick(hood.streets)
            let yearBuilt = rng.weighted([
                (rng.int(1890...1949), 2), (rng.int(1950...1989), 3), (rng.int(1990...2024), 4)
            ])

            let propertyID = Domain.Identifier<Domain.Property>(rng.uuid())
            let address = Domain.Address(
                line1: "\(rng.int(3...2480)) \(street)",
                city: "Toronto",
                postalCode: TorontoSeeds.postalCode(fsa: hood.fsa, generator: &rng),
                latitude: 43.60 + rng.double(0...0.20),
                longitude: -79.55 + rng.double(0...0.35)
            )

            properties.append(
                Domain.Property(
                    id: propertyID,
                    organizationID: orgID,
                    name: name,
                    neighborhood: hood.name,
                    address: address,
                    kind: kind,
                    yearBuilt: yearBuilt,
                    squareFeet: unitCount * rng.int(620...980),
                    purchasePrice: .init(Decimal(rng.int(780, 4_200) * 1_000)),
                    purchaseDate: rng.date(daysAgo: 400...4_200),
                    marketValue: .init(Decimal(rng.int(950, 5_400) * 1_000)),
                    managerID: managers.isEmpty ? nil : rng.pick(managers).id,
                    status: .active
                )
            )

            // Larger properties get multiple structures.
            let structureCount = unitCount > 18 ? rng.int(2...3) : 1
            var remaining = unitCount

            for structure in 0..<structureCount {
                let isLast = structure == structureCount - 1
                let share = isLast ? remaining : max(1, unitCount / structureCount)
                remaining -= share

                let buildingID = Domain.Identifier<Domain.Building>(rng.uuid())
                let buildingName = structureCount == 1
                    ? "Main Building"
                    : ["Tower A", "Tower B", "Tower C"][structure]

                buildings.append(
                    Domain.Building(
                        id: buildingID,
                        organizationID: orgID,
                        propertyID: propertyID,
                        name: buildingName,
                        floorCount: max(1, share / 4),
                        hasElevator: share > 12,
                        yearBuilt: yearBuilt,
                        accessNotes: rng.chance(0.4)
                            ? "Lockbox at side entrance — code on file with the office."
                            : nil
                    )
                )

                for index in 0..<max(share, 1) {
                    units.append(
                        Self.makeUnit(
                            index: index,
                            orgID: orgID,
                            propertyID: propertyID,
                            buildingID: buildingID,
                            kind: kind,
                            hood: hood,
                            rng: &rng
                        )
                    )
                }
            }
        }

        return (properties, buildings, units)
    }

    /// One unit, with rent derived from neighbourhood index and layout
    /// rather than picked at random — so a two-bedroom in Yorkville
    /// really does cost more than a studio in Scarborough.
    private static func makeUnit(
        index: Int,
        orgID: Domain.Identifier<Domain.Organization>,
        propertyID: Domain.Identifier<Domain.Property>,
        buildingID: Domain.Identifier<Domain.Building>,
        kind: Domain.Property.Kind,
        hood: TorontoSeeds.Neighbourhood,
        rng: inout SeededRandom
    ) -> Domain.Unit {

        let bedrooms = rng.weighted([(0, 1.0), (1, 4.0), (2, 3.0), (3, 1.2)])
        let bathrooms: Decimal = bedrooms >= 2 && rng.chance(0.5) ? 2 : 1

        // 2026 Toronto baselines by bedroom count.
        let base: Int = switch bedrooms {
        case 0: 1_760
        case 1: 2_180
        case 2: 2_860
        default: 3_540
        }
        // Split and explicitly typed: as one expression this mixed Int,
        // Double and Decimal literals across four operators and blew the
        // type-checker's budget. It was also wrong — `Int` has no
        // `rounded()`, so the rounding never happened.
        let variance: Double = rng.double(0.94...1.08)
        let rawRent: Double = Double(base) * hood.rentIndex * variance
        let rent: Int = Int((rawRent / 10).rounded()) * 10

        let floor = index / 4 + 1
        let label: String = switch kind {
        case .house: index == 0 ? "Main Unit" : "Lower Unit"
        case .condo: "Suite \(floor)\(String(format: "%02d", index % 4 + 1))"
        case .commercial: "Bay \(index + 1)"
        default: "Unit \(floor)\(String(format: "%02d", index % 4 + 1))"
        }

        let amenityPool = Domain.Unit.Amenity.allCases
        let amenities = rng.sample(amenityPool, count: rng.int(0...4))

        return Domain.Unit(
            id: .init(rng.uuid()),
            organizationID: orgID,
            propertyID: propertyID,
            buildingID: buildingID,
            label: label,
            floor: floor,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            squareFeet: 420 + bedrooms * rng.int(230...320),
            layout: bedrooms == 0 ? .studio : (kind == .commercial ? .commercial : .apartment),
            marketRent: .init(Decimal(rent)),
            depositAmount: .init(Decimal(rent)),
            status: .vacant, // Corrected once leases are generated.
            amenities: amenities
        )
    }

    /// Derives unit occupancy from the leases that actually exist.
    static func applyOccupancy(
        to units: [Domain.Unit],
        leases: [Domain.Lease]
    ) -> [Domain.Unit] {
        var leaseByUnit: [Domain.Identifier<Domain.Unit>: Domain.Lease] = [:]
        for lease in leases where lease.status.isCurrent {
            leaseByUnit[lease.unitID] = lease
        }

        return units.map { unit in
            var updated = unit
            if let lease = leaseByUnit[unit.id] {
                updated.status = lease.status == .expiring ? .notice : .occupied
            }
            return updated
        }
    }

    // MARK: - Helpers

    static func email(for name: String, domain: String) -> String {
        let parts = name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "en_CA"))
            .split(separator: " ")
        let handle = parts.count >= 2
            ? "\(parts[0]).\(parts[1])".replacingOccurrences(of: "'", with: "")
            : String(parts.first ?? "contact")
        return "\(handle)@\(domain)"
    }

    static func domain(for company: String) -> String {
        company.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined() + ".ca"
    }
}

// MARK: - Int Range Helper

private extension SeededRandom {
    /// Convenience for the "thousands" ranges used in valuations.
    mutating func int(_ low: Int, _ high: Int) -> Int {
        int(low...high)
    }
}
