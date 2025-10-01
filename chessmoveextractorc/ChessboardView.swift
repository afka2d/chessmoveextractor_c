import SwiftUI

struct ChessboardView: View {
    let fen: String
    let startInEditor: Bool
    @State private var boardState: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var selectedSquare: (row: Int, col: Int)? = nil
    @State private var showEditor: Bool = false
    @State private var selectedPieceType: String? = nil
    @State private var selectedPieceColor: Bool = true // true = white, false = black
    @State private var currentFEN: String = ""
    @State private var sideToMove: Bool = true // true = white, false = black
    @State private var castlingRights: Set<String> = ["K", "Q", "k", "q"]
    @State private var showFENField: Bool = false
    @State private var isFlipped: Bool = false
    
    init(fen: String, startInEditor: Bool = false) {
        self.fen = fen
        self.startInEditor = startInEditor
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
        
        // Add side to move
        fenString += sideToMove ? " w " : " b "
        
        // Add castling rights
        if castlingRights.isEmpty {
            fenString += "-"
        } else {
            let ordered = ["K", "Q", "k", "q"].filter { castlingRights.contains($0) }
            fenString += ordered.joined()
        }
        
        // Add en passant and move counters
        fenString += " - 0 1"
        
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
                    let availableWidth = geometry.size.width - 16  // Account for horizontal padding
                    let boardWidth = availableWidth - 24 - 12  // Subtract eval bar width and spacing
                    let boardSize = min(boardWidth, geometry.size.height)
                    
                    HStack(spacing: 12) {
                        // Evaluation bar (left side) - exact board height
                        evaluationBar
                            .frame(width: 24, height: boardSize)
                        
                        // Chessboard
                        editorChessboard
                            .frame(width: boardSize, height: boardSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 8)
                
                // Best move display
                if let eval = evaluation, let move = eval.move {
                    bestMoveDisplay
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                
                Spacer(minLength: 20)
                
                // Piece palette (two rows) - Exact Lichess style
                VStack(spacing: 8) {
                    // Black pieces
                    HStack(spacing: 8) {
                        ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                            Button(action: {
                                selectedPieceType = pieceType
                                selectedPieceColor = false
                            }) {
                                Image(ChessPiece(type: pieceType, isWhite: false).imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 42, height: 42)
                                    .padding(6)
                                    .background(
                                        selectedPieceType == pieceType && !selectedPieceColor ?
                                            Color.white.opacity(0.15) : Color.clear
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // White pieces
                    HStack(spacing: 8) {
                        ForEach(["k", "q", "r", "b", "n", "p"], id: \.self) { pieceType in
                            Button(action: {
                                selectedPieceType = pieceType
                                selectedPieceColor = true
                            }) {
                                Image(ChessPiece(type: pieceType, isWhite: true).imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 42, height: 42)
                                    .padding(6)
                                    .background(
                                        selectedPieceType == pieceType && selectedPieceColor ?
                                            Color.white.opacity(0.15) : Color.clear
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(red: 0.20, green: 0.20, blue: 0.20))
                
                // Bottom action icons - Exact Lichess layout
                HStack {
                    Button(action: setStartPosition) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: { isFlipped.toggle() }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: clearBoard) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: { selectedPieceType = "delete" }) {
                        Image(systemName: "trash")
                            .font(.system(size: 24))
                            .foregroundColor(selectedPieceType == "delete" ? .white : .white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: copyFEN) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: openInLichess) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 4)
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
            // Fetch evaluation when board opens
            fetchCloudEvaluation()
        }
        .onChange(of: boardState) { _, newState in
            print("🎯 Board state changed, now has \(newState.flatMap { $0 }.compactMap { $0 }.count) pieces")
            // Re-evaluate when position changes
            fetchCloudEvaluation()
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
        if let pieceType = selectedPieceType {
            if pieceType == "delete" {
                boardState[row][col] = nil
            } else {
                boardState[row][col] = ChessPiece(type: pieceType, isWhite: selectedPieceColor)
            }
        } else {
            boardState[row][col] = nil
        }
        
        // Trigger evaluation update after changing position
        fetchCloudEvaluation()
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
                
                // Evaluation text
                if evaluation != nil {
                    Text(evaluationText(eval: evaluation))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(whiteAdvantage > 0.5 ? .black : .white)
                        .rotationEffect(.degrees(-90))
                        .frame(height: 60)
                        .position(x: 12, y: whiteAdvantage > 0.5 ? height * whiteAdvantage - 30 : height * whiteAdvantage + 30)
                }
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
                        Text(move)
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
    
    private func fetchCloudEvaluation() {
        let fen = generateFEN()
        guard let url = URL(string: "https://chess-api.com/v1") else {
            print("❌ Invalid URL for Chess API")
            return
        }
        
        print("🔍 Fetching Chess-API eval for FEN: \(fen)")
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
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
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
                    } else {
                        evaluation = result
                        print("✅ Chess-API eval: \(result.eval ?? 0.0), mate: \(result.mate ?? 0)")
                        print("✅ Best move: \(result.move ?? "none")")
                    }
                    isLoadingEval = false
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

#Preview {
    ChessboardView(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        .padding()
} 