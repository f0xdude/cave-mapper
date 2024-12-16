import SwiftUI
import CoreGraphics
import CoreMotion

struct NorthOrientedMapView: View {
    @State private var mapData: [SavedData] = []
    
    // Persistent state variables
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    @State private var offset: CGSize = .zero
    
    // Gesture state variables
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureRotation: Angle = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var headingError: Double = 0.0
    
    @State private var initialFitDone = false

    private let markerSize: CGFloat = 10.0

    @StateObject private var motionDetector = MotionDetector()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear // Ensure the gesture area fills the entire screen
                
                // Transformed content
                ZStack {
                    if mapData.isEmpty {
                        Text("No data available to draw the map")
                            .font(.headline)
                            .foregroundColor(.gray)
                    } else {
                        drawPath(in: geometry.size)
                    }
                    
                }
                .scaleEffect(scale * gestureScale, anchor: .center)
                .rotationEffect(rotation + gestureRotation)
                .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                .onAppear {
                    loadMapData()
                    // Fit the map after data is loaded
                    DispatchQueue.main.async {
                        if !initialFitDone && !mapData.isEmpty {
                            fitMap(in: geometry.size)
                            initialFitDone = true
                        }
                    }
                }
            }
            .contentShape(Rectangle()) // Ensure the entire area can receive gestures
            .gesture(combinedGesture())
        }
        .navigationTitle("Map")
        .onAppear {
            motionDetector.doubleTapDetected = {
                self.presentationMode.wrappedValue.dismiss()
            }
            motionDetector.startDetection()
        }
        .onDisappear {
            motionDetector.stopDetection()
        }
    }

    // Combine magnification, rotation, and drag gestures
    private func combinedGesture() -> some Gesture {
        // Magnification Gesture
        let magnifyGesture = MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                // Limit the total scale during the gesture
                let totalScale = self.scale * value
                let limitedScale = max(0.1, min(totalScale, 10.0))
                state = limitedScale / self.scale
            }
            .onEnded { value in
                // Update the persistent scale state
                let totalScale = self.scale * value
                self.scale = max(0.1, min(totalScale, 10.0))
            }

        // Rotation Gesture
        let rotationGesture = RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                self.rotation += value
            }

        // Drag Gesture
        let dragGesture = DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                self.offset.width += value.translation.width
                self.offset.height += value.translation.height
            }

        // Combine all gestures
        return SimultaneousGesture(
            SimultaneousGesture(magnifyGesture, rotationGesture),
            dragGesture
        )
    }

    private func drawPath(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let (path, positions) = createPath(center: center)

        return ZStack {
            // Path Line
            path.stroke(Color.blue, lineWidth: 2)
            
            // Start Marker
            Circle()
                .fill(Color.green)
                .frame(width: markerSize, height: markerSize)
                .position(center)
            
            // Start Label
            Text("Start")
                .font(.system(size: 12))
                .foregroundColor(.green)
                .position(x: center.x, y: center.y - 15)

            // End Marker
            if let end = positions.last {
                Circle()
                    .fill(Color.red)
                    .frame(width: markerSize, height: markerSize)
                    .position(end)
                
                // End Label
                Text("End")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .position(x: end.x, y: end.y - 15)
            }

            // Display Depth Labels at Measurement Points with rtype = "manual"
            ForEach(positions.indices.filter { mapData[$0].rtype == "manual" }, id: \.self) { index in
                let position = positions[index]
                let depth = mapData[index].depth // Access the depth value
                
                Text(String(format: "%.1f m", depth))
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(5)
                    .position(position)
            }
        }
    }

    // Modified to return both path and positions
    private func createPath(center: CGPoint) -> (path: Path, positions: [CGPoint]) {
        var path = Path()
        guard !mapData.isEmpty else { return (path, []) }

        var positions: [CGPoint] = []
        var currentPosition = center
        path.move(to: currentPosition)

        for data in mapData {
            let angleInRadians = data.heading.toMathRadiansFromHeading()
            
            let deltaX = CGFloat(data.distance * cos(angleInRadians))
            let deltaY = CGFloat(data.distance * sin(angleInRadians))
            currentPosition.x += deltaX
            currentPosition.y += deltaY
            path.addLine(to: currentPosition)
            positions.append(currentPosition)
        }

        return (path, positions)
    }

    private func loadMapData() {
        mapData = DataManager.loadSavedData()
    }

    private func fitMap(in size: CGSize) {
        // Ensure we have data
        guard !mapData.isEmpty else { return }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let (path, _) = createPath(center: center)
        let boundingRect = path.boundingRect
        
        // Compute scale so boundingRect fits fully inside size with some margin
        let widthRatio = size.width / boundingRect.width
        let heightRatio = size.height / boundingRect.height
        let fitScale = min(widthRatio, heightRatio) * 0.9
        
        // Apply the computed scale
        scale = fitScale

        // We scale around the center point, so we must adjust offset to recenter the boundingRect
        // after scaling. The final position after scaling is:
        // finalX = center.x + (boundingRect.midX - center.x)*scale
        // We want finalX = center.x, so:
        // center.x = center.x + (boundingRect.midX - center.x)*scale + offset.width
        // offset.width = center.x - center.x - (boundingRect.midX - center.x)*scale
        // offset.width = (center.x - boundingRect.midX)*scale
        offset = CGSize(
            width: (center.x - boundingRect.midX)*fitScale,
            height: (center.y - boundingRect.midY)*fitScale
        )
    }
}

private extension Double {
    func toMathRadiansFromHeading() -> Double {
        return (90.0 - self) * .pi / 180.0
    }
}

// MotionDetector Class to detect double taps via accelerometer
class MotionDetector: ObservableObject {

    private let motionManager = CMMotionManager()
    private var lastTapTime: Date?
    private var tapCount = 0
    
    // Thresholds for detecting taps
    private let accelerationThreshold = 4.0 // Adjust as needed
    private let tapTimeWindow = 0.3 // Max time between taps in seconds

    var doubleTapDetected: (() -> Void)?
    
    func startDetection() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.01
            motionManager.startAccelerometerUpdates(to: OperationQueue()) { (data, error) in
                guard let data = data else { return }
                self.processAccelerationData(data.acceleration)
            }
        }
    }
    
    func stopDetection() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func processAccelerationData(_ acceleration: CMAcceleration) {
        let totalAcceleration = sqrt(pow(acceleration.x, 2) +
                                     pow(acceleration.y, 2) +
                                     pow(acceleration.z, 2))
        
        if totalAcceleration > accelerationThreshold {
            DispatchQueue.main.async {
                let now = Date()
                if let lastTapTime = self.lastTapTime {
                    let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
                    if timeSinceLastTap < self.tapTimeWindow {
                        self.tapCount += 1
                    } else {
                        self.tapCount = 1
                    }
                } else {
                    self.tapCount = 1
                }
                
                self.lastTapTime = now
                
                if self.tapCount >= 3 {
                    self.tapCount = 0
                    self.doubleTapDetected?()
                }
            }
        }
    }
}
