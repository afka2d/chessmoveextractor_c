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
            
            // Main chessboard (with coordinates inside like Lichess)
            chessboardView
            
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
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func chessSquare(row: Int, col: Int) -> some View {
        let isWhiteSquare = (row + col) % 2 == 0
        let piece = boardState[row][col]
        
        return Button(action: {
            handleSquareTap(row: row, col: col)
        }) {
            ZStack {
                // Exact Lichess brown theme colors
                Rectangle()
                    .fill(isWhiteSquare ? 
                          Color(red: 0.93, green: 0.89, blue: 0.78) :  // Light squares: warm cream
                          Color(red: 0.70, green: 0.53, blue: 0.39))   // Dark squares: warm brown
                    .frame(width: 36, height: 36)
                    .overlay(
                        Rectangle()
                            .stroke(selectedSquare?.row == row && selectedSquare?.col == col ? 
                                   Color(red: 0.95, green: 0.77, blue: 0.20).opacity(0.8) : Color.clear, 
                                   lineWidth: 3)
                    )
                
                // Coordinates (always behind pieces) - Lichess exact positioning
                ZStack(alignment: .topTrailing) {
                    // Rank numbers on RIGHT edge (h-file only)
                    if col == 7 {
                        Text("\(8 - row)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isWhiteSquare ? 
                                           Color(red: 0.70, green: 0.53, blue: 0.39).opacity(0.8) : 
                                           Color(red: 0.93, green: 0.89, blue: 0.78).opacity(0.8))
                            .padding(.trailing, 2)
                            .padding(.top, 1)
                    }
                }
                .frame(width: 36, height: 36, alignment: .topTrailing)
                
                ZStack(alignment: .bottomLeading) {
                    // File letters on bottom LEFT (1st rank only)
                    if row == 7 {
                        Text(String(Character(UnicodeScalar(97 + col)!)))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isWhiteSquare ? 
                                           Color(red: 0.70, green: 0.53, blue: 0.39).opacity(0.8) : 
                                           Color(red: 0.93, green: 0.89, blue: 0.78).opacity(0.8))
                            .padding(.leading, 2)
                            .padding(.bottom, 1)
                    }
                }
                .frame(width: 36, height: 36, alignment: .bottomLeading)
                
                // Chess piece (always on top, centered)
                if let piece = piece {
                    Image(piece.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
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
    
    var imageName: String {
        let color = isWhite ? "w" : "b"
        let piece = type.uppercased()
        return "\(color)\(piece)"
    }
    
    static func == (lhs: ChessPiece, rhs: ChessPiece) -> Bool {
        return lhs.type == rhs.type && lhs.isWhite == rhs.isWhite
    }
}

#Preview {
    ChessboardView(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        .padding()
} 