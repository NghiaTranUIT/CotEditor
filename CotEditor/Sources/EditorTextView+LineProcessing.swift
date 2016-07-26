/*
 
 EditorTextView+LineProcessing.swift
 
 CotEditor
 http://coteditor.com
 
 Created by 1024jp on 2016-01-10.
 
 ------------------------------------------------------------------------------
 
 © 2014-2016 1024jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

import Foundation

extension EditorTextView {
    
    // MARK: Action Messages
    
    /// move selected line up
    @IBAction func moveLineUp(_ sender: AnyObject?) {
        
        guard let textStorage = self.textStorage else { return }
        
        // get line ranges to process
        let lineRanges = self.selectedLineRanges
        
        // cannot perform Move Line Up if one of the selections is already in the first line
        guard !lineRanges.isEmpty, lineRanges.first?.location != 0 else {
            NSBeep()
            return
        }
        
        let selectedRanges = self.selectedRanges as! [NSRange]
        
        // register redo for text selection
        self.undoManager?.prepare(withInvocationTarget: self).setSelectedRangesWithUndo(self.selectedRanges)
        
        var newSelectedRanges = [NSRange]()
        
        // swap lines
        textStorage.beginEditing()
        for lineRange in lineRanges {
            let string = textStorage.string as NSString
            
            let upperLineRange = string.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
            var lineString = string.substring(with: lineRange)
            var upperLineString = string.substring(with: upperLineRange)
            
            // last line
            if !lineString.hasSuffix("\n") {
                lineString += "\n"
                upperLineString = upperLineString.trimmingCharacters(in: .newlines)
            }
            
            let replacementString = lineString + upperLineString
            let editRange = NSRange(location: upperLineRange.location, length: replacementString.utf16.count)
            
            // swap
            guard self.shouldChangeText(in: editRange, replacementString: replacementString) else { continue }
            
            textStorage.replaceCharacters(in: editRange, with: replacementString)
            self.didChangeText()
            
            // move selected ranges in the line to move
            for selectedRange in selectedRanges {
                let intersectionRange = NSIntersectionRange(selectedRange, editRange)
                
                if intersectionRange.length > 0 {
                    newSelectedRanges.append(NSRange(location: intersectionRange.location - upperLineRange.length,
                                                     length: intersectionRange.length))
                    
                } else if NSLocationInRange(selectedRange.location, editRange) {
                    newSelectedRanges.append(NSRange(location: selectedRange.location - upperLineRange.length,
                                                     length: selectedRange.length))
                }
            }
        }
        textStorage.endEditing()
        
        self.setSelectedRangesWithUndo(newSelectedRanges)
        
        self.undoManager?.setActionName(NSLocalizedString("Move Line", comment: "action name"))
    }
    
    
    /// move selected line down
    @IBAction func moveLineDown(_ sender: AnyObject?) {
        
        guard let textStorage = self.textStorage else { return }
        
        // get line ranges to process
        let lineRanges = self.selectedLineRanges
        
        // cannot perform Move Line Down if one of the selections is already in the last line
        if lineRanges.last?.max == textStorage.length {
            NSBeep()
            return
        }
        
        let selectedRanges = self.selectedRanges as! [NSRange]
        
        // register redo for text selection
        self.undoManager?.prepare(withInvocationTarget: self).setSelectedRangesWithUndo(self.selectedRanges)
        
        var newSelectedRanges = [NSRange]()
        
        // swap lines
        textStorage.beginEditing()
        for lineRange in lineRanges.reversed() {
            let string = textStorage.string as NSString
            
            var lowerLineRange = string.lineRange(for: NSRange(location: lineRange.max, length: 0))
            var lineString = string.substring(with: lineRange)
            var lowerLineString = string.substring(with: lowerLineRange)
            
            // last line
            if !lowerLineString.hasSuffix("\n") {
                lineString = lineString.trimmingCharacters(in: .newlines)
                lowerLineString += "\n"
                lowerLineRange.length += 1
            }
            
            let replacementString = lowerLineString + lineString
            let editRange = NSRange(location: lineRange.location, length: replacementString.utf16.count)
            
            // swap
            guard self.shouldChangeText(in: editRange, replacementString: replacementString) else { continue }
            
            textStorage.replaceCharacters(in: editRange, with: replacementString)
            self.didChangeText()
            
            // move selected ranges in the line to move
            for selectedRange in selectedRanges {
                let intersectionRange = NSIntersectionRange(selectedRange, editRange)
                
                if intersectionRange.length > 0 {
                    newSelectedRanges.append(NSRange(location: intersectionRange.location + lowerLineRange.length,
                                                     length: intersectionRange.length))
                    
                } else if NSLocationInRange(selectedRange.location, editRange) {
                    newSelectedRanges.append(NSRange(location: selectedRange.location + lowerLineRange.length,
                                                     length: selectedRange.length))
                }
            }
        }
        textStorage.endEditing()
        
        self.setSelectedRangesWithUndo(newSelectedRanges)
        
        self.undoManager?.setActionName(NSLocalizedString("Move Line", comment: "action name"))
    }
    
    
    /// sort selected lines (only in the first selection) ascending
    @IBAction func sortLinesAscending(_ sender: AnyObject?) {
        
        guard let string = self.string as NSString? else { return }
        
        // process whole document if no text selected
        if self.selectedRange().length == 0 {
            self.setSelectedRange(string.range)
        }
        
        let lineRange = string.lineRange(for: self.selectedRange(), excludingLastLineEnding: true)
        
        guard lineRange.length > 0 else { return }
        
        var lines = string.substring(with: lineRange).components(separatedBy: .newlines)
        
        // do nothing with single line
        guard lines.count > 1 else { return }
        
        // sort alphabetically ignoring case
        lines.sort { $0.localizedCompare($1) == .orderedAscending }
        
        let newString = lines.joined(separator: "\n")
        
        self.replace(with: newString, range: lineRange, selectedRange: lineRange,
                     actionName: NSLocalizedString("Sort Lines", comment: "action name"))
    }
    
    
    /// reverse selected lines (only in the first selection)
    @IBAction func reverseLines(_ sender: AnyObject?) {
        
        guard let string = self.string as NSString? else { return }
        
        // process whole document if no text selected
        if self.selectedRange().length == 0 {
            self.setSelectedRange(string.range)
        }
        
        let lineRange = string.lineRange(for: self.selectedRange(), excludingLastLineEnding: true)
        
        guard lineRange.length > 0 else { return }
        
        let lines = string.substring(with: lineRange).components(separatedBy: .newlines)
        
        // do nothing with single line
        guard lines.count > 1 else { return }
        
        // make new string
        let newString = lines.reversed().joined(separator: "\n")
        
        self.replace(with: newString, range: lineRange, selectedRange: lineRange,
                     actionName: NSLocalizedString("Reverse Lines", comment: "action name"))
    }
    
    
    /// delete duplicate lines in selection
    @IBAction func deleteDuplicateLine(_ sender: AnyObject?) {
        
        guard let string = self.string as NSString? else { return }
        
        // process whole document if no text selected
        if self.selectedRange().length == 0 {
            self.setSelectedRange(string.range)
        }
        
        guard self.selectedRange().length > 0 else { return }
        
        var replacementRanges = [NSRange]()
        var replacementStrings = [String]()
        let uniqueLines = NSMutableOrderedSet()  // [String]
        var processedCount = 0
        
        // collect duplicate lines
        for range in self.selectedRanges as! [NSRange] {
            let lineRange = string.lineRange(for: range, excludingLastLineEnding: true)
            let targetString = string.substring(with: lineRange)
            let lines = targetString.components(separatedBy: CharacterSet.newlines)
            
            // filter duplicate lines
            uniqueLines.addObjects(from: lines)
            
            let targetLinesRange: Range<Int> = processedCount..<uniqueLines.count
            processedCount += targetLinesRange.count
            
            // do nothing if no duplicate line exists
            guard targetLinesRange.count != lines.count else { continue }
            
            let indexSet = IndexSet(integersIn: targetLinesRange)
            let replacementString = (uniqueLines.objects(at: indexSet) as! [String]).joined(separator: "\n")
            
            replacementStrings.append(replacementString)
            replacementRanges.append(lineRange)
        }
        
        self.replace(with: replacementStrings, ranges: replacementRanges, selectedRanges: nil,
                     actionName: NSLocalizedString("Delete Duplicate Lines", comment: "action name"))
    }
    
    
    /// duplicate selected lines below
    @IBAction func duplicateLine(_ sender: AnyObject?) {
        
        guard let string = self.string as NSString? else { return }
        
        var replacementRanges = [NSRange]()
        var replacementStrings = [String]()
        
        let selectedRanges = self.selectedRanges as! [NSRange]
        
        // get lines to process
        for selectedRange in selectedRanges {
            let lineRange = string.lineRange(for: selectedRange)
            let replacementRange = NSRange(location: lineRange.location, length: 0)
            var lineString = string.substring(with: lineRange)
            
            // add line break if it's the last line
            if !lineString.hasSuffix("\n") {
                lineString += "\n"
            }
            
            replacementRanges.append(replacementRange)
            replacementStrings.append(lineString)
        }
        
        self.replace(with: replacementStrings, ranges: replacementRanges, selectedRanges: nil,
                     actionName: NSLocalizedString("Duplicate Line", comment: "action name"))
    }
    
    
    /// remove selected lines
    @IBAction func deleteLine(_ sender: AnyObject?) {
        
        let replacementRanges = self.selectedLineRanges
        
        // on empty last line
        guard !replacementRanges.isEmpty else { return }
        
        let replacementStrings = [String](repeating: "", count: replacementRanges.count)
        
        self.replace(with: replacementStrings, ranges: replacementRanges, selectedRanges: nil,
                     actionName: NSLocalizedString("Delete Line", comment: "action name"))
    }
    
    
    /// trim all trailing whitespace
    @IBAction func trimTrailingWhitespace(_ sender: AnyObject?) {
        
        self.trimTrailingWhitespaceKeepingEditingPoint(false)
    }
    
    
    
    // MARK: Private Methods
    
    /// extract line by line line ranges which selected ranges include
    private var selectedLineRanges: [NSRange] {
        
        guard let string = self.string as NSString? else { return [] }
        
        let lineRanges = NSMutableOrderedSet()  // [NSRange]
        
        // get line ranges to process
        for selectedRange in self.selectedRanges as! [NSRange] {
            let linesRange = string.lineRange(for: selectedRange)
            
            // store each line to process
            string.enumerateSubstrings(in: linesRange, options: [.byLines, .substringNotRequired], using: { (substring: String?, substringRange, enclosingRange, stop) in
                
                lineRanges.add(enclosingRange)
            })
        }
        
        return lineRanges.array as! [NSRange]
    }
    
}
