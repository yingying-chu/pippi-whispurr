//
//  HealthViews.swift
//  PippiWhispurr
//
//  Lightweight owner-observed health check-ins. These are personal records,
//  not medical assessments.
//

import SwiftUI

struct HealthCheckInEditorView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPetID: UUID?
    @State private var date = Date()
    @State private var appetite = HealthCheckIn.Level.normal
    @State private var energy = HealthCheckIn.Level.normal
    @State private var mood = HealthCheckIn.Mood.calm
    @State private var weightText = ""
    @State private var weightUnit = HealthCheckIn.WeightUnit.pounds
    @State private var notes = ""

    init(preselectedPetID: UUID? = nil) {
        _selectedPetID = State(initialValue: preselectedPetID)
    }

    var body: some View {
        Group {
            if storyStore.pets.isEmpty {
                emptyPetState
            } else {
                Form {
                    Section {
                        Picker("Pet", selection: $selectedPetID) {
                            ForEach(storyStore.pets) { pet in
                                Text(pet.name).tag(Optional(pet.id))
                            }
                        }

                        DatePicker(
                            "Date",
                            selection: $date,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    checkInSection(
                        title: "Appetite",
                        systemImage: "fork.knife",
                        selection: $appetite
                    )

                    checkInSection(
                        title: "Energy",
                        systemImage: "bolt.fill",
                        selection: $energy
                    )

                    Section("Mood") {
                        Picker("Mood", selection: $mood) {
                            ForEach(HealthCheckIn.Mood.allCases, id: \.self) { value in
                                Text(value.displayName).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section {
                        HStack {
                            TextField("Weight", text: $weightText)
                                .keyboardType(.decimalPad)

                            Picker("Unit", selection: $weightUnit) {
                                ForEach(HealthCheckIn.WeightUnit.allCases, id: \.self) { unit in
                                    Text(unit.shortName).tag(unit)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 110)
                        }

                        TextField("Anything you noticed?", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    } header: {
                        Text("Optional details")
                    } footer: {
                        Text("A simple observation log for you. It does not replace veterinary advice.")
                    }
                }
            }
        }
        .navigationTitle("Health Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            if !storyStore.pets.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(selectedPetID == nil)
                }
            }
        }
        .onAppear {
            if selectedPetID == nil || !storyStore.pets.contains(where: { $0.id == selectedPetID }) {
                selectedPetID = storyStore.pets.first?.id
            }
        }
    }

    private var emptyPetState: some View {
        VStack(spacing: 14) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Add a pet first")
                .font(.title2.bold())
            Text("Health check-ins belong to a pet. Add one from the Pets tab, then come back here.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func checkInSection(
        title: String,
        systemImage: String,
        selection: Binding<HealthCheckIn.Level>
    ) -> some View {
        Section {
            Picker(title, selection: selection) {
                ForEach(HealthCheckIn.Level.allCases, id: \.self) { value in
                    Text(value.displayName).tag(value)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label(title, systemImage: systemImage)
        }
    }

    private func save() {
        guard let petID = selectedPetID else { return }
        let normalizedWeight = weightText.replacingOccurrences(of: ",", with: ".")
        let weight = normalizedWeight.isEmpty ? nil : Double(normalizedWeight)

        storyStore.upsertHealthCheckIn(
            HealthCheckIn(
                petID: petID,
                date: date,
                appetite: appetite,
                energy: energy,
                mood: mood,
                weight: weight,
                weightUnit: weightUnit,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        dismiss()
    }
}

struct PetHealthView: View {
    @EnvironmentObject private var storyStore: StoryStore
    let petID: UUID
    @State private var showingEditor = false

    private var pet: PetProfile? {
        storyStore.pets.first { $0.id == petID }
    }

    private var checkIns: [HealthCheckIn] {
        storyStore.healthCheckIns
            .filter { $0.petID == petID }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if checkIns.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("No check-ins yet")
                        .font(.title2.bold())
                    Text("Record appetite, energy, mood, and anything else you notice.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Button("Add First Check-in") { showingEditor = true }
                        .buttonStyle(PippiPrimaryButtonStyle())
                        .controlSize(.large)
                }
            } else {
                List {
                    Section {
                        ForEach(checkIns) { checkIn in
                            HealthCheckInRow(checkIn: checkIn)
                        }
                        .onDelete(perform: delete)
                    } footer: {
                        Text("These entries show your observations over time and are not a medical diagnosis.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(pet.map { "\($0.name)’s Health" } ?? "Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationView {
                HealthCheckInEditorView(preselectedPetID: petID)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            storyStore.deleteHealthCheckIn(id: checkIns[index].id)
        }
    }
}

private struct HealthCheckInRow: View {
    let checkIn: HealthCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(checkIn.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                Label(checkIn.mood.displayName, systemImage: checkIn.mood.systemImage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 18) {
                value(label: "Appetite", value: checkIn.appetite.displayName)
                value(label: "Energy", value: checkIn.energy.displayName)
                if let weight = checkIn.weight {
                    value(
                        label: "Weight",
                        value: "\(weight.formatted()) \(checkIn.weightUnit.shortName)"
                    )
                }
            }

            if !checkIn.notes.isEmpty {
                Text(checkIn.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func value(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

extension HealthCheckIn.Level {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
}

extension HealthCheckIn.Mood {
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .playful: return "Playful"
        case .anxious: return "Anxious"
        case .unwell: return "Unwell"
        }
    }

    var systemImage: String {
        switch self {
        case .happy: return "face.smiling"
        case .calm: return "leaf"
        case .playful: return "sparkles"
        case .anxious: return "exclamationmark.bubble"
        case .unwell: return "cross.case"
        }
    }
}

extension HealthCheckIn.WeightUnit {
    var shortName: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }
}
