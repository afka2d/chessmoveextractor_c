# Chess Move Extractor v1.1 Release Notes

## 🎉 What's New in Version 1.1

### ✨ Major UI Improvements
- **Simplified App Flow**: Removed the captured photos screen for a cleaner, more direct experience
- **Streamlined Navigation**: After taking a photo, you go directly to corner adjustment, then to board editor
- **Better Visual Design**: Updated board colors to a custom blue-gray theme (distinct from Lichess)
- **Larger Board Size**: Increased chessboard size with proportional evaluation bar sizing

### 🎯 Enhanced User Experience
- **Swipe-to-Dismiss Messages**: Both camera and corner selector screens now have dismissible instruction messages
- **Double-Tap to Edit**: Double-tap any board to open the board editor
- **Helpful Instructions**: Added guidance messages throughout the app
- **Fixed White Screen Flash**: Eliminated temporary white screens during transitions

### 🔧 Technical Improvements
- **Optimized API Calls**: Chess analysis API only called when board state actually changes
- **Better Error Handling**: Improved handling of API responses and edge cases
- **Performance Optimizations**: Reduced unnecessary network requests and improved responsiveness

### 🎨 Board Editor Enhancements
- **Visual Evaluation Bar**: Removed numerical evaluation, keeping only the visual bar
- **Piece Symbol Notation**: Best move now shows "Qg1+" instead of "c1g1"
- **Open in Lichess**: Added button to open current position in Lichess online editor
- **Instruction Messages**: Clear guidance on how to adjust pieces manually

### 🐛 Bug Fixes
- Fixed evaluation bar not updating after board changes
- Fixed corner selector showing wrong photo
- Fixed repeated board editor opening/closing
- Fixed API response parsing issues
- Fixed various UI layout and spacing issues

## 🚀 How to Use Version 1.1

1. **Take Photo**: Point camera at chess board from white side
2. **Adjust Corners**: Manually position the four corner points
3. **Analyze Position**: Tap "Analyze Position" to get FEN notation
4. **Edit Board**: Double-tap to open board editor for manual adjustments
5. **Share or Open**: Use "Open in Lichess" to view position online

## 📱 System Requirements
- iOS 18.2 or later
- iPhone (optimized for all screen sizes)

## 🔗 API Endpoints Used
- Position Recognition: `http://159.203.102.249:8010/recognize_chess_position_with_corners`
- Chess Analysis: `https://chess-api.com/v1`
- Lichess Integration: `https://lichess.org/editor/{FEN}`

---

**Version**: 1.1  
**Build**: 2  
**Release Date**: $(date)  
**Bundle ID**: horatio.chessmoveextractorc
