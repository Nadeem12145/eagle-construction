import CoreLocation
import MapKit

struct PickedPlace: Equatable {
    var lat: Double
    var lng: Double
    var address: String
    var postalCode: String
}

/// One-shot current location and address lookups.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus)
    }

    /// Shows the system permission prompt once; returns when the user has answered.
    func requestPermission() async {
        guard manager.authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async -> CLLocation? {
        await requestPermission()
        guard isAuthorized else { return nil }
        if let recent = manager.location, recent.timestamp.timeIntervalSinceNow > -60 { return recent }
        return await withCheckedContinuation { continuation in
            locationContinuation?.resume(returning: nil)
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Street address and postal code for a coordinate.
    func place(at coordinate: CLLocationCoordinate2D) async -> PickedPlace {
        var place = PickedPlace(lat: coordinate.latitude, lng: coordinate.longitude, address: "", postalCode: "")
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let request = MKReverseGeocodingRequest(location: location), let item = try? await request.mapItems.first {
            place.address = item.address?.fullAddress.replacingOccurrences(of: "\n", with: ", ") ?? item.name ?? ""
            place.postalCode = Self.postalCode(in: place.address)
        }
        if place.address.isEmpty {
            place.address = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }
        return place
    }

    /// Search results for the map's search field.
    func search(_ text: String, near region: MKCoordinateRegion?) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        if let region { request.region = region }
        return (try? await MKLocalSearch(request: request).start().mapItems) ?? []
    }

    /// UK and US style postcodes inside an address line ("SW1A 1AA", "10001").
    static func postalCode(in address: String) -> String {
        let patterns = [#"[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}"#, #"\b\d{5}(-\d{4})?\b"#]
        for pattern in patterns {
            if let range = address.range(of: pattern, options: .regularExpression) { return String(address[range]) }
        }
        return ""
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard manager.authorizationStatus != .notDetermined else { return }
            authContinuation?.resume()
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
