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

// Simple API Response Types
struct ChessPositionResponse: Codable {
    let fen: String
    let hasChessBoard: Bool?
    let error: String?
    let message: String?
    let lichess_url: String?
    let ascii: String?
    let legal_position: Bool?
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

struct DetectCornersResponse: Codable {
    let corners: [[Double]]
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
            CameraView(cameraManager: cameraManager, selectedTab: $selectedTab)
        .onAppear {
            // Customize tab bar appearance for better visibility
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            // Add a subtle border to the tab bar
            appearance.shadowColor = UIColor.systemGray4
            appearance.shadowImage = UIImage()
            
            // Make tab bar background slightly transparent with border
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            
            // Apply the appearance
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

struct CameraView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var selectedTab: Int
    @State private var editorFEN: String? = nil
    @State private var editingPhotoForEditor: UUID? = nil
    @State private var editingPhotoId: EditingPhotoID? = nil
    @State private var fullscreenCorners: [CGPoint] = []
    @State private var isDetectingCorners = false
    @State private var lastPhotoCount = 0
    
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
            cameraManager.selectedTabBinding = $selectedTab
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .fullScreenCover(item: Binding(
            get: { editorFEN.map { FENWrapper(fen: $0) } },
            set: { editorFEN = $0?.fen }
        )) { fenWrapper in
            ChessboardView(fen: fenWrapper.fen, startInEditor: true) { editedFEN in
                // Save the edited FEN back to the photo if we have one
                if let photoId = editingPhotoForEditor {
                    cameraManager.updatePhotoFEN(with: photoId, newFEN: editedFEN)
                    print("✅ Saved edited FEN to photo: \(editedFEN)")
                }
                // Clear the editor state
                editingPhotoForEditor = nil
                editorFEN = nil
            }
        }
        .fullScreenCover(item: $editingPhotoId) { editingId in
            if let photo = cameraManager.capturedPhotos.first(where: { $0.id == editingId.id }) {
                FullScreenCornerEditor(
                    photo: photo,
                    corners: $fullscreenCorners,
                    isDetectingCorners: isDetectingCorners,
                    cameraManager: cameraManager,
                    onDone: {
                        editingPhotoId = nil
                        isDetectingCorners = false
                    },
                    onSendToAPI: { corners in
                        Task {
                            await cameraManager.sendCorrectedCornersToAPI(for: photo.id, corners: corners)
                            
                            // After API call completes, open board editor if we have a FEN
                            await MainActor.run {
                                if let updatedPhoto = cameraManager.capturedPhotos.first(where: { $0.id == photo.id }),
                                   let fen = updatedPhoto.positionResult?.fen {
                                    print("📋 Setting editorFEN to: \(fen)")
                                    print("📋 Closing corner editor...")
                                    self.editingPhotoId = nil
                                    self.isDetectingCorners = false
                                    print("📋 Opening board editor...")
                                    self.editingPhotoForEditor = photo.id  // Track which photo we're editing
                                    self.editorFEN = fen  // This triggers the fullScreenCover
                                } else {
                                    print("❌ No FEN found in updated photo")
                                    self.editingPhotoId = nil
                                    self.isDetectingCorners = false
                                    // Open board editor with starting position if no FEN
                                    self.editingPhotoForEditor = photo.id
                                    self.editorFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
                                }
                            }
                        }
                    },
                    onSaveGreyedImage: { greyedImage in
                        // Save greyed image to photos if needed
                        UIImageWriteToSavedPhotosAlbum(greyedImage, nil, nil, nil)
                    }
                )
            }
        }
        .onChange(of: cameraManager.capturedPhotos.count) { _, newCount in
            // When a new photo is captured, automatically open corner selector
            if newCount > lastPhotoCount && newCount > 0 {
                let latestPhoto = cameraManager.capturedPhotos.first!
                editingPhotoId = EditingPhotoID(id: latestPhoto.id)
                isDetectingCorners = true
                fullscreenCorners = [
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: 1, y: 0),
                    CGPoint(x: 1, y: 1),
                    CGPoint(x: 0, y: 1)
                ]
                lastPhotoCount = newCount
            }
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















class DebugLogger {
    func log(_ message: String) {
        print("🔍 \(message)")
    }
}

class LocalChessService {
    private let recognizeURL = "http://159.203.102.249:8010/recognize_chess_position_with_corners"
    private let detectCornersURL = "http://159.203.102.249:8011/detect_corners"
    private let debugLogger = DebugLogger()
    
    func recognizePositionWithCorners(imageData: Data, corners: [CGPoint]) async throws -> (ChessPositionResponse?, String?, [String: UIImage]?) {
        guard let url = URL(string: recognizeURL) else {
            debugLogger.log("Invalid URL for recognize_chess_position_with_corners")
            throw URLError(.badURL)
        }
        
        let (body, boundary) = createMultipartFormDataWithCorners(imageData: imageData, corners: corners)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30.0 // 30 second timeout
        
        debugLogger.log("Making recognize_chess_position_with_corners API call with \(imageData.count) bytes and manual corners")
        debugLogger.log("Manual corners: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
        debugLogger.log("Target URL: \(recognizeURL)")
        
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
                return (nil, "Server returned status code \(httpResponse.statusCode): \(errorMessage)", nil)
            }
            
            do {
                let result = try JSONDecoder().decode(ChessPositionResponse.self, from: data)
                debugLogger.log("Successfully decoded recognize_chess_position_with_corners response")
                return (result, nil, nil)
            } catch {
                debugLogger.log("Error decoding response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLogger.log("Failed to decode response: \(responseString)")
                }
                return (nil, "Failed to decode response: \(error.localizedDescription)", nil)
            }
        } catch {
            debugLogger.log("Error in recognize_chess_position_with_corners: \(error.localizedDescription)")
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
        // API expects JSON array format: [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
        // Convert normalized coordinates (0-1) to actual pixel coordinates
        // Corner order: Top-left, top-right, bottom-right, bottom-left (clockwise)
        // Get image dimensions from the image data
        let image = UIImage(data: imageData)
        let imageWidth = image?.size.width ?? 1080.0
        let imageHeight = image?.size.height ?? 1920.0
        
        let pixelCorners = corners.map { CGPoint(x: $0.x * imageWidth, y: $0.y * imageHeight) }
        let cornersString = "[\(pixelCorners.map { "[\(Int($0.x)), \(Int($0.y))]" }.joined(separator: ", "))]"
        
        debugLogger.log("Image dimensions: \(imageWidth) x \(imageHeight) pixels")
        debugLogger.log("Normalized corners: \(corners.map { "(\($0.x), \($0.y))" })")
        debugLogger.log("Pixel corners: \(pixelCorners.map { "(\(Int($0.x)), \(Int($0.y)))" })")
        debugLogger.log("Formatted corners string: '\(cornersString)'")
        debugLogger.log("Expected API format: [[x1, y1], [x2, y2], [x3, y3], [x4, y4]] (pixel coordinates)")
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"corners\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cornersString)\r\n".data(using: .utf8)!)
        
        // Add debug parameters as specified by the API
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"debug_image_width\"\r\n\r\n".data(using: .utf8)!)
        body.append("800\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"debug_image_height\"\r\n\r\n".data(using: .utf8)!)
        body.append("600\r\n".data(using: .utf8)!)
        
        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Debug: Log the request body for troubleshooting
        if let bodyString = String(data: body, encoding: .utf8) {
            debugLogger.log("Request body preview: \(String(bodyString.prefix(500)))")
        }
        
        // Log the complete request structure for API debugging
        debugLogger.log("API Request Structure:")
        debugLogger.log("- image: JPEG file (\(imageData.count) bytes)")
        debugLogger.log("- color: white")
        debugLogger.log("- corners: \(cornersString) (JSON array)")
        debugLogger.log("- debug_image_width: 800")
        debugLogger.log("- debug_image_height: 600")
        
        return (body, boundary)
    }
    
    func detectCorners(imageData: Data) async throws -> [CGPoint] {
        guard let url = URL(string: detectCornersURL) else {
            debugLogger.log("Invalid URL for detect_corners")
                throw URLError(.badURL)
            }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = NSMutableData()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body as Data
        
        debugLogger.log("Making detect_corners API call with \(imageData.count) bytes")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            debugLogger.log("Detect corners API Response Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Parse the corners response
                if let cornersResponse = try? JSONDecoder().decode(DetectCornersResponse.self, from: data) {
                    debugLogger.log("Successfully detected corners: \(cornersResponse.corners)")
                    // Convert pixel coordinates to normalized coordinates (0-1)
                    // Assuming the API returns pixel coordinates, we need image dimensions
                    let image = UIImage(data: imageData)
                    let imageWidth = image?.size.width ?? 1080.0
                    let imageHeight = image?.size.height ?? 1920.0
                    
                    return cornersResponse.corners.map { cornerArray in
                        CGPoint(x: cornerArray[0] / imageWidth, y: cornerArray[1] / imageHeight)
                    }
                                } else {
                    debugLogger.log("Failed to decode corners response")
                    throw URLError(.cannotParseResponse)
                }
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.log("Detect corners API Error: \(errorString)")
                throw URLError(.badServerResponse)
            }
        }
        
        throw URLError(.badServerResponse)
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
    var selectedTabBinding: Binding<Int>?
    
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
    
    func updatePhotoFEN(with id: UUID, newFEN: String) {
        if let index = capturedPhotos.firstIndex(where: { $0.id == id }) {
            capturedPhotos[index].positionResult?.fen = newFEN
            print("📝 Updated FEN for photo \(id): \(newFEN)")
        }
    }
    
    func detectInitialCorners(for photo: CapturedPhoto) async -> [CGPoint] {
        guard let imageData = photo.image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG data")
            // Return default corners if image conversion fails
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1)
            ]
        }
        
        do {
            let detectedCorners = try await localChessService.detectCorners(imageData: imageData)
            print("🎯 Detected initial corners: \(detectedCorners)")
            return detectedCorners
        } catch {
            print("❌ Failed to detect corners: \(error.localizedDescription)")
            // Return default corners if detection fails
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1)
            ]
        }
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
            
            // Create greyed image with chessboard focus for API (on background thread)
            let imageData = await Task.detached(priority: .userInitiated) {
            let normalizedImage = photo.image.fixOrientation()
            let greyedImage = normalizedImage.createBlurredImageWithChessboardFocus(corners: corners)
                return greyedImage?.jpegData(compressionQuality: 0.80) ?? Data()
            }.value
            print("🔄 Sending corrected corners to API: \(corners.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
            
            // Use the simplified LocalChessService
            let response = try await localChessService.recognizePositionWithCorners(imageData: imageData, corners: corners)
            
            await MainActor.run {
                // Clear processing state
                self.capturedPhotos[photoIndex].isSendingCornersToAPI = false
                
                // Update manual corners
                self.capturedPhotos[photoIndex].manualCorners = corners
                
                // Update position result with simplified format
                if let result = response.0 {
                    self.capturedPhotos[photoIndex].positionResult = CapturedPhoto.PositionResult(
                        fen: result.fen
                    )
                    
                    print("✅ Successfully analyzed position!")
                    print("🔍 FEN: \(result.fen)")
                    
                    // Clear any previous errors
                    self.capturedPhotos[photoIndex].apiErrors = CapturedPhoto.APIErrors(
                        positionError: nil,
                        cornersError: nil
                    )
                } else {
                    // Handle error
                    self.capturedPhotos[photoIndex].apiErrors = CapturedPhoto.APIErrors(
                        positionError: response.1 ?? "Unknown error",
                        cornersError: nil
                    )
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
                
                // No API calls here - just store the photo and let user manually adjust corners
                    if let index = self.capturedPhotos.firstIndex(where: { $0.id == capturedPhoto.id }) {
                    // Set default corners for manual adjustment
                    self.capturedPhotos[index].manualCorners = [
                        CGPoint(x: 0.1, y: 0.1),   // Top-left
                        CGPoint(x: 0.9, y: 0.1),   // Top-right
                        CGPoint(x: 0.9, y: 0.9),   // Bottom-right
                        CGPoint(x: 0.1, y: 0.9)    // Bottom-left
                    ]
                    
                    // Mark as not processing
                        self.capturedPhotos[index].isProcessing = false
                    
                    print("📸 Photo captured and stored. User can now manually adjust corners and press Analyze Position.")
                    
                    // Automatically switch to Photos tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.selectedTabBinding?.wrappedValue = 1
                        print("🔄 Automatically switched to Photos tab")
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
    var manualCorners: [CGPoint]? // Manual corner adjustments
    var isSendingCornersToAPI: Bool = false // Track if corners are being sent to API
    
    struct PositionResult {
        var fen: String  // Changed to var so it can be updated after editing
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

// Helper struct to wrap FEN for Identifiable conformance
struct FENWrapper: Identifiable {
    let id = UUID()
    let fen: String
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
                                        false
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
                .opacity(0.6)
                .frame(width: isEditing ? 20 : 12, height: isEditing ? 20 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
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
    let isDetectingCorners: Bool
    @ObservedObject var cameraManager: CameraManager
    let onDone: () -> Void
    let onSendToAPI: ([CGPoint]) -> Void
    let onSaveGreyedImage: (UIImage) -> Void
    @State private var isEditing = true
    @State private var selectedCornerIndex: Int? = nil
    @State private var isProcessing = false
    @State private var hasAnimated = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Full screen image background
            Color.black.ignoresSafeArea()
            
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFit()
                .ignoresSafeArea()
            
            // Corner detection overlay (full screen)
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
                    ForEach(0..<corners.count, id: \.self) { index in
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
            
            // Loading overlay (fullscreen when active)
                    if isDetectingCorners {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                        
                VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Detecting corners...")
                                .font(.title3)
                                .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
            }
            
            // Floating UI elements
            VStack {
                // Top: Swipe indicator (pull to dismiss)
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.6))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 0)
                
                Spacer()
                
                // Bottom: Instructions and button
                VStack(spacing: 14) {
                    // Instructional text with glass morphism effect
                    VStack(spacing: 8) {
                        Text("Manually adjust the board corners as necessary")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Board corners should be inside the algebraic notation around the chess board right on the a1, a8, h1, h8 corners")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 20)
                    
                    // Large Open in Lichess button with glass effect
                    Button(action: {
                        isProcessing = true
                        onSendToAPI(corners)
                    }) {
                        HStack(spacing: 10) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Processing...")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "square.grid.3x3.fill")
                                    .font(.title3)
                                Text("Analyze Position")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.5), radius: 16, x: 0, y: 8)
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // Only allow downward dragging
                    if gesture.translation.height > 0 {
                        dragOffset = gesture.translation.height
                    }
                }
                .onEnded { gesture in
                    // Swipe down to dismiss
                    if gesture.translation.height > 150 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = 1000 // Slide off screen
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDone()
                        }
                    } else {
                        // Spring back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            print("🖼️ FullScreenCornerEditor appeared")
            print("🖼️ Initial corners: \(corners)")
            print("🖼️ Is detecting corners: \(isDetectingCorners)")
            
            // Start corner detection if needed
            if isDetectingCorners {
                Task {
                    let detectedCorners = await cameraManager.detectInitialCorners(for: photo)
                    await MainActor.run {
                        print("🎯 Corner detection completed: \(detectedCorners)")
                        corners = detectedCorners
                        isDetectingCorners = false
                        
                        // Animate corners to their detected positions
                        if !hasAnimated && corners.count == 4 {
                            let targetCorners = corners
                            // Start with corners in center
                            corners = [
                                CGPoint(x: 0.5, y: 0.5),
                                CGPoint(x: 0.5, y: 0.5),
                                CGPoint(x: 0.5, y: 0.5),
                                CGPoint(x: 0.5, y: 0.5)
                            ]
                            
                            // Animate to detected positions
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                corners = targetCorners
                            }
                            hasAnimated = true
                        }
                    }
                }
            } else if !hasAnimated && corners.count == 4 {
                // Animate corners to their detected positions
                let targetCorners = corners
                // Start with corners in center
                corners = [
                    CGPoint(x: 0.5, y: 0.5),
                    CGPoint(x: 0.5, y: 0.5),
                    CGPoint(x: 0.5, y: 0.5),
                    CGPoint(x: 0.5, y: 0.5)
                ]
                
                // Animate to detected positions
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    corners = targetCorners
                }
                hasAnimated = true
            }
        }
        .onChange(of: corners) { _, newCorners in
            print("🖼️ Corners changed to: \(newCorners)")
        }
        .onChange(of: isDetectingCorners) { _, newValue in
            print("🖼️ isDetectingCorners changed to: \(newValue)")
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
            // Main corner dot with glass effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: selectedCornerIndex == index ? 
                            [Color.yellow.opacity(0.9), Color.orange.opacity(0.7)] :
                            [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: selectedCornerIndex == index ? 40 : 36, height: selectedCornerIndex == index ? 40 : 36)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(3)
                )
                .shadow(color: (selectedCornerIndex == index ? Color.yellow : Color.blue).opacity(0.6), radius: 12, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                .position(transformedCorner)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedCornerIndex == index)
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
            
            // Corner label with glass effect
            Text(cornerLabel(for: index))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                .position(x: transformedCorner.x, y: transformedCorner.y - 40)
        }
    }
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


