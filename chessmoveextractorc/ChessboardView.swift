import SwiftUI

struct ChessboardView: View {
    let fen: String
    @State private var boardState: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var selectedSquare: (row: Int, col: Int)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left column - rank numbers (8-1)
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        Text("\(8 - row)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 36)
                    }
                }
                
                // Main chessboard
                chessboardView
            }
            
            // Bottom row - file letters (a-h)
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: 20) // Left margin
                ForEach(0..<8, id: \.self) { col in
                    Text(String(Character(UnicodeScalar(97 + col)!))) // 'a' = 97
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 20)
                }
            }
        }
        .onAppear {
            parseFEN(fen)
        }
        .onChange(of: fen) { _, newFen in
            parseFEN(newFen)
        }
    }
    
    private var chessboardView: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        chessSquare(row: row, col: col)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
        .shadow(radius: 2)
    }
    
    private func chessSquare(row: Int, col: Int) -> some View {
        let isWhiteSquare = (row + col) % 2 == 0
        let piece = boardState[row][col]
        
        return Button(action: {
            handleSquareTap(row: row, col: col)
        }) {
            ZStack {
                Rectangle()
                    .fill(isWhiteSquare ? Color(red: 0.96, green: 0.93, blue: 0.85) : Color(red: 0.4, green: 0.6, blue: 0.4))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Rectangle()
                            .stroke(selectedSquare?.row == row && selectedSquare?.col == col ? Color.blue : Color.clear, lineWidth: 2)
                    )
                
                if let piece = piece {
                    // Chess.com/Lichess-style piece design
                    Text(piece.symbol)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(piece.isWhite ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.9, green: 0.9, blue: 0.9))
                        .shadow(color: piece.isWhite ? Color.white.opacity(0.9) : Color.black.opacity(0.7), radius: 0.5, x: 0, y: 0)
                        .shadow(color: piece.isWhite ? Color.black.opacity(0.3) : Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleSquareTap(row: Int, col: Int) {
        if let selected = selectedSquare {
            // If a square is already selected, try to move piece
            if selected.row != row || selected.col != col {
                // TODO: Implement piece movement logic
                print("Move piece from (\(selected.row), \(selected.col)) to (\(row), \(col))")
            }
            selectedSquare = nil
        } else {
            // Select this square if it has a piece
            if boardState[row][col] != nil {
                selectedSquare = (row, col)
            }
        }
    }
    
    private func parseFEN(_ fen: String) {
        let components = fen.components(separatedBy: " ")
        guard components.count >= 1 else { return }
        
        let positionString = components[0]
        let ranks = positionString.components(separatedBy: "/")
        
        // Clear board
        boardState = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        
        for (rankIndex, rank) in ranks.enumerated() {
            var fileIndex = 0
            for char in rank {
                if char.isNumber {
                    // Empty squares
                    let emptyCount = Int(String(char)) ?? 0
                    fileIndex += emptyCount
                } else {
                    // Piece
                    if fileIndex < 8 && rankIndex < 8 {
                        let isWhite = char.isUppercase
                        let pieceType = char.lowercased()
                        boardState[rankIndex][fileIndex] = ChessPiece(type: pieceType, isWhite: isWhite)
                    }
                    fileIndex += 1
                }
            }
        }
    }
}

struct ChessPiece {
    let type: String
    let isWhite: Bool
    
    var symbol: String {
        let pieceSymbols: [String: String] = [
            "k": "♔", "q": "♕", "r": "♖", "b": "♗", "n": "♘", "p": "♙"
        ]
        return pieceSymbols[type] ?? "?"
    }
}

#Preview {
    ChessboardView(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        .padding()
} 