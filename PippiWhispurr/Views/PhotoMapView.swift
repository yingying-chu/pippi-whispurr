//
//  PhotoMapView.swift
//  PippiWhispurr
//

import SwiftUI
import MapKit
import CoreLocation

private struct MapMoment: Identifiable {
    enum Kind {
        case photo(PetPhoto)
        case memory(UUID)
        case home
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let date: Date?
    let kind: Kind
}

struct PhotoMapBrowserView: View {
    @EnvironmentObject private var storyStore: StoryStore
    let photos: [PetPhoto]

    @StateObject private var locationProvider = MapLocationProvider()
    @State private var selectedMomentID: String?
    @State private var showingHomeEditor = false
    @State private var hasPositionedInitially = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
        span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 35)
    )

    @AppStorage("pippiHomeLocationName") private var homeName = ""
    @AppStorage("pippiHomeLatitude") private var homeLatitude = 0.0
    @AppStorage("pippiHomeLongitude") private var homeLongitude = 0.0
    @AppStorage("pippiHasHomeLocation") private var hasHomeLocation = false

    private let maximumVisiblePins = 200

    private var moments: [MapMoment] {
        var values: [MapMoment] = photos.compactMap { photo in
            guard let coordinate = photo.asset?.location?.coordinate,
                  CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return MapMoment(
                id: "photo-\(photo.id)",
                coordinate: coordinate,
                title: photo.petType.rawValue,
                date: photo.date,
                kind: .photo(photo)
            )
        }

        values += storyStore.memories.compactMap { memory in
            guard let latitude = memory.latitude,
                  let longitude = memory.longitude else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return MapMoment(
                id: "memory-\(memory.id.uuidString)",
                coordinate: coordinate,
                title: memory.title.isEmpty ? "Pet memory" : memory.title,
                date: memory.memoryDate,
                kind: .memory(memory.id)
            )
        }

        values.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        if hasHomeLocation {
            values.append(MapMoment(
                id: "home",
                coordinate: homeCoordinate,
                title: homeName.isEmpty ? "Home" : homeName,
                date: nil,
                kind: .home
            ))
        }
        return values
    }

    private var visibleMoments: [MapMoment] {
        Array(moments.prefix(maximumVisiblePins))
    }

    private var selectedMoment: MapMoment? {
        visibleMoments.first { $0.id == selectedMomentID }
    }

    private var homeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(
                coordinateRegion: $region,
                interactionModes: .all,
                showsUserLocation: true,
                annotationItems: visibleMoments
            ) { moment in
                MapAnnotation(coordinate: moment.coordinate) {
                    Button {
                        selectedMomentID = moment.id
                    } label: {
                        Image(systemName: markerIcon(for: moment))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(9)
                            .background(markerColor(for: moment))
                            .clipShape(Circle())
                            .shadow(radius: 3, y: 2)
                    }
                }
            }

            VStack(spacing: 10) {
                if visibleMoments.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "pawprint.fill")
                            .font(.title2)
                        Text("Your paths will appear here")
                            .font(.pippi(18, weight: .extraBold))
                        Text("Add a Home location or save a memory with a place.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("SET HOME LOCATION") { showingHomeEditor = true }
                            .buttonStyle(PippiPrimaryButtonStyle())
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
                    .padding()
                } else if let selectedMoment {
                    selectedMomentCard(selectedMoment)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Button {
                    focusNearby()
                } label: {
                    Image(systemName: "location.fill")
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Button {
                    showingHomeEditor = true
                } label: {
                    Image(systemName: "house.fill")
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .foregroundColor(.forestInk)
            .padding(12)
        }
        .onAppear {
            locationProvider.requestLocation()
            focusInitialRegion()
        }
        .onChange(of: moments.map(\.id)) { _ in
            focusInitialRegion()
        }
        .onChange(of: locationProvider.coordinate?.latitude) { _ in
            focusInitialRegion()
        }
        .sheet(isPresented: $showingHomeEditor, onDismiss: {
            hasPositionedInitially = false
            focusInitialRegion()
        }) {
            HomeLocationEditor(
                name: $homeName,
                latitude: $homeLatitude,
                longitude: $homeLongitude,
                isSet: $hasHomeLocation
            )
        }
    }

    @ViewBuilder
    private func selectedMomentCard(_ moment: MapMoment) -> some View {
        switch moment.kind {
        case .photo(let photo):
            NavigationLink(destination: PhotoDetailView(photo: photo, photos: photos)) {
                HStack(spacing: 12) {
                    PhotoThumbnailView(photo: photo).frame(width: 64, height: 64)
                    cardText(moment)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .mapCardStyle()
            }
            .buttonStyle(.plain)
        case .memory(let id):
            NavigationLink(destination: JournalDetailView(memoryID: id)) {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(Color.honeyYellow)
                        .clipShape(Circle())
                    cardText(moment)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .mapCardStyle()
            }
            .buttonStyle(.plain)
        case .home:
            HStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.title2)
                cardText(moment)
                Spacer()
                Button("Edit") { showingHomeEditor = true }
            }
            .mapCardStyle()
        }
    }

    private func cardText(_ moment: MapMoment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(moment.title).font(.headline).foregroundColor(.primary)
            if let date = moment.date {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func markerIcon(for moment: MapMoment) -> String {
        switch moment.kind {
        case .home: return "house.fill"
        case .memory: return "book.closed.fill"
        case .photo: return selectedMomentID == moment.id ? "pawprint.fill" : "pawprint"
        }
    }

    private func markerColor(for moment: MapMoment) -> Color {
        switch moment.kind {
        case .home: return .blobOrange
        case .memory: return .honeyYellow
        case .photo: return .forestInk
        }
    }

    private func focusInitialRegion() {
        guard !hasPositionedInitially else { return }
        if let recentMoment = moments.first(where: {
            if case .home = $0.kind { return false }
            return true
        }) {
            setRegion(center: recentMoment.coordinate)
        } else if hasHomeLocation {
            setRegion(center: homeCoordinate)
        } else if let coordinate = locationProvider.coordinate {
            setRegion(center: coordinate)
        } else {
            return
        }
        hasPositionedInitially = true
    }

    private func focusNearby() {
        if let coordinate = locationProvider.coordinate {
            setRegion(center: coordinate)
        } else if hasHomeLocation {
            setRegion(center: homeCoordinate)
        } else if let first = moments.first {
            setRegion(center: first.coordinate)
        }
    }

    private func setRegion(center: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    }
}

private extension View {
    func mapCardStyle() -> some View {
        self
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 8, y: 4)
            .padding()
    }
}

private final class MapLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

private struct HomeLocationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var isSet: Bool
    @State private var query = ""
    @State private var isLookingUp = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Where is home?")
                    .font(.pippi(26, weight: .extraBold))
                    .foregroundColor(.forestInk)
                Text("A neighborhood, city, or address is enough. PiPi keeps the saved coordinate on this device.")
                    .foregroundColor(.secondary)
                TextField("e.g. Silver Lake, Los Angeles", text: $query)
                    .textFieldStyle(.roundedBorder)
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundColor(.red)
                }
                Button {
                    Task { await saveHome() }
                } label: {
                    if isLookingUp {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("SAVE HOME LOCATION").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PippiPrimaryButtonStyle())
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLookingUp)
                Spacer()
            }
            .padding(20)
            .background(Color.cream.ignoresSafeArea())
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .onAppear { query = name }
        }
    }

    @MainActor
    private func saveHome() async {
        isLookingUp = true
        defer { isLookingUp = false }
        guard let placemark = try? await CLGeocoder().geocodeAddressString(query).first,
              let coordinate = placemark.location?.coordinate else {
            errorMessage = "PiPi couldn’t find that place. Try a city and state."
            return
        }
        name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        isSet = true
        dismiss()
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
                    .font(.subheadline.weight(.semibold))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(8)
            }
            .frame(height: 140)
            .cornerRadius(.radiusCard)
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
        let coordinate = photo.asset?.location?.coordinate ?? CLLocationCoordinate2D()
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
