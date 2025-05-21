import Foundation
import CoreVideo
import UIKit

struct ChessCogResponse: Codable {
    let success: Bool
    let fen: String
    let boardAscii: String
    let pieceCount: Int
    let whitePieces: PieceCount
    let blackPieces: PieceCount
    let turn: String
    let isCheck: Bool
    let isCheckmate: Bool
    
    enum CodingKeys: String, CodingKey {
        case success
        case fen
        case boardAscii = "board_ascii"
        case pieceCount = "piece_count"
        case whitePieces = "white_pieces"
        case blackPieces = "black_pieces"
        case turn
        case isCheck = "is_check"
        case isCheckmate = "is_checkmate"
    }
}

struct PieceCount: Codable {
    let pawn: Int
    let knight: Int
    let bishop: Int
    let rook: Int
    let queen: Int
    let king: Int
}

class ChessCogService {
    private let baseURL = "https://chess-scan-server-tonyblum2.replit.app/api"
    private let session: URLSession
    private let maxRetries = 3
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // 30 second timeout
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func recognizePosition(imageData: Data) async throws -> ChessCogResponse {
        // Optimize image data before sending
        guard let optimizedData = optimizeImageData(imageData) else {
            throw NSError(domain: "ChessCogError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to optimize image"])
        }
        
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                return try await makeRequest(with: optimizedData)
            } catch {
                lastError = error
                retryCount += 1
                if retryCount < maxRetries {
                    print("Retry attempt \(retryCount) of \(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * retryCount)) // Exponential backoff
                }
            }
        }
        
        throw lastError ?? NSError(domain: "ChessCogError", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    private func makeRequest(with imageData: Data) async throws -> ChessCogResponse {
        guard let url = URL(string: "\(baseURL)/recognize") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30 // 30 second timeout
        
        // Generate boundary string
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form data
        var body = Data()
        
        // Add image file data
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"chessboard.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("Making API request to: \(url)")
        print("Request body size: \(body.count) bytes")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid HTTP response")
                throw URLError(.badServerResponse)
            }
            
            print("API Response status code: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    print("API Error: \(errorMessage)")
                    throw NSError(domain: "ChessCogError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                throw NSError(domain: "ChessCogError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
            }
            
            print("Received response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")")
            
            let decoder = JSONDecoder()
            return try decoder.decode(ChessCogResponse.self, from: data)
        } catch let error as URLError {
            print("Network error: \(error.localizedDescription)")
            throw error
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func optimizeImageData(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        // Calculate new size (max dimension 1024 pixels)
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        // Create new image with smaller size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Convert to JPEG with lower quality
        return resizedImage?.jpegData(compressionQuality: 0.7)
    }
    
    // Helper function to convert CVPixelBuffer to Data
    func pixelBufferToData(_ pixelBuffer: CVPixelBuffer) -> Data? {
        print("Starting pixel buffer conversion...")
        
        // Lock the pixel buffer
        let lockFlags = CVPixelBufferLockFlags.readOnly
        let lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags)
        guard lockResult == kCVReturnSuccess else {
            print("Failed to lock pixel buffer: \(lockResult)")
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, lockFlags) }
        
        // Get buffer dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("Buffer dimensions: \(width)x\(height)")
        
        // Get pixel format
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        print("Pixel format: \(pixelFormat)")
        
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        print("Created CIImage with extent: \(ciImage.extent)")
        
        // Create a CIContext
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // Create a CGImage from the CIImage
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to create CGImage from CIImage")
            return nil
        }
        print("Successfully created CGImage")
        
        // Convert CGImage to UIImage
        let uiImage = UIImage(cgImage: cgImage)
        print("Created UIImage with size: \(uiImage.size)")
        
        // Convert UIImage to JPEG data with higher quality
        guard let imageData = uiImage.jpegData(compressionQuality: 0.9) else {
            print("Failed to convert UIImage to JPEG data")
            return nil
        }
        print("Successfully converted to JPEG data: \(imageData.count) bytes")
        
        return imageData
    }
} 