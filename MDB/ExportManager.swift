//
//  ExportManager.swift
//  MDB
//
//  Created on 24/07/25.
//

import Foundation
import UniformTypeIdentifiers

class ExportManager {
    enum ExportError: Error {
        case exportFailed
        case noMatches
    }
    
    // Export matches as XML for DaVinci Resolve
    static func exportAsResolveXML(matches: [MatchedPair], completion: @escaping (Result<URL, Error>) -> Void) {
        guard !matches.isEmpty else {
            completion(.failure(ExportError.noMatches))
            return
        }
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("metadata_bridge_\(Date().timeIntervalSince1970).xml")
        
        let extractor = MetadataExtractor()
        let success = extractor.generateResolveXML(matches: matches, outputURL: outputURL)
        
        if success {
            completion(.success(outputURL))
        } else {
            completion(.failure(ExportError.exportFailed))
        }
    }
    
    // Export matches as CSV
    static func exportAsCSV(matches: [MatchedPair], completion: @escaping (Result<URL, Error>) -> Void) {
        guard !matches.isEmpty else {
            completion(.failure(ExportError.noMatches))
            return
        }
        
        // Create CSV content
        var csvContent = "Monitor File,DIT File,Match Confidence\n"
        
        for match in matches {
            csvContent += "\"\(match.monitorFile.filename)\",\"\(match.ditFile.filename)\",\(match.matchConfidence)\n"
        }
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("metadata_bridge_\(Date().timeIntervalSince1970).csv")
        
        do {
            try csvContent.write(to: outputURL, atomically: true, encoding: .utf8)
            completion(.success(outputURL))
        } catch {
            completion(.failure(error))
        }
    }
    
    // Export detailed report as text
    static func exportDetailedReport(matches: [MatchedPair], completion: @escaping (Result<URL, Error>) -> Void) {
        guard !matches.isEmpty else {
            completion(.failure(ExportError.noMatches))
            return
        }
        
        // Create report content
        var reportContent = "Metadata Bridge Report\n"
        reportContent += "Generated on \(Date())\n\n"
        
        for (index, match) in matches.enumerated() {
            reportContent += "Match \(index + 1)\n"
            reportContent += "----------\n"
            
            // Monitor file details
            reportContent += "Monitor File: \(match.monitorFile.filename)\n"
            reportContent += "Path: \(match.monitorFile.path.path)\n"
            if let timecode = match.monitorFile.timecode {
                reportContent += "Timecode: \(timecode)\n"
            }
            if let clipName = match.monitorFile.clipName {
                reportContent += "Clip Name: \(clipName)\n"
            }
            if let duration = match.monitorFile.duration {
                reportContent += "Duration: \(duration) seconds\n"
            }
            if let frameRate = match.monitorFile.frameRate {
                reportContent += "Frame Rate: \(frameRate) fps\n"
            }
            if let resolution = match.monitorFile.resolution {
                reportContent += "Resolution: \(resolution)\n"
            }
            if !match.monitorFile.extractedText.isEmpty {
                reportContent += "Extracted Text: \(match.monitorFile.extractedText.joined(separator: ", "))\n"
            }
            
            reportContent += "\n"
            
            // DIT file details
            reportContent += "DIT File: \(match.ditFile.filename)\n"
            reportContent += "Path: \(match.ditFile.path.path)\n"
            if let timecode = match.ditFile.timecode {
                reportContent += "Timecode: \(timecode)\n"
            }
            if let clipName = match.ditFile.clipName {
                reportContent += "Clip Name: \(clipName)\n"
            }
            if let duration = match.ditFile.duration {
                reportContent += "Duration: \(duration) seconds\n"
            }
            if let frameRate = match.ditFile.frameRate {
                reportContent += "Frame Rate: \(frameRate) fps\n"
            }
            if let resolution = match.ditFile.resolution {
                reportContent += "Resolution: \(resolution)\n"
            }
            
            reportContent += "\n"
            reportContent += "Match Confidence: \(match.matchConfidence * 100)%\n"
            reportContent += "\n\n"
        }
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("metadata_bridge_report_\(Date().timeIntervalSince1970).txt")
        
        do {
            try reportContent.write(to: outputURL, atomically: true, encoding: .utf8)
            completion(.success(outputURL))
        } catch {
            completion(.failure(error))
        }
    }
}