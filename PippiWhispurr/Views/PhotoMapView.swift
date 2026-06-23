//
//  PhotoMapView.swift
//  PippiWhispurr
//
//  Browse geotagged pet photos and inspect a photo's capture location.
//

import SwiftUI
import MapKit

private struct LocatedPetPhoto: Identifiable {
    let photo: PetPhoto
    let coordinate: CLLocationCoordinate2D

    var id: String { photo.id }
}

struct PhotoMapBrowserView: View {
    let photos: [PetPhoto]
    @State private var selectedPhotoID: String?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
        span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 45)
    )

    private let maximumVisiblePins = 200

    private var allLocatedPhotos: [LocatedPetPhoto] {
        photos.compactMap { photo in
            guard let coordinate = photo.asset.location?.coordinate,
                  CLLocationCoordinate2DIsValid(coordinate),
                  coordinate.latitude.isFinite,
                  coordinate.longitude.isFinite else {
                return nil
            }
            return LocatedPetPhoto(photo: photo, coordinate: coordinate)
        }
    }

    private var locatedPhotos: [LocatedPetPhoto] {
        Array(allLocatedPhotos.prefix(maximumVisiblePins))
    }

    private var selectedPhoto: PetPhoto? {
        guard let selectedPhotoID else { return nil }
        return locatedPhotos.first { $0.id == selectedPhotoID }?.photo
    }

    var body: some View {
        Group {
            if locatedPhotos.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "map")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary)
                    Text("No photo locations available")
                        .font(.headline)
                    Text("Only photos captured with location metadata appear on the map.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .bottom) {
                    Map(
                        coordinateRegion: $region,
                        interactionModes: .all,
                        annotationItems: locatedPhotos
                    ) { item in
                        MapAnnotation(coordinate: item.coordinate) {
                            Button {
                                selectedPhotoID = item.id
                            } label: {
                                Image(systemName: selectedPhotoID == item.id ? "pawprint.fill" : "pawprint")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(9)
                                    .background(selectedPhotoID == item.id ? Color.orange : Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 3, y: 2)
                            }
                        }
                    }

                    if let selectedPhoto {
                        NavigationLink(destination: PhotoDetailView(photo: selectedPhoto, photos: photos)) {
                            HStack(spacing: 12) {
                                PhotoThumbnailView(photo: selectedPhoto)
                                    .frame(width: 64, height: 64)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selectedPhoto.petType.rawValue)
                                        .font(.headline)
                                    Text(selectedPhoto.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(radius: 8, y: 4)
                            .padding()
                        }
                        .buttonStyle(.plain)
                    }

                    if allLocatedPhotos.count > maximumVisiblePins && selectedPhoto == nil {
                        Text("Showing the \(maximumVisiblePins) most recent mapped photos")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.bottom, 16)
                    }
                }
                .onAppear {
                    fitMapToPhotos()
                }
            }
        }
    }

    private func fitMapToPhotos() {
        let coordinates = locatedPhotos.map(\.coordinate)
        guard let first = coordinates.first else { return }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude

        let latitudeDelta = min(
            max((maxLatitude - minLatitude) * 1.4, 0.05),
            120
        )
        let longitudeDelta = min(
            max((maxLongitude - minLongitude) * 1.4, 0.05),
            180
        )
        let centerLatitude = min(max((minLatitude + maxLatitude) / 2, -85), 85)
        let centerLongitude = min(max((minLongitude + maxLongitude) / 2, -180), 180)

        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: centerLatitude,
                longitude: centerLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )
    }
}

struct PhotoLocationCard: View {
    let coordinate: CLLocationCoordinate2D
    let action: () -> Void
    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D, action: @escaping () -> Void) {
        self.coordinate = coordinate
        self.action = action
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Map(
                    coordinateRegion: $region,
                    interactionModes: [],
                    annotationItems: [MapPoint(coordinate: coordinate)]
                ) { point in
                    MapMarker(coordinate: point.coordinate, tint: .blue)
                }
                .allowsHitTesting(false)

                Label("View photo location", systemImage: "map.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(8)
            }
            .frame(height: 140)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

struct PhotoLocationFullMap: View {
    @Environment(\.dismiss) private var dismiss
    let photo: PetPhoto
    private let coordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion

    init(photo: PetPhoto) {
        self.photo = photo
        let coordinate = photo.asset.location?.coordinate ?? CLLocationCoordinate2D()
        self.coordinate = coordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    var body: some View {
        NavigationView {
            Map(
                coordinateRegion: $region,
                annotationItems: [MapPoint(coordinate: coordinate)]
            ) { point in
                MapMarker(coordinate: point.coordinate, tint: .blue)
            }
            .navigationTitle("Photo Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct MapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
