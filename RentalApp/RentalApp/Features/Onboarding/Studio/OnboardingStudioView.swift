//
//  OnboardingStudioView.swift
//  RentalApp (Purrperty)
//
//  Onboarding studio — Runs one of the three 1.3–1.11 directions on the
//  real flow view model, with mock data. DEBUG builds only.
//
//      -PurrpertyStudio stage|bust|bubbles [-PurrpertyStudioDemo YES]
//
//  The demo answers everything by itself, for recording.
//

#if DEBUG
import SwiftUI

enum StudioDirection: String {
    /// A: Purr stands on a stage; the answers sit in front of him.
    case stage
    /// B: a giant Purr rises from the bottom; answers are keys above him.
    case bust
    /// C: answers are liquid bubbles orbiting him.
    case bubbles

    static var requested: StudioDirection? {
        UserDefaults.standard.string(forKey: "PurrpertyStudio").flatMap(StudioDirection.init(rawValue:))
    }
}

struct OnboardingStudioView: View {

    let direction: StudioDirection
    @State private var viewModel: OnboardingFlowViewModel
    @State private var scheme: ColorScheme?

    init(direction: StudioDirection) {
        self.direction = direction
        let container = AppContainer.preview
        _viewModel = State(initialValue: OnboardingFlowViewModel(
            store: container.onboardingProfile, preferences: container.preferences,
            dashboard: container.dashboard, authService: container.auth, analytics: container.analytics
        ))
    }

    private var isDemo: Bool { UserDefaults.standard.bool(forKey: "PurrpertyStudioDemo") }

    var body: some View {
        TiltScene {
            switch direction {
            case .stage: StudioStage(viewModel: viewModel)
            case .bust: StudioBust(viewModel: viewModel)
            case .bubbles: StudioBubbles(viewModel: viewModel)
            }
        }
        .preferredColorScheme(viewModel.theme == .dark && viewModel.step == .personalize ? .dark : .light)
        .task { await start() }
    }

    private func start() async {
        viewModel.profile = OnboardingProfile()
        viewModel.theme = .light
        viewModel.advance()
        viewModel.finishIntro(skipped: true)
        guard isDemo else { return }
        await pause(5)
        for step in viewModel.steps where step.showsProgress {
            while viewModel.step != step { await pause(0.05) }
            print("STUDIO \(step.rawValue) \(Date.now.timeIntervalSince1970)")
            await pause(step == .signUp ? 3 : 2.2)
            switch step {
            case .persona: viewModel.select(OnboardingPersona.landlord)
            case .units: viewModel.select(OnboardingUnitRange.sixToTwenty)
            case .headaches:
                viewModel.toggle(.lateRent); await pause(1.2); viewModel.toggle(.repairs); await pause(0.8); viewModel.toggle(.paperwork)
            case .goal: viewModel.select(OnboardingGoal.getPaidOnTime)
            case .personalize: viewModel.theme = .dark; await pause(2); viewModel.theme = .light
            case .building: continue
            case .unlocked: await pause(2)
            case .signUp:
                print("STUDIO filled \(Date.now.timeIntervalSince1970)")
                await type("Maya Chen", into: \.name)
                await type("maya@example.com", into: \.email)
                await type("sunnyside42", into: \.password)
                await pause(4)
            default: break
            }
            await pause(2.4)
            if step != .signUp { viewModel.advance() }
        }
        print("STUDIO end \(Date.now.timeIntervalSince1970)")
    }

    private func type(_ text: String, into field: ReferenceWritableKeyPath<AuthViewModel, String>) async {
        for character in text {
            viewModel.auth[keyPath: field].append(character)
            await pause(0.05)
        }
    }

    private func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
}
#endif
