import SwiftUI

struct ChessboardView: View {
    let fen: String
    @State private var boardState: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var selectedSquare: (row: Int, col: Int)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            chessboardView
            fenDisplayView
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
        .background(Color.black)
        .cornerRadius(8)
        .shadow(radius: 3)
    }
    
    private func chessSquare(row: Int, col: Int) -> some View {
        let isWhiteSquare = (row + col) % 2 == 0
        let piece = boardState[row][col]
        
        return Button(action: {
            handleSquareTap(row: row, col: col)
        }) {
            ZStack {
                Rectangle()
                    .fill(isWhiteSquare ? Color(white: 0.9) : Color(white: 0.6))
                    .frame(width: 36, height: 36) // Reduced from 44x44
                    .overlay(
                        Rectangle()
                            .stroke(selectedSquare?.row == row && selectedSquare?.col == col ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                if let piece = piece {
                    Text(piece.symbol)
                        .font(.system(size: 28, weight: .bold)) // Reduced from 32
                        .foregroundColor(piece.isWhite ? .black : .white)
                        .background(
                            Circle()
                                .fill(piece.isWhite ? Color.white : Color.black)
                                .frame(width: 30, height: 30)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fenDisplayView: some View {
        Text("FEN: \(fen)")
            .font(.caption)
            .font(.system(.caption, design: .monospaced))
            .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
            .padding(.top, 8)
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