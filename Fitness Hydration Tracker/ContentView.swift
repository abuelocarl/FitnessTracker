//
//  ContentView.swift
//  Fitness Hydration Tracker
//

import SwiftUI
import UIKit

// MARK: - Tab Bar Suppressor

/// Walks every UIWindow in every active UIWindowScene and hides any
/// UITabBarController tab bar iOS may have injected, regardless of whether
/// our representable VC happens to be inside one.
private struct TabBarSuppressor: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .compactMap { $0.rootViewController }
            .forEach { suppress($0) }
    }

    private func suppress(_ vc: UIViewController) {
        if let tab = vc as? UITabBarController {
            tab.tabBar.isHidden = true
            tab.tabBar.frame   = .zero
        }
        vc.children.forEach { suppress($0) }
    }
}

// MARK: - Beach Palette

extension Color {
    static let oceanDeep  = Color(red: 0.04, green: 0.18, blue: 0.42)
    static let oceanMid   = Color(red: 0.06, green: 0.40, blue: 0.70)
    static let seafoam    = Color(red: 0.18, green: 0.72, blue: 0.72)
    static let sandy      = Color(red: 0.98, green: 0.84, blue: 0.45)
    static let coral      = Color(red: 1.00, green: 0.42, blue: 0.42)
    static let sunset     = Color(red: 1.00, green: 0.60, blue: 0.20)
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var vm     = HydrationViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ocean background — fills everything
            LinearGradient(
                colors: [.oceanDeep, .oceanMid, .seafoam],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Tab content — no TabView, so iOS never renders a system tab bar
            ZStack {
                TodayView(vm: vm)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                ProfileView(vm: vm)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            BeachTabBar(selectedTab: $selectedTab)
        }
        .task { await vm.onAppear() }
        .preferredColorScheme(.dark)
        .toolbarVisibility(.hidden, for: .tabBar)
        .background(TabBarSuppressor())
    }
}

// MARK: - Bottom Tab Bar

struct BeachTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            BeachTabItem(icon: "drop.fill",   label: "Hydrate", tag: 0, selected: $selectedTab)
            BeachTabItem(icon: "person.fill", label: "Profile", tag: 1, selected: $selectedTab)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, 60)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }
}

struct BeachTabItem: View {
    let icon: String
    let label: String
    let tag: Int
    @Binding var selected: Int

    var isOn: Bool { selected == tag }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = tag }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(isOn ? Color.sandy : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .scaleEffect(isOn ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today Tab

struct TodayView: View {
    @ObservedObject var vm: HydrationViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                headerSection
                BeachRingView(
                    progress:   vm.progress,
                    loggedCups: vm.loggedCups,
                    goalCups:   vm.result.totalCups
                )
                statusBadge
                quickLogSection
                factorCardsSection
                breakdownSection
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stay Hydrated 🌊")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: Status badge

    private var statusBadge: some View {
        Group {
            if vm.goalReached {
                Label("Goal Crushed! 🏆", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.oceanDeep)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.sandy)
                    .clipShape(Capsule())
            } else {
                Text(String(format: "%.1f cups to go 💧", vm.remainingCups))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: Quick log

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Log Water")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ForEach([(0.5, "½"), (1.0, "1"), (1.5, "1½"), (2.0, "2")], id: \.0) { cups, label in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            vm.logWater(cups: cups)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("🌊").font(.title3)
                            Text(label)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text(cups == 1.0 ? "cup" : "cups")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.seafoam, Color.oceanMid],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.seafoam.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Factor cards

    private var factorCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's Vibes")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                BeachFactorCard(
                    emoji: weatherEmoji,
                    title: vm.weather.weather?.cityName ?? "Weather",
                    value: weatherValue,
                    subtitle: weatherSubtitle,
                    accent: Color.sunset,
                    isLoading: vm.weather.isLoading
                )
                BeachFactorCard(
                    emoji: stepsEmoji,
                    title: "Steps",
                    value: vm.health.steps.formatted(),
                    subtitle: stepsSubtitle,
                    accent: Color.coral,
                    isLoading: false
                )
            }

            if vm.weather.usingDefaultLocation {
                Text("📍 Using default location — grant access for local weather.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                BeachBreakdownRow(label: "Base",     icon: "🏖️", cups: vm.result.baseCups,      accent: .seafoam)
                BeachBreakdownRow(label: "Activity", icon: "👟", cups: vm.result.stepsCups,     accent: .coral)
                BeachBreakdownRow(label: "Heat",     icon: "☀️", cups: vm.result.tempCups,      accent: .sunset)
                BeachBreakdownRow(label: "Humidity", icon: "💦", cups: vm.result.humidityCups,  accent: .sandy)

                Divider().overlay(.white.opacity(0.25))

                HStack {
                    Text("Daily Goal")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(String(format: "%.1f cups", vm.result.totalCups))
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(Color.sandy)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: Display helpers

    private var weatherEmoji: String {
        guard let w = vm.weather.weather else { return "🌤️" }
        switch w.weatherCode {
        case 0:       return "☀️"
        case 1, 2:    return "⛅"
        case 3:       return "☁️"
        case 45, 48:  return "🌫️"
        case 51...65: return "🌧️"
        case 71...77: return "❄️"
        case 80...82: return "🌨️"
        case 95...99: return "⛈️"
        default:      return "🌤️"
        }
    }

    private var weatherValue: String {
        guard let w = vm.weather.weather else { return "--" }
        return "\(Int(w.temperatureFahrenheit))°F · \(Int(w.humidity))%"
    }

    private var weatherSubtitle: String {
        if vm.weather.isLoading { return "Loading…" }
        guard let w = vm.weather.weather else { return "Unavailable" }
        return HydrationCalculator.weatherDescription(for: w.weatherCode)
    }

    private var stepsEmoji: String {
        switch vm.health.steps {
        case 0..<2_000:  return "🐌"
        case 2_000..<5_000:  return "🚶"
        case 5_000..<10_000: return "🏃"
        default:             return "⚡️"
        }
    }

    private var stepsSubtitle: String {
        switch vm.health.steps {
        case 0..<2_000:      return "Let's move!"
        case 2_000..<5_000:  return "Keep it up!"
        case 5_000..<10_000: return "Great work!"
        default:             return "Crushing it!"
        }
    }
}

// MARK: - Beach Ring

struct BeachRingView: View {
    let progress:   Double
    let loggedCups: Double
    let goalCups:   Double

    @State private var animatedProgress: Double = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.seafoam.opacity(0.18), lineWidth: 26)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [Color.sandy, Color.coral, Color.seafoam],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.coral.opacity(0.5), radius: 14, x: 0, y: 4)

            VStack(spacing: 6) {
                Text("🌊")
                    .font(.system(size: 36))
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: pulse
                    )

                Text(String(format: "%.1f", loggedCups))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(format: "of %.1f cups", goalCups))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))

                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.oceanDeep)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Color.sandy)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 258, height: 258)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { animatedProgress = progress }
            pulse = true
        }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.5)) { animatedProgress = new }
        }
    }
}

// MARK: - Factor Card

struct BeachFactorCard: View {
    let emoji:     String
    let title:     String
    let value:     String
    let subtitle:  String
    let accent:    Color
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji).font(.title2)
            Text(title)
                .font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            Text(isLoading ? "--" : value)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white).lineLimit(1)
            Text(isLoading ? "Loading…" : subtitle)
                .font(.caption2).foregroundStyle(accent).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Breakdown Row

struct BeachBreakdownRow: View {
    let label:  String
    let icon:   String
    let cups:   Double
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.body)
            Text(label)
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(String(format: "+%.2f cups", cups))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(accent)
        }
    }
}

// MARK: - Profile / Configurator Tab

struct ProfileView: View {
    @ObservedObject var vm: HydrationViewModel
    @State private var weightText = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Profile 🏄")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Customize your hydration target")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                activityLevelSection
                weightSection
                goalPreviewCard
                resetSection
                infoSection

                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .onAppear { weightText = String(format: "%.0f", vm.weightLbs) }
    }

    // MARK: Activity level picker

    private var activityLevelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity Level")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(HydrationLevel.allCases, id: \.rawValue) { level in
                    HydrationLevelCard(
                        level: level,
                        isSelected: vm.hydrationLevel == level
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.hydrationLevel = level
                        }
                    }
                }
            }
        }
    }

    // MARK: Weight input

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Body Weight")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Text("⚖️").font(.title2)

                TextField("154", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .onChange(of: weightText) { _, v in
                        if let w = Double(v), w > 0 { vm.weightLbs = w }
                    }

                Text("lbs")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Live goal preview

    private var goalPreviewCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Text(String(format: "%.1f cups", vm.result.totalCups))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.sandy)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Level")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(vm.hydrationLevel.emoji) \(vm.hydrationLevel.rawValue)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.oceanMid, Color.seafoam.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.sandy.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: Reset

    private var resetSection: some View {
        Button { vm.resetToday() } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset Today's Intake").fontWeight(.semibold)
            }
            .foregroundStyle(Color.coral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.coral.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.coral.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                InfoRow(label: "Formula",  value: "WHO + Activity")
                InfoRow(label: "Weather",  value: "Open-Meteo API")
                InfoRow(label: "Steps",    value: "Apple HealthKit")
                InfoRow(label: "Units",    value: "US Imperial (cups / °F / lbs)")
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Hydration Level Card

struct HydrationLevelCard: View {
    let level:      HydrationLevel
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(level.emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.sandy.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(isSelected ? Color.sandy : .white)
                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                Text(String(format: "×%.2f", level.multiplier))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? Color.oceanDeep : .white.opacity(0.45))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(isSelected ? Color.sandy : Color.white.opacity(0.08))
                    .clipShape(Capsule())

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sandy)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(isSelected ? Color.seafoam.opacity(0.18) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? Color.sandy.opacity(0.55) : Color.white.opacity(0.08),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview { ContentView() }
