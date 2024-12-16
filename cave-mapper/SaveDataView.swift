import SwiftUI
import UIKit

struct SaveDataView: View {
    @State private var pointNumber: Int = DataManager.loadPointNumber()
    @ObservedObject var magnetometer: MagnetometerViewModel
    @State private var depth: Double = DataManager.loadLastSavedDepth() // Initialize with last saved depth
    @State private var distance: Double = DataManager.loadLastSavedDistance() // Initialize with last saved distance

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Point Number: \(pointNumber)")
                .font(.title2)
                .padding()
            
//            Text("Distance: \(magnetometer.distanceInMeters, specifier: "%.2f") m")
            Text("Distance: \(distance, specifier: "%.2f") meters")

            Text("Heading: \(magnetometer.currentHeading?.magneticHeading ?? 0, specifier: "%.2f")°")
            Text("Depth: \(depth, specifier: "%.2f") m")
                .padding()

            ZStack {
                Button(action: { shareData() }) {
                    ZStack {
                        Circle().fill(Color.purple).frame(width: 50, height: 50)
                        Image(systemName: "square.and.arrow.up").foregroundColor(.white).font(.title2)
                    }
                }
                .offset(x: -120, y: 200)
                
                Button(action: { depth -= 1 }) {
                    ZStack {
                        Circle().fill(Color.orange).frame(width: 50, height: 50)
                        Image(systemName: "minus").foregroundColor(.white).font(.title2)
                    }
                }
                .offset(x: -70, y: 140)

                Button(action: { saveData() }) {
                    ZStack {
                        Circle().fill(Color.green).frame(width: 70, height: 70)
                        Text("Save").foregroundColor(.white).bold()
                    }
                }
                .offset(y: 200)

                Button(action: { depth += 1 }) {
                    ZStack {
                        Circle().fill(Color.orange).frame(width: 50, height: 50)
                        Image(systemName: "plus").foregroundColor(.white).font(.title2)
                    }
                }
                .offset(x: 70, y: 140)

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    ZStack {
                        Circle().fill(Color.blue).frame(width: 50, height: 50)
                        Image(systemName: "arrow.backward").foregroundColor(.white).font(.title2)
                    }
                }
                .offset(x: 120, y: 200)
            }
        }
    }

    private func saveData() {
        pointNumber += 1
        let savedData = SavedData(recordNumber: pointNumber, distance: distance, heading: magnetometer.roundedMagneticHeading ?? 0, depth: depth, rtype:"manual")
        DataManager.save(savedData: savedData)
        DataManager.savePointNumber(pointNumber)
    }

    private func shareData() {
        let savedDataArray = DataManager.loadSavedData()
        guard !savedDataArray.isEmpty else {
            print("No data available to share.")
            return
        }
        
        var csvText = "RecordNumber,Distance,Heading,Depth,Type\n"
        for data in savedDataArray {
            csvText += "\(data.recordNumber),\(data.distance),\(data.heading),\(data.depth),\(data.rtype)\n"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("SavedData.csv")
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write CSV file: \(error.localizedDescription)")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
}

struct SavedData: Codable {
    let recordNumber: Int
    let distance: Double
    let heading: Double
    let depth: Double
    let rtype: String
}

