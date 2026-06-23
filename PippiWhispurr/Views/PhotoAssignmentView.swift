//
//  PhotoAssignmentView.swift
//  PippiWhispurr
//
//  Assign one library photo to one or more pet stories.
//

import SwiftUI

struct PhotoAssignmentView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @Environment(\.dismiss) private var dismiss

    let photo: PetPhoto
    @State private var selectedPetIDs: Set<UUID>

    init(photo: PetPhoto, assignedPetIDs: Set<UUID>) {
        self.photo = photo
        _selectedPetIDs = State(initialValue: assignedPetIDs)
    }

    var body: some View {
        NavigationView {
            Group {
                if storyStore.pets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "pawprint.circle")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        Text("Add a pet first")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("A photo can belong to one pet or several pets who appear together.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        Section {
                            ForEach(storyStore.pets) { pet in
                                Button {
                                    toggle(pet.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(pet.name)
                                                .foregroundColor(.primary)
                                            Text(pet.species)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: selectedPetIDs.contains(pet.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(selectedPetIDs.contains(pet.id) ? .blue : .secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } footer: {
                            Text("Select every pet who appears in this photo. You can choose more than one.")
                        }
                    }
                }
            }
            .navigationTitle("Assign to Pets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        storyStore.assignPhoto(id: photo.id, to: selectedPetIDs)
                        dismiss()
                    }
                    .disabled(storyStore.pets.isEmpty)
                }
            }
        }
    }

    private func toggle(_ petID: UUID) {
        if selectedPetIDs.contains(petID) {
            selectedPetIDs.remove(petID)
        } else {
            selectedPetIDs.insert(petID)
        }
    }
}
