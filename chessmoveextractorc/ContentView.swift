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
    let hasChessBoard: Bool?
    let error: String?
    let message: String?
    let lichess_url: String?
    let debug_images: [String: String]? // Base64-encoded debug images
    let ascii: String? // ASCII art of the board
    let legal_position: Bool? // Is the position legal
    let debug_image_paths: [String: String]? // File paths to saved debug images
    let corners: [[Double]]? // The corners used for recognition
    let processing_time: String? // Timestamp
    let image_info: [String: String]? // Metadata about the uploaded image
    let debug_info: [String: String]? // Pipeline step status
}

struct ChessPositionDescriptionResponse: Codable {
    let fen: String
    let ascii: String? // ASCII art of the board
    let lichess_url: String?
    let legal_position: Bool? // Is the position legal
    let position_description: String? // Chess position description (API field name)
    let board_2d: [[String]]? // 2D board representation
    let pieces_found: Int? // Number of pieces found
    let debug_images: [String: String]? // Base64-encoded debug images
    let debug_image_paths: [String: String]? // File paths to saved debug images
    let corners: [[Double]]? // The corners used for recognition
    let processing_time: Double? // Timestamp
    let image_info: [String: String]? // Metadata about the uploaded image
    let debug_info: [String: String]? // Pipeline step status
    let error: ErrorInfo? // Error information
    
    struct ErrorInfo: Codable {
        let type: String?
        let message: String?
        let suggestion: String?
    }
    
    // Computed property to match our expected interface
    var description: String? {
        return position_description
    }
    
    // Computed property to match our expected interface
    var hasChessBoard: Bool {
        return legal_position ?? false
    }
}

struct CornersResponse: Codable {
    let corners: [Corner]
    let hasChessBoard: Bool
    let error: String?
    let message: String?
    let debug_images: [String: String]? // New field for base64-encoded debug images
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
                    
                    // Calculate scaling to fit the image in the view
                    let scaleX = viewWidth / imageSize.width
                    let scaleY = viewHeight / imageSize.height
                    let scale = min(scaleX, scaleY) // Use min to maintain aspect ratio
                    
                    // Calculate the scaled image dimensions
                    let scaledImageWidth = imageSize.width * scale
                    let scaledImageHeight = imageSize.height * scale
                    
                    // Calculate offsets to center the image
                    let xOffset = (viewWidth - scaledImageWidth) / 2.0
                    let yOffset = (viewHeight - scaledImageHeight) / 2.0

                    let transformedCorners = corners.map { corner in
                        // The corners are normalized (0-1), so we need to scale them to the actual image size first
                        let imageCornerX = corner.x * imageSize.width
                        let imageCornerY = corner.y * imageSize.height
                        
                        // Transform the corner coordinates
                        let transformedX = imageCornerX * scale + xOffset
                        let transformedY = imageCornerY * scale + yOffset
                        
                        return CGPoint(x: transformedX, y: transformedY)
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

// Helper extension to decode base64 images
extension String {
    func decodeBase64Image() -> UIImage? {
        print("🔍 Attempting to decode base64 image, length: \(self.count)")
        
        // First try standard base64 decoding
        if let data = Data(base64Encoded: self) {
            print("🔍 Standard base64 decoding successful, data size: \(data.count)")
            if let image = UIImage(data: data) {
                print("✅ Successfully created UIImage from standard base64")
                return image
            } else {
                print("❌ Failed to create UIImage from standard base64 data")
            }
        } else {
            print("❌ Standard base64 decoding failed")
        }
        
        // Try with ignoreUnknownCharacters option
        if let data = Data(base64Encoded: self, options: .ignoreUnknownCharacters) {
            print("🔍 IgnoreUnknownCharacters base64 decoding successful, data size: \(data.count)")
            if let image = UIImage(data: data) {
                print("✅ Successfully created UIImage from ignoreUnknownCharacters base64")
                return image
            } else {
                print("❌ Failed to create UIImage from ignoreUnknownCharacters base64 data")
            }
        } else {
            print("❌ IgnoreUnknownCharacters base64 decoding failed")
        }
        
        // Try removing potential data URL prefix
        let cleanString = self.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpg;base64,", with: "")
        
        if cleanString != self {
            print("🔍 Cleaned base64 string, new length: \(cleanString.count)")
            if let data = Data(base64Encoded: cleanString) {
                print("🔍 Cleaned standard base64 decoding successful, data size: \(data.count)")
                if let image = UIImage(data: data) {
                    print("✅ Successfully created UIImage from cleaned standard base64")
                    return image
                } else {
                    print("❌ Failed to create UIImage from cleaned standard base64 data")
                }
            }
            if let data = Data(base64Encoded: cleanString, options: .ignoreUnknownCharacters) {
                print("🔍 Cleaned ignoreUnknownCharacters base64 decoding successful, data size: \(data.count)")
                if let image = UIImage(data: data) {
                    print("✅ Successfully created UIImage from cleaned ignoreUnknownCharacters base64")
                    return image
                } else {
                    print("❌ Failed to create UIImage from cleaned ignoreUnknownCharacters base64 data")
                }
            }
        }
        
        print("❌ All base64 decoding attempts failed")
        return nil
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
            return (chessResponse.hasChessBoard ?? false, chessResponse.fen, chessResponse.lichess_url)
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
            
            // Process debug images from corners API
            if let debugImagesBase64 = cornersResponse.debug_images {
                print("🔍 Debug images received from corners API: \(debugImagesBase64.keys.sorted())")
                var debugImages: [String: UIImage] = [:]
                for (key, base64String) in debugImagesBase64 {
                    print("🔍 Processing corners debug image: \(key)")
                    if let image = base64String.decodeBase64Image() {
                        debugImages[key] = image
                        print("✅ Successfully decoded corners debug image: \(key)")
                    } else {
                        print("❌ Failed to decode corners debug image: \(key)")
                    }
                }
                print("🔍 Final corners debug images count: \(debugImages.count)")
            }
            
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
    private let recognizeWithDescriptionURL = "https://api.chesspositionscanner.store/recognize_chess_position_with_cursor_description"
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
        
        // Add color parameter (required by the API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"color\"\r\n\r\n".data(using: .utf8)!)
        body.append("white\r\n".data(using: .utf8)!)
        
        // Add debug parameter to help identify issues
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"debug\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return (body, boundary)
    }
    
    func recognizePosition(imageData: Data) async throws -> (ChessPositionResponse?, String?, [String: UIImage]?) {
        guard let url = URL(string: recognizeURL) else {
            debugLogger.log("Invalid URL for recognize_chess_position")
            throw URLError(.badURL)
        }
        
        // Try with original image data first
        var result = try await makeRecognizeRequest(imageData: imageData)
        
        // If it fails with 502 error, retry once after a short delay
        if result.1 != nil && result.1!.contains("502") {
            debugLogger.log("First attempt failed with 502 error, retrying after 2 seconds...")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            result = try await makeRecognizeRequest(imageData: imageData)
        }
        
        // If it fails with 500 error, try with different compression
        if result.1 != nil && result.1!.contains("500") {
            debugLogger.log("First attempt failed with 500 error, trying with different compression...")
            
            // Try with higher quality JPEG
            if let uiImage = UIImage(data: imageData),
               let highQualityData = uiImage.jpegData(compressionQuality: 0.95) {
                result = try await makeRecognizeRequest(imageData: highQualityData)
            }
            
            // If still failing, try with PNG
            if result.1 != nil && result.1!.contains("500") {
                debugLogger.log("JPEG attempts failed, trying with PNG...")
                if let uiImage = UIImage(data: imageData),
                   let pngData = uiImage.pngData() {
                    result = try await makeRecognizeRequest(imageData: pngData)
                }
            }
            
            // If still failing, try with a smaller resized image
            if result.1 != nil && result.1!.contains("500") {
                debugLogger.log("All format attempts failed, trying with smaller resized image...")
                if let uiImage = UIImage(data: imageData) {
                    let resizedImage = uiImage.resized(to: CGSize(width: 800, height: 600))
                    if let resizedData = resizedImage.jpegData(compressionQuality: 0.8) {
                        result = try await makeRecognizeRequest(imageData: resizedData)
                    }
                }
            }
            
            // If still failing, try with normalized orientation
            if result.1 != nil && result.1!.contains("500") {
                debugLogger.log("All size attempts failed, trying with normalized orientation...")
                if let uiImage = UIImage(data: imageData) {
                    let normalizedImage = UIImage(cgImage: uiImage.cgImage!, scale: uiImage.scale, orientation: .up)
                    if let normalizedData = normalizedImage.jpegData(compressionQuality: 0.8) {
                        result = try await makeRecognizeRequest(imageData: normalizedData)
                    }
                }
            }
        }
        
        // If it fails with 502 error, retry once after a short delay
        if result.1 != nil && result.1!.contains("502") {
            debugLogger.log("First attempt failed with 502 error, retrying after delay...")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            result = try await makeRecognizeRequest(imageData: imageData)
        }
        
        return (result.0, result.1, result.2)
    }
    
    private func makeRecognizeRequest(imageData: Data) async throws -> (ChessPositionResponse?, String?, [String: UIImage]?) {
        let (body, boundary) = createMultipartFormData(imageData: imageData)
        
        var request = URLRequest(url: URL(string: recognizeURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        debugLogger.log("Making recognize_chess_position API call with \(imageData.count) bytes")
        debugLogger.log("Image data size: \(imageData.count) bytes")
        if let uiImage = UIImage(data: imageData) {
            debugLogger.log("Image dimensions: \(uiImage.size.width) x \(uiImage.size.height)")
            debugLogger.log("Image scale: \(uiImage.scale)")
            debugLogger.log("Image orientation: \(uiImage.imageOrientation.rawValue)")
        }
        debugLogger.logAPICall(endpoint: "recognize_chess_position", requestData: imageData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLogger.log("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            debugLogger.log("API Response Status Code: \(httpResponse.statusCode)")
            
            // Always try to decode the response to extract debug images, even on error
            var debugImages: [String: UIImage]?
            if let responseString = String(data: data, encoding: .utf8) {
                debugLogger.log("Raw API Response: \(responseString)")
                
                // Try to decode as JSON to extract debug images
                if let jsonData = responseString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let debugImagesBase64 = json["debug_images"] as? [String: String] {
                            
                            debugLogger.log("🔍 Debug images found in API response (even on error): \(debugImagesBase64.keys.sorted())")
                            debugImages = [:]
                            for (key, base64String) in debugImagesBase64 {
                                debugLogger.log("🔍 Processing debug image from error response: \(key)")
                                if let image = base64String.decodeBase64Image() {
                                    debugImages?[key] = image
                                    debugLogger.log("✅ Successfully decoded debug image from error response: \(key)")
                                } else {
                                    debugLogger.log("❌ Failed to decode debug image from error response: \(key)")
                                }
                            }
                        }
                    } catch {
                        debugLogger.log("Failed to parse JSON for debug images: \(error)")
                    }
                }
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("API Error: \(errorMessage)")
                
                // Special handling for 500 errors which might be due to image format issues
                if httpResponse.statusCode == 500 {
                    debugLogger.log("Server error (500) - this might be due to image format issues")
                    return (nil, "Server processing error (500): \(errorMessage). This might be due to image format or preprocessing issues.", debugImages)
                }
                
                // Special handling for 502 errors (Bad Gateway)
                if httpResponse.statusCode == 502 {
                    debugLogger.log("Server error (502) - Bad Gateway, server is temporarily unavailable")
                    return (nil, "Server temporarily unavailable (502 Bad Gateway). Please try again in a few moments. This is a server-side issue, not a problem with your image.", debugImages)
                }
                
                // Special handling for 503 errors (Service Unavailable)
                if httpResponse.statusCode == 503 {
                    debugLogger.log("Server error (503) - Service Unavailable")
                    return (nil, "Server is temporarily overloaded (503 Service Unavailable). Please try again later.", debugImages)
                }
                
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)", debugImages)
            }
            
            do {
                let result = try JSONDecoder().decode(ChessPositionResponse.self, from: data)
                debugLogger.log("Successfully decoded recognize_chess_position response")
                
                // Add detailed logging for debug images
                if let debugImages = result.debug_images {
                    debugLogger.log("🔍 Debug images found in API response: \(debugImages.count) images")
                    debugLogger.log("🔍 Debug image keys: \(debugImages.keys.sorted())")
                    for (key, base64String) in debugImages {
                        debugLogger.log("🔍 Debug image '\(key)': length=\(base64String.count), startsWith=\(String(base64String.prefix(50)))")
                    }
                } else {
                    debugLogger.log("❌ No debug_images field in API response")
                }
                
                debugLogger.logAPIResponse(endpoint: "recognize_chess_position", response: data)
                return (result, nil, debugImages)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Failed to decode response: \(responseString)")
                }
                return (nil, "Failed to decode response: \(error.localizedDescription)", debugImages)
            }
        } catch {
            debugLogger.log("Error in recognize_chess_position: \(error.localizedDescription)")
            throw error
        }
    }
    
    func detectCorners(imageData: Data) async throws -> (CornersResponse?, String?, [String: UIImage]?) {
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
            
            // Always try to decode the response to extract debug images, even on error
            var debugImages: [String: UIImage]?
            if let responseString = String(data: data, encoding: .utf8) {
                debugLogger.log("Raw API Response: \(responseString)")
                
                // Try to decode as JSON to extract debug images
                if let jsonData = responseString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let debugImagesBase64 = json["debug_images"] as? [String: String] {
                            
                            debugLogger.log("🔍 Debug images found in corners API response (even on error): \(debugImagesBase64.keys.sorted())")
                            debugImages = [:]
                            for (key, base64String) in debugImagesBase64 {
                                debugLogger.log("🔍 Processing corners debug image from error response: \(key)")
                                if let image = base64String.decodeBase64Image() {
                                    debugImages?[key] = image
                                    debugLogger.log("✅ Successfully decoded corners debug image from error response: \(key)")
                                } else {
                                    debugLogger.log("❌ Failed to decode corners debug image from error response: \(key)")
                                }
                            }
                        }
                    } catch {
                        debugLogger.log("Failed to parse JSON for debug images: \(error)")
                    }
                }
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("API Error: \(errorMessage)")
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)", debugImages)
            }
            
            do {
                let result = try JSONDecoder().decode(CornersResponse.self, from: data)
                debugLogger.log("Successfully decoded detect_corners response")
                debugLogger.logAPIResponse(endpoint: "detect_corners", response: data)
                return (result, nil, debugImages)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Failed to decode response: \(responseString)")
                }
                return (nil, "Failed to decode response: \(error.localizedDescription)", debugImages)
            }
        } catch {
            debugLogger.log("Error in detect_corners: \(error.localizedDescription)")
            throw error
        }
    }
    
    func recognizePositionWithCorners(imageData: Data, corners: [CGPoint]) async throws -> (ChessPositionResponse?, String?, [String: UIImage]?) {
        guard let url = URL(string: recognizeURL) else {
            debugLogger.log("Invalid URL for recognize_chess_position with corners")
            throw URLError(.badURL)
        }
        
        let (body, boundary) = createMultipartFormDataWithCorners(imageData: imageData, corners: corners)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        debugLogger.log("Making recognize_chess_position API call with \(imageData.count) bytes and manual corners")
        debugLogger.log("Manual corners: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
        debugLogger.logAPICall(endpoint: "recognize_chess_position_with_corners", requestData: imageData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLogger.log("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            debugLogger.log("API Response Status Code: \(httpResponse.statusCode)")
            
            // Always try to decode the response to extract debug images, even on error
            var debugImages: [String: UIImage]?
            if let responseString = String(data: data, encoding: .utf8) {
                debugLogger.log("Raw API Response: \(responseString)")
                
                // Try to decode as JSON to extract debug images
                if let jsonData = responseString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let debugImagesBase64 = json["debug_images"] as? [String: String] {
                            
                            debugLogger.log("🔍 Debug images found in API response (even on error): \(debugImagesBase64.keys.sorted())")
                            debugImages = [:]
                            for (key, base64String) in debugImagesBase64 {
                                debugLogger.log("🔍 Processing debug image from error response: \(key)")
                                if let image = base64String.decodeBase64Image() {
                                    debugImages?[key] = image
                                    debugLogger.log("✅ Successfully decoded debug image from error response: \(key)")
                                } else {
                                    debugLogger.log("❌ Failed to decode debug image from error response: \(key)")
                                }
                            }
                        }
                    } catch {
                        debugLogger.log("Failed to parse JSON for debug images: \(error)")
                    }
                }
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("API Error: \(errorMessage)")
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)", debugImages)
            }
            
            do {
                let result = try JSONDecoder().decode(ChessPositionResponse.self, from: data)
                debugLogger.log("Successfully decoded recognize_chess_position with corners response")
                debugLogger.logAPIResponse(endpoint: "recognize_chess_position_with_corners", response: data)
                return (result, nil, debugImages)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Failed to decode response: \(responseString)")
                }
                return (nil, "Failed to decode response: \(error.localizedDescription)", debugImages)
            }
        } catch {
            debugLogger.log("Error in recognize_chess_position with corners: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func createMultipartFormDataWithCorners(imageData: Data, corners: [CGPoint]) -> (Data, String) {
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add color parameter (required by the API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"color\"\r\n\r\n".data(using: .utf8)!)
        body.append("white\r\n".data(using: .utf8)!)
        
        // Add corners parameter
        let cornersString = corners.map { "\($0.x),\($0.y)" }.joined(separator: ";")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"corners\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cornersString)\r\n".data(using: .utf8)!)
        
        // Add cursor_description parameter (required by the cursor description endpoint)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"cursor_description\"\r\n\r\n".data(using: .utf8)!)
        body.append("Chess position with manually adjusted corners\r\n".data(using: .utf8)!)
        
        // Add debug parameter to help identify issues
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"debug\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return (body, boundary)
    }
    
    func recognizePositionWithDescription(imageData: Data, corners: [CGPoint]) async throws -> (ChessPositionDescriptionResponse?, String?, [String: UIImage]?) {
                    guard let url = URL(string: recognizeWithDescriptionURL) else {
                debugLogger.log("Invalid URL for recognize_chess_position_with_cursor_description")
                throw URLError(.badURL)
            }
        
        let (body, boundary) = createMultipartFormDataWithCorners(imageData: imageData, corners: corners)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        debugLogger.log("Making recognize_chess_position_with_cursor_description API call with \(imageData.count) bytes and manual corners")
        debugLogger.log("API URL: \(recognizeWithDescriptionURL)")
        debugLogger.log("Manual corners: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
        debugLogger.logAPICall(endpoint: "recognize_chess_position_with_cursor_description", requestData: imageData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLogger.log("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            debugLogger.log("API Response Status Code: \(httpResponse.statusCode)")
            
            // Always try to decode the response to extract debug images, even on error
            var debugImages: [String: UIImage]?
            if let responseString = String(data: data, encoding: .utf8) {
                debugLogger.log("Raw API Response: \(responseString)")
                
                // Try to decode as JSON to extract debug images
                if let jsonData = responseString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let debugImagesBase64 = json["debug_images"] as? [String: String] {
                            
                            debugLogger.log("🔍 Debug images found in API response (even on error): \(debugImagesBase64.keys.sorted())")
                            debugImages = [:]
                            for (key, base64String) in debugImagesBase64 {
                                debugLogger.log("🔍 Processing debug image from error response: \(key)")
                                if let image = base64String.decodeBase64Image() {
                                    debugImages?[key] = image
                                    debugLogger.log("✅ Successfully decoded debug image from error response: \(key)")
                                } else {
                                    debugLogger.log("❌ Failed to decode debug image from error response: \(key)")
                                }
                            }
                        }
                    } catch {
                        debugLogger.log("Failed to parse JSON for debug images: \(error)")
                    }
                }
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("API Error: \(errorMessage)")
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)", debugImages)
            }
            
            do {
                let result = try JSONDecoder().decode(ChessPositionDescriptionResponse.self, from: data)
                debugLogger.log("Successfully decoded recognize_chess_position_with_cursor_description response")
                debugLogger.log("FEN: \(result.fen)")
                debugLogger.log("Position Description: \(result.position_description ?? "nil")")
                debugLogger.log("Computed Description: \(result.description ?? "nil")")
                debugLogger.logAPICall(endpoint: "recognize_chess_position_with_cursor_description", requestData: data)
                return (result, nil, debugImages)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Raw response that failed to decode: \(responseString)")
                }
                
                // Try to decode as regular ChessPositionResponse as fallback
                do {
                    let fallbackResult = try JSONDecoder().decode(ChessPositionResponse.self, from: data)
                    debugLogger.log("Successfully decoded as fallback ChessPositionResponse")
                    
                    // Convert to ChessPositionDescriptionResponse
                    let result = ChessPositionDescriptionResponse(
                        fen: fallbackResult.fen,
                        ascii: fallbackResult.ascii,
                        lichess_url: fallbackResult.lichess_url,
                        legal_position: fallbackResult.legal_position,
                        position_description: nil, // No description in fallback response
                        board_2d: nil, // No board_2d in fallback response
                        pieces_found: nil, // No pieces_found in fallback response
                        debug_images: fallbackResult.debug_images,
                        debug_image_paths: fallbackResult.debug_image_paths,
                        corners: fallbackResult.corners,
                        processing_time: nil, // Convert if needed
                        image_info: fallbackResult.image_info,
                        debug_info: fallbackResult.debug_info,
                        error: nil // No error info in fallback response
                    )
                    return (result, nil, debugImages)
                } catch {
                    // Try minimal FEN-only fallback
                    do {
                        let minimal = try JSONDecoder().decode(MinimalFENResponse.self, from: data)
                        let result = ChessPositionDescriptionResponse(
                            fen: minimal.fen,
                            ascii: nil,
                            lichess_url: nil,
                            legal_position: nil,
                            position_description: nil,
                            board_2d: nil,
                            pieces_found: nil,
                            debug_images: nil,
                            debug_image_paths: nil,
                            corners: nil,
                            processing_time: nil,
                            image_info: nil,
                            debug_info: nil,
                            error: nil
                        )
                        return (result, nil, nil)
                    } catch {
                        debugLogger.log("Fallback decoding also failed: \(error)")
                        return (nil, "Failed to decode response: \(error.localizedDescription). Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to read response")", debugImages)
                    }
                }
            }
        } catch {
            debugLogger.log("Error in recognize_chess_position_with_cursor_description: \(error.localizedDescription)")
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
            isProcessing: false // No API call, so not processing
        )
        capturedPhotos.append(photo)
        // Do NOT make any API calls here. Only after user sets corners.
    }
    
    private func convertPixelBufferToImageData(_ pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
    
    func deletePhoto(at index: Int) {
        guard index >= 0 && index < capturedPhotos.count else { return }
        capturedPhotos.remove(at: index)
    }
    
    func deletePhoto(with id: UUID) {
        capturedPhotos.removeAll { $0.id == id }
    }
    
    func sendCorrectedCornersToAPI(for photoId: UUID, corners: [CGPoint]) async {
        guard let photoIndex = capturedPhotos.firstIndex(where: { $0.id == photoId }) else {
            print("❌ Photo not found for ID: \(photoId)")
            return
        }
        
        let photo = capturedPhotos[photoIndex]
        
        do {
            // Set processing state
            await MainActor.run {
                self.capturedPhotos[photoIndex].isSendingCornersToAPI = true
            }
            
            // Create greyed image with chessboard focus for API (as the model was trained on greyed images)
            let normalizedImage = photo.image.fixOrientation()
            let greyedImage = normalizedImage.createBlurredImageWithChessboardFocus(corners: corners)
            let imageData = greyedImage?.jpegData(compressionQuality: 0.95) ?? Data()
            print("🔄 Sending corrected corners to description API: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
            print("🔄 Image data size: \(imageData.count) bytes")
            print("🔄 Original image size: \(photo.image.size)")
            print("🔄 Normalized image size: \(normalizedImage.size)")
            print("🔄 Original image orientation: \(photo.image.imageOrientation.rawValue)")
            print("🔄 Normalized image orientation: \(normalizedImage.imageOrientation.rawValue)")
            print("🔄 Using greyed image for API (model trained on greyed images)")
            
            let (positionResponse, positionError, positionDebugImages) = try await localChessService.recognizePositionWithDescription(imageData: imageData, corners: corners)
            
            await MainActor.run {
                // Clear processing state
                self.capturedPhotos[photoIndex].isSendingCornersToAPI = false
                
                // Update manual corners
                self.capturedPhotos[photoIndex].manualCorners = corners
                
                // Update position result with corrected corners
                if let position = positionResponse {
                    self.capturedPhotos[photoIndex].positionResult = CapturedPhoto.PositionResult(
                        fen: position.fen,
                        lichessURL: position.lichess_url,
                        ascii: position.ascii,
                        legalPosition: position.legal_position ?? false,
                        debugImages: positionDebugImages, // This will show in the "Position Recognition Debug Images" row
                        debugImagePaths: position.debug_image_paths,
                        corners: position.corners,
                        processingTime: position.processing_time?.description,
                        imageInfo: position.image_info,
                        debugInfo: position.debug_info,
                        description: position.description, // Add the description from the new API
                        board2d: position.board_2d,
                        piecesFound: position.pieces_found
                    )
                    
                    // Process debug images from the new API call
                    if let positionDebugImages = positionDebugImages {
                        print("🔍 Processing debug images from corrected corners API call: \(positionDebugImages.keys.sorted())")
                        print("🔍 New debug images will appear in 'Position Recognition Debug Images' section")
                        for (key, image) in positionDebugImages {
                            print("🔍 New debug image '\(key)': size=\(image.size), scale=\(image.scale)")
                        }
                    }
                    
                    // Log the description if available
                    print("🔍 Full API response analysis:")
                    print("🔍 FEN: \(position.fen)")
                    print("🔍 Position Description: \(position.position_description ?? "nil")")
                    print("🔍 Computed Description: \(position.description ?? "nil")")
                    print("🔍 Has Debug Images: \(position.debug_images != nil)")
                    print("🔍 Debug Image Keys: \(position.debug_images?.keys.sorted() ?? [])")
                    
                    if let description = position.description {
                        print("📝 Position description length: \(description.count)")
                        print("📝 Position description preview: \(String(description.prefix(200)))")
                        
                        // Check for various base64 image indicators
                        let isBase64Image = description.contains("data:image") || 
                                          description.contains("iVBORw0KGgo") ||
                                          description.contains("zQx1ZWeeT9lJ5ufbaoX+E7BekMASoA2YSVvbko/jsF29SyKUDDAzOcb2dV1sSs7ztH1dFzAbWzf9wX48n4Akx7aS3OLjONrOBDWJpOu6bH/69On++fPM9IPttVYSIIm22Wy3lXQch6TjOP4PJawEpiiI1nwAAAAASUVORK5CYII=") ||
                                          description.count > 1000
                        
                        if isBase64Image {
                            print("⚠️ Position description contains base64 image data!")
                            print("⚠️ This appears to be an image, not text description")
                        } else {
                            print("✅ Position description appears to be valid text")
                        }
                    } else {
                        print("❌ No position description in API response")
                    }
                    
                    // Update API errors (no corners error since we don't use that endpoint)
                    self.capturedPhotos[photoIndex].apiErrors = CapturedPhoto.APIErrors(
                        positionError: positionError,
                        cornersError: nil
                    )
                    
                    print("✅ Successfully updated position with corrected corners and description")
                    
                    // Show success message briefly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        // The success will be visible in the updated position result and debug images
                    }
                } else if let error = positionError {
                    // Update only the position error (no corners error since we don't use that endpoint)
                    self.capturedPhotos[photoIndex].apiErrors = CapturedPhoto.APIErrors(
                        positionError: error,
                        cornersError: nil
                    )
                    
                    print("❌ Failed to update position with corrected corners: \(error)")
                }
            }
        } catch {
            print("❌ Error sending corrected corners to API: \(error)")
            await MainActor.run {
                // Clear processing state
                self.capturedPhotos[photoIndex].isSendingCornersToAPI = false
                
                self.capturedPhotos[photoIndex].apiErrors = CapturedPhoto.APIErrors(
                    positionError: "Failed to send corrected corners: \(error.localizedDescription)",
                    cornersError: nil
                )
            }
        }
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
                    // Only detect corners initially, don't send to position API until user manually adjusts corners
                    let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                    print("📸 Detecting corners only with size: \(imageData.count) bytes")
                    
                    let (cornersResponse, cornersError, cornersDebugImages) = try await self.localChessService.detectCorners(imageData: imageData)
                    // Don't call position API initially - wait for user to adjust corners
                    
                    print("🔍 Corners API response: \(cornersResponse?.corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", ") ?? "nil")")
                    print("🔍 Corners API error: \(cornersError ?? "none")")
                    
                    // Update the photo with results
                    if let index = self.capturedPhotos.firstIndex(where: { $0.id == capturedPhoto.id }) {
                        // Convert corners response
                        if let corners = cornersResponse {
                            print("🔍 Storing corners response: \(corners.corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
                            self.capturedPhotos[index].cornersResult = CapturedPhoto.CornersResult(
                                corners: corners.corners.map { CGPoint(x: $0.x, y: $0.y) },
                                message: corners.message
                            )
                            print("🔍 Corners stored successfully")
                        } else {
                            print("❌ No corners response received")
                        }
                        
                        // Set API errors (only corners error for now)
                        self.capturedPhotos[index].apiErrors = CapturedPhoto.APIErrors(
                            positionError: nil, // No position API call initially
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
    var error: String?
    var apiErrors: APIErrors?
    var debugImages: [String: UIImage]? // New field for debug images
    var manualCorners: [CGPoint]? // Manual corner adjustments
    var isAdjustingCorners: Bool = false // Track if user is adjusting corners
    var isSendingCornersToAPI: Bool = false // Track if corners are being sent to API
    
    struct PositionResult {
        let fen: String
        let lichessURL: String?
        let ascii: String?
        let legalPosition: Bool
        let debugImages: [String: UIImage]? // Debug images from API response
        let debugImagePaths: [String: String]? // File paths to saved debug images
        let corners: [[Double]]? // The corners used for recognition
        let processingTime: String? // Timestamp
        let imageInfo: [String: String]? // Metadata about the uploaded image
        let debugInfo: [String: String]? // Pipeline step status
        let description: String? // Chess position description
        let board2d: [[String]]? // 2D board representation
        let piecesFound: Int? // Number of pieces found
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

// Helper struct to wrap UUID for Identifiable conformance
struct EditingPhotoID: Identifiable, Equatable {
    let id: UUID
}

// 2D Board View Component
struct Board2DView: View {
    let board2d: [[String]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("2D Board:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(board2d.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 1) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            Text(cell)
                                .font(.caption2)
                                .frame(width: 20, height: 20)
                                .background((rowIndex + colIndex) % 2 == 0 ? Color.white : Color.gray.opacity(0.3))
                                .border(Color.black, width: 0.5)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .cornerRadius(4)
        }
    }
}

struct CapturedPhotosView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    @State private var shareSheet: ShareSheet?
    @State private var showingShareSheet = false
    @State private var photoToDelete: UUID?
    @State private var showingDeleteAlert = false
    @State private var blurredImage: UIImage?
    @State private var showingBlurredImage = false
    @State private var imageSavedMessage = ""
    @State private var editingPhotoId: EditingPhotoID? = nil
    @State private var fullscreenCorners: [CGPoint] = []
    
    private func generateShareText(for photo: CapturedPhoto) -> String {
        var text = "Chess Position Analysis\n\n"
        
        if let positionResult = photo.positionResult {
            text += "Position Recognition:\n"
            text += "FEN: \(positionResult.fen)\n"
            text += "Legal Position: \(positionResult.legalPosition ? "Yes" : "No")\n"
            if let description = positionResult.description, !description.isEmpty {
                text += "Description: \(description)\n"
            }
            if let lichessURL = positionResult.lichessURL {
                text += "Lichess URL: \(lichessURL)\n"
            }
            if let ascii = positionResult.ascii {
                text += "\nASCII Board:\n\(ascii)\n\n"
            }
        } else if let error = photo.apiErrors?.positionError {
            text += "Position Recognition Error: \(error)\n\n"
        }
        
        // No corner detection info since we don't use that endpoint anymore
        
        // Add debug images information
        if let debugImages = photo.debugImages, !debugImages.isEmpty {
            text += "Debug Images:\n"
            text += "Number of preprocessing steps: \(debugImages.count)\n"
            text += "Steps: \(debugImages.keys.sorted().joined(separator: ", "))\n\n"
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
            // Original photo with corner editing
                VStack(alignment: .leading, spacing: 4) {
                Text("Chess Photo")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ZStack {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
                        .onTapGesture(count: 2) {
                            // Open full screen editor for this photo
                            editingPhotoId = EditingPhotoID(id: photo.id)
                                                // Use manual corners if set, else default to image corners
                    let initialCorners: [CGPoint]
                    if let manual = photo.manualCorners, manual.count == 4 {
                        initialCorners = manual
                    } else {
                        // Default to image corners (normalized)
                        initialCorners = [
                            CGPoint(x: 0, y: 0),
                            CGPoint(x: 1, y: 0),
                            CGPoint(x: 1, y: 1),
                            CGPoint(x: 0, y: 1)
                        ]
                    }
                            fullscreenCorners = initialCorners
                        }
                    
                    // Show corner overlay if manual corners are available
                    if let manualCorners = photo.manualCorners, manualCorners.count == 4 {
                        CornerOverlayView(corners: manualCorners, imageSize: photo.image.size)
                    }
                }
                .frame(height: 200)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 4) {
        HStack {
                        Image(systemName: "pencil.circle.fill")
                .foregroundColor(.blue)
                        Text("Double-tap to edit corners")
                            .font(.caption)
                    .foregroundColor(.blue)
                    }
                    
                    if photo.manualCorners != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Manual corners applied")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        
            // Processing indicator
            if photo.isProcessing {
                HStack {
                    ProgressView()
                    Text("Processing...")
                        .font(.caption)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
            if photo.isSendingCornersToAPI {
                                            HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Sending corners to API...")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
        }
        .padding()
                .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
            // Position result (complete API response)
            if let positionResult = photo.positionResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Response Data")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // FEN
                    if !positionResult.fen.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FEN:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(positionResult.fen)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // 2D Board
                    if let board2d = positionResult.board2d {
                        Board2DView(board2d: board2d)
                    }
                    
                    // ASCII Board
                    if let ascii = positionResult.ascii, !ascii.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ASCII Board:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(ascii)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Position Description
                    if let description = positionResult.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Position Description:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            // Check if description contains base64 image data
                            let isBase64Image = description.contains("data:image") || 
                                              description.contains("iVBORw0KGgo") ||
                                              description.contains("zQx1ZWeeT9lJ5ufbaoX+E7BekMASoA2YSVvbko/jsF29SyKUDDAzOcb2dV1sSs7ztH1dFzAbWzf9wX48n4Akx7aS3OLjONrOBDWJpOu6bH/69On++fPM9IPttVYSIIm22Wy3lXQch6TjOP4PJawEpiiI1nwAAAAASUVORK5CYII=") ||
                                              description.count > 1000
                            
                            if isBase64Image {
                                Text("Contains base64 image data (length: \(description.count))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(5)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    // Legal Position
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Legal Position:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(positionResult.legalPosition ? "Yes" : "No")
                            .font(.caption)
                            .foregroundColor(positionResult.legalPosition ? .green : .red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(4)
                    
                    // Pieces Found
                    if let piecesFound = positionResult.piecesFound {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pieces Found:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("\(piecesFound)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    // Lichess URL
                    if let lichessUrl = positionResult.lichessURL, !lichessUrl.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lichess URL:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(lichessUrl)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    // Processing Time
                    if let processingTime = positionResult.processingTime {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processing Time:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("\(processingTime)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    // Debug Info
                    if let debugInfo = positionResult.debugInfo, !debugInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Debug Info:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(debugInfo.keys.sorted()), id: \.self) { key in
                                if let value = debugInfo[key] {
                                    HStack {
                                        Text("\(key):")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(value)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                    }
                    

                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
    
            // Error display (simplified)
            if let error = photo.error {
                Text("Error: \(error)")
                                        .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                                            .cornerRadius(8)
                                        }
            
            if let apiErrors = photo.apiErrors, apiErrors.positionError != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let positionError = apiErrors.positionError {
                        Text("Position Error: \(positionError)")
                                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                    }
            
            // Share button
            shareButton(photo)
                    }
                    .padding()
        .background(Color.white)
                                    .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    
    
        private func sendCorrectedCornersToAPI(photo: CapturedPhoto, corners: [CGPoint]) {
        Task {
            // Send the image with manually adjusted corners to the API
            await cameraManager.sendCorrectedCornersToAPI(for: photo.id, corners: corners)
        }
    }
    
    
    
    
    

    
    private func saveBlurredImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.imageSavedMessage = "✅ Image saved to photos successfully!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self.imageSavedMessage = ""
                            }
                        } else if let error = error {
                            self.imageSavedMessage = "❌ Failed to save image: \(error.localizedDescription)"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self.imageSavedMessage = ""
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.imageSavedMessage = "❌ Photo library access denied"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.imageSavedMessage = ""
                    }
                }
            }
        }
    }
    
    private func shareButton(_ photo: CapturedPhoto) -> some View {
        Button(action: {
            var items: [Any] = []
            
            // Add original photo
            items.append(photo.image)
            
            // Add preprocessed photo if available
            if let preprocessedImage = photo.preprocessedImage {
                items.append(preprocessedImage)
            }
            
            // Add debug images if available
            if let debugImages = photo.debugImages {
                for (key, image) in debugImages {
                    items.append(image)
                }
            }
            
            // Add API results text
            let text = generateShareText(for: photo)
            items.append(text)
            
            shareSheet = ShareSheet(activityItems: items)
            showingShareSheet = true
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Photos & Results")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private func deleteButton(_ photo: CapturedPhoto) -> some View {
        Button(action: {
            photoToDelete = photo.id
            showingDeleteAlert = true
        }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                        ForEach(cameraManager.capturedPhotos) { photo in
                            photoCard(photo)
                                .overlay(
                                    deleteButton(photo)
                                        .padding(8),
                                    alignment: .topTrailing
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Saved Photos")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let shareSheet = shareSheet {
                    shareSheet
                }
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    photoToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let id = photoToDelete {
                        cameraManager.deletePhoto(with: id)
                    }
                    photoToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
            .fullScreenCover(item: $editingPhotoId) { editingId in
                if let photo = cameraManager.capturedPhotos.first(where: { $0.id == editingId.id }) {
                    FullScreenCornerEditor(
                        photo: photo,
                        corners: $fullscreenCorners,
                        onDone: {
                            // Save corners back to photo
                            if let index = cameraManager.capturedPhotos.firstIndex(where: { $0.id == editingId.id }) {
                                cameraManager.capturedPhotos[index].manualCorners = fullscreenCorners
                            }
                            editingPhotoId = nil
                        },
                        onSendToAPI: { correctedCorners in
                            sendCorrectedCornersToAPI(photo: photo, corners: correctedCorners)
                        },
                        onSaveGreyedImage: { image in
                            saveBlurredImageToPhotos(image)
                        }
                    )
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
                    
                    // Log debug images information
                    if let debugImages = positionResponse.debug_images {
                        logMessage += ", Debug Images: \(debugImages.count) images (\(debugImages.keys.sorted().joined(separator: ", ")))"
                    }
                } else if endpoint == "recognize_chess_position_with_cursor_description" {
                    let positionResponse = try JSONDecoder().decode(ChessPositionDescriptionResponse.self, from: response)
                    logMessage += "FEN: \(positionResponse.fen), Legal: \(positionResponse.hasChessBoard)"
                    
                    // Log description if available
                    if let description = positionResponse.description {
                        logMessage += ", Description: \(description)"
                    }
                    
                    // Log debug images information
                    if let debugImages = positionResponse.debug_images {
                        logMessage += ", Debug Images: \(debugImages.count) images (\(debugImages.keys.sorted().joined(separator: ", ")))"
                    }
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
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { (context) in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func createBlurredImageWithChessboardFocus(corners: [CGPoint]) -> UIImage? {
        guard corners.count == 4 else { return nil }
        
        print("🔍 Creating blurred image with corners: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
        print("🔍 Image size: \(self.size)")
        
        let renderer = UIGraphicsImageRenderer(size: self.size)
        return renderer.image { context in
            // Draw the original image
            self.draw(in: CGRect(origin: .zero, size: self.size))
            
            // Manual corners are already in normalized UIKit coordinates (0-1, origin top-left)
            // No coordinate conversion needed
            print("🔍 Using corners directly: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
            
            // Create a path for the chessboard area
            let path = UIBezierPath()
            path.move(to: CGPoint(x: corners[0].x * self.size.width, y: corners[0].y * self.size.height))
            path.addLine(to: CGPoint(x: corners[1].x * self.size.width, y: corners[1].y * self.size.height))
            path.addLine(to: CGPoint(x: corners[2].x * self.size.width, y: corners[2].y * self.size.height))
            path.addLine(to: CGPoint(x: corners[3].x * self.size.width, y: corners[3].y * self.size.height))
            path.close()
            
            // Save the current graphics state
            context.cgContext.saveGState()
            
            // Clip to the chessboard area (invert the path)
            let clipPath = UIBezierPath(rect: CGRect(origin: .zero, size: self.size))
            clipPath.append(path)
            clipPath.usesEvenOddFillRule = true
            clipPath.addClip()
            
            // Create a greyed-out overlay for the area outside the chessboard
            let greyOverlay = UIColor.black.withAlphaComponent(0.6)
            greyOverlay.setFill()
            
            // Fill the area outside the chessboard with grey overlay
            let fullRect = CGRect(origin: .zero, size: self.size)
            context.fill(fullRect)
            
            // Restore the graphics state
            context.cgContext.restoreGState()
            
            // No border drawing - clean image without any lines
        }
    }
    
    func fixOrientation() -> UIImage {
        // If the image is already in the correct orientation, return it
        if self.imageOrientation == .up {
            return self
        }
        
        // Create a graphics context with the correct orientation
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        
        // Draw the image in the correct orientation
        self.draw(in: CGRect(origin: .zero, size: self.size))
        
        // Get the normalized image
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
    
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

// Interactive Corner Overlay for manual adjustment
struct InteractiveCornerOverlayView: View {
    @Binding var corners: [CGPoint]
    let imageSize: CGSize
    let onCornersUpdated: ([CGPoint]) -> Void
    let cameraManager: CameraManager
    let onSaveGreyedImage: (UIImage) -> Void
    @State private var isEditing = false
    @State private var selectedCornerIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw lines between corners
                Path { path in
                    guard corners.count == 4 else { return }

                    let viewWidth = geometry.size.width
                    let viewHeight = geometry.size.height
                    
                    // Calculate scaling to fit the image in the view
                    let scaleX = viewWidth / imageSize.width
                    let scaleY = viewHeight / imageSize.height
                    let scale = min(scaleX, scaleY) // Use min to maintain aspect ratio
                    
                    // Calculate the scaled image dimensions
                    let scaledImageWidth = imageSize.width * scale
                    let scaledImageHeight = imageSize.height * scale
                    
                    // Calculate offsets to center the image
                    let xOffset = (viewWidth - scaledImageWidth) / 2.0
                    let yOffset = (viewHeight - scaledImageHeight) / 2.0

                    let transformedCorners = corners.map { corner in
                        // The corners are normalized (0-1), so we need to scale them to the actual image size first
                        let imageCornerX = corner.x * imageSize.width
                        let imageCornerY = corner.y * imageSize.height
                        
                        // Transform the corner coordinates
                        let transformedX = imageCornerX * scale + xOffset
                        let transformedY = imageCornerY * scale + yOffset
                        
                        return CGPoint(x: transformedX, y: transformedY)
                    }

                    path.move(to: transformedCorners[0])
                    path.addLine(to: transformedCorners[1])
                    path.addLine(to: transformedCorners[2])
                    path.addLine(to: transformedCorners[3])
                    path.closeSubpath()
                }
                .stroke(isEditing ? Color.blue : Color.red, lineWidth: isEditing ? 3 : 2)

                // Draw interactive corner dots
                ForEach(0..<corners.count, id: \.self) { index in
                    InteractiveCornerDotView(
                        corner: $corners[index],
                        index: index,
                        geometry: geometry,
                        imageSize: imageSize,
                        isEditing: $isEditing,
                        selectedCornerIndex: $selectedCornerIndex,
                        onCornerMoved: { updatedCorners in
                            onCornersUpdated(updatedCorners)
                        }
                    )
                }
                
                // Edit mode controls
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Button(action: {
                                isEditing.toggle()
                                if !isEditing {
                                    selectedCornerIndex = nil
                                }
                            }) {
                                HStack {
                                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                                    Text(isEditing ? "Done" : "Edit")
                                }
                                .font(.caption)
                                .padding(8)
                                .background(isEditing ? Color.green : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            if isEditing {
                                Button(action: {
                                    // Send corrected corners to API
                                    onCornersUpdated(corners)
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text("Send to API")
                                    }
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    // Generate and save greyed-out image
                                    if let photo = cameraManager.capturedPhotos.first(where: { photo in
                                        photo.debugImages?.keys.contains("corners") == true
                                    }) {
                                        let greyedImage = photo.image.createBlurredImageWithChessboardFocus(corners: corners)
                                        if let greyedImage = greyedImage {
                                            onSaveGreyedImage(greyedImage)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save Greyed")
                                    }
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}

struct InteractiveCornerDotView: View {
    @Binding var corner: CGPoint
    let index: Int
    let geometry: GeometryProxy
    let imageSize: CGSize
    @Binding var isEditing: Bool
    @Binding var selectedCornerIndex: Int?
    let onCornerMoved: ([CGPoint]) -> Void
    
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
    
    private func updateCornerPosition(_ newPosition: CGPoint) {
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
        
        // Convert back to normalized coordinates
        let normalizedX = (newPosition.x - xOffset) / scaleX
        let normalizedY = (newPosition.y - yOffset) / scaleY
        
        // Clamp to image bounds
        let clampedX = max(0, min(1, normalizedX))
        let clampedY = max(0, min(1, normalizedY))
        
        corner = CGPoint(x: clampedX, y: clampedY)
    }
    
    var body: some View {
        ZStack {
            // Corner dot
            Circle()
                .fill(selectedCornerIndex == index ? Color.yellow : (isEditing ? Color.blue : Color.red))
                .frame(width: isEditing ? 20 : 12, height: isEditing ? 20 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(transformedCorner)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isEditing {
                                selectedCornerIndex = index
                                updateCornerPosition(value.location)
                            }
                        }
                        .onEnded { _ in
                            if isEditing {
                                selectedCornerIndex = nil
                            }
                        }
                )
            
            // Corner label (only in edit mode)
            if isEditing {
                Text("\(index + 1)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
                    .position(
                        x: transformedCorner.x,
                        y: transformedCorner.y - 25
                    )
            }
        }
    }
}

// Simplified corner overlay for debug image editing
struct DebugImageCornerOverlayView: View {
    @Binding var corners: [CGPoint]
    let imageSize: CGSize
    let onCornersUpdated: ([CGPoint]) -> Void
    @State private var selectedCornerIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Add a semi-transparent background to make the overlay visible
                Color.red.opacity(0.1)
                    .allowsHitTesting(false)
                
                // Draw lines between corners
                Path { path in
                    guard corners.count == 4 else { 
                        return 
                    }

                    let viewWidth = geometry.size.width
                    let viewHeight = geometry.size.height
                    
                    // Calculate scaling to fit the image in the view
                    let scaleX = viewWidth / imageSize.width
                    let scaleY = viewHeight / imageSize.height
                    let scale = min(scaleX, scaleY) // Use min to maintain aspect ratio
                    
                    // Calculate the scaled image dimensions
                    let scaledImageWidth = imageSize.width * scale
                    let scaledImageHeight = imageSize.height * scale
                    
                    // Calculate offsets to center the image
                    let xOffset = (viewWidth - scaledImageWidth) / 2.0
                    let yOffset = (viewHeight - scaledImageHeight) / 2.0

                    let transformedCorners = corners.map { corner in
                        // The corners are normalized (0-1), so we need to scale them to the actual image size first
                        let imageCornerX = corner.x * imageSize.width
                        let imageCornerY = corner.y * imageSize.height
                        
                        // Transform the corner coordinates
                        let transformedX = imageCornerX * scale + xOffset
                        let transformedY = imageCornerY * scale + yOffset
                        
                        return CGPoint(x: transformedX, y: transformedY)
                    }

                    path.move(to: transformedCorners[0])
                    path.addLine(to: transformedCorners[1])
                    path.addLine(to: transformedCorners[2])
                    path.addLine(to: transformedCorners[3])
                    path.closeSubpath()
                }
                .stroke(Color.blue, lineWidth: 3)

                // Draw interactive corner dots
                ForEach(0..<corners.count, id: \.self) { index in
                    DebugImageCornerDotView(
                        corner: $corners[index],
                        index: index,
                        geometry: geometry,
                        imageSize: imageSize,
                        selectedCornerIndex: $selectedCornerIndex,
                        onCornerMoved: { updatedCorners in
                            print("🔍 Corner moved, updating to: \(updatedCorners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
                            onCornersUpdated(updatedCorners)
                        }
                    )
                }
            }
        }
        .onAppear {
            print("🔍 DebugImageCornerOverlayView appeared with \(corners.count) corners")
            print("🔍 Image size: \(imageSize)")
            
            // Calculate and show transformed corner positions using the same logic as the view
            let viewWidth: CGFloat = 400 // Approximate view width for debugging
            let viewHeight: CGFloat = 600 // Approximate view height for debugging
            
            // Calculate scaling to fit the image in the view
            let scaleX = viewWidth / imageSize.width
            let scaleY = viewHeight / imageSize.height
            let scale = min(scaleX, scaleY) // Use min to maintain aspect ratio
            
            // Calculate the scaled image dimensions
            let scaledImageWidth = imageSize.width * scale
            let scaledImageHeight = imageSize.height * scale
            
            // Calculate offsets to center the image
            let xOffset = (viewWidth - scaledImageWidth) / 2.0
            let yOffset = (viewHeight - scaledImageHeight) / 2.0

            for (index, corner) in corners.enumerated() {
                // The corners are normalized (0-1), so we need to scale them to the actual image size first
                let imageCornerX = corner.x * imageSize.width
                let imageCornerY = corner.y * imageSize.height
                
                // Transform the corner coordinates
                let transformedX = imageCornerX * scale + xOffset
                let transformedY = imageCornerY * scale + yOffset
                
                let transformedCorner = CGPoint(x: transformedX, y: transformedY)
                print("🔍 Corner \(index + 1) original: (\(corner.x), \(corner.y)) -> transformed: (\(transformedCorner.x), \(transformedCorner.y))")
            }
        }
        .onChange(of: corners) { newCorners in
            print("🔍 Corners changed to: \(newCorners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
        }
    }
}

struct DebugImageCornerDotView: View {
    @Binding var corner: CGPoint
    let index: Int
    let geometry: GeometryProxy
    let imageSize: CGSize
    @Binding var selectedCornerIndex: Int?
    let onCornerMoved: ([CGPoint]) -> Void
    
    private var transformedCorner: CGPoint {
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height
        
        // The corners are normalized (0-1), so we need to scale them to the actual image size first
        let imageCornerX = corner.x * imageSize.width
        let imageCornerY = corner.y * imageSize.height
        
        // Calculate scaling to fit the image in the view
        let scaleX = viewWidth / imageSize.width
        let scaleY = viewHeight / imageSize.height
        let scale = min(scaleX, scaleY) // Use min to maintain aspect ratio
        
        // Calculate the scaled image dimensions
        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale
        
        // Calculate offsets to center the image
        let xOffset = (viewWidth - scaledImageWidth) / 2.0
        let yOffset = (viewHeight - scaledImageHeight) / 2.0
        
        // Transform the corner coordinates
        let transformedX = imageCornerX * scale + xOffset
        let transformedY = imageCornerY * scale + yOffset
        
        return CGPoint(x: transformedX, y: transformedY)
    }
    
    private func updateCornerPosition(_ newPosition: CGPoint) {
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height
        
        // Calculate scaling to fit the image in the view
        let scaleX = viewWidth / imageSize.width
        let scaleY = viewHeight / imageSize.height
        let scale = min(scaleX, scaleY) // Use min to maintain aspect ratio
        
        // Calculate the scaled image dimensions
        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale
        
        // Calculate offsets to center the image
        let xOffset = (viewWidth - scaledImageWidth) / 2.0
        let yOffset = (viewHeight - scaledImageHeight) / 2.0
        
        // Convert back to image coordinates
        let imageX = (newPosition.x - xOffset) / scale
        let imageY = (newPosition.y - yOffset) / scale
        
        // Convert to normalized coordinates (0-1)
        let normalizedX = imageX / imageSize.width
        let normalizedY = imageY / imageSize.height
        
        // Clamp to image bounds
        let clampedX = max(0, min(1, normalizedX))
        let clampedY = max(0, min(1, normalizedY))
        
        corner = CGPoint(x: clampedX, y: clampedY)
    }
    
    var body: some View {
        ZStack {
            // Corner dot
            Circle()
                .fill(selectedCornerIndex == index ? Color.yellow : Color.blue)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(transformedCorner)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            print("🔍 Corner \(index + 1) drag started at: \(value.location)")
                            selectedCornerIndex = index
                            updateCornerPosition(value.location)
                        }
                        .onEnded { _ in
                            print("🔍 Corner \(index + 1) drag ended")
                            selectedCornerIndex = nil
                        }
                )
            
            // Corner label (always visible)
            Text("\(index + 1)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(2)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
                .position(
                    x: transformedCorner.x,
                    y: transformedCorner.y - 25
                )
        }
        .onAppear {
            print("🔍 DebugImageCornerDotView appeared for corner \(index + 1) at position: \(transformedCorner)")
            print("🔍 Corner \(index + 1) original coordinates: (\(corner.x), \(corner.y))")
            print("🔍 Corner \(index + 1) transformed coordinates: (\(transformedCorner.x), \(transformedCorner.y))")
        }
    }
}

// Add a new view for full screen corner editing
struct FullScreenCornerEditor: View {
    let photo: CapturedPhoto
    @Binding var corners: [CGPoint]
    let onDone: () -> Void
    let onSendToAPI: ([CGPoint]) -> Void
    let onSaveGreyedImage: (UIImage) -> Void
    @State private var isEditing = true
    @State private var selectedCornerIndex: Int? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDone) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                Spacer()
                ZStack {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    GeometryReader { geometry in
                        ZStack {
                            // Draw lines between corners
                            Path { path in
                                guard corners.count == 4 else { return }
                                let viewWidth = geometry.size.width
                                let viewHeight = geometry.size.height
                                let scaleX = viewWidth / photo.image.size.width
                                let scaleY = viewHeight / photo.image.size.height
                                let scale = min(scaleX, scaleY)
                                let scaledImageWidth = photo.image.size.width * scale
                                let scaledImageHeight = photo.image.size.height * scale
                                let xOffset = (viewWidth - scaledImageWidth) / 2.0
                                let yOffset = (viewHeight - scaledImageHeight) / 2.0
                                let transformedCorners = corners.map { corner in
                                    let imageCornerX = corner.x * photo.image.size.width
                                    let imageCornerY = corner.y * photo.image.size.height
                                    let transformedX = imageCornerX * scale + xOffset
                                    let transformedY = imageCornerY * scale + yOffset
                                    return CGPoint(x: transformedX, y: transformedY)
                                }
                                path.move(to: transformedCorners[0])
                                path.addLine(to: transformedCorners[1])
                                path.addLine(to: transformedCorners[2])
                                path.addLine(to: transformedCorners[3])
                                path.closeSubpath()
                            }
                            .stroke(Color.blue, lineWidth: 3)
                            // Draw interactive corner dots
                            ForEach(0..<corners.count, id: \ .self) { index in
                                FullScreenCornerDotView(
                                    corner: $corners[index],
                                    index: index,
                                    geometry: geometry,
                                    imageSize: photo.image.size,
                                    isEditing: $isEditing,
                                    selectedCornerIndex: $selectedCornerIndex
                                )
                            }
                        }
                    }
                }
                .aspectRatio(photo.image.size, contentMode: .fit)
                .padding()
                Spacer()
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button(action: {
                            onSendToAPI(corners)
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Send to API")
                            }
                            .font(.headline)
                            .padding(12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        Button(action: {
                            if let greyedImage = photo.image.createBlurredImageWithChessboardFocus(corners: corners) {
                                onSaveGreyedImage(greyedImage)
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Greyed")
                            }
                            .font(.headline)
                            .padding(12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        // In FullScreenCornerEditor, add a debug button to save the exact API image
                        Button(action: {
                            // Save the exact image sent to the API (normalized, greyed)
                            let normalizedImage = photo.image.fixOrientation()
                            if let apiGreyedImage = normalizedImage.createBlurredImageWithChessboardFocus(corners: corners) {
                                onSaveGreyedImage(apiGreyedImage)
                            }
                        }) {
                            HStack {
                                Image(systemName: "ladybug")
                                Text("Save API Image (Debug)")
                            }
                            .font(.headline)
                            .padding(12)
                            .background(Color.pink)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    Text("Drag the corners to adjust. Tap 'Send to API' to update recognition.")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding(.bottom, 32)
            }
        }
    }
}

struct FullScreenCornerDotView: View {
    @Binding var corner: CGPoint
    let index: Int
    let geometry: GeometryProxy
    let imageSize: CGSize
    @Binding var isEditing: Bool
    @Binding var selectedCornerIndex: Int?

    private var transformedCorner: CGPoint {
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height
        let scaleX = viewWidth / imageSize.width
        let scaleY = viewHeight / imageSize.height
        let scale = min(scaleX, scaleY)
        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale
        let xOffset = (viewWidth - scaledImageWidth) / 2.0
        let yOffset = (viewHeight - scaledImageHeight) / 2.0
        let imageCornerX = corner.x * imageSize.width
        let imageCornerY = corner.y * imageSize.height
        let transformedX = imageCornerX * scale + xOffset
        let transformedY = imageCornerY * scale + yOffset
        return CGPoint(x: transformedX, y: transformedY)
    }

    private func updateCornerPosition(_ newPosition: CGPoint) {
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height
        let scaleX = viewWidth / imageSize.width
        let scaleY = viewHeight / imageSize.height
        let scale = min(scaleX, scaleY)
        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale
        let xOffset = (viewWidth - scaledImageWidth) / 2.0
        let yOffset = (viewHeight - scaledImageHeight) / 2.0
        let imageX = (newPosition.x - xOffset) / scale
        let imageY = (newPosition.y - yOffset) / scale
        let normalizedX = imageX / imageSize.width
        let normalizedY = imageY / imageSize.height
        let clampedX = max(0, min(1, normalizedX))
        let clampedY = max(0, min(1, normalizedY))
        corner = CGPoint(x: clampedX, y: clampedY)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(selectedCornerIndex == index ? Color.yellow : (isEditing ? Color.blue : Color.red))
                .frame(width: isEditing ? 32 : 20, height: isEditing ? 32 : 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .position(transformedCorner)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isEditing {
                                selectedCornerIndex = index
                                updateCornerPosition(value.location)
                            }
                        }
                        .onEnded { _ in
                            if isEditing {
                                selectedCornerIndex = nil
                            }
                        }
                )
            Text(cornerLabel(for: index))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
                .position(x: transformedCorner.x, y: transformedCorner.y - 36)
        }
    }
}

// Minimal fallback struct for just FEN
struct MinimalFENResponse: Codable {
    let fen: String
}

// Helper for chessboard corner labels
func cornerLabel(for index: Int) -> String {
    switch index {
    case 0: return "a8" // top-left
    case 1: return "h8" // top-right
    case 2: return "h1" // bottom-right
    case 3: return "a1" // bottom-left
    default: return ""
    }
}


