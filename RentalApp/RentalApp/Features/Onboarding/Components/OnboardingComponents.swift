//
//  OnboardingComponents.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Building blocks shared by onboarding and getting started.
//
//  Modelled on the system's own setup flows (Face ID, Apple Pay, Health):
//  an illustration, a large title and one line of explanation at the top;
//  an inset-grouped list of choices with checkmarks; one prominent action
//  in a bottom bar. Purr is the illustration — content, never chrome.
//

import SwiftUI

// MARK: - Header

/// Purr, a large title and a short explanation, centred like a system
/// setup screen. Used as the first, borderless section of a step's list.
struct OnboardingHeader: View {

    let mood: MascotMood
    let title: String
    var message: String? = nil
    /// Kept below each pose's crisp limit (see `MascotPose.nativePixels`).
    var mascotSize: CGFloat = 120

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 12) {
            // Artwork gives way to text at accessibility sizes.
            MascotView(mood: mood, size: typeSize.isAccessibilitySize ? mascotSize * 0.6 : mascotSize)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}

extension View {
    /// Places a view as a full-width, background-free list section.
    func onboardingHeaderSection() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
    }
}

// MARK: - Checklist Row

/// One line of an honest progress checklist: waiting, working, done.
struct OnboardingChecklistRow: View {

    let task: OnboardingBuildTask

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if task.state == .running {
                    ProgressView()
                } else {
                    Image(systemName: task.state == .done ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(task.state == .done ? AnyShapeStyle(.green) : AnyShapeStyle(Color(uiColor: .tertiaryLabel)))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 28)
            .accessibilityHidden(true)

            Text(task.title)
                .foregroundStyle(task.state == .pending ? .secondary : .primary)
        }
        .frame(minHeight: 44)
        .sensoryFeedback(.success, trigger: task.state == .done)
        .accessibilityElement(children: .combine)
        .accessibilityValue(task.state == .done ? "Done" : task.state == .running ? "In progress" : "Waiting")
    }
}

// MARK: - Unlock Row

struct OnboardingUnlockRow: View {

    let unlock: OnboardingUnlock

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(unlock.title)
                Text(unlock.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            SymbolTile(systemName: unlock.icon, color: unlock.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress

/// Goal-gradient progress (playbook §5) for the navigation bar.
struct OnboardingProgressView: View {

    let progress: Double
    let label: String

    var body: some View {
        ProgressView(value: progress)
            .frame(width: 160)
            .animation(.smooth, value: progress)
            .accessibilityLabel("Setup progress")
            .accessibilityValue(label)
    }
}

// MARK: - Previews

#Preview("Components") {
    NavigationStack {
        List {
            Section {
                OnboardingHeader(mood: .thinking, title: "Who are you?", message: "Tell me a little about you.")
            }
            .onboardingHeaderSection()

            Section {
                ChoiceRow(symbol: "key.fill", tint: .orange, title: "I own rentals", subtitle: "Landlord or owner", isSelected: true) {}
                ChoiceRow(symbol: "person.2.fill", tint: .blue, title: "I manage for others", isSelected: false) {}
            }

            Section {
                OnboardingChecklistRow(task: .init(id: "a", title: "Saving your answers", state: .done))
                OnboardingChecklistRow(task: .init(id: "b", title: "Choosing your alert settings", state: .running))
                OnboardingChecklistRow(task: .init(id: "c", title: "Preparing your dashboard"))
            }
        }
        .primaryActionBar {
            PrimaryActionButton(title: "Continue") {}
        }
    }
}
