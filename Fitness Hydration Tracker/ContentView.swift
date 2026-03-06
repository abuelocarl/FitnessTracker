//
//  ContentView.swift
//  Fitness Hydration Tracker
//
//  Created by Carlos Calegari on 3/6/26.
//

import SwiftUI

// MARK: - Root view

struct ContentView: View {
    @State private var vm = HydrationViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    statusLabel
                    HydrationRingView(
                        progress: vm.progress,
                        loggedML: vm.loggedML,
                        goalML: vm.result.totalML
                    )
                    quickLogSection
                    factorCardsSection
                    breakdownSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.blue)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(vm: vm)
            }
        }
        .task { await vm.onAppear() }
    }

    // MARK: - Sub-sections

    private var statusLabel: some View {
        Group {
            if vm.goalReached {
                Label("Daily goal reached!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .clipShape(Capsule())
            } else {
                Text("\(Int(vm.remainingML)) ml remaining today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Log Water")
            HStack(spacing: 10) {
                ForEach([150, 250, 350, 500], id: \.self) { amount in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.logWater(Double(amount))
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.body)
                            Text("\(amount)")
                                .font(.caption2.weight(.bold))
                            Text("ml")
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var factorCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Factors")
            HStack(spacing: 12) {
                FactorCard(
                    icon: weatherIcon,
                    iconColor: .orange,
                    title: vm.weather.weather?.cityName ?? "Weather",
                    subtitle: weatherSubtitle,
                    value: weatherValue,
                    isLoading: vm.weather.isLoading
                )
                FactorCard(
                    icon: "figure.walk",
                    iconColor: .green,
                    title: "Steps Today",
                    subtitle: stepsSubtitle,
                    value: vm.health.steps.formatted(),
                    isLoading: false
                )
            }
            if vm.weather.usingDefaultLocation {
                Text("Using London as default — grant location access for accurate weather.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Breakdown")
            VStack(spacing: 10) {
                BreakdownRow(label: "Base (body weight)", value: vm.result.baseML, color: .blue)
                BreakdownRow(label: "Activity (steps)", value: vm.result.stepsAdditionML, color: .green)
                BreakdownRow(label: "Heat (temperature)", value: vm.result.temperatureAdditionML, color: .orange)
                BreakdownRow(label: "Humidity", value: vm.result.humidityAdditionML, color: .cyan)
                Divider()
                HStack {
                    Text("Daily goal")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(vm.result.totalLiters)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Computed display helpers

    private var weatherIcon: String {
        HydrationCalculator.weatherIcon(for: vm.weather.weather?.weatherCode ?? 0)
    }

    private var weatherSubtitle: String {
        if vm.weather.isLoading { return "Loading…" }
        guard let w = vm.weather.weather else { return "Unavailable" }
        return HydrationCalculator.weatherDescription(for: w.weatherCode)
    }

    private var weatherValue: String {
        guard let w = vm.weather.weather else { return "--" }
        return "\(Int(w.temperatureCelsius))°C · \(Int(w.humidity))%"
    }

    private var stepsSubtitle: String {
        switch vm.health.steps {
        case 0 ..< 2_000:     return "Let's get moving!"
        case 2_000 ..< 5_000: return "Keep it up!"
        case 5_000 ..< 10_000: return "Great progress!"
        default:               return "Outstanding!"
        }
    }
}

// MARK: - Hydration Ring

struct HydrationRingView: View {
    let progress: Double
    let loggedML: Double
    let goalML: Double

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 24)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .cyan, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)

            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
                    )
                Text("\(Int(loggedML)) ml")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("of \(Int(goalML)) ml")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 240, height: 240)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.5)) {
                animatedProgress = new
            }
        }
    }
}

// MARK: - Reusable components

struct FactorCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(isLoading ? "--" : value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BreakdownRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("+\(Int(value)) ml")
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - Settings

struct SettingsView: View {
    let vm: HydrationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Body") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("70", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Today") {
                    Button("Reset today's intake", role: .destructive) {
                        vm.resetToday()
                        dismiss()
                    }
                }
                Section("About") {
                    LabeledContent("Formula", value: "WHO + Activity guidelines")
                    LabeledContent("Weather", value: "Open-Meteo (free API)")
                    LabeledContent("Steps", value: "Apple HealthKit")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if let w = Double(weightText), w > 0 {
                            vm.weightKg = w
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { weightText = String(format: "%.0f", vm.weightKg) }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
