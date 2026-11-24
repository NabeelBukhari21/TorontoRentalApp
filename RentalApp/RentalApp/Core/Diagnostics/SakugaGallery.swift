//
//  SakugaGallery.swift
//  RentalApp (Purrperty)
//
//  Diagnostics — All twelve Sakuga controls, live. DEBUG builds only.
//
//      -PurrpertySakuga YES [-PurrpertySakugaDemo YES]   plays by itself
//

#if DEBUG
import SwiftUI

struct SakugaGallery: View {

    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "PurrpertySakuga") }

    @State private var stage = SakugaStage()
    @State private var feedback = FeedbackPlayer(preferences: InMemoryPreferencesRepository())
    @State private var page = 0

    @State private var fire1 = 0
    @State private var fire2 = 0
    @State private var isOn = false
    @State private var isChecked = false
    @State private var isToast = false
    @State private var isTip = false
    @State private var slider = 0.3
    @State private var progress = 0.0
    @State private var radio = 0
    @State private var tab = 0
    @State private var score = 0
    @State private var text = ""
    @State private var sliderFrame: CGRect = .zero

    private let titles = ["Buttons", "Toggle", "Slider", "Checkbox", "Radio", "Text input", "Tabs", "Progress", "Rating", "Toast", "Tooltip"]

    var body: some View {
        VStack(spacing: 0) {
            Text(titles[page])
                .font(DS.Typography.brand(34))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.top, 30)
            ZStack { content }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
            HStack {
                Button("Back") { page = max(0, page - 1) }.disabled(page == 0)
                Spacer()
                Text("\(page + 1) of \(titles.count)").foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Button("Next") { page = min(titles.count - 1, page + 1) }.disabled(page == titles.count - 1)
            }
            .font(DS.Typography.brand(.headline))
            .padding(24)
        }
        .background {
            LinearGradient(colors: [Color(hex: 0xFFF6EC), .white], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
        .overlay { SakugaLayer(stage: stage).ignoresSafeArea() }
        .environment(\.sakuga, stage)
        .environment(\.feedback, feedback)
        .preferredColorScheme(.light)
        .task {
            await feedback.prepare()
            await demo()
        }
    }

    @ViewBuilder private var content: some View {
        switch page {
        case 0:
            VStack(spacing: 90) {
                SakugaButton(title: "Confirm", fire: fire1)
                SakugaButton(title: "Cancel", isPrimary: false, fire: fire2)
            }
        case 1: SakugaToggle(isOn: $isOn, label: "Notifications").scaleEffect(1.35)
        case 2: SakugaSlider(value: $slider, label: "Budget")
        case 3: SakugaCheckbox(title: "Remember me", isOn: $isChecked)
        case 4: SakugaRadio(options: ["Monthly rent", "Yearly rent"], selection: $radio)
        case 5: SakugaInput(prompt: "Type something", text: $text)
        case 6: SakugaTabs(titles: ["Units", "Rent", "Repairs"], selection: $tab)
        case 7: SakugaProgress(value: progress)
        case 8: SakugaRating(score: $score)
        case 9: SakugaToast(message: "Rent recorded", isShown: $isToast)
        default: SakugaTooltip(hint: "Tap a unit to see its tenant", isOpen: $isTip)
        }
    }

    // MARK: Demo

    private func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }

    private func demo() async {
        guard UserDefaults.standard.bool(forKey: "PurrpertySakugaDemo") else { return }
        await pause(4)
        for p in titles.indices {
            page = p
            print("SAKUGA \(p) \(Date.now.timeIntervalSince1970)")
            await pause(0.9)
            switch p {
            case 0: fire1 += 1; await pause(2.2); fire2 += 1; await pause(1)
            case 1: isOn = true; await pause(2.6); isOn = false; await pause(1)
            case 2: NotificationCenter.default.post(name: .sakugaDemoSlide, object: nil); await pause(3.6)
            case 3: isChecked = true; await pause(1.8); isChecked = false; await pause(0.8)
            case 4: radio = 1; await pause(1.5); radio = 0; await pause(1.3)
            case 5: for c in "Nice cat!" { text.append(c); await pause(0.13) }; await pause(0.8)
            case 6: tab = 1; await pause(1.2); tab = 2; await pause(1.2); tab = 0; await pause(1.2)
            case 7: for i in 1...32 { progress = Double(i) / 32; await pause(i.isMultiple(of: 7) ? 0.22 : 0.09) }; await pause(2)
            case 8: score = 3; await pause(1.6); score = 5; await pause(2)
            case 9: isToast = true; await pause(2.2); isToast = false; await pause(0.8)
            default: isTip = true; await pause(2.2)
            }
        }
        print("SAKUGA end \(Date.now.timeIntervalSince1970)")
    }
}
extension Notification.Name { static let sakugaDemoSlide = Notification.Name("sakugaDemoSlide") }
#endif
