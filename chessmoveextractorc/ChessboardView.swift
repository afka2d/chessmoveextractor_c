import SwiftUI

struct ChessboardView: View {
    let fen: String
    @State private var boardState: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var selectedSquare: (row: Int, col: Int)? = nil
    @State private var isEditMode: Bool = false
    @State private var selectedPieceType: String? = nil
    @State private var selectedPieceColor: Bool = true // true = white, false = black
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar - piece selection (only visible in edit mode)
            if isEditMode {
                pieceSelectionToolbar
            }
            
            // Main chessboard
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
            
            // Bottom toolbar - piece selection (only visible in edit mode)
            if isEditMode {
                pieceSelectionToolbar
            }
        }
        .onTapGesture(count: 2) {
            openInLichess()
        }
        .onLongPressGesture {
            isEditMode.toggle()
            if !isEditMode {
                selectedPieceType = nil
                selectedSquare = nil
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
        if isEditMode {
            // Edit mode: place or remove pieces
            if let pieceType = selectedPieceType {
                if pieceType == "delete" {
                    // Delete piece
                    boardState[row][col] = nil
                } else {
                    // Place selected piece
                    boardState[row][col] = ChessPiece(type: pieceType, isWhite: selectedPieceColor)
                }
            } else {
                // Remove piece if no piece type selected
                boardState[row][col] = nil
            }
        } else {
            // Normal mode: select squares for movement
            if let selected = selectedSquare {
                // If a square is already selected, try to move piece
                if selected.row != row || selected.col != col {
                    // TODO: Implement piece movement logic
                }
                selectedSquare = nil
            } else {
                // Select this square if it has a piece
                if boardState[row][col] != nil {
                    selectedSquare = (row, col)
                }
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
    
    private func openInLichess() {
        let lichessURL = "https://lichess.org/editor/\(fen.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fen)"
        
        if let url = URL(string: lichessURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private var pieceSelectionToolbar: some View {
        HStack(spacing: 8) {
            // Pointer/Selection tool
            Button(action: {
                selectedPieceType = nil
            }) {
                Image(systemName: "hand.point.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(selectedPieceType == nil ? Color.green : Color.gray)
                    .cornerRadius(6)
            }
            
            // Piece selection buttons
            ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                Button(action: {
                    selectedPieceType = pieceType
                }) {
                    Text(ChessPiece(type: pieceType, isWhite: true).symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(selectedPieceType == pieceType ? Color.blue : Color.gray)
                        .cornerRadius(6)
                }
            }
            
            // Color toggle
            Button(action: {
                selectedPieceColor.toggle()
            }) {
                Text(selectedPieceColor ? "♔" : "♚")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            
            // Delete/Clear tool
            Button(action: {
                selectedPieceType = "delete"
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(selectedPieceType == "delete" ? Color.red : Color.gray)
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(8)
    }
}

struct ChessPiece: Equatable {
    let type: String
    let isWhite: Bool
    
    var symbol: String {
        let pieceSymbols: [String: String] = [
            "k": "♔", "q": "♕", "r": "♖", "b": "♗", "n": "♘", "p": "♙"
        ]
        return pieceSymbols[type] ?? "?"
    }
    
    static func == (lhs: ChessPiece, rhs: ChessPiece) -> Bool {
        return lhs.type == rhs.type && lhs.isWhite == rhs.isWhite
    }
}

#Preview {
    ChessboardView(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        .padding()
} 