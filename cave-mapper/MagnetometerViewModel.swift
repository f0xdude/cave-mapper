//
//  MagnetometerViewModel.swift
//  cave-mapper
//
//  Created by Andrey Manolov on 22.11.24.
//

import SwiftUI
import CoreMotion
import CoreLocation

class MagnetometerViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    // MARK: - UserDefaults Keys
    private struct DefaultsKeys {
        static let highThreshold = "highThreshold"
        static let lowThreshold = "lowThreshold"
        static let wheelCircumference = "wheelCircumference"
    }
    
    // MARK: - Published Properties
    @Published var highThreshold: Double {
        didSet {
            UserDefaults.standard.set(highThreshold, forKey: DefaultsKeys.highThreshold)
        }
    }
    
    @Published var lowThreshold: Double {
        didSet {
            UserDefaults.standard.set(lowThreshold, forKey: DefaultsKeys.lowThreshold)
        }
    }
    
    @Published var wheelCircumference: Double {
        didSet {
            UserDefaults.standard.set(wheelCircumference, forKey: DefaultsKeys.wheelCircumference)
        }
    }
    
    // Internal State
    @Published var revolutions = DataManager.loadPointNumber()
    @Published var isRunning = false
    @Published var currentField: CMMagneticField = CMMagneticField(x: 0, y: 0, z: 0)
    @Published var currentMagnitude: Double = 0.0
    @Published var magneticFieldHistory: [Double] = [] // Debugging: Store recent magnitudes
    @Published var currentHeading: CLHeading?          // Stores the current heading
    @Published var calibrationNeeded: Bool = false     // Indicates if calibration is needed
    
    private var isReadyForNewPeak: Bool = true // Tracks if the system is ready for a new peak
    private var lastPosition = CGPoint.zero    // Last position on the stick map
    
    // MARK: - Initializer
    override init() {
        // Initialize published properties from UserDefaults or set default values
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: DefaultsKeys.highThreshold) != nil {
            self.highThreshold = userDefaults.double(forKey: DefaultsKeys.highThreshold)
        } else {
            self.highThreshold = 1170 // Default value
        }
        
        if userDefaults.object(forKey: DefaultsKeys.lowThreshold) != nil {
            self.lowThreshold = userDefaults.double(forKey: DefaultsKeys.lowThreshold)
        } else {
            self.lowThreshold = 1000 // Default value
        }
        
        if userDefaults.object(forKey: DefaultsKeys.wheelCircumference) != nil {
            self.wheelCircumference = userDefaults.double(forKey: DefaultsKeys.wheelCircumference)
        } else {
            self.wheelCircumference = 11.78 // Default value in centimeters
        }
        
        super.init()
        
        // Setup Location Manager
        locationManager.delegate = self
        locationManager.headingFilter = 1 // Update for every degree of heading change
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Monitoring Methods
    
    func startMonitoring() {
        guard motionManager.isMagnetometerAvailable else { return }
        motionManager.magnetometerUpdateInterval = 0.03             // IMPORTNAT FOX EDIT 0.01 for fast reading
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data, error == nil else { return }
            self.isRunning = true
            self.currentField = data.magneticField
            self.currentMagnitude = self.calculateMagnitude(data.magneticField)
            self.magneticFieldHistory.append(self.currentMagnitude)
            if self.magneticFieldHistory.count > 50 {
                self.magneticFieldHistory.removeFirst()
            }
            self.detectPeak(self.currentMagnitude)
        }
        
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    func stopMonitoring() {
        motionManager.stopMagnetometerUpdates()
        locationManager.stopUpdatingHeading()
        isRunning = false
    }
    
    // MARK: - Helper Methods
    
    private func calculateMagnitude(_ magneticField: CMMagneticField) -> Double {
        return sqrt(pow(magneticField.x, 2) + pow(magneticField.y, 2) + pow(magneticField.z, 2))
        
        // andrew patch Only Z axis is fluctuating with current magnet wheel setup
        
    }
    
    private func detectPeak(_ magnitude: Double) {
        if isReadyForNewPeak && magnitude > highThreshold {
            // Peak detected
            revolutions += 1
            isReadyForNewPeak = false // Block further peaks until reset
        } else if !isReadyForNewPeak && magnitude < lowThreshold {
            // Reset condition met, ready for the next peak
            isReadyForNewPeak = true
        }
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.currentHeading = newHeading
            
            // Check if calibration is needed based on heading accuracy
            if newHeading.headingAccuracy < 0 || newHeading.headingAccuracy > 20 {
                // Notify that calibration is needed if accuracy is poor
                self.calibrationNeeded = true
            } else {
                self.calibrationNeeded = false
            }
        }
    }
    
    // This method asks for calibration if heading accuracy is poor
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        if let currentHeading = currentHeading {
            // Request calibration if heading accuracy is below a suitable threshold
            return currentHeading.headingAccuracy < 0 || currentHeading.headingAccuracy > 20
        }
        return true // Default to true if no heading is available
    }
    
    // MARK: - Start Calibration
        func startCalibration() {
            // This method triggers the calibration process
            // By starting heading updates, the system may prompt for calibration if needed
            if CLLocationManager.headingAvailable() {
                locationManager.startUpdatingHeading()
                
                // Optionally, you can check if calibration is already needed
                if let currentHeading = currentHeading {
                    if currentHeading.headingAccuracy < 0 || currentHeading.headingAccuracy > 20 {
                        // Prompted via the delegate methods to display calibration
                    }
                }
            }
        }
        
    // MARK: - Computed Properties
    
    // Computed property to calculate distance in centimeters
    var distanceInCentimeters: Double {
        return Double(revolutions) * wheelCircumference
    }
    
    // Computed property to calculate distance in meters
    var distanceInMeters: Double {
        return distanceInCentimeters / 100.0
    }
    
    // MARK: - New Computed Properties for Rounded Values
    
    /// Distance in meters rounded to two decimal places
    var roundedDistanceInMeters: Double {
        return (distanceInMeters * 100).rounded() / 100
    }
    
    /// Magnetic heading rounded to two decimal places
    var roundedMagneticHeading: Double? {
        guard let heading = currentHeading else { return nil }
        return (heading.magneticHeading * 100).rounded() / 100
    }
    
    /// True heading rounded to two decimal places
    var roundedTrueHeading: Double? {
        guard let heading = currentHeading else { return nil }
        return (heading.trueHeading * 100).rounded() / 100
    }
    
    
    
    // MARK: - Reset Method
    
    /// Resets the thresholds and wheel circumference to default values
    func resetToDefaults() {
        highThreshold = 1170
        lowThreshold = 1000
        wheelCircumference = 11.78
    }
}
