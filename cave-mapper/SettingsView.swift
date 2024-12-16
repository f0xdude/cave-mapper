import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MagnetometerViewModel
    
    // NumberFormatter to handle decimal input
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    // State variable to control the display of calibration alert
    @State private var showCalibrationAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Threshold Settings
                Section(header: Text("Threshold Settings")) {
                    // High Threshold Input
                    HStack {
                        Text("High Threshold")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("1170", value: $viewModel.highThreshold, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    // Low Threshold Input
                    HStack {
                        Text("Low Threshold")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("1000", value: $viewModel.lowThreshold, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                // MARK: - Wheel Settings
                Section(header: Text("Wheel Settings")) {
                    // Wheel Circumference Input
                    HStack {
                        Text("Wheel Circumference (cm)")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("11.78", value: $viewModel.wheelCircumference, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                // MARK: - Calibration Section
                Section(header: Text("Compass Calibration")) {
                    Button(action: {
                        startCalibration()
                    }) {
                        Text("Start Compass Calibration")
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 5)
                    
                    Text("Ensure you move your device in a figure-eight motion until calibration is complete.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // MARK: - Reset Section
                Section {
                    Button(action: {
                        // Reset values to defaults
                        viewModel.resetToDefaults()
                    }) {
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showCalibrationAlert) {
                Alert(
                    title: Text("Compass Calibration"),
                    message: Text("Please move your device in a figure-eight motion to calibrate the compass."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    // MARK: - Calibration Action
    private func startCalibration() {
        // Trigger calibration in the ViewModel
        viewModel.startCalibration()
        
        // Show an alert to guide the user
        showCalibrationAlert = true
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Preview
//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView(viewModel: MagnetometerViewModel())
//    }
//}
