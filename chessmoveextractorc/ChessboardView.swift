import SwiftUI

struct ChessboardView: View {
    let fen: String
    let startInEditor: Bool
    var onEditorDismiss: ((String) -> Void)?  // Callback with edited FEN when editor closes
    @State private var boardState: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var selectedSquare: (row: Int, col: Int)? = nil
    @State private var showEditor: Bool = false
    @State private var selectedPieceType: String? = nil
    @State private var selectedPieceColor: Bool = true // true = white, false = black
    @State private var currentFEN: String = ""
    @State private var sideToMove: Bool = true // true = white, false = black
    @State private var castlingRights: Set<String> = []  // No castling by default for custom positions
    @State private var showFENField: Bool = false
    @State private var isFlipped: Bool = false
    
    init(fen: String, startInEditor: Bool = false, onEditorDismiss: ((String) -> Void)? = nil) {
        self.fen = fen
        self.startInEditor = startInEditor
        self.onEditorDismiss = onEditorDismiss
        _currentFEN = State(initialValue: fen)
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if startInEditor {
                // Show editor directly
                LichessEditorView(
                    boardState: $boardState,
                    sideToMove: $sideToMove,
                    castlingRights: $castlingRights,
                    isFlipped: $isFlipped,
                    onDismiss: {
                        // Generate final FEN and call callback before dismissing
                        let finalFEN = generateFEN()
                        print("📝 Editor closing with FEN: \(finalFEN)")
                        onEditorDismiss?(finalFEN)
                        dismiss()
                    }
                )
                .onAppear {
                    // Parse FEN when editor opens
                    print("🎨 Board editor opening with FEN: \(fen)")
                    parseFEN(fen)
                    currentFEN = fen
                    print("🎨 Board state after parsing: \(boardState.flatMap { $0 }.compactMap { $0 }.count) pieces")
                }
            } else {
                // Simple board view - double-tap to edit
                chessboardView
                    .onTapGesture(count: 2) {
                        showEditor = true
                    }
                    .fullScreenCover(isPresented: $showEditor) {
                        LichessEditorView(
                            boardState: $boardState,
                            sideToMove: $sideToMove,
                            castlingRights: $castlingRights,
                            isFlipped: $isFlipped,
                            onDismiss: {
                                showEditor = false
                            }
                        )
                    }
                    .onAppear {
                        parseFEN(fen)
                        currentFEN = fen
                    }
                    .onChange(of: fen) { _, newFen in
                        parseFEN(newFen)
                        currentFEN = newFen
                    }
            }
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
        // In main view, just select squares (no editing)
        if let selected = selectedSquare {
            if selected.row != row || selected.col != col {
                // TODO: Implement piece movement logic
            }
            selectedSquare = nil
        } else {
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
    
    private func openInLichess() {
        let fenToUse = generateFEN()
        let lichessURL = "https://lichess.org/editor/\(fenToUse.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fenToUse)"
        
        if let url = URL(string: lichessURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func setStartPosition() {
        parseFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        sideToMove = true
        castlingRights = ["K", "Q", "k", "q"]
    }
    
    private func clearBoard() {
        boardState = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    }
    
    private func generateFEN() -> String {
        var fenString = ""
        
        // Generate position string
        for row in 0..<8 {
            var emptyCount = 0
            for col in 0..<8 {
                if let piece = boardState[row][col] {
                    if emptyCount > 0 {
                        fenString += "\(emptyCount)"
                        emptyCount = 0
                    }
                    let char = piece.type.lowercased()  // Ensure lowercase
                    fenString += piece.isWhite ? char.uppercased() : char
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                fenString += "\(emptyCount)"
            }
            if row < 7 {
                fenString += "/"
            }
        }
        
        // Add side to move
        fenString += sideToMove ? " w" : " b"
        
        // Add castling rights
        fenString += " "
        if castlingRights.isEmpty {
            fenString += "-"
        } else {
            let ordered = ["K", "Q", "k", "q"].filter { castlingRights.contains($0) }
            fenString += ordered.joined()
        }
        
        // Add en passant and move counters
        fenString += " - 0 1"
        
        print("📋 Generated FEN: \(fenString)")
        return fenString
    }
    
    private var draggablePiecePalette: some View {
        VStack(spacing: 12) {
            // Black pieces row
            HStack(spacing: 16) {
                ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                    Button(action: {
                        selectedPieceType = pieceType
                        selectedPieceColor = false // Black
                    }) {
                        Image(ChessPiece(type: pieceType, isWhite: false).imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding(8)
                            .background(
                                selectedPieceType == pieceType && !selectedPieceColor ? 
                                    Color.white.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(8)
                    }
                }
            }
            
            // White pieces row
            HStack(spacing: 16) {
                ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                    Button(action: {
                        selectedPieceType = pieceType
                        selectedPieceColor = true // White
                    }) {
                        Image(ChessPiece(type: pieceType, isWhite: true).imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding(8)
                            .background(
                                selectedPieceType == pieceType && selectedPieceColor ? 
                                    Color.white.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var actionButtonBar: some View {
        HStack(spacing: 24) {
            // Settings/Start Position
            Button(action: setStartPosition) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Flip board
            Button(action: { isFlipped.toggle() }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Clear board
            Button(action: clearBoard) {
                Image(systemName: "xmark")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Delete/Trash
            Button(action: {
                selectedPieceType = "delete"
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 24))
                    .foregroundColor(selectedPieceType == "delete" ? .white : .white.opacity(0.7))
            }
            
            // Copy FEN / Export
            Button(action: {
                UIPasteboard.general.string = generateFEN()
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Share / Open in Lichess
            Button(action: openInLichess) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal)
    }
    
    private var editorControlPanel: some View {
        HStack(spacing: 10) {
            // Start Position
            Button(action: setStartPosition) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                    Text("Start")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 44)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(8)
            }
            
            // Clear Board
            Button(action: clearBoard) {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("Clear")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 44)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }
            
            // Flip Board
            Button(action: { isFlipped.toggle() }) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14))
                    Text("Flip")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 44)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Side to Move Toggle
            Button(action: { sideToMove.toggle() }) {
                VStack(spacing: 2) {
                    Text(sideToMove ? "♔" : "♚")
                        .font(.system(size: 18))
                    Text(sideToMove ? "White" : "Black")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 44)
                .background(Color.purple.opacity(0.8))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    private var fenControlPanel: some View {
        VStack(spacing: 8) {
            // FEN Display/Edit
            HStack(spacing: 8) {
                Text("FEN:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(generateFEN())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                
                // Copy FEN button
                Button(action: {
                    UIPasteboard.general.string = generateFEN()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(6)
                }
            }
            
            // Castling Rights
            HStack(spacing: 8) {
                Text("Castling:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                ForEach(["K", "Q", "k", "q"], id: \.self) { right in
                    Button(action: {
                        if castlingRights.contains(right) {
                            castlingRights.remove(right)
                        } else {
                            castlingRights.insert(right)
                        }
                    }) {
                        Text(right)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(castlingRights.contains(right) ? Color.green : Color.gray)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
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

// Chess-API.com Evaluation Response
struct ChessAPIEval: Codable {
    let type: String?  // "move", "bestmove", "error"
    let error: String?
    let eval: Double?
    let move: String?
    let mate: Int?
    let depth: Int?
    let continuationArr: [String]?
    let text: String?
    let winChance: Double?
    let centipawns: String?
    
    // Custom decoding to handle mate as either string or int, and centipawns as either string or int
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decodeIfPresent(String.self, forKey: .type)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        eval = try container.decodeIfPresent(Double.self, forKey: .eval)
        move = try container.decodeIfPresent(String.self, forKey: .move)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        continuationArr = try container.decodeIfPresent([String].self, forKey: .continuationArr)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        winChance = try container.decodeIfPresent(Double.self, forKey: .winChance)
        
        // Handle mate as either string or int
        if let mateString = try? container.decodeIfPresent(String.self, forKey: .mate) {
            mate = Int(mateString)
        } else {
            mate = try container.decodeIfPresent(Int.self, forKey: .mate)
        }
        
        // Handle centipawns as either string or int
        if let centipawnsString = try? container.decodeIfPresent(String.self, forKey: .centipawns) {
            centipawns = centipawnsString
        } else if let centipawnsInt = try? container.decodeIfPresent(Int.self, forKey: .centipawns) {
            centipawns = String(centipawnsInt)
        } else {
            centipawns = nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, error, eval, move, mate, depth, continuationArr, text, winChance, centipawns
    }
}

// Fullscreen Lichess-style Editor
struct LichessEditorView: View {
    @Binding var boardState: [[ChessPiece?]]
    @Binding var sideToMove: Bool
    @Binding var castlingRights: Set<String>
    @Binding var isFlipped: Bool
    let onDismiss: () -> Void
    
    @State private var selectedPieceType: String? = nil
    @State private var selectedPieceColor: Bool = true
    @State private var dragOffset: CGFloat = 0
    @State private var evaluation: ChessAPIEval? = nil
    @State private var isLoadingEval: Bool = false
    @State private var positionError: String? = nil
    @State private var selectedBoardPiece: (row: Int, col: Int)? = nil
    @State private var lastEvaluatedFEN: String? = nil
    
    var body: some View {
        ZStack {
            Color(red: 0.18, green: 0.18, blue: 0.18).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top: Swipe indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // Main chessboard with evaluation bar
                Spacer(minLength: 20)
                
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let totalHeight = geometry.size.height
                    // Account for padding and eval bar
                    let availableWidth = totalWidth - 40  // 8px padding each side + margins
                    let availableHeight = totalHeight
                    let boardSize = min(availableWidth - 36, availableHeight)  // 36 = eval bar (24) + spacing (12)
                    
                    HStack(spacing: 8) {
                        // Evaluation bar (left side) - exact board height
                        evaluationBar
                            .frame(width: 20, height: boardSize)
                        
                        // Chessboard
                        editorChessboard
                            .frame(width: boardSize, height: boardSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 12)
                
                // Position error message or best move display
                if let error = positionError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                } else if let eval = evaluation, eval.move != nil {
                    bestMoveDisplay
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                
                Spacer(minLength: 20)
                
                // Piece palette (two rows) - Exact Lichess style
                VStack(spacing: 6) {
                    // Black pieces
                    HStack(spacing: 6) {
                        // Trash/delete tool
                        Button(action: {
                            selectedPieceType = "delete"
                            selectedBoardPiece = nil
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .padding(4)
                                .background(
                                    selectedPieceType == "delete" ?
                                        Color.red.opacity(0.3) : Color.clear
                                )
                                .cornerRadius(6)
                        }
                        
                        ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                            Button(action: {
                                selectedPieceType = pieceType
                                selectedPieceColor = false
                                selectedBoardPiece = nil
                            }) {
                                Image(ChessPiece(type: pieceType, isWhite: false).imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 36, height: 36)
                                    .padding(4)
                                    .background(
                                        selectedPieceType == pieceType && !selectedPieceColor ?
                                            Color.white.opacity(0.15) : Color.clear
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // White pieces
                    HStack(spacing: 6) {
                        // Clear selection tool
                        Button(action: {
                            selectedPieceType = nil
                            selectedBoardPiece = nil
                        }) {
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .padding(4)
                                .background(
                                    selectedPieceType == nil ?
                                        Color.green.opacity(0.3) : Color.clear
                                )
                                .cornerRadius(6)
                        }
                        
                        ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                            Button(action: {
                                selectedPieceType = pieceType
                                selectedPieceColor = true
                                selectedBoardPiece = nil
                            }) {
                                Image(ChessPiece(type: pieceType, isWhite: true).imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 36, height: 36)
                                    .padding(4)
                                    .background(
                                        selectedPieceType == pieceType && selectedPieceColor ?
                                            Color.white.opacity(0.15) : Color.clear
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .padding(.bottom, 16)
                .background(Color(red: 0.20, green: 0.20, blue: 0.20))
                .onTapGesture {
                    // Tap outside board to deselect and remove selected piece
                    if let selected = selectedBoardPiece {
                        boardState[selected.row][selected.col] = nil
                        selectedBoardPiece = nil
                        // Force state update and evaluation
                        let newState = boardState
                        boardState = newState
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            fetchCloudEvaluation()
                        }
                    }
                }
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if gesture.translation.height > 0 {
                        dragOffset = gesture.translation.height
                    }
                }
                .onEnded { gesture in
                    if gesture.translation.height > 150 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = 1000
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            print("🎯 LichessEditorView appeared")
            print("🎯 Board state has \(boardState.flatMap { $0 }.compactMap { $0 }.count) pieces")
            
            // Small delay to ensure UI has rendered pieces before fetching evaluation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🎯 Delayed evaluation fetch, board now has \(boardState.flatMap { $0 }.compactMap { $0 }.count) pieces")
                fetchCloudEvaluation()
            }
        }
        .onChange(of: boardState) { oldState, newState in
            let oldPieceCount = oldState.flatMap { $0 }.compactMap { $0 }.count
            let newPieceCount = newState.flatMap { $0 }.compactMap { $0 }.count
            
            print("🎯 Board state changed from \(oldPieceCount) to \(newPieceCount) pieces")
            print("🎯 Old state: \(oldState)")
            print("🎯 New state: \(newState)")
            
            // Always trigger evaluation when board state changes
            // Add small delay to avoid rapid-fire API calls
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                print("🎯 Triggering evaluation after board change")
                fetchCloudEvaluation()
            }
        }
    }
    
    private var editorChessboard: some View {
        GeometryReader { geometry in
            let boardSize = min(geometry.size.width, geometry.size.height)
            let squareSize = boardSize / 8
            
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            editorSquare(row: row, col: col, squareSize: squareSize)
                        }
                    }
                }
            }
            .frame(width: boardSize, height: boardSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func editorSquare(row: Int, col: Int, squareSize: CGFloat) -> some View {
        let isWhiteSquare = (row + col) % 2 == 0
        let piece = boardState[row][col]
        
        return Button(action: {
            handleSquareTap(row: row, col: col)
        }) {
            ZStack {
                Rectangle()
                    .fill(isWhiteSquare ?
                          Color(red: 0.93, green: 0.89, blue: 0.78) :
                          Color(red: 0.70, green: 0.53, blue: 0.39))
                    .frame(width: squareSize, height: squareSize)
                    .overlay(
                        Rectangle()
                            .stroke(
                                selectedBoardPiece?.row == row && selectedBoardPiece?.col == col ?
                                    Color.yellow.opacity(0.8) : Color.clear,
                                lineWidth: 3
                            )
                    )
                
                // Rank numbers on RIGHT edge (h-file) - top-right corner
                if col == 7 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(8 - row)")
                                .font(.system(size: squareSize * 0.22, weight: .bold))
                                .foregroundColor(isWhiteSquare ?
                                               Color(red: 0.70, green: 0.53, blue: 0.39).opacity(0.8) :
                                               Color(red: 0.93, green: 0.89, blue: 0.78).opacity(0.8))
                                .padding(.trailing, squareSize * 0.06)
                                .padding(.top, squareSize * 0.03)
                        }
                        Spacer()
                    }
                    .frame(width: squareSize, height: squareSize)
                }
                
                // File letters on BOTTOM edge - bottom-left corner
                if row == 7 {
                    VStack {
                        Spacer()
                        HStack {
                            Text(String(Character(UnicodeScalar(97 + col)!)))
                                .font(.system(size: squareSize * 0.22, weight: .bold))
                                .foregroundColor(isWhiteSquare ?
                                               Color(red: 0.70, green: 0.53, blue: 0.39).opacity(0.8) :
                                               Color(red: 0.93, green: 0.89, blue: 0.78).opacity(0.8))
                                .padding(.leading, squareSize * 0.06)
                                .padding(.bottom, squareSize * 0.03)
                            Spacer()
                        }
                    }
                    .frame(width: squareSize, height: squareSize)
                }
                
                // Piece
                if let piece = piece {
                    Image(piece.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: squareSize * 0.75, height: squareSize * 0.75)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: squareSize, height: squareSize)
    }
    
    private func handleSquareTap(row: Int, col: Int) {
        print("🎯 Square tapped at row: \(row), col: \(col)")
        print("🎯 Selected piece type: \(selectedPieceType ?? "nil")")
        print("🎯 Selected piece color: \(selectedPieceColor)")
        
        // If a piece from palette is selected, place or delete
        if let pieceType = selectedPieceType {
            print("🎯 Placing piece: \(pieceType) (\(selectedPieceColor ? "white" : "black")) at (\(row), \(col))")
            if pieceType == "delete" {
                boardState[row][col] = nil
                print("🎯 Deleted piece at (\(row), \(col))")
            } else {
                boardState[row][col] = ChessPiece(type: pieceType, isWhite: selectedPieceColor)
                print("🎯 Placed piece at (\(row), \(col))")
            }
            // Force state update - onChange will handle evaluation
            let newState = boardState
            boardState = newState
            print("🎯 Board state updated")
        }
        // If no palette piece selected, select the board piece for removal
        else if boardState[row][col] != nil {
            selectedBoardPiece = (row, col)
            print("🎯 Selected board piece at (\(row), \(col))")
        }
        // If tapping empty square with board piece selected, cancel selection
        else {
            selectedBoardPiece = nil
            print("🎯 Cancelled piece selection")
        }
    }
    
    private func setStartPosition() {
        let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
        parseFEN(startFEN)
        sideToMove = true
        castlingRights = ["K", "Q", "k", "q"]
        fetchCloudEvaluation()
    }
    
    private func clearBoard() {
        boardState = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        evaluation = nil  // Clear evaluation for empty board
    }
    
    private var evaluationBar: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let whiteAdvantage = evaluationToPercentage()
            
            ZStack(alignment: .bottom) {
                // Black advantage (top)
                Rectangle()
                    .fill(Color.black)
                
                // White advantage (bottom)
                Rectangle()
                    .fill(Color.white)
                    .frame(height: height * whiteAdvantage)
                
                // Evaluation text removed - only show visual bar
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var bestMoveDisplay: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Best move
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Move")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if let move = evaluation?.move {
                        Text(formatMoveWithPiece(move: move))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Evaluation
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Evaluation")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if let evalValue = evaluation?.eval {
                        Text(String(format: "%+.2f", evalValue))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(evalColor(eval: evalValue))
                    } else if let mate = evaluation?.mate {
                        Text("M\(abs(mate))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(mate > 0 ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            // Continuation line
            if let continuation = evaluation?.continuationArr, !continuation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continuation")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(continuation.prefix(5).joined(separator: " "))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private func evaluationToPercentage() -> CGFloat {
        guard let eval = evaluation else {
            return 0.5  // Equal position
        }
        
        if let mate = eval.mate {
            return mate > 0 ? 0.95 : 0.05
        }
        
        if let evalValue = eval.eval {
            // Chess-API returns eval as pawns (e.g., 1.5 = +1.5 pawns)
            let normalizedEval = evalValue / 10.0  // Divide by 10 pawns for scaling
            let percentage = 0.5 + (normalizedEval / 2.0)
            return CGFloat(max(0.05, min(0.95, percentage)))
        }
        
        return 0.5
    }
    
    private func evaluationText(eval: ChessAPIEval?) -> String {
        guard let eval = eval else { return "0.0" }
        
        if let mate = eval.mate {
            return "M\(abs(mate))"
        }
        
        if let evalValue = eval.eval {
            return String(format: "%.1f", evalValue)
        }
        
        return "0.0"
    }
    
    private func evalColor(eval: Double) -> Color {
        if eval > 1.0 { return Color.green }
        if eval < -1.0 { return Color.red }
        return Color.yellow
    }
    
    private func formatMoveWithPiece(move: String) -> String {
        // Convert move from "c1g1" format to "Qg1+" format
        guard move.count == 4 else { return move }
        
        let fromSquare = String(move.prefix(2))
        let toSquare = String(move.suffix(2))
        
        // Get the piece at the from square
        let fromCol = Int(fromSquare.first!.asciiValue! - Character("a").asciiValue!)
        let fromRow = Int(fromSquare.last!.asciiValue! - Character("1").asciiValue!)
        
        guard fromRow >= 0 && fromRow < 8 && fromCol >= 0 && fromCol < 8 else { return move }
        
        let piece = boardState[7 - fromRow][fromCol]
        let pieceSymbol = getPieceSymbol(piece: piece)
        
        // Check if it's a capture by seeing if there's a piece at the destination
        let toCol = Int(toSquare.first!.asciiValue! - Character("a").asciiValue!)
        let toRow = Int(toSquare.last!.asciiValue! - Character("1").asciiValue!)
        
        guard toRow >= 0 && toRow < 8 && toCol >= 0 && toCol < 8 else { return move }
        
        let capturedPiece = boardState[7 - toRow][toCol]
        let isCapture = capturedPiece != nil
        
        // Check if it's check by generating FEN and checking if king is in check
        let isCheck = checkIfMoveIsCheck(from: fromSquare, to: toSquare)
        
        var result = pieceSymbol + toSquare
        if isCapture { result += "x" }
        if isCheck { result += "+" }
        
        return result
    }
    
    private func getPieceSymbol(piece: ChessPiece?) -> String {
        guard let piece = piece else { return "P" } // Default to pawn if no piece
        
        let symbols: [String: String] = [
            "k": "K", "q": "Q", "r": "R", "b": "B", "n": "N", "p": ""
        ]
        
        let symbol = symbols[piece.type] ?? ""
        return piece.isWhite ? symbol : symbol.lowercased()
    }
    
    private func checkIfMoveIsCheck(from: String, to: String) -> Bool {
        // Simplified check detection - in a real implementation you'd need to
        // simulate the move and check if the opponent's king is in check
        // For now, we'll just return false to avoid complexity
        return false
    }
    
    private func fetchCloudEvaluation() {
        let fen = generateFEN()
        
        print("🔍 fetchCloudEvaluation called with FEN: \(fen)")
        print("🔍 Last evaluated FEN: \(lastEvaluatedFEN ?? "nil")")
        print("🔍 Is loading: \(isLoadingEval)")
        
        // Skip if we already evaluated this exact position
        if lastEvaluatedFEN == fen {
            print("🔍 Skipping evaluation - same FEN as last evaluation: \(fen)")
            return
        }
        
        // Skip if already loading
        if isLoadingEval {
            print("🔍 Skipping evaluation - already loading")
            return
        }
        
        // Validate FEN has required kings
        let pieces = boardState.flatMap { $0 }.compactMap { $0 }
        let whiteKings = pieces.filter { $0.type == "k" && $0.isWhite }.count
        let blackKings = pieces.filter { $0.type == "k" && !$0.isWhite }.count
        
        if whiteKings != 1 || blackKings != 1 {
            var errorMsg = "Invalid position: "
            if whiteKings == 0 { errorMsg += "missing white king" }
            else if whiteKings > 1 { errorMsg += "\(whiteKings) white kings (need exactly 1)" }
            if blackKings == 0 { errorMsg += (whiteKings != 1 ? ", " : "") + "missing black king" }
            else if blackKings > 1 { errorMsg += (whiteKings != 1 ? ", " : "") + "\(blackKings) black kings (need exactly 1)" }
            
            positionError = errorMsg
            evaluation = nil
            isLoadingEval = false
            lastEvaluatedFEN = fen
            print("❌ \(errorMsg)")
            return
        }
        
        guard let url = URL(string: "https://chess-api.com/v1") else {
            print("❌ Invalid URL for Chess API")
            return
        }
        
        print("🔍 Fetching Chess-API eval for FEN: \(fen)")
        print("🔍 FEN length: \(fen.count) characters")
        print("🔍 FEN components: \(fen.components(separatedBy: " "))")
        print("🔍 Board has \(pieces.count) pieces")
        print("🔍 White pieces: \(pieces.filter { $0.isWhite }.count)")
        print("🔍 Black pieces: \(pieces.filter { !$0.isWhite }.count)")
        
        // Print piece by piece for debugging
        for row in 0..<8 {
            var rowStr = ""
            for col in 0..<8 {
                if let piece = boardState[row][col] {
                    rowStr += piece.isWhite ? piece.type.uppercased() : piece.type.lowercased()
                } else {
                    rowStr += "."
                }
            }
            print("🔍 Row \(row): \(rowStr)")
        }
        
        positionError = nil  // Clear any previous error
        isLoadingEval = true
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let requestBody: [String: Any] = [
                    "fen": fen,
                    "depth": 15,  // Good balance of speed vs accuracy
                    "variants": 1
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("🔍 Request body: \(jsonString)")
                }
                request.httpBody = jsonData
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Log raw response
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 Chess-API HTTP status: \(httpResponse.statusCode)")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("🔍 Chess-API response: \(jsonString)")
                }
                
                let decoder = JSONDecoder()
                let result = try decoder.decode(ChessAPIEval.self, from: data)
                
                await MainActor.run {
                    if result.type == "error" {
                        print("❌ Chess-API error: \(result.error ?? "unknown"), text: \(result.text ?? "")")
                        evaluation = nil
                        positionError = result.text ?? "Invalid position"
                    } else {
                        evaluation = result
                        positionError = nil
                        print("✅ Chess-API eval: \(result.eval ?? 0.0), mate: \(result.mate ?? 0)")
                        print("✅ Best move: \(result.move ?? "none")")
                        print("🔍 Evaluation state updated - evaluation: \(evaluation?.eval ?? 0)")
                    }
                    isLoadingEval = false
                    lastEvaluatedFEN = fen
                }
            } catch {
                await MainActor.run {
                    isLoadingEval = false
                    print("❌ Chess-API error: \(error)")
                }
            }
        }
    }
    
    private func copyFEN() {
        UIPasteboard.general.string = generateFEN()
    }
    
    private func openInLichess() {
        let fenToUse = generateFEN()
        let lichessURL = "https://lichess.org/editor/\(fenToUse.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fenToUse)"
        if let url = URL(string: lichessURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func parseFEN(_ fenString: String) {
        let components = fenString.components(separatedBy: " ")
        guard components.count >= 1 else { return }
        
        let positionString = components[0]
        let ranks = positionString.components(separatedBy: "/")
        
        boardState = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        
        for (rankIndex, rank) in ranks.enumerated() {
            var fileIndex = 0
            for char in rank {
                if char.isNumber {
                    let emptyCount = Int(String(char)) ?? 0
                    fileIndex += emptyCount
                } else {
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
    
    private func generateFEN() -> String {
        var fenString = ""
        
        for row in 0..<8 {
            var emptyCount = 0
            for col in 0..<8 {
                if let piece = boardState[row][col] {
                    if emptyCount > 0 {
                        fenString += "\(emptyCount)"
                        emptyCount = 0
                    }
                    let char = piece.type
                    fenString += piece.isWhite ? char.uppercased() : char.lowercased()
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                fenString += "\(emptyCount)"
            }
            if row < 7 {
                fenString += "/"
            }
        }
        
        fenString += sideToMove ? " w " : " b "
        
        if castlingRights.isEmpty {
            fenString += "-"
        } else {
            let ordered = ["K", "Q", "k", "q"].filter { castlingRights.contains($0) }
            fenString += ordered.joined()
        }
        
        fenString += " - 0 1"
        
        return fenString
    }
}

// Simplified read-only chessboard for the captured photos screen
struct SimplifiedChessboardView: View {
    let fen: String
    let onDoubleTap: (() -> Void)?  // Optional callback for double-tap
    @State private var boardState: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var evaluation: ChessAPIEval? = nil
    @State private var isLoadingEval: Bool = false
    
    init(fen: String, onDoubleTap: (() -> Void)? = nil) {
        self.fen = fen
        self.onDoubleTap = onDoubleTap
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            // Make board height match the available height (photo height)
            let boardSize = totalHeight
            let evaluationBarWidth: CGFloat = 8  // Thinner evaluation bar
            
            HStack(spacing: 4) {  // Reduced spacing
                // Evaluation bar (left side) - thinner
                evaluationBar
                    .frame(width: evaluationBarWidth, height: boardSize)
                
                // Chessboard - now matches photo height
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                square(row: row, col: col, squareSize: boardSize / 8)
                            }
                        }
                    }
                }
                .frame(width: boardSize, height: boardSize)
                .onTapGesture(count: 2) {
                    onDoubleTap?()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            parseFEN(fen)
            fetchEvaluation()
        }
        .onChange(of: fen) { _, newFEN in
            parseFEN(newFEN)
            fetchEvaluation()
        }
    }
    
    private var evaluationBar: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let whiteAdvantage = evaluationToPercentage()
            
            ZStack(alignment: .bottom) {
                // Black advantage (top)
                Rectangle()
                    .fill(Color.black)
                
                // White advantage (bottom)
                Rectangle()
                    .fill(Color.white)
                    .frame(height: height * whiteAdvantage)
                
                // Evaluation text
                if let eval = evaluation {
                    Text(evaluationText(eval: eval))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(whiteAdvantage > 0.5 ? .black : .white)
                        .rotationEffect(.degrees(-90))
                        .frame(maxHeight: .infinity)
                }
            }
            .cornerRadius(3)
        }
    }
    
    private func evaluationToPercentage() -> CGFloat {
        guard let eval = evaluation else {
            return 0.5
        }
        
        if let mate = eval.mate {
            return mate > 0 ? 0.95 : 0.05
        }
        
        if let evalValue = eval.eval {
            let normalizedEval = evalValue / 10.0
            let percentage = 0.5 + (normalizedEval / 2.0)
            return CGFloat(max(0.05, min(0.95, percentage)))
        }
        
        return 0.5
    }
    
    private func evaluationText(eval: ChessAPIEval) -> String {
        if let mate = eval.mate {
            return "M\(abs(mate))"
        }
        
        if let evalValue = eval.eval {
            return String(format: "%.1f", evalValue)
        }
        
        return "0.0"
    }
    
    private func fetchEvaluation() {
        // Validate FEN has required kings
        let pieces = boardState.flatMap { $0 }.compactMap { $0 }
        let whiteKings = pieces.filter { $0.type == "k" && $0.isWhite }.count
        let blackKings = pieces.filter { $0.type == "k" && !$0.isWhite }.count
        
        if whiteKings != 1 || blackKings != 1 {
            evaluation = nil
            isLoadingEval = false
            return
        }
        
        guard let url = URL(string: "https://chess-api.com/v1") else {
            return
        }
        
        isLoadingEval = true
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let requestBody: [String: Any] = [
                    "fen": fen,
                    "depth": 15,
                    "variants": 1
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoder = JSONDecoder()
                let result = try decoder.decode(ChessAPIEval.self, from: data)
                
                await MainActor.run {
                    if result.type != "error" {
                        evaluation = result
                    } else {
                        evaluation = nil
                    }
                    isLoadingEval = false
                }
            } catch {
                await MainActor.run {
                    evaluation = nil
                    isLoadingEval = false
                }
            }
        }
    }
    
    private func square(row: Int, col: Int, squareSize: CGFloat) -> some View {
        let isWhiteSquare = (row + col) % 2 == 0
        let piece = boardState[row][col]
        
        return ZStack {
            // Square background
            Rectangle()
                .fill(isWhiteSquare ?
                      Color(red: 0.93, green: 0.89, blue: 0.78) :
                      Color(red: 0.70, green: 0.53, blue: 0.39))
                .frame(width: squareSize, height: squareSize)
            
            // Rank numbers on RIGHT edge - top-right corner
            if col == 7 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(8 - row)")
                            .font(.system(size: squareSize * 0.22, weight: .bold))
                            .foregroundColor(isWhiteSquare ?
                                           Color(red: 0.70, green: 0.53, blue: 0.39).opacity(0.8) :
                                           Color(red: 0.93, green: 0.89, blue: 0.78).opacity(0.8))
                            .padding(.trailing, squareSize * 0.06)
                            .padding(.top, squareSize * 0.03)
                    }
                    Spacer()
                }
                .frame(width: squareSize, height: squareSize)
            }
            
            // File letters on BOTTOM edge - bottom-left corner
            if row == 7 {
                VStack {
                    Spacer()
                    HStack {
                        Text(String(Character(UnicodeScalar(97 + col)!)))
                            .font(.system(size: squareSize * 0.22, weight: .bold))
                            .foregroundColor(isWhiteSquare ?
                                           Color(red: 0.70, green: 0.53, blue: 0.39).opacity(0.8) :
                                           Color(red: 0.93, green: 0.89, blue: 0.78).opacity(0.8))
                            .padding(.leading, squareSize * 0.06)
                            .padding(.bottom, squareSize * 0.03)
                        Spacer()
                    }
                }
                .frame(width: squareSize, height: squareSize)
            }
            
            // Piece
            if let piece = piece {
                Image(piece.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: squareSize * 0.75, height: squareSize * 0.75)
            }
        }
        .frame(width: squareSize, height: squareSize)
    }
    
    private func parseFEN(_ fen: String) {
        let components = fen.components(separatedBy: " ")
        guard components.count >= 1 else { return }
        
        let positionString = components[0]
        let ranks = positionString.components(separatedBy: "/")
        
        boardState = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        
        for (rankIndex, rank) in ranks.enumerated() {
            var fileIndex = 0
            for char in rank {
                if char.isNumber {
                    let emptyCount = Int(String(char)) ?? 0
                    fileIndex += emptyCount
                } else {
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

#Preview {
    ChessboardView(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        .padding()
} 