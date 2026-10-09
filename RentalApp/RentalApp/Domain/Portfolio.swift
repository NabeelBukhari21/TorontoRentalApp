//
//  Portfolio.swift
//  RentalApp (RentOS)
//
//  Domain — The physical hierarchy.
//
//      Organization → Property → Building → Unit
//
//  `Building` sits between property and unit so a single address can
//  hold multiple structures (a house plus a laneway suite, a complex
//  with three towers). Single-structure properties get one implicit
//  building, which keeps every query uniform — the alternative,
//  nullable `building_id` on `Unit`, poisons every join forever.
//

import Foundation

// MARK: - Property

extension Domain {

    /// A managed address. The unit of ownership and reporting.
    struct Property: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Property
        static let tableName = "properties"

        // Identity
        let id: Identifier<Property>
        let organizationID: Identifier<Organization>
        var name: String
        /// Neighbourhood or district, e.g. "Leslieville".
        var neighborhood: String?
        var address: Address
        var kind: Kind

        // Physical
        var yearBuilt: Int?
        /// Total lot or gross floor area, square feet.
        var squareFeet: Int?

        // Financial
        var purchasePrice: Money?
        var purchaseDate: Date?
        /// Latest appraisal or automated valuation.
        var marketValue: Money?

        // Ownership
        /// Staff member accountable for this property.
        var managerID: Identifier<User>?

        // Media
        var coverImagePath: String?

        // Lifecycle
        var status: Status
        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Property> = .init(),
            organizationID: Identifier<Organization>,
            name: String,
            neighborhood: String? = nil,
            address: Address,
            kind: Kind,
            yearBuilt: Int? = nil,
            squareFeet: Int? = nil,
            purchasePrice: Money? = nil,
            purchaseDate: Date? = nil,
            marketValue: Money? = nil,
            managerID: Identifier<User>? = nil,
            coverImagePath: String? = nil,
            status: Status = .active,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.name = name
            self.neighborhood = neighborhood
            self.address = address
            self.kind = kind
            self.yearBuilt = yearBuilt
            self.squareFeet = squareFeet
            self.purchasePrice = purchasePrice
            self.purchaseDate = purchaseDate
            self.marketValue = marketValue
            self.managerID = managerID
            self.coverImagePath = coverImagePath
            self.status = status
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case condo
            case house
            case duplex
            case triplex
            case multiUnit = "multi_unit"
            case commercial
            case mixedUse = "mixed_use"
            case unknown
        }

        enum Status: String, FallbackDecodable, CaseIterable {
            case active
            /// Under renovation, not leasable.
            case offline
            case listedForSale = "listed_for_sale"
            case sold
            case unknown
        }

        enum CodingKeys: String, CodingKey {
            case id, name, neighborhood, kind, status
            case organizationID = "organization_id"
            case yearBuilt = "year_built"
            case squareFeet = "square_feet"
            case purchasePrice = "purchase_price"
            case purchaseDate = "purchase_date"
            case marketValue = "market_value"
            case managerID = "manager_id"
            case coverImagePath = "cover_image_path"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
            // Address is flattened into this table.
            case address
        }
    }
}

// MARK: - Building

extension Domain {

    /// A structure on a property. Properties with one structure still
    /// get one building, so `Unit.buildingID` is never optional.
    struct Building: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Building
        static let tableName = "buildings"

        let id: Identifier<Building>
        let organizationID: Identifier<Organization>
        let propertyID: Identifier<Property>

        /// e.g. "Main House", "Tower A", "Laneway Suite".
        var name: String
        var floorCount: Int
        var hasElevator: Bool
        var yearBuilt: Int?
        /// Entry instructions for vendors and couriers.
        var accessNotes: String?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Building> = .init(),
            organizationID: Identifier<Organization>,
            propertyID: Identifier<Property>,
            name: String = "Main Building",
            floorCount: Int = 1,
            hasElevator: Bool = false,
            yearBuilt: Int? = nil,
            accessNotes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.propertyID = propertyID
            self.name = name
            self.floorCount = floorCount
            self.hasElevator = hasElevator
            self.yearBuilt = yearBuilt
            self.accessNotes = accessNotes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum CodingKeys: String, CodingKey {
            case id, name
            case organizationID = "organization_id"
            case propertyID = "property_id"
            case floorCount = "floor_count"
            case hasElevator = "has_elevator"
            case yearBuilt = "year_built"
            case accessNotes = "access_notes"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Unit

extension Domain {

    /// A leasable space. The atom of occupancy and revenue.
    ///
    /// Carries `propertyID` alongside `buildingID` — a denormalisation
    /// that makes the overwhelmingly common "all units at a property"
    /// query a single indexed filter instead of a join.
    struct Unit: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Unit
        static let tableName = "units"

        // Identity
        let id: Identifier<Unit>
        let organizationID: Identifier<Organization>
        let propertyID: Identifier<Property>
        let buildingID: Identifier<Building>
        /// Door label, e.g. "304", "Suite 2204".
        var label: String
        var floor: Int?

        // Layout
        var bedrooms: Int
        /// Half-baths are common, so this is fractional.
        var bathrooms: Decimal
        var squareFeet: Int?
        var layout: Layout

        // Economics
        var marketRent: Money
        /// Nil until a deposit schedule is agreed.
        var depositAmount: Money?

        // State
        var status: Status
        var amenities: [Amenity]

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Unit> = .init(),
            organizationID: Identifier<Organization>,
            propertyID: Identifier<Property>,
            buildingID: Identifier<Building>,
            label: String,
            floor: Int? = nil,
            bedrooms: Int = 1,
            bathrooms: Decimal = 1,
            squareFeet: Int? = nil,
            layout: Layout = .apartment,
            marketRent: Money,
            depositAmount: Money? = nil,
            status: Status = .vacant,
            amenities: [Amenity] = [],
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.propertyID = propertyID
            self.buildingID = buildingID
            self.label = label
            self.floor = floor
            self.bedrooms = bedrooms
            self.bathrooms = bathrooms
            self.squareFeet = squareFeet
            self.layout = layout
            self.marketRent = marketRent
            self.depositAmount = depositAmount
            self.status = status
            self.amenities = amenities
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Layout: String, FallbackDecodable, CaseIterable {
            case studio
            case apartment
            case townhouse
            case basementSuite = "basement_suite"
            case commercial
            case unknown
        }

        /// Occupancy state. The single source of truth for vacancy
        /// metrics — derive it from leases on write, never on read.
        enum Status: String, FallbackDecodable, CaseIterable {
            case occupied
            case vacant
            /// Tenant has given notice; lease still active.
            case notice
            /// Between tenants, being prepared.
            case turnover
            /// Withheld from the market (renovation, owner use).
            case offline
            case unknown

            /// Counts toward occupancy in portfolio reporting.
            var countsAsOccupied: Bool {
                self == .occupied || self == .notice
            }
        }

        enum Amenity: String, Codable, Sendable, CaseIterable {
            case parking
            case inSuiteLaundry = "in_suite_laundry"
            case dishwasher
            case airConditioning = "air_conditioning"
            case balcony
            case storage
            case petFriendly = "pet_friendly"
            case furnished
        }

        enum CodingKeys: String, CodingKey {
            case id, label, floor, bedrooms, bathrooms, layout, status, amenities
            case organizationID = "organization_id"
            case propertyID = "property_id"
            case buildingID = "building_id"
            case squareFeet = "square_feet"
            case marketRent = "market_rent"
            case depositAmount = "deposit_amount"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}
