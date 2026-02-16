//
//  LocationService.swift
//  ilkelMDM
//
//  Location updates via CoreLocation; reports via callback.
//

import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject {
    private let locationManager = CLLocationManager()
    var onLocationUpdate: ((CLLocation) -> Void)?

    func start() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            onLocationUpdate?(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
