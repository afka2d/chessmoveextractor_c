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

struct RecordedGame: Identifiable {
    let id = UUID()
    let url: URL
    let creationDate: Date
    let hasChessBoard: Bool
    let confidence: Double
    let corners: [CGPoint]? // Normalized corners for this recording
}

struct ContentView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "video.fill")
                }
            
            RecordedGamesView()
                .tabItem {
                    Label("Games", systemImage: "list.bullet")
                }
        }
    }
}

struct ChessBoardOverlayView: View {
    let fen: String?
    let isBoardDetected: Bool
    let lichessURL: String?
    
    // Cache the board state to avoid recalculating on every render
    private let boardState: [[String]]
    
    init(fen: String?, isBoardDetected: Bool, lichessURL: String? = nil) {
        print("=== ChessBoardOverlayView Init ===")
        print("FEN: \(fen ?? "nil")")
        print("isBoardDetected: \(isBoardDetected)")
        print("lichessURL: \(lichessURL ?? "nil")")
        
        self.fen = fen
        self.isBoardDetected = isBoardDetected
        self.lichessURL = lichessURL
        
        // Initialize board state
        if let fen = fen, !fen.isEmpty {
            print("Parsing FEN: \(fen)")
            var board = Array(repeating: Array(repeating: "", count: 8), count: 8)
            let parts = fen.split(separator: " ")
            if let position = parts.first {
                print("Position part: \(position)")
                let ranks = position.split(separator: "/")
                print("Found \(ranks.count) ranks")
                
                for (row, rank) in ranks.enumerated() {
                    print("Processing rank \(row): \(rank)")
                    var col = 0
                    for char in rank {
                        if let number = Int(String(char)) {
                            print("Found number \(number) at col \(col)")
                            col += number
                        } else {
                            let piece = String(char)
                            print("Found piece \(piece) at row \(row), col \(col)")
                            // Convert FEN piece notation to our internal representation
                            switch piece {
                            case "K": board[row][col] = "♔"
                            case "Q": board[row][col] = "♕"
                            case "R": board[row][col] = "♖"
                            case "B": board[row][col] = "♗"
                            case "N": board[row][col] = "♘"
                            case "P": board[row][col] = "♙"
                            case "k": board[row][col] = "♚"
                            case "q": board[row][col] = "♛"
                            case "r": board[row][col] = "♜"
                            case "b": board[row][col] = "♝"
                            case "n": board[row][col] = "♞"
                            case "p": board[row][col] = "♟"
                            default: break
                            }
                            col += 1
                        }
                    }
                }
            }
            print("Final board state:")
            for row in board {
                print(row)
            }
            self.boardState = board
        } else {
            print("No valid FEN provided, using empty board")
            self.boardState = Array(repeating: Array(repeating: "", count: 8), count: 8)
        }
        print("=== End ChessBoardOverlayView Init ===")
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Chess board
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            let isLightSquare = (row + col) % 2 == 0
                            let piece = boardState[row][col]
                            
                            ZStack {
                                Rectangle()
                                    .fill(isLightSquare ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                                    .aspectRatio(1, contentMode: .fit)
                                
                                if !piece.isEmpty {
                                    Text(piece)
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(piece == piece.uppercased() ? .white : .black)
                                        .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
            
            // Status text
            if !isBoardDetected {
                Text("No Chess Board Detected")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
            
            // Lichess URL button
            if let url = lichessURL {
                Link(destination: URL(string: url)!) {
                    HStack {
                        Image(systemName: "link")
                        Text("View on Lichess")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .onAppear {
            print("=== ChessBoardOverlayView Appeared ===")
            print("Current FEN: \(fen ?? "nil")")
            print("Board state:")
            for row in boardState {
                print(row)
            }
            print("=== End ChessBoardOverlayView Appeared ===")
        }
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
    @StateObject private var cameraManager = CameraManager()
    @Namespace private var moveNamespace
    
    var body: some View {
        ZStack {
            if cameraManager.isSessionReady {
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(session: cameraManager.session)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                        
                        // Chess board overlay
                        VStack {
                            ChessBoardOverlayView(
                                fen: cameraManager.lastFEN,
                                isBoardDetected: cameraManager.isChessBoardDetected,
                                lichessURL: cameraManager.lastLichessURL
                            )
                            .frame(width: geo.size.width * 0.8)
                            .padding(.top, 50)
                            
                            Spacer()
                        }
                        
                        // Debug overlay
                        VStack {
                            HStack {
                                Spacer()
                                DebugOverlayView(
                                    lastFEN: cameraManager.lastFEN,
                                    isProcessing: cameraManager.isProcessing,
                                    lastAPICallTime: cameraManager.lastAPICallTime
                                )
                                .padding(.top, 50)
                                .padding(.trailing, 20)
                            }
                            Spacer()
                        }
                        
                        // Show move overlay during live recording
                        if let move = cameraManager.currentMove,
                           cameraManager.isRecording,
                           cameraManager.isChessBoardDetected {
                            MoveOverlayView(move: move)
                        }
                        
                        Spacer()
                        
                        RecordingControlsView(
                            isRecording: cameraManager.isRecording,
                            onRecordToggle: {
                                if cameraManager.isRecording {
                                    cameraManager.stopRecording()
                                } else {
                                    cameraManager.startRecording()
                                }
                            }
                        )
                    }
                }
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}

struct RecordedGamesView: View {
    @State private var recordedGames: [RecordedGame] = []
    @State private var gameToDelete: URL?
    @State private var showingDeleteAlert = false
    @State private var gameToShare: URL?
    @State private var showingShareSheet = false
    @State private var isProcessingShare = false
    @State private var shareError: String?
    @State private var showingShareError = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recordedGames) { game in
                    HStack {
                        NavigationLink(destination: VideoPlayerView(videoURL: game.url)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.url.lastPathComponent)
                            .font(.headline)
                                Text(game.creationDate.formatted())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                                if game.hasChessBoard {
                                    Text("Chess Board Detected (Confidence: \(Int(game.confidence * 100))%)")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                } else {
                                    Text("No Chess Board Detected")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            handleShare(for: game)
                        } label: {
                            if isProcessingShare {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(isProcessingShare)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            gameToDelete = game.url
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Recorded Games")
            .onAppear {
                loadRecordedGames()
            }
            .alert("Delete Game", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    gameToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let url = gameToDelete {
                        deleteGame(at: url)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this game? This action cannot be undone.")
            }
            .alert("Share Error", isPresented: $showingShareError) {
                Button("OK", role: .cancel) {
                    shareError = nil
                }
            } message: {
                if let error = shareError {
                    Text(error)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = gameToShare {
                    ShareSheet(items: [url as Any])
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    private func loadRecordedGames() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.creationDateKey])
            let movFiles = files.filter { $0.pathExtension == "mov" }
            
            recordedGames = movFiles.compactMap { url in
                guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                    return nil
                }
                
                // Load detection status from UserDefaults
                let gameInfo = UserDefaults.standard.dictionary(forKey: url.lastPathComponent)
                let hasChessBoard = gameInfo?["hasChessBoard"] as? Bool ?? false
                let confidence = gameInfo?["confidence"] as? Double ?? 0.0
                var corners: [CGPoint]? = nil
                if let arr = gameInfo?["corners"] as? [[Double]], arr.count == 4 {
                    corners = arr.map { CGPoint(x: $0[0], y: $0[1]) }
                }
                
                return RecordedGame(
                    url: url,
                    creationDate: creationDate,
                    hasChessBoard: hasChessBoard,
                    confidence: confidence,
                    corners: corners
                )
            }
            .sorted { $0.creationDate > $1.creationDate }
        } catch {
            print("Error loading recorded games: \(error)")
        }
    }
    
    private func deleteGame(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            // Remove the deleted game from the array
            recordedGames.removeAll { $0.url == url }
        } catch {
            print("Error deleting game: \(error)")
        }
    }
    
    private func handleShare(for game: RecordedGame) {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: game.url.path) else {
            shareError = "Video file not found"
            showingShareError = true
            return
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: game.url.path) else {
            shareError = "Cannot read video file"
            showingShareError = true
            return
        }
        
        if game.hasChessBoard {
            isProcessingShare = true
            createVideoWithOverlay(from: game.url) { processedURL in
                DispatchQueue.main.async {
                    isProcessingShare = false
                    if let url = processedURL {
                        gameToShare = url
                        showingShareSheet = true
                    } else {
                        shareError = "Failed to process video for sharing"
                        showingShareError = true
                    }
                }
            }
        } else {
            gameToShare = game.url
            showingShareSheet = true
        }
    }
    
    private func createOverlayImage(for videoSize: CGSize) -> CIImage {
        let text = "Chess Board Detected"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 36),
            .foregroundColor: UIColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 20
        let backgroundRect = CGRect(
            x: 0,
            y: 0,
            width: textSize.width + (padding * 2),
            height: textSize.height + (padding * 2)
        )
        
        let renderer = UIGraphicsImageRenderer(size: backgroundRect.size)
        let image = renderer.image { context in
            // Draw background
            let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 10)
            UIColor.black.withAlphaComponent(0.7).setFill()
            backgroundPath.fill()
            
            // Draw text
            let textRect = CGRect(
                x: padding,
                y: padding,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        guard let cgImage = image.cgImage else {
            return CIImage(color: .clear)
        }
        
        let overlayCIImage = CIImage(cgImage: cgImage)
        
        // Calculate scale factor based on video size
        let scaleFactor = min(videoSize.width / backgroundRect.width, videoSize.height / backgroundRect.height) * 0.2
        
        // Scale the overlay
        let scale = CIFilter(name: "CILanczosScaleTransform")
        scale?.setValue(overlayCIImage, forKey: kCIInputImageKey)
        scale?.setValue(scaleFactor, forKey: kCIInputScaleKey)
        
        if let scaledImage = scale?.outputImage {
            // Position the overlay in the top-left corner
            let transform = CIFilter(name: "CIAffineTransform")
            transform?.setValue(scaledImage, forKey: kCIInputImageKey)
            transform?.setValue(CGAffineTransform(translationX: 20, y: videoSize.height - scaledImage.extent.height - 20), forKey: kCIInputTransformKey)
            
            return transform?.outputImage ?? overlayCIImage
        }
        return overlayCIImage
    }
    
    private func createVideoWithOverlay(from sourceURL: URL, completion: @escaping (URL?) -> Void) {
        // Verify source file exists and is readable
        guard FileManager.default.fileExists(atPath: sourceURL.path),
              FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            print("Source video file not found or not readable")
            completion(nil)
            return
        }
        
        let asset = AVAsset(url: sourceURL)
        let composition = AVMutableComposition()
        
        // Load tracks asynchronously
        let group = DispatchGroup()
        group.enter()
        
        var videoTrack: AVAssetTrack?
        var audioTrack: AVAssetTrack?
        
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            defer { group.leave() }
            
            var error: NSError?
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            
            guard status == .loaded else {
                print("Error loading asset tracks: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            videoTrack = asset.tracks(withMediaType: .video).first
            audioTrack = asset.tracks(withMediaType: .audio).first
        }
        
        group.notify(queue: .main) {
            guard let videoTrack = videoTrack,
                  let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                print("Failed to setup video track")
                completion(nil)
                return
            }
            
            do {
                // Add video track
                try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
                
                // Add audio track if available
                if let audioTrack = audioTrack,
                   let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
                }
                
                // Get video dimensions
                let videoSize = videoTrack.naturalSize
                
                // Create video composition
                let videoComposition = AVMutableVideoComposition(asset: composition) { request in
                    let source = request.sourceImage.clampedToExtent()
                    
                    // Create text overlay
                    let textOverlay = self.createOverlayImage(for: videoSize)
                    
                    // Create chess board overlay
                    let chessBoardRenderer = ChessBoardRenderer()
                    let boardOverlay = chessBoardRenderer.renderBoard()
                    
                    // Scale and position the chess board overlay
                    var finalImage = source
                    
                    if let boardOverlay = boardOverlay {
                        // Scale the board to fit the video width while maintaining aspect ratio
                        let scale = videoSize.width / boardOverlay.extent.width
                        let scaledBoard = boardOverlay.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        
                        // Position the board in the center of the video
                        let xOffset = (videoSize.width - scaledBoard.extent.width) / 2
                        let yOffset = (videoSize.height - scaledBoard.extent.height) / 2
                        let positionedBoard = scaledBoard.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
                        
                        // Composite the board onto the source image
                        finalImage = source.composited(over: positionedBoard)
                    }
                    
                    // Add the text overlay
                    finalImage = finalImage.composited(over: textOverlay)
                    
                    request.finish(with: finalImage, context: nil)
                }
                
                // Set video composition render size
                videoComposition.renderSize = videoSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                // Configure export session
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    print("Failed to create export session")
                    completion(nil)
                    return
                }
                
                exportSession.videoComposition = videoComposition
                
                // Create output URL
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("chess_game_with_overlay_\(Date().timeIntervalSince1970).mov")
                
                // Remove existing file if it exists
                try? FileManager.default.removeItem(at: outputURL)
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mov
                exportSession.shouldOptimizeForNetworkUse = true
                
                // Start export
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        print("Video export completed successfully")
                        completion(outputURL)
                    case .failed:
                        print("Video export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                        completion(nil)
                    case .cancelled:
                        print("Video export cancelled")
                        completion(nil)
                    default:
                        print("Video export status: \(exportSession.status.rawValue)")
                        completion(nil)
                    }
                }
            } catch {
                print("Error creating video with overlay: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    @StateObject private var playerManager = VideoPlayerManager()
    private let confidenceThreshold: Double = 0.7
    @State private var lastMoveID: UUID? = nil
    @Namespace private var moveNamespace
    
    var body: some View {
        ZStack {
            if let player = playerManager.player {
                VideoPlayer(player: player)
            .edgesIgnoringSafeArea(.all)
                    .onDisappear {
                        playerManager.cleanup()
                    }
                
                // Add chess board overlay
                if playerManager.isChessBoardDetected {
                    VStack {
                        ChessBoardOverlayView(
                            fen: playerManager.lastFEN,
                            isBoardDetected: true,
                            lichessURL: playerManager.lastLichessURL
                        )
                        .frame(width: UIScreen.main.bounds.width * 0.8)
                        .padding(.top, 50)
                        
                        Spacer()
                    }
                }
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                if let error = playerManager.error {
                    VStack {
                        Text("Error playing video")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            
            // Overlay most recent move
            if let move = playerManager.detectedMoves.last {
                VStack {
                    Text(move.notation)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                        .shadow(radius: 8)
                        .id(move.id)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: move.id)
                    Spacer()
                }
                .padding(.top, 60)
            }
            
            VStack {
                if playerManager.isChessBoardDetected && playerManager.detectionConfidence >= confidenceThreshold {
                    VStack(spacing: 4) {
                        Text("Chess Board Detected")
                            .font(.headline)
                        Text("Confidence: \(Int(playerManager.detectionConfidence * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 50)
                }
                Spacer()
                if !playerManager.detectedMoves.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(playerManager.detectedMoves, id: \.timestamp) { move in
                                HStack {
                                    Text("\(move.moveNumber).")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(move.notation)
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Text("(\(String(format: "%.1f", move.timestamp))s)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    }
                    .frame(maxHeight: 200)
                    .padding()
                }
            }
        }
        .onAppear {
            playerManager.setupPlayer(with: videoURL)
        }
    }
}

struct ChessMove: Identifiable {
    let id = UUID()
    let notation: String
    let timestamp: Double
    let moveNumber: Int
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

class VideoPlayerManager: NSObject, ObservableObject {
    @Published var isChessBoardDetected = false
    @Published var detectionConfidence: Double = 0.0
    @Published var detectedMoves: [ChessMove] = []
    @Published var player: AVPlayer?
    @Published var error: Error?
    @Published var lastFEN: String?
    @Published var lastLichessURL: String?
    private var playerItem: AVPlayerItem?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playerItemOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private let chessBoardDetector = ChessBoardDetector()
    private let chessBoardRenderer = ChessBoardRenderer()
    private let confidenceThreshold: Double = 0.7
    private var isProcessingFrame = false
    private var currentBoardOverlay: CIImage?
    private var loadedCorners: [CGPoint]? = nil
    private var processingQueue = DispatchQueue(label: "com.chess.videoprocessing", qos: .userInitiated)
    private var lastProcessedTime: CMTime = .zero
    private let processingInterval: CMTime = CMTime(value: 1, timescale: 1) // Process every second
    private var fenPositions: [(time: CMTime, fen: String, lichessURL: String?)] = []
    private var recordingStartTime: Double = 0
    private var isPlayerReady = false
    
    func setupPlayer(with url: URL) {
        // Clean up any existing resources
        cleanup()
        
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.isReadableFile(atPath: url.path) else {
            Task { @MainActor in
                self.error = NSError(domain: "VideoPlayerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found or not readable"])
            }
            return
        }
        
        // Load FEN positions from UserDefaults
        let gameKey = "game_\(url.lastPathComponent)"
        print("Loading FEN positions for game: \(gameKey)")
        if let gameInfo = UserDefaults.standard.dictionary(forKey: gameKey),
           let fenPositionsData = gameInfo["fenPositions"] as? [[String: Any]],
           let startTime = gameInfo["recordingStartTime"] as? Double {
            recordingStartTime = startTime
            fenPositions = fenPositionsData.compactMap { data in
                guard let time = data["time"] as? Double,
                      let fen = data["fen"] as? String else { return nil }
                let lichessURL = data["lichessURL"] as? String
                // Convert absolute timestamp to relative timestamp
                let relativeTime = time - startTime
                print("Converting timestamp - Absolute: \(time), Start: \(startTime), Relative: \(relativeTime)")
                return (time: CMTime(seconds: relativeTime, preferredTimescale: 600), fen: fen, lichessURL: lichessURL)
            }
            print("Loaded \(fenPositions.count) FEN positions for playback")
            fenPositions.forEach { position in
                print("Loaded FEN - Relative Time: \(position.time.seconds), FEN: \(position.fen)")
            }
        } else {
            print("No FEN positions found in UserDefaults for key: \(gameKey)")
        }
        
        // Create asset and player item
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        self.playerItem = playerItem
        
        // Setup video output for frame processing
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        playerItem.add(videoOutput)
        self.playerItemOutput = videoOutput
        
        // Create and configure player
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // Setup display link for frame processing
        displayLink = CADisplayLink(target: self, selector: #selector(handleFrame))
        displayLink?.preferredFramesPerSecond = 5 // Reduce processing frequency
        displayLink?.add(to: .main, forMode: .common)
        
        // Add observer for player item status
        playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch item.status {
                case .failed:
                    print("Player item failed: \(String(describing: item.error))")
                    self.error = item.error
                    self.cleanup()
                case .readyToPlay:
                    print("Player item ready to play")
                    self.error = nil
                    self.isPlayerReady = true
                case .unknown:
                    print("Player item status unknown")
                @unknown default:
                    break
                }
            }
        }
        
        // Update UI on main thread
        Task { @MainActor in
            self.player = newPlayer
            self.player?.play()
        }
    }
    
    @MainActor
    private func updateUI(isBoardDetected: Bool, fen: String?, lichessURL: String?, isProcessing: Bool = false) {
        print("=== Updating UI ===")
        print("isBoardDetected: \(isBoardDetected)")
        print("FEN: \(fen ?? "nil")")
        print("lichessURL: \(lichessURL ?? "nil")")
        print("isProcessing: \(isProcessing)")
        
        self.isChessBoardDetected = isBoardDetected
        self.lastFEN = fen
        self.lastLichessURL = lichessURL
        self.isProcessingFrame = isProcessing
        
        print("=== End Updating UI ===")
    }
    
    @objc private func handleFrame() {
        // Prevent concurrent frame processing and check player readiness
        guard !isProcessingFrame,
              isPlayerReady,
              let videoOutput = playerItemOutput,
              let player = player,
              let currentTime = player.currentItem?.currentTime() else { return }
        
        // Check if enough time has passed since last processing
        guard currentTime - lastProcessedTime >= processingInterval else { return }
        
        isProcessingFrame = true
        lastProcessedTime = currentTime
        
        // Move processing to background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Find the appropriate FEN for the current time
            if let position = self.findFENForTime(currentTime) {
                print("Processing frame at time \(currentTime.seconds) with FEN: \(position.fen)")
                Task { @MainActor in
                    await self.updateUI(isBoardDetected: true, fen: position.fen, lichessURL: position.lichessURL)
                }
            } else {
                print("No FEN found for time \(currentTime.seconds)")
                Task { @MainActor in
                    await self.updateUI(isBoardDetected: false, fen: nil, lichessURL: nil)
                }
            }
        }
    }
    
    private func findFENForTime(_ time: CMTime) -> (fen: String, lichessURL: String?)? {
        // Find the most recent FEN position before the current time
        let position = fenPositions
            .filter { $0.time <= time }
            .sorted { $0.time > $1.time }
            .first
        
        if let position = position {
            print("Found FEN for relative time \(time.seconds): \(position.fen)")
            return (fen: position.fen, lichessURL: position.lichessURL)
        } else {
            print("No FEN found for relative time \(time.seconds)")
            return nil
        }
    }
    
    func getCurrentBoardOverlay() -> CIImage? {
        return currentBoardOverlay
    }
    
    func cleanup() {
        // Remove observer
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        
        // Invalidate display link
        displayLink?.invalidate()
        displayLink = nil
        
        // Clean up player
        player?.pause()
        player = nil
        
        // Clean up outputs
        playerItemOutput = nil
        playerItem = nil
        
        // Reset state
        isChessBoardDetected = false
        detectionConfidence = 0.0
        detectedMoves = []
        error = nil
        isProcessingFrame = false
        currentBoardOverlay = nil
        loadedCorners = nil
        lastProcessedTime = .zero
        fenPositions.removeAll()
        recordingStartTime = 0
        isPlayerReady = false
        lastFEN = nil
        lastLichessURL = nil
    }
    
    deinit {
        cleanup()
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
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure the share sheet
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // For iPad support
        if let popoverController = controller.popoverPresentationController {
            popoverController.sourceView = UIView()
            popoverController.sourceRect = CGRect(x: 0, y: 0, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
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
    private let baseURL = "http://159.203.102.249:8000"
    
    struct ChessPositionResponse: Codable {
        let fen: String
        let ascii: String
        let lichess_url: String
        let legal_position: Bool
    }
    
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
        
        print("Sending request to API with image size: \(imageData.count) bytes")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LocalChessAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
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
            print("API Response - FEN: \(chessResponse.fen), Legal: \(chessResponse.legal_position)")
            print("ASCII Board:\n\(chessResponse.ascii)")
            print("Lichess URL: \(chessResponse.lichess_url)")
            
            // Return the FEN string even if the position is not legal
            return (chessResponse.legal_position, chessResponse.fen, chessResponse.lichess_url)
        } catch {
            print("Error decoding response: \(error)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Raw response: \(errorString)")
            }
            return (false, "", nil)
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

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    @Published var isChessBoardDetected = false
    @Published var isSessionReady = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var currentMove: String?
    @Published var moveNumber: Int = 0
    @Published var lastFEN: String?
    @Published var isProcessingFrame = false
    private let localChessService = LocalChessAPIService()
    private var videoInput: AVCaptureDeviceInput?
    private var isSessionConfigured = false
    private var lastBoardState: [[String]] = Array(repeating: Array(repeating: "", count: 8), count: 8)
    private var lastMoveTime: Date = Date()
    @Published var lastAPICallTime: Date = Date()
    private let apiCallInterval: TimeInterval = 2.0
    private var processingTask: Task<Void, Never>?
    private var fenPositions: [(time: CMTime, fen: String, lichessURL: String?)] = []
    private var recordingStartTime: CMTime?
    @Published var lastASCIIBoard: String?
    @Published var lastLichessURL: String?
    private let setupQueue = DispatchQueue(label: "com.chess.camera.setup", qos: .userInitiated)
    
    @MainActor
    private func updateUI(isBoardDetected: Bool, fen: String?, lichessURL: String?, isProcessing: Bool = false) {
        print("=== Updating UI ===")
        print("isBoardDetected: \(isBoardDetected)")
        print("FEN: \(fen ?? "nil")")
        print("lichessURL: \(lichessURL ?? "nil")")
        print("isProcessing: \(isProcessing)")
        
        self.isChessBoardDetected = isBoardDetected
        self.lastFEN = fen
        self.lastLichessURL = lichessURL
        self.isProcessingFrame = isProcessing
        
        print("=== End Updating UI ===")
    }
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        guard !isSessionConfigured else { return }
        
        Task { @MainActor in
            self.isSessionReady = false
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Configure session for high quality
            self.session.sessionPreset = .high
            
            // Setup camera input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                    self.videoInput = videoInput
                }
            } catch {
                print("Error setting up camera input: \(error)")
                return
            }
            
            // Setup video data output for frame processing
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue", qos: .userInitiated))
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(videoDataOutput) {
                self.session.addOutput(videoDataOutput)
                self.videoDataOutput = videoDataOutput
            }
            
            // Setup movie file output for recording
            let movieOutput = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(movieOutput) {
                self.session.addOutput(movieOutput)
                self.videoOutput = movieOutput
                
                // Configure for long recordings
                if let connection = movieOutput.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }
            
            self.session.commitConfiguration()
            self.isSessionConfigured = true
            
            if !self.session.isRunning {
                self.session.startRunning()
                Task { @MainActor in
                    self.isSessionReady = true
                }
            }
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput else { return }
        
        // Reset FEN tracking
        fenPositions.removeAll()
        recordingStartTime = nil
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("chess_game_\(Date().timeIntervalSince1970).mov")
        
        // Ensure the video connection is properly configured before recording
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        // Set maximum recording duration to 0 (unlimited)
        videoOutput.maxRecordedDuration = .zero
        
        Task { @MainActor in
            self.isRecording = true
        }
        
        videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop the video output first
        videoOutput?.stopRecording()
        
        // Update UI immediately
        Task { @MainActor in
            self.isRecording = false
            self.isProcessing = true
        }
    }
    
    private func detectMoves(in pixelBuffer: CVPixelBuffer) {
        // Prevent concurrent processing
        guard !isProcessingFrame else { return }
        
        // Check if enough time has passed since last API call
        let now = Date()
        guard now.timeIntervalSince(lastAPICallTime) >= apiCallInterval else { return }
        
        Task { @MainActor in
            self.isProcessingFrame = true
            self.lastAPICallTime = now
        }
        
        // Move processing to background queue
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            guard let imageData = self.localChessService.pixelBufferToData(pixelBuffer) else {
                print("Failed to convert pixel buffer to data")
                await self.updateUI(isBoardDetected: false, fen: nil, lichessURL: nil)
                return
            }
            
            do {
                print("Calling Chess Position API...")
                let response = try await self.localChessService.recognizePosition(imageData: imageData)
                print("API Response received - Success: \(response.success), FEN: \(response.fen)")
                
                // Debug print the FEN parsing
                if !response.fen.isEmpty {
                    print("Parsing FEN: \(response.fen)")
                    let parts = response.fen.split(separator: " ")
                    if let position = parts.first {
                        print("Position part: \(position)")
                        let ranks = position.split(separator: "/")
                        print("Ranks: \(ranks)")
                    }
                }
                
                // Always update UI with the FEN if we have one
                if !response.fen.isEmpty {
                    print("Updating UI with FEN: \(response.fen)")
                    await self.updateUI(isBoardDetected: true, fen: response.fen, lichessURL: response.lichessURL)
                    
                    // Store FEN position with timestamp if recording
                    if await self.isRecording {
                        if self.recordingStartTime == nil {
                            self.recordingStartTime = CMTime(seconds: 0, preferredTimescale: 600)
                        }
                        
                        // Store absolute timestamp
                        let absoluteTime = now.timeIntervalSince1970
                        let relativeTime = absoluteTime - (self.recordingStartTime?.seconds ?? 0)
                        
                        // Only add new FEN if it's different from the last one
                        if let lastFEN = self.fenPositions.last?.fen, lastFEN == response.fen {
                            print("Skipping duplicate FEN position")
                        } else {
                            print("Adding new FEN position at time \(relativeTime)")
                            self.fenPositions.append((time: CMTime(seconds: relativeTime, preferredTimescale: 600), fen: response.fen, lichessURL: response.lichessURL))
                        }
                    }
                } else {
                    print("Empty FEN detected, skipping")
                    await self.updateUI(isBoardDetected: false, fen: nil, lichessURL: nil)
                }
                
            } catch {
                print("Error recognizing position: \(error)")
                await self.updateUI(isBoardDetected: false, fen: nil, lichessURL: nil)
            }
        }
    }
    
    deinit {
        processingTask?.cancel()
    }
    
    private func processVideoWithOverlay(inputURL: URL, gameKey: String) async {
        print("Starting video processing with overlay for game: \(gameKey)")
        
        // Load FEN positions from UserDefaults
        if let gameInfo = UserDefaults.standard.dictionary(forKey: gameKey),
           let fenPositionsData = gameInfo["fenPositions"] as? [[String: Any]] {
            print("Loaded \(fenPositionsData.count) FEN positions from UserDefaults")
            fenPositionsData.forEach { data in
                if let time = data["time"] as? Double,
                   let fen = data["fen"] as? String {
                    print("Loaded FEN - Time: \(time), FEN: \(fen)")
                }
            }
        } else {
            print("No FEN positions found in UserDefaults for key: \(gameKey)")
        }
        
        // Process video in background
        await Task.detached(priority: .userInitiated) {
            // Create asset and composition
            let asset = AVAsset(url: inputURL)
            let composition = AVMutableComposition()
            
            // Load tracks asynchronously
            let group = DispatchGroup()
            group.enter()
            
            var videoTrack: AVAssetTrack?
            var audioTrack: AVAssetTrack?
            
            asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                defer { group.leave() }
                
                var error: NSError?
                let status = asset.statusOfValue(forKey: "tracks", error: &error)
                
                guard status == .loaded else {
                    print("Error loading asset tracks: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                videoTrack = asset.tracks(withMediaType: .video).first
                audioTrack = asset.tracks(withMediaType: .audio).first
            }
            
            group.notify(queue: .main) {
                guard let videoTrack = videoTrack,
                      let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    print("Failed to setup video track")
                    return
                }
                
                do {
                    // Add video track
                    try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
                    
                    // Add audio track if available
                    if let audioTrack = audioTrack,
                       let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
                    }
                    
                    // Get video dimensions
                    let videoSize = videoTrack.naturalSize
                    
                    // Create video composition
                    let videoComposition = AVMutableVideoComposition(asset: composition) { request in
                        let source = request.sourceImage.clampedToExtent()
                        
                        // Create text overlay
                        let textOverlay = self.createOverlayImage(for: videoSize)
                        
                        // Create chess board overlay
                        let chessBoardRenderer = ChessBoardRenderer()
                        let boardOverlay = chessBoardRenderer.renderBoard()
                        
                        // Scale and position the chess board overlay
                        var finalImage = source
                        
                        if let boardOverlay = boardOverlay {
                            // Scale the board to fit the video width while maintaining aspect ratio
                            let scale = videoSize.width / boardOverlay.extent.width
                            let scaledBoard = boardOverlay.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                            
                            // Position the board in the center of the video
                            let xOffset = (videoSize.width - scaledBoard.extent.width) / 2
                            let yOffset = (videoSize.height - scaledBoard.extent.height) / 2
                            let positionedBoard = scaledBoard.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
                            
                            // Composite the board onto the source image
                            finalImage = source.composited(over: positionedBoard)
                        }
                        
                        // Add the text overlay
                        finalImage = finalImage.composited(over: textOverlay)
                        
                        request.finish(with: finalImage, context: nil)
                    }
                    
                    // Set video composition render size
                    videoComposition.renderSize = videoSize
                    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                    
                    // Configure export session
                    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                        print("Failed to create export session")
                        return
                    }
                    
                    exportSession.videoComposition = videoComposition
                    
                    // Create output URL
                    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("chess_game_with_overlay_\(Date().timeIntervalSince1970).mov")
                    
                    // Remove existing file if it exists
                    try? FileManager.default.removeItem(at: outputURL)
                    
                    exportSession.outputURL = outputURL
                    exportSession.outputFileType = .mov
                    exportSession.shouldOptimizeForNetworkUse = true
                    
                    // Start export
                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            print("Video export completed successfully")
                            Task { @MainActor in
                                self.isProcessing = false
                            }
                        case .failed:
                            print("Video export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                            Task { @MainActor in
                                self.isProcessing = false
                            }
                        case .cancelled:
                            print("Video export cancelled")
                            Task { @MainActor in
                                self.isProcessing = false
                            }
                        default:
                            print("Video export status: \(exportSession.status.rawValue)")
                            Task { @MainActor in
                                self.isProcessing = false
                            }
                        }
                    }
                } catch {
                    print("Error creating video with overlay: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isProcessing = false
                    }
                }
            }
        }.value
    }
    
    private func createOverlayImage(for videoSize: CGSize) -> CIImage {
        let text = "Chess Board Detected"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 36),
            .foregroundColor: UIColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 20
        let backgroundRect = CGRect(
            x: 0,
            y: 0,
            width: textSize.width + (padding * 2),
            height: textSize.height + (padding * 2)
        )
        
        let renderer = UIGraphicsImageRenderer(size: backgroundRect.size)
        let image = renderer.image { context in
            // Draw background
            let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 10)
            UIColor.black.withAlphaComponent(0.7).setFill()
            backgroundPath.fill()
            
            // Draw text
            let textRect = CGRect(
                x: padding,
                y: padding,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        guard let cgImage = image.cgImage else {
            return CIImage(color: .clear)
        }
        
        let overlayCIImage = CIImage(cgImage: cgImage)
        
        // Calculate scale factor based on video size
        let scaleFactor = min(videoSize.width / backgroundRect.width, videoSize.height / backgroundRect.height) * 0.2
        
        // Scale the overlay
        let scale = CIFilter(name: "CILanczosScaleTransform")
        scale?.setValue(overlayCIImage, forKey: kCIInputImageKey)
        scale?.setValue(scaleFactor, forKey: kCIInputScaleKey)
        
        if let scaledImage = scale?.outputImage {
            // Position the overlay in the top-left corner
            let transform = CIFilter(name: "CIAffineTransform")
            transform?.setValue(scaledImage, forKey: kCIInputImageKey)
            transform?.setValue(CGAffineTransform(translationX: 20, y: videoSize.height - scaledImage.extent.height - 20), forKey: kCIInputTransformKey)
            
            return transform?.outputImage ?? overlayCIImage
        }
        return overlayCIImage
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Started recording to: \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            Task { @MainActor in
                self.isProcessing = false
            }
            return
        }
        
        print("Recording finished. Processing video with \(fenPositions.count) FEN positions")
        
        // Filter out invalid FEN positions
        let validFENPositions = fenPositions.filter { !$0.fen.isEmpty }
        
        // Save the detection status and FEN positions to UserDefaults
        let gameInfo: [String: Any] = [
            "hasChessBoard": !validFENPositions.isEmpty,
            "confidence": validFENPositions.isEmpty ? 0.0 : 1.0,
            "fenPositions": validFENPositions.map { [
                "time": $0.time.seconds,
                "fen": $0.fen,
                "lichessURL": $0.lichessURL as Any
            ]},
            "recordingStartTime": Date().timeIntervalSince1970
        ]
        
        // Save to UserDefaults with a unique key
        let gameKey = "game_\(outputFileURL.lastPathComponent)"
        UserDefaults.standard.set(gameInfo, forKey: gameKey)
        print("Saved FEN positions for game: \(gameKey)")
        print("FEN positions saved: \(validFENPositions.count)")
        validFENPositions.forEach { position in
            print("Time: \(position.time.seconds), FEN: \(position.fen)")
        }
        
        // Process the video in the background
        processingTask = Task {
            await processVideoWithOverlay(inputURL: outputFileURL, gameKey: gameKey)
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        if isRecording {
            detectMoves(in: pixelBuffer)
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
        
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            if superview != nil {
                videoPreviewLayer.videoGravity = .resizeAspectFill
                videoPreviewLayer.connection?.videoOrientation = .portrait
            }
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.frame = uiView.bounds
        uiView.videoPreviewLayer.connection?.videoOrientation = .portrait
    }
}

#Preview {
    ContentView()
}


