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

struct RecordedGame: Identifiable {
    let id = UUID()
    let url: URL
    let creationDate: Date
    let hasChessBoard: Bool
    let confidence: Double
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

struct RecordingView: View {
    @StateObject private var cameraManager = CameraManager()
    private let confidenceThreshold: Double = 0.7 // 70% confidence threshold
    
    var body: some View {
        ZStack {
            if cameraManager.isSessionReady {
                CameraPreviewView(session: cameraManager.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                
                if cameraManager.isRecording && cameraManager.isChessBoardDetected && cameraManager.detectionConfidence >= confidenceThreshold {
                    VStack {
                        VStack(spacing: 4) {
                            Text("Chess Board Detected")
                                .font(.headline)
                            Text("Confidence: \(Int(cameraManager.detectionConfidence * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 50)
                        Spacer()
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            if cameraManager.isRecording {
                                cameraManager.stopRecording()
                            } else {
                                cameraManager.startRecording()
                            }
                        }) {
                            Image(systemName: cameraManager.isRecording ? "stop.circle.fill" : "record.circle")
                                .font(.system(size: 64))
                                .foregroundColor(cameraManager.isRecording ? .red : .white)
                        }
                        .padding()
                    }
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding(.bottom, 20)
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
                            gameToShare = game.url
                            showingShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
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
                if let gameInfo = UserDefaults.standard.dictionary(forKey: url.lastPathComponent) {
                    let hasChessBoard = gameInfo["hasChessBoard"] as? Bool ?? false
                    let confidence = gameInfo["confidence"] as? Double ?? 0.0
                    
                    return RecordedGame(
                        url: url,
                        creationDate: creationDate,
                        hasChessBoard: hasChessBoard,
                        confidence: confidence
                    )
                }
                
                return RecordedGame(
                    url: url,
                    creationDate: creationDate,
                    hasChessBoard: false,
                    confidence: 0.0
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
}

struct VideoPlayerView: View {
    let videoURL: URL
    @StateObject private var playerManager = VideoPlayerManager()
    private let confidenceThreshold: Double = 0.7
    
    var body: some View {
        ZStack {
            if let player = playerManager.player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
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
        .onDisappear {
            playerManager.cleanup()
        }
    }
}

struct ChessMove: Identifiable {
    let id = UUID()
    let notation: String
    let timestamp: Double
    let moveNumber: Int
}

class VideoPlayerManager: NSObject, ObservableObject {
    @Published var isChessBoardDetected = false
    @Published var detectionConfidence: Double = 0.0
    @Published var detectedMoves: [ChessMove] = []
    @Published var player: AVPlayer?
    private var playerItemOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private let chessBoardDetector = ChessBoardDetector()
    private var lastMoveTime: Double = 0
    private var moveCounter = 0
    private var lastBoardState: [[String]] = []
    private var playerItem: AVPlayerItem?
    
    func setupPlayer(with url: URL) {
        // Clean up any existing resources
        cleanup()
        
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
        displayLink?.add(to: .main, forMode: .common)
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.player = newPlayer
            self.player?.play()
        }
        
        // Add observer for player item status
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status",
           let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .failed:
                print("Player item failed: \(String(describing: playerItem.error))")
                cleanup()
            case .readyToPlay:
                print("Player item ready to play")
            case .unknown:
                print("Player item status unknown")
            @unknown default:
                break
            }
        }
    }
    
    @objc private func handleFrame() {
        guard let videoOutput = playerItemOutput,
              let player = player,
              let currentTime = player.currentItem?.currentTime() else { return }
        
        let itemTime = CMTime(seconds: currentTime.seconds, preferredTimescale: 600)
        guard videoOutput.hasNewPixelBuffer(forItemTime: itemTime) else { return }
        
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else { return }
        
        let (detected, confidence) = chessBoardDetector.detectChessBoard(in: pixelBuffer)
        let currentBoardState = chessBoardDetector.detectBoardState(in: pixelBuffer)
        
        DispatchQueue.main.async {
            self.isChessBoardDetected = detected
            self.detectionConfidence = confidence
            
            // Check for moves
            if detected && confidence >= 0.7 {
                if let move = self.detectMove(from: self.lastBoardState, to: currentBoardState, at: currentTime.seconds) {
                    self.detectedMoves.append(move)
                }
                self.lastBoardState = currentBoardState
            }
        }
    }
    
    private func detectMove(from oldState: [[String]], to newState: [[String]], at timestamp: Double) -> ChessMove? {
        // Only detect moves if enough time has passed since last move
        guard timestamp - lastMoveTime > 1.0 else { return nil }
        
        // Find the differences between board states
        var fromSquare = ""
        var toSquare = ""
        var piece = ""
        
        for i in 0..<8 {
            for j in 0..<8 {
                if oldState[i][j] != newState[i][j] {
                    if oldState[i][j] != "" {
                        fromSquare = "\(["a", "b", "c", "d", "e", "f", "g", "h"][j])\(8-i)"
                        piece = oldState[i][j]
                    }
                    if newState[i][j] != "" {
                        toSquare = "\(["a", "b", "c", "d", "e", "f", "g", "h"][j])\(8-i)"
                    }
                }
            }
        }
        
        if !fromSquare.isEmpty && !toSquare.isEmpty {
            lastMoveTime = timestamp
            moveCounter += 1
            
            // Create move notation
            let notation = "\(piece)\(fromSquare)-\(toSquare)"
            return ChessMove(notation: notation, timestamp: timestamp, moveNumber: moveCounter)
        }
        
        return nil
    }
    
    func cleanup() {
        // Remove observer
        if let playerItem = playerItem {
            playerItem.removeObserver(self, forKeyPath: "status")
        }
        
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
        lastMoveTime = 0
        moveCounter = 0
        lastBoardState = []
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
        
        // Apply edge detection
        guard let edges = detectEdges(in: grayscaleImage) else { return (false, 0.0) }
        
        // Look for grid-like patterns
        return detectGridPattern(in: edges)
    }
    
    func detectBoardState(in pixelBuffer: CVPixelBuffer) -> [[String]] {
        // Initialize empty board
        var board = Array(repeating: Array(repeating: "", count: 8), count: 8)
        
        // TODO: Implement actual piece detection
        // For now, return empty board
        return board
    }
    
    private func convertToGrayscale(_ image: CIImage) -> CIImage? {
        let grayscaleFilter = CIFilter(name: "CIColorControls")
        grayscaleFilter?.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter?.setValue(0.0, forKey: kCIInputSaturationKey)
        return grayscaleFilter?.outputImage
    }
    
    private func detectEdges(in image: CIImage) -> CIImage? {
        let edgeFilter = CIFilter(name: "CIEdges")
        edgeFilter?.setValue(image, forKey: kCIInputImageKey)
        edgeFilter?.setValue(5.0, forKey: kCIInputIntensityKey)
        return edgeFilter?.outputImage
    }
    
    private func detectGridPattern(in image: CIImage) -> (Bool, Double) {
        // Create a request to detect rectangles
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.8
        request.maximumAspectRatio = 1.2
        request.minimumSize = 0.2
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
        
        guard let observations = request.results else { return (false, 0.0) }
        
        if let observation = observations.first {
            // Calculate confidence based on multiple factors
            var confidence = Double(observation.confidence)
            
            // Adjust confidence based on aspect ratio (closer to 1.0 is better)
            let aspectRatio = Double(observation.boundingBox.width / observation.boundingBox.height)
            let aspectRatioConfidence = 1.0 - abs(1.0 - aspectRatio)
            confidence *= (0.7 + 0.3 * aspectRatioConfidence)
            
            // Adjust confidence based on size (larger is better, up to a point)
            let sizeConfidence = min(Double(observation.boundingBox.width * observation.boundingBox.height * 4), 1.0)
            confidence *= (0.7 + 0.3 * sizeConfidence)
            
            return (true, confidence)
        }
        
        return (false, 0.0)
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

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    @Published var isChessBoardDetected = false
    @Published var detectionConfidence: Double = 0.0
    @Published var isSessionReady = false
    @Published var isRecording = false
    private let chessBoardDetector = ChessBoardDetector()
    private var currentRecordingHasChessBoard = false
    private var currentRecordingConfidence = 0.0
    private var videoInput: AVCaptureDeviceInput?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
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
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if self.session.canAddOutput(videoDataOutput) {
                self.session.addOutput(videoDataOutput)
                self.videoDataOutput = videoDataOutput
            }
            
            // Setup movie file output for recording
            let movieOutput = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(movieOutput) {
                self.session.addOutput(movieOutput)
                self.videoOutput = movieOutput
            }
            
            // Configure session
            self.session.sessionPreset = .high
            
            // Ensure the video connection is properly configured
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.session.commitConfiguration()
            
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionReady = true
                }
            }
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput else { return }
        
        // Reset detection status for new recording
        currentRecordingHasChessBoard = false
        currentRecordingConfidence = 0.0
        
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
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
        
        videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }
    
    func stopRecording() {
        videoOutput?.stopRecording()
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Started recording to: \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            return
        }
        
        // Save the detection status to UserDefaults
        let gameInfo = [
            "hasChessBoard": currentRecordingHasChessBoard,
            "confidence": currentRecordingConfidence
        ] as [String: Any]
        
        UserDefaults.standard.set(gameInfo, forKey: outputFileURL.lastPathComponent)
        print("Video saved to: \(outputFileURL)")
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let (detected, confidence) = chessBoardDetector.detectChessBoard(in: pixelBuffer)
        DispatchQueue.main.async {
            self.isChessBoardDetected = detected
            self.detectionConfidence = confidence
            
            // Update current recording status
            if self.isRecording {
                self.currentRecordingHasChessBoard = detected
                self.currentRecordingConfidence = confidence
            }
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
