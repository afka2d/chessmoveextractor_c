//
//  ContentView.swift
//  chessmoveextractorc
//
//  Created by Tony Blum on 5/7/25.
//

import SwiftUI
import AVFoundation
import AVKit
import Vision
import CoreImage
import CoreML
import Photos
import UniformTypeIdentifiers

// API Response Types
struct ChessPositionResponse: Codable {
    let fen: String
    let hasChessBoard: Bool
    let error: String?
    let message: String?
    let lichess_url: String
}

struct CornersResponse: Codable {
    let corners: [Corner]
    let hasChessBoard: Bool
    let error: String?
    let message: String?
}

struct Corner: Codable {
    let x: Double
    let y: Double
}

struct RecordedGame: Identifiable {
    let id: String
    let fileName: String
    let fileSize: UInt64
    let recordedDate: Date
    let url: URL
    
    init(id: String, fileName: String, fileSize: UInt64, recordedDate: Date, url: URL) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.recordedDate = recordedDate
        self.url = url
    }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView(cameraManager: cameraManager)
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
                .tag(0)
            
            CapturedPhotosView(cameraManager: cameraManager)
                .tabItem {
                    Label("Photos", systemImage: "photo.on.rectangle")
                }
                .tag(1)
        }
    }
}

struct CameraView: View {
    @ObservedObject var cameraManager: CameraManager
    
    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
            
            if cameraManager.isChessBoardDetected {
                ChessBoardOverlay(corners: cameraManager.detectedCorners ?? [], imageSize: cameraManager.lastImageSize ?? .zero)
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        cameraManager.capturePhoto()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    .disabled(cameraManager.isCapturing)
                    
                    Spacer()
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

struct ChessBoardOverlayView: View {
    let fen: String
    let isDetected: Bool
    let lichessURL: String
    
    var body: some View {
        VStack {
            if isDetected {
                Text("Chess Board Detected")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                
                if !fen.isEmpty {
                    Text("FEN: \(fen)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                
                if !lichessURL.isEmpty {
                    Link("View on Lichess", destination: URL(string: lichessURL)!)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
        .padding(.top, 50)
    }
}

struct MoveOverlayView: View {
    let move: String

    var body: some View {
        VStack {
            Text(move)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
                .shadow(radius: 8)
                .id(move)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: move)
            Spacer()
        }
        .padding(.top, 60)
    }
}

struct RecordingControlsView: View {
    let isRecording: Bool
    let onRecordToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onRecordToggle) {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 64))
                    .foregroundColor(isRecording ? .red : .white)
            }
            .padding()
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
        .padding(.bottom, 20)
    }
}

struct DebugOverlayView: View {
    let lastFEN: String?
    let isProcessing: Bool
    let lastAPICallTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API Status: \(isProcessing ? "Processing..." : "Ready")")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isProcessing ? .yellow : .green)

            if let fen = lastFEN {
                Text("Position: \(fen)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
            }

            Text("Last Call: \(lastAPICallTime.formatted(.dateTime.hour().minute().second()))")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
}

struct RecordingView: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var showCapturedPhotos = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // Chess board overlay
            if cameraManager.isChessBoardDetected {
                ChessBoardOverlayView(
                    fen: cameraManager.lastFEN ?? "",
                    isDetected: cameraManager.isChessBoardDetected,
                    lichessURL: cameraManager.lastLichessURL ?? ""
                )
            }
            
            // Error message when no board is detected
            if !cameraManager.isChessBoardDetected {
                VStack {
                    Spacer()
                    Text("No chess board detected")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
            }
            
            // Capture button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        cameraManager.capturePhoto()
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                player = AVPlayer(url: url)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

struct ChessMove: Identifiable {
    let id = UUID()
    let notation: String
    let timestamp: Double
    let moveNumber: Int
}

// Update CornerOverlayView to show red dots at corners
struct CornerOverlayView: View {
    let corners: [CGPoint]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw lines between corners
                Path { path in
                    guard corners.count == 4 else { return }

                    let viewWidth = geometry.size.width
                    let viewHeight = geometry.size.height
                    var scaleX: CGFloat = 1.0
                    var scaleY: CGFloat = 1.0
                    var xOffset: CGFloat = 0.0
                    var yOffset: CGFloat = 0.0

                    if imageSize.width > 0, imageSize.height > 0 {
                         let widthRatio = viewWidth / imageSize.width
                         let heightRatio = viewHeight / imageSize.height
                         let scale = max(widthRatio, heightRatio)

                         scaleX = scale
                         scaleY = scale

                         xOffset = (viewWidth - imageSize.width * scale) / 2.0
                         yOffset = (viewHeight - imageSize.height * scale) / 2.0
                    }

                    let transformedCorners = corners.map { corner in
                        CGPoint(x: corner.x * scaleX + xOffset, y: corner.y * scaleY + yOffset)
                    }

                    path.move(to: transformedCorners[0])
                    path.addLine(to: transformedCorners[1])
                    path.addLine(to: transformedCorners[2])
                    path.addLine(to: transformedCorners[3])
                    path.closeSubpath()
                }
                .stroke(Color.red, lineWidth: 2)

                // Draw red dots at corners
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<corners.count, id: \.self) { index in
                            CornerDotView(
                                corner: corners[index],
                                geometry: geometry,
                                imageSize: imageSize
                            )
                        }
                    }
                }
            }
        }
    }
}

struct CornerDotView: View {
    let corner: CGPoint
    let geometry: GeometryProxy
    let imageSize: CGSize
    
    private var transformedCorner: CGPoint {
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        var xOffset: CGFloat = 0.0
        var yOffset: CGFloat = 0.0

        if imageSize.width > 0, imageSize.height > 0 {
            let widthRatio = viewWidth / imageSize.width
            let heightRatio = viewHeight / imageSize.height
            let scale = max(widthRatio, heightRatio)

            scaleX = scale
            scaleY = scale

            xOffset = (viewWidth - imageSize.width * scale) / 2.0
            yOffset = (viewHeight - imageSize.height * scale) / 2.0
        }

        return CGPoint(
            x: corner.x * scaleX + xOffset,
            y: corner.y * scaleY + yOffset
        )
    }
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .position(transformedCorner)
    }
}

class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var error: Error?
    @Published var isChessBoardDetected = false
    @Published var detectionConfidence: Double = 0.0
    @Published var lastFEN: String?
    @Published var lastLichessURL: String?
    @Published var detectedMoves: [ChessMove] = []
    @Published var loadedCorners: [CGPoint]?
    @Published var lastImageSize: CGSize?
    
    private var timeObserver: Any?
    private var gameKey: String?
    
    func setupPlayer(with url: URL) {
        // Create player
        let player = AVPlayer(url: url)
        self.player = player
        
        // Get game key from URL
        gameKey = "game_\(url.lastPathComponent)"
        
        // Load game info from UserDefaults
        if let gameInfo = UserDefaults.standard.dictionary(forKey: gameKey ?? "") {
            // Load corners and image size
            if let cornersData = gameInfo["corners"] as? [[Double]] {
                loadedCorners = cornersData.map { CGPoint(x: $0[0], y: $0[1]) }
            }
            if let sizeData = gameInfo["imageSize"] as? [Double], sizeData.count == 2 {
                lastImageSize = CGSize(width: sizeData[0], height: sizeData[1])
            }
            
            // Load FEN positions
            if let fenPositionsData = gameInfo["fenPositions"] as? [[String: Any]] {
                var moves: [ChessMove] = []
                for (index, data) in fenPositionsData.enumerated() {
                    if let time = data["time"] as? Double,
                       let fen = data["fen"] as? String {
                        moves.append(ChessMove(
                            notation: fen,
                            timestamp: time,
                            moveNumber: index + 1
                        ))
                    }
                }
                detectedMoves = moves
            }
            
            // Set board detection status
            isChessBoardDetected = gameInfo["hasChessBoard"] as? Bool ?? false
            detectionConfidence = gameInfo["confidence"] as? Double ?? 0.0
        }
        
        // Add time observer to track playback
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.updateCurrentPosition(time: time)
        }
    }
    
    private func updateCurrentPosition(time: CMTime) {
        // Update FEN and moves based on current playback time
        if let gameInfo = UserDefaults.standard.dictionary(forKey: gameKey ?? ""),
           let fenPositionsData = gameInfo["fenPositions"] as? [[String: Any]] {
            
            let currentTime = time.seconds
            
            // Find the most recent FEN position before current time
            var lastFEN: String?
            var lastLichessURL: String?
            
            for data in fenPositionsData {
                if let positionTime = data["time"] as? Double,
                   positionTime <= currentTime {
                    lastFEN = data["fen"] as? String
                    lastLichessURL = data["lichessURL"] as? String
                } else {
                    break
                }
            }
            
            self.lastFEN = lastFEN
            self.lastLichessURL = lastLichessURL
        }
    }
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player?.pause()
        player = nil
    }
}

class ChessBoardRenderer {
    private let boardSize: CGFloat = 400
    private let squareSize: CGFloat
    private let lightSquareColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.7)
    private let darkSquareColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.7)
    private let ciContext = CIContext()

    init() {
        squareSize = boardSize / 8
    }

    func renderBoard() -> CIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: boardSize, height: boardSize))

        let image = renderer.image { context in
            // Draw squares
            for row in 0..<8 {
                for col in 0..<8 {
                    let isLightSquare = (row + col) % 2 == 0
                    let color = isLightSquare ? lightSquareColor : darkSquareColor
                    color.setFill()

                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(rect)
                }
            }

            // Draw coordinates
            let coordinateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]

            // Draw file coordinates (a-h)
            for col in 0..<8 {
                let file = String(UnicodeScalar(97 + col)!)
                let text = file as NSString
                let size = text.size(withAttributes: coordinateAttributes)
                let x = CGFloat(col) * squareSize + (squareSize - size.width) / 2
                let y = boardSize - size.height - 2
                text.draw(at: CGPoint(x: x, y: y), withAttributes: coordinateAttributes)
            }

            // Draw rank coordinates (1-8)
            for row in 0..<8 {
                let rank = String(8 - row)
                let text = rank as NSString
                let size = text.size(withAttributes: coordinateAttributes)
                let x: CGFloat = 2
                let y = CGFloat(row) * squareSize + (squareSize - size.height) / 2
                text.draw(at: CGPoint(x: x, y: y), withAttributes: coordinateAttributes)
            }
        }

        guard let cgImage = image.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}

class ChessBoardDetector {
    private let ciContext = CIContext()
    
    func detectChessBoard(in pixelBuffer: CVPixelBuffer) -> (Bool, Double) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert to grayscale for better edge detection
        guard let grayscaleImage = convertToGrayscale(ciImage) else { return (false, 0.0) }
        
        // Apply edge detection with multiple passes
        guard let edges = detectEdges(in: grayscaleImage) else { return (false, 0.0) }
        
        // Look for grid-like patterns with perspective correction
        return detectGridPattern(in: edges, originalImage: ciImage)
    }
    
    func detectBoardState(in pixelBuffer: CVPixelBuffer, corners: [CGPoint]?, imageSize: CGSize) -> [[String]] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        var board = Array(repeating: Array(repeating: "", count: 8), count: 8)

        // Use provided corners if available and valid
        if let corners = corners, corners.count == 4 {
            // Convert normalized Vision coordinates (origin bottom-left) to pixel coordinates
            let pixelCorners = corners.map { pt in
                CGPoint(x: pt.x * imageSize.width, y: (1.0 - pt.y) * imageSize.height)
            }
            // Perspective correction
            let perspectiveTransform = CIFilter(name: "CIPerspectiveCorrection")!
            perspectiveTransform.setValue(CIVector(cgPoint: pixelCorners[0]), forKey: "inputTopLeft")
            perspectiveTransform.setValue(CIVector(cgPoint: pixelCorners[1]), forKey: "inputTopRight")
            perspectiveTransform.setValue(CIVector(cgPoint: pixelCorners[2]), forKey: "inputBottomRight")
            perspectiveTransform.setValue(CIVector(cgPoint: pixelCorners[3]), forKey: "inputBottomLeft")
            perspectiveTransform.setValue(ciImage, forKey: kCIInputImageKey)
            guard let correctedBoardImage = perspectiveTransform.outputImage else {
                print("Failed to apply perspective correction to the board (manual corners).")
                return board
            }
            let boardImage = correctedBoardImage.cropped(to: correctedBoardImage.extent)
            let squareWidth = boardImage.extent.width / 8
            let squareHeight = boardImage.extent.height / 8
            for row in 0..<8 {
                for col in 0..<8 {
                    let squareRect = CGRect(
                        x: boardImage.extent.origin.x + CGFloat(col) * squareWidth,
                        y: boardImage.extent.origin.y + CGFloat(row) * squareHeight,
                        width: squareWidth,
                        height: squareHeight
                    )
                    let squareImage = boardImage.cropped(to: squareRect)
                    if let piece = detectPiece(in: squareImage) {
                        board[row][col] = piece
                    }
                }
            }
            return board
        }
        // ... fallback to old method if no corners ...
        // (existing rectangle detection and perspective correction)
        // ... existing code ...
        // (copy the old code here if needed)
        return board
    }
    
    private func detectPiece(in squareImage: CIImage) -> String? {
        // Convert to grayscale
        guard let grayscaleImage = convertToGrayscale(squareImage) else { return nil }
        
        // Apply threshold to separate piece from background
        let thresholdFilter = CIFilter(name: "CIColorThreshold")
        thresholdFilter?.setValue(grayscaleImage, forKey: kCIInputImageKey)
        thresholdFilter?.setValue(0.3, forKey: "inputThreshold") // Lowered threshold
        guard let thresholdImage = thresholdFilter?.outputImage else { return nil }
        
        // Calculate average brightness
        let context = CIContext()
        guard let cgImage = context.createCGImage(thresholdImage, from: thresholdImage.extent) else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalBrightness: Float = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = Float(rawData[i])
            let g = Float(rawData[i + 1])
            let b = Float(rawData[i + 2])
            totalBrightness += (r + g + b) / (3.0 * 255.0)
        }
        
        let averageBrightness = totalBrightness / Float(pixelCount)
        
        // Lowered threshold for piece detection
        if averageBrightness > 0.2 { // More sensitive threshold
            return "P" // P for piece
        }
        
        return nil
    }
    
    private func convertToGrayscale(_ image: CIImage) -> CIImage? {
        let grayscaleFilter = CIFilter(name: "CIColorControls")
        grayscaleFilter?.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter?.setValue(0.0, forKey: kCIInputSaturationKey)
        grayscaleFilter?.setValue(1.1, forKey: kCIInputContrastKey) // Increase contrast
        return grayscaleFilter?.outputImage
    }
    
    private func detectEdges(in image: CIImage) -> CIImage? {
        // Apply Gaussian blur to reduce noise
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(image, forKey: kCIInputImageKey)
        blurFilter?.setValue(1.0, forKey: kCIInputRadiusKey)
        guard let blurredImage = blurFilter?.outputImage else { return nil }
        
        // Apply edge detection
        let edgeFilter = CIFilter(name: "CIEdges")
        edgeFilter?.setValue(blurredImage, forKey: kCIInputImageKey)
        edgeFilter?.setValue(4.0, forKey: kCIInputIntensityKey)
        guard let edgeImage = edgeFilter?.outputImage else { return nil }
        
        // Apply morphological operations to strengthen lines
        let morphologyFilter = CIFilter(name: "CIMorphologyRectangleMaximum")
        morphologyFilter?.setValue(edgeImage, forKey: kCIInputImageKey)
        morphologyFilter?.setValue(3, forKey: "inputWidth")
        morphologyFilter?.setValue(3, forKey: "inputHeight")
        
        return morphologyFilter?.outputImage
    }
    
    private func detectGridPattern(in image: CIImage, originalImage: CIImage) -> (Bool, Double) {
        // Create a request to detect rectangles with more lenient parameters
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5  // More lenient aspect ratio
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1  // Smaller minimum size
        request.maximumObservations = 1
        request.quadratureTolerance = 20  // Allow more deviation from perfect rectangle
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
        
        guard let observations = request.results else { return (false, 0.0) }
        
        if let observation = observations.first {
            // Calculate confidence based on multiple factors
            var confidence = Double(observation.confidence)
            
            // Adjust confidence based on aspect ratio (more lenient)
            let aspectRatio = Double(observation.boundingBox.width / observation.boundingBox.height)
            let aspectRatioConfidence = 1.0 - min(abs(1.0 - aspectRatio), 0.5) / 0.5
            confidence *= (0.6 + 0.4 * aspectRatioConfidence)
            
            // Adjust confidence based on size (larger is better, up to a point)
            let sizeConfidence = min(Double(observation.boundingBox.width * observation.boundingBox.height * 4), 1.0)
            confidence *= (0.6 + 0.4 * sizeConfidence)
            
            // Check for grid-like pattern within the detected rectangle
            if let gridConfidence = detectGridLines(in: originalImage, boundingBox: observation.boundingBox) {
                confidence *= (0.7 + 0.3 * gridConfidence)
            }
            
            return (true, confidence)
        }
        
        return (false, 0.0)
    }
    
    private func detectGridLines(in image: CIImage, boundingBox: CGRect) -> Double? {
        // Create a request to detect contours
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 512
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
        
        guard let observations = request.results else { return nil }
        
        // Count horizontal and vertical lines
        var horizontalLines = 0
        var verticalLines = 0
        
        for observation in observations {
            let contour = observation.normalizedPath
            
            // Convert contour to points
            var pathPoints: [CGPoint] = []
            contour.applyWithBlock { element in
                let type = element.pointee.type
                let elementPoints = element.pointee.points
                
                switch type {
                case .moveToPoint:
                    pathPoints.append(elementPoints[0])
                case .addLineToPoint:
                    pathPoints.append(elementPoints[0])
                case .addQuadCurveToPoint:
                    pathPoints.append(elementPoints[0])
                    pathPoints.append(elementPoints[1])
                case .addCurveToPoint:
                    pathPoints.append(elementPoints[0])
                    pathPoints.append(elementPoints[1])
                    pathPoints.append(elementPoints[2])
                case .closeSubpath:
                    if let firstPoint = pathPoints.first {
                        pathPoints.append(firstPoint)
                    }
                @unknown default:
                    break
                }
            }
            
            // Analyze line segments
            for i in 0..<pathPoints.count - 1 {
                let start = pathPoints[i]
                let end = pathPoints[i + 1]
                
                // Check if line is within the bounding box
                let lineCenter = CGPoint(
                    x: (start.x + end.x) / 2,
                    y: (start.y + end.y) / 2
                )
                
                if boundingBox.contains(lineCenter) {
                    let angle = abs(atan2(end.y - start.y, end.x - start.x))
                    
                    if angle < .pi / 4 || angle > 3 * .pi / 4 {
                        horizontalLines += 1
                    } else {
                        verticalLines += 1
                    }
                }
            }
        }
        
        // Calculate confidence based on the number of detected lines
        let expectedLines = 9 // 8 internal lines + 2 edges
        let horizontalConfidence = min(Double(horizontalLines) / Double(expectedLines), 1.0)
        let verticalConfidence = min(Double(verticalLines) / Double(expectedLines), 1.0)
        
        return (horizontalConfidence + verticalConfidence) / 2.0
    }
    
    func detectChessBoardWithBoundingBox(in pixelBuffer: CVPixelBuffer) -> (Bool, Double, CGRect?) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Convert to grayscale for better edge detection
        guard let grayscaleImage = convertToGrayscale(ciImage) else { return (false, 0.0, nil) }
        // Apply edge detection with multiple passes
        guard let edges = detectEdges(in: grayscaleImage) else { return (false, 0.0, nil) }
        // Look for grid-like patterns with perspective correction
        // Use the same rectangle detection as before
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1
        request.maximumObservations = 1
        request.quadratureTolerance = 20
        let handler = VNImageRequestHandler(ciImage: edges, options: [:])
        try? handler.perform([request])
        guard let observation = request.results?.first else { return (false, 0.0, nil) }
        // Calculate confidence as before
        var confidence = Double(observation.confidence)
        let aspectRatio = Double(observation.boundingBox.width / observation.boundingBox.height)
        let aspectRatioConfidence = 1.0 - min(abs(1.0 - aspectRatio), 0.5) / 0.5
        confidence *= (0.6 + 0.4 * aspectRatioConfidence)
        let sizeConfidence = min(Double(observation.boundingBox.width * observation.boundingBox.height * 4), 1.0)
        confidence *= (0.6 + 0.4 * sizeConfidence)
        // Return the normalized bounding box
        return (true, confidence, observation.boundingBox)
    }
    
    func detectChessBoardWithBoundingBoxAndCorners(in pixelBuffer: CVPixelBuffer) -> (Bool, Double, CGRect?, [CGPoint]?) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Convert to grayscale for better edge detection
        guard let grayscaleImage = convertToGrayscale(ciImage) else { return (false, 0.0, nil, nil) }
        // Apply edge detection with multiple passes
        guard let edges = detectEdges(in: grayscaleImage) else { return (false, 0.0, nil, nil) }
        // Look for grid-like patterns with perspective correction
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1
        request.maximumObservations = 1
        request.quadratureTolerance = 20
        let handler = VNImageRequestHandler(ciImage: edges, options: [:])
        try? handler.perform([request])
        guard let observation = request.results?.first else { return (false, 0.0, nil, nil) }
        var confidence = Double(observation.confidence)
        let aspectRatio = Double(observation.boundingBox.width / observation.boundingBox.height)
        let aspectRatioConfidence = 1.0 - min(abs(1.0 - aspectRatio), 0.5) / 0.5
        confidence *= (0.6 + 0.4 * aspectRatioConfidence)
        let sizeConfidence = min(Double(observation.boundingBox.width * observation.boundingBox.height * 4), 1.0)
        confidence *= (0.6 + 0.4 * sizeConfidence)
        // Corners are normalized (0-1) in Vision coordinates (origin bottom-left)
        let corners = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
        return (true, confidence, observation.boundingBox, corners)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL {
    var creationDate: Date? {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            return nil
        }
    }
}

class LocalChessAPIService {
    private let baseURL = "https://api.chesspositionscanner.store" // Updated baseURL to the correct one

    func recognizePosition(imageData: Data) async throws -> (success: Bool, fen: String, lichessURL: String?) {
        let url = URL(string: "\(baseURL)/recognize_chess_position")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data with proper headers
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add color parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"color\"\r\n\r\n".data(using: .utf8)!)
        body.append("white\r\n".data(using: .utf8)!)

        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("Sending request to API: \(url)")
        print("Request body size: \(body.count) bytes")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LocalChessAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

         print("API Response Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("API Error: Status code \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            throw NSError(domain: "LocalChessAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
        }

        // Parse the response using Codable
        let decoder = JSONDecoder()
        do {
            let chessResponse = try decoder.decode(ChessPositionResponse.self, from: data)
            print("API Response - FEN: \(chessResponse.fen), Legal: \(chessResponse.hasChessBoard)")
            print("ASCII Board:\n\(chessResponse.message ?? "")")
            print("Lichess URL: \(chessResponse.lichess_url)")

            // Return the FEN string even if the position is not legal
            return (chessResponse.hasChessBoard, chessResponse.fen, chessResponse.lichess_url)
        } catch {
            print("Error decoding recognize position response: \(error)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Raw response: \(errorString)")
            }
            return (false, "", nil)
        }
    }

    // New function to call the detect_corners endpoint
    func detectCorners(imageData: Data) async throws -> [CGPoint]? {
        let url = URL(string: "\(baseURL)/detect_corners")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("Sending request to API: \(url)")
        print("Request body size: \(body.count) bytes")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LocalChessAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

         print("API Response Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("API Error: Status code \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            throw NSError(domain: "LocalChessAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
        }

        // Parse the response
        let decoder = JSONDecoder()
        do {
            let cornersResponse = try decoder.decode(CornersResponse.self, from: data)
            print("API Response - Corners: \(cornersResponse.corners)")
            print("API Response - Message: \(cornersResponse.message ?? "nil")")

            // Convert [[Double]] to [CGPoint]
            let corners = cornersResponse.corners.map { CGPoint(x: $0.x, y: $0.y) }
            return corners

        } catch {
            print("Error decoding detect corners response: \(error)")
             if let errorString = String(data: data, encoding: .utf8) {
                print("Raw response: \(errorString)")
            }
            return nil
        }
    }

    func pixelBufferToData(_ pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        // Create a properly oriented image
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: 1.0, y: -1.0))

        // Ensure we have a valid image
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            print("Failed to create CGImage from CIImage")
            return nil
        }

        // Create UIImage with proper orientation
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)

        // Convert to JPEG with high quality
        guard let imageData = uiImage.jpegData(compressionQuality: 0.9) else {
            print("Failed to convert UIImage to JPEG data")
            return nil
        }

        print("Created image data with size: \(imageData.count) bytes")
        return imageData
    }
}

class LocalChessService {
    private let recognizeURL = "https://api.chesspositionscanner.store/recognize_chess_position"
    private let detectCornersURL = "https://api.chesspositionscanner.store/detect_corners"
    private let debugLogger = DebugLogger()
    
    private func createMultipartFormData(imageData: Data) -> (Data, String) {
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return (body, boundary)
    }
    
    func recognizePosition(imageData: Data) async throws -> (ChessPositionResponse?, String?) {
        guard let url = URL(string: recognizeURL) else {
            debugLogger.log("Invalid URL for recognize_chess_position")
            throw URLError(.badURL)
        }
        
        let (body, boundary) = createMultipartFormData(imageData: imageData)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        debugLogger.log("Making recognize_chess_position API call with \(imageData.count) bytes")
        debugLogger.logAPICall(endpoint: "recognize_chess_position", requestData: imageData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLogger.log("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            debugLogger.log("API Response Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("API Error: \(errorMessage)")
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                debugLogger.log("Raw API Response: \(responseString)")
            }
            
            do {
                let result = try JSONDecoder().decode(ChessPositionResponse.self, from: data)
                debugLogger.log("Successfully decoded recognize_chess_position response")
                debugLogger.logAPIResponse(endpoint: "recognize_chess_position", response: data)
                return (result, nil)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Failed to decode response: \(responseString)")
                }
                return (nil, "Failed to decode response: \(error.localizedDescription)")
            }
        } catch {
            debugLogger.log("Error in recognize_chess_position: \(error.localizedDescription)")
            throw error
        }
    }
    
    func detectCorners(imageData: Data) async throws -> (CornersResponse?, String?) {
        guard let url = URL(string: detectCornersURL) else {
            debugLogger.log("Invalid URL for detect_corners")
            throw URLError(.badURL)
        }
        
        let (body, boundary) = createMultipartFormData(imageData: imageData)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        debugLogger.log("Making detect_corners API call with \(imageData.count) bytes")
        debugLogger.logAPICall(endpoint: "detect_corners", requestData: imageData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLogger.log("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            debugLogger.log("API Response Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("API Error: \(errorMessage)")
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                debugLogger.log("Raw API Response: \(responseString)")
            }
            
            do {
                let result = try JSONDecoder().decode(CornersResponse.self, from: data)
                debugLogger.log("Successfully decoded detect_corners response")
                debugLogger.logAPIResponse(endpoint: "detect_corners", response: data)
                return (result, nil)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Failed to decode response: \(responseString)")
                }
                return (nil, "Failed to decode response: \(error.localizedDescription)")
            }
        } catch {
            debugLogger.log("Error in detect_corners: \(error.localizedDescription)")
            throw error
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var isChessBoardDetected = false
    @Published var lastFEN: String?
    @Published var lastLichessURL: String?
    @Published var detectedCorners: [CGPoint]?
    @Published var lastImageSize: CGSize?
    @Published var isProcessing = false
    @Published var isCapturing = false
    @Published var lastAPIError: String?
    @Published var lastAPIStatus: String?
    @Published var capturedPhotos: [CapturedPhoto] = []
    
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentMove: String?
    private var isProcessingFrame = false
    private let localChessService = LocalChessService()
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        // Request camera authorization
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else {
                print("Camera access denied")
                return
            }
            
            DispatchQueue.main.async {
                self?.configureCamera()
            }
        }
    }
    
    private func configureCamera() {
        session.beginConfiguration()
        
        // Set session preset
        session.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get video device")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                print("Failed to add video input")
                return
            }
        } catch {
            print("Error creating video input: \(error)")
            return
        }
        
        // Add video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
            
            // Configure video orientation
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        } else {
            print("Failed to add video output")
            return
        }
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            print("Failed to add photo output")
            return
        }
        
        session.commitConfiguration()
        
        // Start the session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput, !isCapturing else { return }
        
        DispatchQueue.main.async {
            self.isCapturing = true
            AudioServicesPlaySystemSound(1108) // Camera shutter sound
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func savePhoto(_ image: UIImage) {
        let photo = CapturedPhoto(
            id: UUID(),
            image: image,
            preprocessedImage: nil,
            timestamp: Date(),
            isProcessing: true
        )
        
        capturedPhotos.append(photo)
        
        // Process the photo with both APIs
        Task {
            do {
                let (cornersResponse, cornersError) = try await localChessService.detectCorners(imageData: image.jpegData(compressionQuality: 0.8) ?? Data())
                let (positionResponse, positionError) = try await localChessService.recognizePosition(imageData: image.jpegData(compressionQuality: 0.8) ?? Data())
                
                await MainActor.run {
                    if let index = capturedPhotos.firstIndex(where: { $0.id == photo.id }) {
                        // Convert corners response
                        if let corners = cornersResponse {
                            capturedPhotos[index].cornersResult = CapturedPhoto.CornersResult(
                                corners: corners.corners.map { CGPoint(x: $0.x, y: $0.y) },
                                message: corners.message
                            )
                        }
                        
                        // Convert position response
                        if let position = positionResponse {
                            capturedPhotos[index].positionResult = CapturedPhoto.PositionResult(
                                fen: position.fen,
                                lichessURL: position.lichess_url,
                                ascii: position.message ?? "",
                                legalPosition: position.hasChessBoard
                            )
                        }
                        
                        // Set API errors
                        capturedPhotos[index].apiErrors = CapturedPhoto.APIErrors(
                            positionError: positionError,
                            cornersError: cornersError
                        )
                        capturedPhotos[index].isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    if let index = capturedPhotos.firstIndex(where: { $0.id == photo.id }) {
                        capturedPhotos[index].error = error.localizedDescription
                        capturedPhotos[index].isProcessing = false
                    }
                }
            }
        }
    }
    
    private func convertPixelBufferToImageData(_ pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            DispatchQueue.main.async {
                self.isCapturing = false
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to create image from photo data")
            DispatchQueue.main.async {
                self.isCapturing = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isCapturing = false
            // Process the image and make API calls
            Task {
                // Create a new captured photo with both original and preprocessed images
                let preprocessedImage = image.preprocessForChessboard()
                let capturedPhoto = CapturedPhoto(
                    id: UUID(),
                    image: image,
                    preprocessedImage: preprocessedImage,
                    timestamp: Date(),
                    isProcessing: true
                )
                
                // Add to the array immediately
                self.capturedPhotos.append(capturedPhoto)
                
                do {
                    // Make API calls using the preprocessed image if available
                    let imageToProcess = preprocessedImage ?? image
                    let (cornersResponse, cornersError) = try await self.localChessService.detectCorners(imageData: imageToProcess.jpegData(compressionQuality: 0.8) ?? Data())
                    let (positionResponse, positionError) = try await self.localChessService.recognizePosition(imageData: imageToProcess.jpegData(compressionQuality: 0.8) ?? Data())
                    
                    // Update the photo with results
                    if let index = self.capturedPhotos.firstIndex(where: { $0.id == capturedPhoto.id }) {
                        // Update corners result
                        if let corners = cornersResponse {
                            let detectedCorners = corners.corners.map { CGPoint(x: $0.x, y: $0.y) }
                            self.capturedPhotos[index].cornersResult = CapturedPhoto.CornersResult(
                                corners: detectedCorners,
                                message: corners.message
                            )
                            
                            // Generate masked image with detected corners
                            if detectedCorners.count == 4 {
                                self.capturedPhotos[index].maskedImage = capturedPhoto.image.maskChessboardArea(corners: detectedCorners)
                            }
                        }
                        
                        // Update position result
                        if let position = positionResponse {
                            self.capturedPhotos[index].positionResult = CapturedPhoto.PositionResult(
                                fen: position.fen,
                                lichessURL: position.lichess_url,
                                ascii: position.message ?? "",
                                legalPosition: position.hasChessBoard
                            )
                        }
                        
                        // Set API errors
                        self.capturedPhotos[index].apiErrors = CapturedPhoto.APIErrors(
                            positionError: positionError,
                            cornersError: cornersError
                        )
                        
                        // Mark as not processing
                        self.capturedPhotos[index].isProcessing = false
                    }
                } catch {
                    print("Error processing photo: \(error)")
                    if let index = self.capturedPhotos.firstIndex(where: { $0.id == capturedPhoto.id }) {
                        self.capturedPhotos[index].error = error.localizedDescription
                        self.capturedPhotos[index].isProcessing = false
                    }
                }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Only update the video preview, no API calls
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Update the preview layer with the current frame
        DispatchQueue.main.async {
            self.lastImageSize = CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
        }
    }
}

struct CapturedPhoto: Identifiable {
    let id: UUID
    let image: UIImage
    let preprocessedImage: UIImage?
    let timestamp: Date
    var isProcessing: Bool
    var positionResult: PositionResult?
    var cornersResult: CornersResult?
    var maskedImage: UIImage?
    var error: String?
    var apiErrors: APIErrors?
    
    struct PositionResult {
        let fen: String
        let lichessURL: String
        let ascii: String
        let legalPosition: Bool
    }
    
    struct CornersResult {
        let corners: [CGPoint]
        let message: String?
    }
    
    struct APIErrors {
        let positionError: String?
        let cornersError: String?
    }
}

struct CapturedPhotosView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    @State private var shareSheet: ShareSheet?
    @State private var showingShareSheet = false
    @State private var showingManualCornerInput = false
    @State private var photoForManualInput: CapturedPhoto?
    
    private func generateShareText(for photo: CapturedPhoto) -> String {
        var text = "Chess Position Analysis\n\n"
        
        if let positionResult = photo.positionResult {
            text += "Position Recognition:\n"
            text += "FEN: \(positionResult.fen)\n"
            text += "Legal Position: \(positionResult.legalPosition ? "Yes" : "No")\n"
            text += "Lichess URL: \(positionResult.lichessURL)\n"
            text += "\nASCII Board:\n\(positionResult.ascii)\n\n"
        } else if let error = photo.apiErrors?.positionError {
            text += "Position Recognition Error: \(error)\n\n"
        }
        
        if let cornersResult = photo.cornersResult {
            text += "Corner Detection:\n"
            text += "Corners: \(cornersResult.corners.map { "(\(Int($0.x)), \(Int($0.y)))" }.joined(separator: ", "))\n"
            if let message = cornersResult.message {
                text += "Message: \(message)\n"
            }
        } else if let error = photo.apiErrors?.cornersError {
            text += "Corner Detection Error: \(error)\n\n"
        }
        
        if let error = photo.error {
            text += "General Error: \(error)\n"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        text += "\nCaptured at: \(dateFormatter.string(from: photo.timestamp))"
        return text
    }
    
    private func photoCard(_ photo: CapturedPhoto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original Image
            originalImageView(photo)
            
            // Preprocessed Image
            if let preprocessedImage = photo.preprocessedImage {
                preprocessedImageView(preprocessedImage)
            }
            
            // Masked Image (areas outside chessboard greyed out)
            if let maskedImage = photo.maskedImage {
                maskedImageView(maskedImage)
            }
            
            // Processing Indicator
            if photo.isProcessing {
                processingView()
            }
            
            // API Results
            if let positionResult = photo.positionResult {
                positionResultView(positionResult)
            }
            
            if let cornersResult = photo.cornersResult {
                cornersResultView(cornersResult)
            }
            
            // Error Views
            if let error = photo.error {
                errorView(error)
            }
            
            if let apiErrors = photo.apiErrors {
                apiErrorsView(apiErrors)
            }
            
            // Share Button
            shareButton(photo)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func originalImageView(_ photo: CapturedPhoto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Original Image")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Spacer()
                Button("Manual Corner Input") {
                    // Create a new view for manual corner input
                    presentManualCornerInput(for: photo)
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func preprocessedImageView(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preprocessed Image (Sent to API)")
                .font(.subheadline)
                .foregroundColor(.blue)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func maskedImageView(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Masked Image (Outside Chessboard Greyed Out)")
                .font(.subheadline)
                .foregroundColor(.green)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func processingView() -> some View {
        HStack {
            ProgressView()
            Text("Processing...")
        }
    }
    
    private func positionResultView(_ result: CapturedPhoto.PositionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position Recognition Results")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("FEN: \(result.fen)")
                .font(.system(.body, design: .monospaced))
            
            Text("Legal Position: \(result.legalPosition ? "Yes" : "No")")
                .foregroundColor(result.legalPosition ? .green : .red)
            
            if !result.ascii.isEmpty {
                Text("ASCII Board:")
                    .font(.subheadline)
                Text(result.ascii)
                    .font(.system(.body, design: .monospaced))
            }
            
            if !result.lichessURL.isEmpty {
                Link("View on Lichess", destination: URL(string: result.lichessURL)!)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func cornersResultView(_ result: CapturedPhoto.CornersResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Corner Detection Results")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("Detected Corners:")
                .font(.subheadline)
            ForEach(0..<result.corners.count, id: \.self) { index in
                let corner = result.corners[index]
                Text("Corner \(index + 1): (\(Int(corner.x)), \(Int(corner.y)))")
                    .font(.system(.body, design: .monospaced))
            }
            
            if let message = result.message {
                Text("Message: \(message)")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func errorView(_ error: String) -> some View {
        Text("Error: \(error)")
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
    }
    
    private func apiErrorsView(_ errors: CapturedPhoto.APIErrors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let positionError = errors.positionError {
                Text("Position API Error: \(positionError)")
                    .foregroundColor(.red)
            }
            if let cornersError = errors.cornersError {
                Text("Corners API Error: \(cornersError)")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func shareButton(_ photo: CapturedPhoto) -> some View {
        Button(action: {
            let text = generateShareText(for: photo)
            shareSheet = ShareSheet(activityItems: [text])
            showingShareSheet = true
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Results")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private func presentManualCornerInput(for photo: CapturedPhoto) {
        photoForManualInput = photo
        showingManualCornerInput = true
    }
    
    private func updatePhotoWithManualCorners(photo: CapturedPhoto, corners: [CGPoint]) {
        if let index = cameraManager.capturedPhotos.firstIndex(where: { $0.id == photo.id }) {
            // Update corners result with manual input
            cameraManager.capturedPhotos[index].cornersResult = CapturedPhoto.CornersResult(
                corners: corners,
                message: "Manual corner input"
            )
            
            // Generate masked image with manual corners
            if corners.count == 4 {
                cameraManager.capturedPhotos[index].maskedImage = photo.image.maskChessboardAreaWithManualCorners(corners: corners)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                        ForEach(cameraManager.capturedPhotos) { photo in
                            photoCard(photo)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Saved Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareSheet = shareSheet {
                    shareSheet
                }
            }
            .sheet(isPresented: $showingManualCornerInput) {
                if let photo = photoForManualInput {
                    ManualCornerInputView(photo: photo) { corners in
                        updatePhotoWithManualCorners(photo: photo, corners: corners)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

class DebugLogger: ObservableObject {
    @Published var logs: [String] = []
    private let dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.logs.append(logMessage)
            print(logMessage) // Also print to console
        }
    }
    
    func logAPICall(endpoint: String, requestData: Data? = nil) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] API Call to \(endpoint)"
        DispatchQueue.main.async {
            self.logs.append(logMessage)
            print(logMessage)
        }
    }
    
    func logAPIResponse(endpoint: String, response: Data?, error: Error? = nil) {
        let timestamp = dateFormatter.string(from: Date())
        var logMessage = "[\(timestamp)] API Response from \(endpoint): "
        
        if let error = error {
            logMessage += "Error: \(error.localizedDescription)"
        } else if let response = response {
            do {
                if endpoint == "detect_corners" {
                    let cornersResponse = try JSONDecoder().decode(CornersResponse.self, from: response)
                    logMessage += "Corners: \(cornersResponse.corners), Message: \(cornersResponse.message ?? "nil")"
                } else if endpoint == "recognize_chess_position" {
                    let positionResponse = try JSONDecoder().decode(ChessPositionResponse.self, from: response)
                    logMessage += "FEN: \(positionResponse.fen), Legal: \(positionResponse.hasChessBoard)"
                } else {
                    if let responseString = String(data: response, encoding: .utf8) {
                        logMessage += responseString
                    }
                }
            } catch {
                logMessage += "Error decoding response: \(error.localizedDescription)"
                if let responseString = String(data: response, encoding: .utf8) {
                    logMessage += "\nRaw response: \(responseString)"
                }
            }
        }
        
        DispatchQueue.main.async {
            self.logs.append(logMessage)
            print(logMessage)
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.frame = uiView.bounds
    }
}

extension UIImage {
    func preprocessForChessboard() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Create a context for processing
        let context = CIContext()
        
        // Apply filters to enhance the image
        let filters: [(CIImage) -> CIImage] = [
            // Increase contrast
            { image in
                let filter = CIFilter(name: "CIColorControls")
                filter?.setValue(image, forKey: kCIInputImageKey)
                filter?.setValue(1.1, forKey: kCIInputContrastKey)
                filter?.setValue(0.0, forKey: kCIInputBrightnessKey)
                return filter?.outputImage ?? image
            },
            // Reduce noise
            { image in
                let filter = CIFilter(name: "CINoiseReduction")
                filter?.setValue(image, forKey: kCIInputImageKey)
                filter?.setValue(0.02, forKey: "inputNoiseLevel")
                filter?.setValue(0.6, forKey: "inputSharpness")
                return filter?.outputImage ?? image
            },
            // Enhance edges
            { image in
                let filter = CIFilter(name: "CIEdges")
                filter?.setValue(image, forKey: kCIInputImageKey)
                filter?.setValue(2.0, forKey: "inputIntensity")
                return filter?.outputImage ?? image
            }
        ]
        
        // Apply all filters
        var processedImage = ciImage
        for filter in filters {
            processedImage = filter(processedImage)
        }
        
        // Convert back to UIImage
        guard let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    func maskChessboardArea(corners: [CGPoint]) -> UIImage? {
        guard corners.count == 4,
              let cgImage = self.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Create a graphics context
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Draw the original image
        context.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))
        
        // Create a mask for the chessboard area
        let path = UIBezierPath()
        
        // Convert normalized coordinates to image coordinates
        let imageCorners = corners.map { corner in
            CGPoint(x: corner.x * imageSize.width, y: corner.y * imageSize.height)
        }
        
        // Create polygon from corners
        path.move(to: imageCorners[0])
        for i in 1..<imageCorners.count {
            path.addLine(to: imageCorners[i])
        }
        path.close()
        
        // Create a mask that covers the entire image
        let fullImagePath = UIBezierPath(rect: CGRect(origin: .zero, size: imageSize))
        fullImagePath.append(path)
        fullImagePath.usesEvenOddFillRule = true
        
        // Apply grey overlay to areas outside the chessboard
        context.setFillColor(UIColor.gray.withAlphaComponent(0.7).cgColor)
        context.addPath(fullImagePath.cgPath)
        context.fillPath(using: .evenOdd)
        
        // Get the final image
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return maskedImage
    }
    
    func maskChessboardAreaWithManualCorners(corners: [CGPoint]) -> UIImage? {
        guard corners.count == 4,
              let cgImage = self.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Create a graphics context
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Draw the original image
        context.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))
        
        // Create a mask for the chessboard area using manual corners
        let path = UIBezierPath()
        
        // Use corners as pixel coordinates (assuming they're already in pixel space)
        path.move(to: corners[0])
        for i in 1..<corners.count {
            path.addLine(to: corners[i])
        }
        path.close()
        
        // Create a mask that covers the entire image except the chessboard area
        let fullImagePath = UIBezierPath(rect: CGRect(origin: .zero, size: imageSize))
        fullImagePath.append(path)
        fullImagePath.usesEvenOddFillRule = true
        
        // Apply grey overlay to areas outside the chessboard
        context.setFillColor(UIColor.gray.withAlphaComponent(0.7).cgColor)
        context.addPath(fullImagePath.cgPath)
        context.fillPath(using: .evenOdd)
        
        // Get the final image
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return maskedImage
    }
}

struct TipsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                NavigationView {
                    List {
                        Section(header: Text("Tips for Best Results")) {
                            Text("1. Ensure good lighting on the board")
                            Text("2. Keep the board centered in frame")
                            Text("3. Avoid shadows and glare")
                            Text("4. Make sure all pieces are clearly visible")
                            Text("5. Keep the camera steady")
                        }
                    }
                    .navigationTitle("Tips")
                    .navigationBarItems(trailing: Button("Done") { isPresented = false })
                }
            }
        }
    }
}

struct CameraControlsView: View {
    let onTipsTapped: () -> Void
    let onCaptureTapped: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            Button("Tips for Best Results", action: onTipsTapped)
                .buttonStyle(TipsButtonStyle())
                .padding(.bottom, 20)
            
            Button(action: onCaptureTapped) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 60, height: 60)
                    )
            }
            .padding(.bottom, 30)
        }
    }
}

struct TipsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: "lightbulb.fill")
            configuration.label
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(10)
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

class PreviewState: ObservableObject {
    @Published var isPresented = false
    @Published var image: UIImage?
    
    func showPreview(with image: UIImage) {
        self.image = image
        self.isPresented = true
    }
    
    func dismiss() {
        self.isPresented = false
        self.image = nil
    }
}

struct PreviewView: View {
    @ObservedObject var previewState: PreviewState
    let onUseImage: (UIImage) -> Void
    
    var body: some View {
        if previewState.isPresented {
            ZStack {
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                NavigationView {
                    VStack {
                        if let image = previewState.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                            Text("This is how the API will see your image")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                            HStack {
                                Button("Cancel") {
                                    previewState.dismiss()
                                }
                                .buttonStyle(.bordered)
                                Button("Use This Image") {
                                    onUseImage(image)
                                    previewState.dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                    }
                    .navigationTitle("Preview")
                    .navigationBarItems(trailing: Button("Cancel") { previewState.dismiss() })
                }
            }
        }
    }
}

struct ChessBoardOverlay: View {
    let corners: [CGPoint]
    let imageSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Scale corners to fit the current view size
                let scaleX = geometry.size.width / imageSize.width
                let scaleY = geometry.size.height / imageSize.height
                
                // Draw lines between corners
                if corners.count >= 4 {
                    path.move(to: CGPoint(x: corners[0].x * scaleX, y: corners[0].y * scaleY))
                    path.addLine(to: CGPoint(x: corners[1].x * scaleX, y: corners[1].y * scaleY))
                    path.addLine(to: CGPoint(x: corners[2].x * scaleX, y: corners[2].y * scaleY))
                    path.addLine(to: CGPoint(x: corners[3].x * scaleX, y: corners[3].y * scaleY))
                    path.closeSubpath()
                }
            }
            .stroke(Color.green, lineWidth: 2)
        }
    }
}

struct ManualCornerInputView: View {
    let photo: CapturedPhoto
    let onCornersSelected: ([CGPoint]) -> Void
    
    @State private var selectedCorners: [CGPoint] = []
    @State private var imageSize: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Tap on the four corners of the chessboard")
                    .font(.headline)
                    .padding()
                
                Text("Selected: \(selectedCorners.count)/4 corners")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFit()
                            .background(
                                GeometryReader { imageGeometry in
                                    Color.clear
                                        .onAppear {
                                            let imageAspectRatio = photo.image.size.width / photo.image.size.height
                                            let viewAspectRatio = geometry.size.width / geometry.size.height
                                            
                                            if imageAspectRatio > viewAspectRatio {
                                                // Image is wider than view
                                                let displayHeight = geometry.size.width / imageAspectRatio
                                                imageSize = CGSize(width: geometry.size.width, height: displayHeight)
                                            } else {
                                                // Image is taller than view
                                                let displayWidth = geometry.size.height * imageAspectRatio
                                                imageSize = CGSize(width: displayWidth, height: geometry.size.height)
                                            }
                                        }
                                }
                            )
                            .onTapGesture { location in
                                if selectedCorners.count < 4 {
                                    // Convert tap location to image coordinates
                                    let imageLocation = convertTapToImageCoordinates(location: location, geometry: geometry)
                                    selectedCorners.append(imageLocation)
                                }
                            }
                        
                        // Draw selected corners
                        ForEach(0..<selectedCorners.count, id: \.self) { index in
                            let corner = selectedCorners[index]
                            let viewLocation = convertImageToViewCoordinates(point: corner, geometry: geometry)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                                .position(viewLocation)
                            
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .position(viewLocation)
                        }
                        
                        // Draw lines between corners
                        if selectedCorners.count >= 2 {
                            Path { path in
                                let viewCorners = selectedCorners.map { convertImageToViewCoordinates(point: $0, geometry: geometry) }
                                path.move(to: viewCorners[0])
                                for i in 1..<viewCorners.count {
                                    path.addLine(to: viewCorners[i])
                                }
                                if viewCorners.count == 4 {
                                    path.closeSubpath()
                                }
                            }
                            .stroke(Color.red, lineWidth: 2)
                        }
                    }
                }
                
                HStack {
                    Button("Clear All") {
                        selectedCorners.removeAll()
                    }
                    .disabled(selectedCorners.isEmpty)
                    
                    Button("Undo Last") {
                        if !selectedCorners.isEmpty {
                            selectedCorners.removeLast()
                        }
                    }
                    .disabled(selectedCorners.isEmpty)
                    
                    Spacer()
                    
                    Button("Done") {
                        if selectedCorners.count == 4 {
                            onCornersSelected(selectedCorners)
                            dismiss()
                        }
                    }
                    .disabled(selectedCorners.count != 4)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Manual Corner Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func convertTapToImageCoordinates(location: CGPoint, geometry: GeometryProxy) -> CGPoint {
        let imageAspectRatio = photo.image.size.width / photo.image.size.height
        let viewAspectRatio = geometry.size.width / geometry.size.height
        
        var imageRect: CGRect
        
        if imageAspectRatio > viewAspectRatio {
            // Image is wider than view
            let displayHeight = geometry.size.width / imageAspectRatio
            let yOffset = (geometry.size.height - displayHeight) / 2
            imageRect = CGRect(x: 0, y: yOffset, width: geometry.size.width, height: displayHeight)
        } else {
            // Image is taller than view
            let displayWidth = geometry.size.height * imageAspectRatio
            let xOffset = (geometry.size.width - displayWidth) / 2
            imageRect = CGRect(x: xOffset, y: 0, width: displayWidth, height: geometry.size.height)
        }
        
        // Convert tap location to image coordinates
        let relativeX = (location.x - imageRect.origin.x) / imageRect.width
        let relativeY = (location.y - imageRect.origin.y) / imageRect.height
        
        return CGPoint(
            x: relativeX * photo.image.size.width,
            y: relativeY * photo.image.size.height
        )
    }
    
    private func convertImageToViewCoordinates(point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        let imageAspectRatio = photo.image.size.width / photo.image.size.height
        let viewAspectRatio = geometry.size.width / geometry.size.height
        
        var imageRect: CGRect
        
        if imageAspectRatio > viewAspectRatio {
            // Image is wider than view
            let displayHeight = geometry.size.width / imageAspectRatio
            let yOffset = (geometry.size.height - displayHeight) / 2
            imageRect = CGRect(x: 0, y: yOffset, width: geometry.size.width, height: displayHeight)
        } else {
            // Image is taller than view
            let displayWidth = geometry.size.height * imageAspectRatio
            let xOffset = (geometry.size.width - displayWidth) / 2
            imageRect = CGRect(x: xOffset, y: 0, width: displayWidth, height: geometry.size.height)
        }
        
        // Convert image coordinates to view coordinates
        let relativeX = point.x / photo.image.size.width
        let relativeY = point.y / photo.image.size.height
        
        return CGPoint(
            x: imageRect.origin.x + relativeX * imageRect.width,
            y: imageRect.origin.y + relativeY * imageRect.height
        )
    }
}


