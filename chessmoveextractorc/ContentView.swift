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
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recordedGames) { game in
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
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url: videoURL))
            .edgesIgnoringSafeArea(.all)
    }
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
        // Ensure we're on a background thread for session configuration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Stop any existing session
            if self.session.isRunning {
                self.session.stopRunning()
            }
            
            self.session.beginConfiguration()
            
            // Remove any existing inputs and outputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            
            // Setup camera input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                return
            }
            
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
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
            
            // Commit configuration
            self.session.commitConfiguration()
            
            // Start running the session
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
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            previewLayer.connection?.videoOrientation = .portrait
        }
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

#Preview {
    ContentView()
}
