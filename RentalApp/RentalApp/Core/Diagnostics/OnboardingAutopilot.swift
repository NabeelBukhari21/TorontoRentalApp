//
//  OnboardingAutopilot.swift
//  RentalApp (Purrperty)
//
//  Diagnostics — Walks onboarding by itself, for recordings and layout
//  checks. DEBUG builds only.
//
//      -PurrpertyStartAt onboarding -PurrpertyAutopilot YES
//      [-PurrpertyAutopilotStop goal]   stop on that step, answered
//

#if DEBUG
import Foundation

@MainActor
enum OnboardingAutopilot {

    static func run(_ viewModel: OnboardingFlowViewModel) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "PurrpertyAutopilot") else { return }
        let stop = defaults.string(forKey: "PurrpertyAutopilotStop")
        let speed = defaults.double(forKey: "PurrpertyAutopilotSpeed")
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds / (speed > 0 ? speed : 1))) }

        viewModel.profile = OnboardingProfile()
        viewModel.theme = .system
        await pause(5)
        viewModel.advance()
        viewModel.finishIntro(skipped: true)

        for step in viewModel.steps where step.showsProgress {
            while viewModel.step != step {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
            }
            print("AUTOPILOT \(step.rawValue) \(Date.now.timeIntervalSince1970)")
            await pause(1.8)
            switch step {
            case .persona: viewModel.select(OnboardingPersona.landlord)
            case .units: viewModel.select(OnboardingUnitRange.sixToTwenty)
            case .headaches:
                viewModel.toggle(.lateRent); await pause(0.8)
                viewModel.toggle(.repairs); await pause(0.8)
                viewModel.toggle(.paperwork)
            case .goal: viewModel.select(OnboardingGoal.getPaidOnTime)
            case .personalize:
                viewModel.theme = .dark; await pause(2.4)
                viewModel.theme = .system
            case .building:
                if stop == step.rawValue { return }
                continue
            case .unlocked: await pause(1.5)
            case .signUp:
                for c in "Maya Chen" { viewModel.auth.name.append(c); await pause(0.05) }
                for c in "maya@example.com" { viewModel.auth.email.append(c); await pause(0.05) }
                for c in "sunnyside42" { viewModel.auth.password.append(c); await pause(0.05) }
            default: break
            }
            await pause(2.4)
            if stop == step.rawValue { return }
            if step != .signUp { viewModel.advance() }
        }
        print("AUTOPILOT end \(Date.now.timeIntervalSince1970)")
    }
}
#endif
