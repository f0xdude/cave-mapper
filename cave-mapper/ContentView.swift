import SwiftUI
import CoreLocation

struct ContentView: View {
    @ObservedObject var viewModel: MagnetometerViewModel
    @StateObject private var magnetometer = MagnetometerViewModel()

    @State private var showCalibrationAlert = false
    @State private var showResetSuccessAlert = false
    @State private var pointNumber: Int = DataManager.loadPointNumber()
    @State private var loadLastSavedDistance = DataManager.loadLastSavedDistance()
    @State private var showSettings = false // State variable for settings

    var body: some View {
        NavigationView {
            VStack {
                
                
                
                
                // Display the current compass heading
                if let heading = magnetometer.currentHeading {
                    VStack {
                        Text("Compass Heading")
                            .font(.headline)
                        Text("Magnetic Heading: \(heading.magneticHeading, specifier: "%.2f")°")
                        Text("True Heading: \(heading.trueHeading, specifier: "%.2f")°")
                    }
                } else {
                    Text("Heading not available")
                }

                Divider()

                Text("Recorded points:")
                    .font(.largeTitle)
                    .padding()

                Text("\(magnetometer.revolutions)")

                if magnetometer.isRunning {
                    Text("Detecting magnet...")
                        .foregroundColor(.green)
                } else {
                    Text("Start the wheel to detect revolutions")
                        .foregroundColor(.red)
                }

                Divider()

                // Display the calculated distance
                VStack(alignment: .leading) {
                    Text("Distance in Meters: \(magnetometer.distanceInMeters, specifier: "%.2f") m")
                        .font(.headline)
                }
                .padding()

                // Debugging: Display Magnetic Field Strength
                VStack(alignment: .leading) {
                    Text("Magnetic Field Strength (µT):")
                        .font(.headline)
                    Text("X: \(magnetometer.currentField.x, specifier: "%.2f")")
                    Text("Y: \(magnetometer.currentField.y, specifier: "%.2f")")
                    Text("Z: \(magnetometer.currentField.z, specifier: "%.2f")")
                    Text("Magnitude: \(magnetometer.currentMagnitude, specifier: "%.2f")")
                }
                .padding()

                Spacer() // Push content up to leave space for the buttons at the bottom

                // **Place the bottom buttons inside the VStack**
                ZStack {
                    // Reset button with 3-second hold requirement
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                        Text("Reset")
                            .foregroundColor(.white)
                            .bold()
                    }
                    .onLongPressGesture(minimumDuration: 3) {
                        resetMonitoringData()
                    }
                    .padding(.bottom, 20)

                    // Navigation button to show stick map oriented to north
                    NavigationLink(destination: NorthOrientedMapView()) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 50, height: 50)
                            Image(systemName: "map.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                    .offset(x: 120, y: 10)

                    // Save button to save data and navigate to SaveDataView
                    NavigationLink(destination: SaveDataView(magnetometer: magnetometer)) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 50, height: 50)
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                    .offset(x: -70, y: -80)
                    .padding(.bottom, 20)
                }
                .padding(.bottom) // Adjust padding as needed
            }
            .toolbar {
                // Add the settings button to the navigation bar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                }
            }
            // Move the sheet inside the NavigationView
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .onAppear {
                magnetometer.startMonitoring()
                UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from sleeping
            }
            .onDisappear {
                magnetometer.stopMonitoring()
                UIApplication.shared.isIdleTimerDisabled = false // Allow screen to sleep again
            }
            .alert(isPresented: $showCalibrationAlert) {
                Alert(title: Text("Compass Calibration Needed"),
                      message: Text("Please move your device in a figure-eight motion to calibrate the compass."),
                      dismissButton: .default(Text("OK")))
            }
            // Alert for reset success message
            .alert(isPresented: $showResetSuccessAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text("Data reset successfully."),
                    dismissButton: nil // No dismiss button
                )
            }
            .onChange(of: showResetSuccessAlert) { _, isPresented in
                if isPresented {
                    // Dismiss the alert after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showResetSuccessAlert = false
                    }
                }
            }
            .onChange(of: magnetometer.revolutions) { oldValue, newValue in
                _ = DataManager.loadLastSavedDepth()
                let savedData = SavedData(
                    recordNumber: pointNumber,
                    distance: magnetometer.roundedDistanceInMeters,
                    heading: magnetometer.roundedMagneticHeading ?? 0,
                    depth: 0.00,
                    rtype: "auto"
                )

                pointNumber += 1
                DataManager.save(savedData: savedData)
                DataManager.savePointNumber(pointNumber)
            }
        }
    }

    private func resetMonitoringData() {
        pointNumber = 0;
        magnetometer.revolutions = 0
        magnetometer.magneticFieldHistory = []
        DataManager.resetAllData()
        showResetSuccessAlert = true // Show success message
    }
}

//    
//// Preview
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(viewModel: MagnetometerViewModel())
//    }
//}
