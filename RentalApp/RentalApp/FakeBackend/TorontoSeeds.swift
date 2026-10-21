//
//  TorontoSeeds.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Source vocabulary for generated data.
//
//  Everything here is real Toronto: actual neighbourhoods with their
//  correct forward sortation areas, streets that exist in those
//  neighbourhoods, and rent bands drawn from 2026 market levels. The
//  point is that a Toronto landlord reading this screen should never
//  hit a detail that feels invented.
//

import Foundation

enum TorontoSeeds {

    // MARK: - Geography

    /// A Toronto neighbourhood with its postal prefix, plausible
    /// streets, and a rent multiplier against the city baseline.
    struct Neighbourhood {
        let name: String
        /// Forward sortation area, the first three postal characters.
        let fsa: String
        let streets: [String]
        /// 1.0 is the city average; Yorkville is dearer, Scarborough softer.
        let rentIndex: Double
    }

    static let neighbourhoods: [Neighbourhood] = [
        .init(name: "Leslieville", fsa: "M4M",
              streets: ["Queen St E", "Carlaw Ave", "Logan Ave", "Boston Ave", "Ashdale Ave"],
              rentIndex: 1.02),
        .init(name: "Queen West", fsa: "M6J",
              streets: ["Queen St W", "Ossington Ave", "Shaw St", "Dovercourt Rd", "Argyle St"],
              rentIndex: 1.14),
        .init(name: "The Danforth", fsa: "M4K",
              streets: ["Danforth Ave", "Pape Ave", "Jones Ave", "Chester Ave", "Playter Blvd"],
              rentIndex: 0.96),
        .init(name: "Liberty Village", fsa: "M6K",
              streets: ["Hanna Ave", "Atlantic Ave", "Jefferson Ave", "Mowat Ave", "Lynn Williams St"],
              rentIndex: 1.10),
        .init(name: "The Annex", fsa: "M5S",
              streets: ["Brunswick Ave", "Palmerston Blvd", "Howland Ave", "Bernard Ave", "Madison Ave"],
              rentIndex: 1.08),
        .init(name: "Harbourfront", fsa: "M5V",
              streets: ["Queens Quay W", "Lower Simcoe St", "Fort York Blvd", "Bremner Blvd", "Dan Leckie Way"],
              rentIndex: 1.18),
        .init(name: "Roncesvalles", fsa: "M6R",
              streets: ["Roncesvalles Ave", "Sorauren Ave", "Wright Ave", "Marion St", "Fern Ave"],
              rentIndex: 1.01),
        .init(name: "Little Italy", fsa: "M6G",
              streets: ["College St", "Manning Ave", "Euclid Ave", "Grace St", "Clinton St"],
              rentIndex: 1.05),
        .init(name: "Cabbagetown", fsa: "M5A",
              streets: ["Carlton St", "Winchester St", "Amelia St", "Sackville St", "Metcalfe St"],
              rentIndex: 1.03),
        .init(name: "Riverdale", fsa: "M4K",
              streets: ["Broadview Ave", "Withrow Ave", "Langley Ave", "Simpson Ave", "Bain Ave"],
              rentIndex: 0.99),
        .init(name: "High Park", fsa: "M6P",
              streets: ["Bloor St W", "Clendenan Ave", "Gothic Ave", "Quebec Ave", "Pacific Ave"],
              rentIndex: 1.00),
        .init(name: "Yorkville", fsa: "M5R",
              streets: ["Yorkville Ave", "Cumberland St", "Scollard St", "Hazelton Ave", "Bay St"],
              rentIndex: 1.34),
        .init(name: "Distillery District", fsa: "M5A",
              streets: ["Mill St", "Trinity St", "Parliament St", "Cherry St", "Front St E"],
              rentIndex: 1.16),
        .init(name: "Parkdale", fsa: "M6K",
              streets: ["Queen St W", "Jameson Ave", "Cowan Ave", "Dunn Ave", "Springhurst Ave"],
              rentIndex: 0.92),
        .init(name: "The Beaches", fsa: "M4E",
              streets: ["Queen St E", "Kingston Rd", "Wineva Ave", "Balsam Ave", "Lee Ave"],
              rentIndex: 1.04),
        .init(name: "The Junction", fsa: "M6N",
              streets: ["Dundas St W", "Keele St", "Annette St", "Pacific Ave", "High Park Ave"],
              rentIndex: 0.94),
        .init(name: "Corktown", fsa: "M5A",
              streets: ["King St E", "Berkeley St", "Trefann St", "Sumach St", "Eastern Ave"],
              rentIndex: 1.07),
        .init(name: "North York", fsa: "M2N",
              streets: ["Yonge St", "Sheppard Ave E", "Doris Ave", "Bonnington Pl", "Kenneth Ave"],
              rentIndex: 0.88),
        .init(name: "Etobicoke", fsa: "M8V",
              streets: ["Lake Shore Blvd W", "Islington Ave", "Royal York Rd", "Mimico Ave", "Superior Ave"],
              rentIndex: 0.86),
        .init(name: "Scarborough Bluffs", fsa: "M1M",
              streets: ["Kingston Rd", "Brimley Rd", "Midland Ave", "Bellamy Rd N", "Cathedral Bluffs Dr"],
              rentIndex: 0.82)
    ]

    /// Builds a plausible Canadian postal code for a neighbourhood,
    /// e.g. `M4M 2K7`.
    static func postalCode(fsa: String, generator: inout SeededRandom) -> String {
        let letters = Array("ABCEGHJKLMNPRSTVWXYZ")
        let digit1 = generator.int(0...9)
        let letter = letters[generator.int(0...(letters.count - 1))]
        let digit2 = generator.int(0...9)
        return "\(fsa) \(digit1)\(letter)\(digit2)"
    }

    // MARK: - Property Naming

    /// Building-name components that produce names a Toronto listing
    /// would actually carry.
    static let propertyPrefixes = [
        "Maple", "Birchwood", "Riverstone", "Bloor", "Wellesley", "Ashgrove",
        "Kingsway", "Northcliffe", "Rosedale", "Sterling", "Ironwood", "Beacon",
        "Cedarvale", "Fairmount", "Glenholme", "Havelock", "Lakeview", "Westport"
    ]

    static let propertySuffixes = [
        "Lofts", "Residences", "Court", "Terrace", "House", "Commons",
        "Flats", "Manor", "Place", "Row", "Yards", "Mews"
    ]

    // MARK: - People

    /// Given names reflecting Toronto's actual demographic mix.
    static let firstNames = [
        "Sarah", "Marcus", "Priya", "Liam", "Amara", "Noah", "Isabella", "Wei",
        "Fatima", "Jack", "Aisha", "Lucas", "Emma", "Raj", "Olivia", "Diego",
        "Hannah", "Kwame", "Sofia", "Ethan", "Zara", "Felix", "Mei", "Omar",
        "Chloe", "André", "Nadia", "Tomas", "Leila", "Connor", "Yuki", "Hassan",
        "Grace", "Dmitri", "Ana", "Samuel", "Ingrid", "Rohan", "Claire", "Malik",
        "Jasmine", "Viktor", "Elena", "Tariq", "Maya", "Seán", "Anika", "Pablo",
        "Freya", "Jamal", "Naomi", "Étienne", "Simran", "Marco", "Lucia", "Kofi",
        "Hana", "Bilal", "Astrid", "Rafael"
    ]

    static let lastNames = [
        "Chen", "Johnson", "Patel", "O'Connor", "Diallo", "Kim", "Rossi", "Zhang",
        "Al-Rashid", "Thompson", "Mohamed", "Silva", "Tremblay", "Sharma", "Bennett",
        "Fernandez", "Lee", "Mensah", "Petrov", "Wright", "Hussain", "Nguyen",
        "Wang", "Okafor", "Dubois", "Kowalski", "Ivanov", "Martinez", "Singh",
        "Brown", "Murphy", "Haddad", "Yamamoto", "Costa", "Novak", "Reyes",
        "Andersen", "Gupta", "Clarke", "Osei", "Bianchi", "Volkov", "Rahman",
        "Torres", "Walsh", "Desai", "Moreau", "Larsen", "Khan", "Baptiste",
        "Fitzgerald", "Ahmadi", "Lindqvist", "Marchetti", "Boateng", "Sørensen"
    ]

    /// Email domains Canadians actually use.
    static let emailDomains = [
        "gmail.com", "outlook.com", "icloud.com", "hotmail.com",
        "yahoo.ca", "proton.me", "rogers.com", "sympatico.ca"
    ]

    // MARK: - Team

    /// The organization's own staff. Fixed rather than generated so the
    /// team screen stays stable and recognisable.
    static let staff: [(name: String, role: String, email: String)] = [
        ("Syed Bukhari", "Owner", "nabeelbukhari21@gmail.com"),
        ("Sarah Mitchell", "Property Manager", "sarah.m@bukhariproperties.ca"),
        ("David Park", "Maintenance Coordinator", "d.park@bukhariproperties.ca"),
        ("Alex Rivera", "Property Manager", "alex.r@bukhariproperties.ca"),
        ("Nadia Haddad", "Leasing Specialist", "n.haddad@bukhariproperties.ca"),
        ("Tom Wallace", "Accountant", "t.wallace@bukhariproperties.ca")
    ]

    // MARK: - Vendors

    /// Trade companies with names that fit the GTA contractor market.
    static let vendors: [(company: String, contact: String, trade: Domain.Vendor.Trade)] = [
        ("Rapid Plumbing Co.", "Mike Torres", .plumbing),
        ("Danforth Drain Services", "Gus Papadakis", .plumbing),
        ("Humber Mechanical", "Ray Okonkwo", .plumbing),
        ("Volt Electric", "Dana Wells", .electrical),
        ("Beacon Electrical Contracting", "Ivan Petrov", .electrical),
        ("NorthAir HVAC", "Sam Osei", .hvac),
        ("Lakeshore Climate Control", "Elena Marchetti", .hvac),
        ("FixIt Appliance", "Lena Kowalski", .appliance),
        ("GTA Appliance Repair", "Hassan Rahman", .appliance),
        ("Parkdale Carpentry", "Owen Walsh", .carpentry),
        ("Maple Leaf Roofing", "Curtis Bell", .roofing),
        ("Riverdale Landscaping", "Marta Silva", .landscaping),
        ("Trillium Pest Control", "Bruce Ferland", .pestControl),
        ("Bright & Clean GTA", "Rosa Fernandez", .cleaning),
        ("Handy General Services", "Omar Haddad", .general),
        ("Bloor Glass & Window", "Jin Park", .general),
        ("York Fire & Safety", "Denise Clarke", .general),
        ("Downsview Garage Doors", "Paul Nowak", .general),
        ("Beaches Flooring", "Aiden Murphy", .carpentry),
        ("Queen City Painters", "Tomas Novak", .general)
    ]

    // MARK: - Maintenance Catalogue

    /// A realistic work order: what tenants actually report, with the
    /// detail a landlord would receive.
    struct Issue {
        let title: String
        let detail: String
        let trade: Domain.Vendor.Trade
        /// Typical urgency before AI triage adjusts it.
        let priority: Domain.MaintenanceRequest.Priority
        /// Copilot's one-line assessment.
        let aiSummary: String
        let aiActions: [String]
    }

    static let issues: [Issue] = [
        .init(title: "Water leak under kitchen sink",
              detail: "Water is pooling under the sink and the cabinet floor is soaked. I've put a bucket underneath but it's filling every few hours.",
              trade: .plumbing, priority: .urgent,
              aiSummary: "Active leak with pooling — risk of cabinet and subfloor damage within 24–48h. Shut-off valve is accessible under the sink.",
              aiActions: ["Ask tenant to close the under-sink shut-off valve", "Dispatch a plumber within 4 hours", "Photograph the cabinet base for insurance"]),
        .init(title: "No hot water",
              detail: "Hot water stopped overnight. Cold runs fine. The tank is making a low humming noise.",
              trade: .plumbing, priority: .urgent,
              aiSummary: "Total hot water loss with tank noise suggests a failed heating element or thermostat. Same-day fix expected.",
              aiActions: ["Confirm the breaker for the water heater", "Dispatch plumber today", "Check tank age against replacement schedule"]),
        .init(title: "Toilet running continuously",
              detail: "The toilet in the main bathroom keeps running after flushing. Jiggling the handle helps for a bit.",
              trade: .plumbing, priority: .medium,
              aiSummary: "Classic flapper or fill-valve wear. Low urgency but wastes roughly 200L a day on the water bill.",
              aiActions: ["Order a universal flapper kit", "Bundle with the next visit to this property"]),
        .init(title: "Kitchen faucet dripping",
              detail: "Slow but constant drip from the kitchen faucet, worse on the hot side.",
              trade: .plumbing, priority: .low,
              aiSummary: "Worn cartridge. Inexpensive part, 30-minute job.",
              aiActions: ["Order replacement cartridge", "Schedule with other minor work"]),
        .init(title: "Bedroom outlet not working",
              detail: "One outlet in the primary bedroom stopped working. No breaker appears to have tripped.",
              trade: .electrical, priority: .high,
              aiSummary: "Dead receptacle with no visible trip — likely an upstream GFCI or a failed backstab connection.",
              aiActions: ["Ask tenant to reset the bathroom GFCI", "Dispatch electrician within 48h"]),
        .init(title: "Hallway light flickering",
              detail: "Second-floor hallway fixture flickers intermittently. The bulb has already been replaced.",
              trade: .electrical, priority: .medium,
              aiSummary: "Flicker persisting after a bulb swap points to a loose neutral or failing ballast. Common-area, low risk.",
              aiActions: ["Bundle with other electrical work at this property", "Schedule during daytime — no unit access needed"]),
        .init(title: "Breaker trips when microwave runs",
              detail: "Kitchen breaker trips whenever the microwave and kettle are on together.",
              trade: .electrical, priority: .high,
              aiSummary: "Circuit overload on a shared kitchen line. Worth confirming the panel matches current load requirements.",
              aiActions: ["Book electrician to assess circuit load", "Check whether a dedicated kitchen circuit exists"]),
        .init(title: "No heat in living room",
              detail: "The baseboard heater in the living room isn't warming up. The rest of the unit is fine.",
              trade: .hvac, priority: .high,
              aiSummary: "Single-zone heating failure. This unit has a history of thermostat faults.",
              aiActions: ["Ask tenant to check the breaker panel", "Book HVAC tech this week", "Review the unit's thermostat service history"]),
        .init(title: "Air conditioning not cooling",
              detail: "AC runs constantly but the unit never gets below 26°C.",
              trade: .hvac, priority: .high,
              aiSummary: "Running without cooling usually means low refrigerant or a fouled coil. Escalates fast in summer.",
              aiActions: ["Dispatch HVAC within 24h", "Check refrigerant charge and coil condition"]),
        .init(title: "Furnace making banging noise",
              detail: "Loud bang each time the furnace kicks on. Started this week.",
              trade: .hvac, priority: .urgent,
              aiSummary: "Delayed ignition produces a bang and can crack the heat exchanger. Treat as a safety item.",
              aiActions: ["Advise tenant to switch the system off", "Emergency HVAC dispatch", "Test for carbon monoxide"]),
        .init(title: "Dishwasher not draining",
              detail: "Standing water after every cycle. I've cleaned the filter with no change.",
              trade: .appliance, priority: .medium,
              aiSummary: "Likely drain pump or air-gap blockage. The same model failed identically elsewhere in this portfolio.",
              aiActions: ["Reuse prior repair notes for this model", "Order drain pump in advance", "Schedule a one-hour appliance visit"]),
        .init(title: "Fridge making clicking sound",
              detail: "Repetitive clicking every few minutes. Cooling still seems fine.",
              trade: .appliance, priority: .low,
              aiSummary: "Clicking with normal cooling usually indicates a failing start relay — cheap now, compressor damage later.",
              aiActions: ["Order a universal start relay", "Book a 30-minute appliance check"]),
        .init(title: "Dryer not heating",
              detail: "Dryer tumbles but clothes come out damp after a full cycle.",
              trade: .appliance, priority: .medium,
              aiSummary: "No heat with normal tumble points to a blown thermal fuse, often caused by restricted venting.",
              aiActions: ["Replace thermal fuse", "Inspect and clear the dryer vent run"]),
        .init(title: "Balcony door seal replacement",
              detail: "Draft coming through the balcony door seal; it whistles on windy days.",
              trade: .carpentry, priority: .low,
              aiSummary: "Comfort issue rather than a defect. Standard seal kit, 45-minute job.",
              aiActions: ["Order seal kit for the sliding door", "Combine with other work on this floor"]),
        .init(title: "Front door lock sticking",
              detail: "The deadbolt catches and takes several attempts to turn.",
              trade: .general, priority: .high,
              aiSummary: "Lock failure is a security and egress concern — treat as higher priority than the inconvenience suggests.",
              aiActions: ["Dispatch locksmith within 24h", "Consider rekeying if the cylinder is worn"]),
        .init(title: "Bathroom fan noise",
              detail: "Grinding noise from the bathroom exhaust fan whenever it runs.",
              trade: .general, priority: .medium,
              aiSummary: "Bearing wear. Replacing the motor is cheaper than a full unit swap.",
              aiActions: ["Order replacement fan motor", "Schedule with other work in the unit"]),
        .init(title: "Mice in the kitchen",
              detail: "Found droppings behind the stove and heard scratching in the wall at night.",
              trade: .pestControl, priority: .urgent,
              aiSummary: "Active rodent presence. Ontario requires prompt action; delay risks an escalation to the city.",
              aiActions: ["Book pest control within 48h", "Inspect for entry points at the foundation", "Document treatment for compliance"]),
        .init(title: "Ceiling stain in bedroom",
              detail: "Brown stain on the bedroom ceiling that seems to be getting bigger.",
              trade: .roofing, priority: .urgent,
              aiSummary: "A growing stain means active water ingress. Source is likely roof or the unit above.",
              aiActions: ["Inspect the unit above before assuming roof", "Book roofer if no interior source is found", "Photograph the stain to track spread"]),
        .init(title: "Front walkway ice buildup",
              detail: "The walkway ices over badly overnight — it's a slipping hazard.",
              trade: .landscaping, priority: .high,
              aiSummary: "Slip-and-fall liability. Ontario occupiers' liability makes this a documented-response item.",
              aiActions: ["Dispatch salting service today", "Add this property to the winter route", "Log the response for liability records"]),
        .init(title: "Common area needs deep clean",
              detail: "The lobby and stairwell haven't been cleaned properly in weeks.",
              trade: .cleaning, priority: .low,
              aiSummary: "Presentation issue affecting all tenants at this property and any prospective viewings.",
              aiActions: ["Schedule a deep clean", "Review the cleaning contract frequency"])
    ]

    // MARK: - Conversation Snippets
    //
    // Threads are built from question-and-answer pairs, so every reply
    // answers the message before it.

    /// A tenant's message and the manager's answer to it.
    static var tenantExchanges: [(String, String)] { Array(zip(tenantOpeners, managerReplies)) }

    /// A vendor's message and the manager's answer to it.
    static var vendorExchanges: [(String, String)] { Array(zip(vendorMessages, vendorReplies)) }

    /// Opening lines tenants actually send. Paired by position with
    /// `managerReplies`.
    private static let tenantOpeners = [
        "Hi! Just wanted to check in about the repair — any update?",
        "Hello, is it still okay for the technician to come Thursday morning?",
        "Quick question about the rent receipt for last month — could you resend it?",
        "Hi, the issue seems to have settled down but I wanted to flag it anyway.",
        "Good morning! Is there parking available for a visitor this weekend?",
        "Hi, I'll be away next week — happy for maintenance to enter if needed.",
        "Hello, could you confirm what's included in the utilities this year?",
        "Hi there — the new appliance is working perfectly, thank you!"
    ]

    private static let managerReplies = [
        "Thanks for flagging it — I've booked someone for tomorrow afternoon.",
        "Confirmed, they'll buzz your unit between 9 and 11.",
        "Just resent it to your email. Let me know if it doesn't arrive.",
        "Appreciate the update. I'll keep the ticket open for a few days just in case.",
        "Yes, visitor parking is available — I'll leave a pass at the front.",
        "Noted, thanks. I'll make sure they have access instructions.",
        "Hydro and water are included; internet is separate. I'll email the breakdown.",
        "Glad to hear it! Thanks for your patience while we sorted it out."
    ]

    /// Paired by position with `vendorReplies`.
    private static let vendorMessages = [
        "On my way — should be there in about 20 minutes.",
        "Job's done. I've sent the invoice through.",
        "I'll need a part ordered; can be back Thursday to finish.",
        "Confirmed for tomorrow between 2 and 4 PM.",
        "Had a look — it's a bigger job than quoted, want me to write it up?",
        "All set. I've left the old parts in the utility room as requested.",
        "Running about 30 minutes behind, apologies.",
        "Can you confirm someone will be home to let me in?"
    ]

    private static let vendorReplies = [
        "Thanks — the tenant knows to expect you.",
        "Great, thanks. I'll process it this week.",
        "Thursday works. I'll let the tenant know.",
        "Perfect. The tenant has written notice for that window.",
        "Yes please, send the revised quote before you start.",
        "Thank you, appreciated.",
        "No problem, I'll let the tenant know.",
        "The tenant has agreed to entry, so you can let yourself in."
    ]

    /// What a vendor would say about a job at this stage. Nil before
    /// anyone has taken it on.
    static func vendorUpdates(for status: Domain.MaintenanceRequest.Status) -> [String]? {
        switch status {
        case .scheduled:
            ["Confirmed for tomorrow between 2 and 4 PM.", "Can you confirm someone will be home to let me in?"]
        case .inProgress:
            ["On my way — should be there in about 20 minutes.",
             "Running about 30 minutes behind, apologies.",
             "Had a look — it's a bigger job than quoted, want me to write it up?"]
        case .awaitingParts:
            ["I'll need a part ordered; can be back Thursday to finish."]
        case .completed:
            ["Job's done. I've sent the invoice through.",
             "All set. I've left the old parts in the utility room as requested."]
        case .new, .triaged, .cancelled, .unknown:
            nil
        }
    }
}
