//
//  MetadataExtractor.swift
//  MDB
//
//  Created on 24/07/25.
//

import Foundation
import AVFoundation
import Vision
import CoreImage

// Struct to hold extracted metadata
struct ClipMetadata: Identifiable, Hashable, Sendable {
    var id = UUID()
    var filename: String
    var path: URL
    var timecode: String?
    var clipName: String?
    var duration: Double?
    var frameRate: Float?
    var resolution: String?
    var extractedText: [String] = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ClipMetadata, rhs: ClipMetadata) -> Bool {
        return lhs.id == rhs.id
    }
}

// Struct to represent a matched pair of files
struct MatchedPair: Identifiable, Sendable {
    var id = UUID()
    var monitorFile: ClipMetadata
    var ditFile: ClipMetadata
    var matchConfidence: Double
}

@available(macOS 13.0, *)
final class MetadataExtractor: @unchecked Sendable {
    // Extract metadata from video files
    func extractMetadata(from url: URL, completion: @escaping (Result<ClipMetadata, Error>) -> Void) {
        let asset = AVURLAsset(url: url)
        
        var metadata = ClipMetadata(filename: url.lastPathComponent, path: url)
        
        // Use async/await with Task for modern API
        Task {
            do {
                // Get duration
                let duration = try await asset.load(.duration)
                metadata.duration = CMTimeGetSeconds(duration)
                
                // Get video tracks
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                
                if let videoTrack = videoTracks.first {
                    // Get frame rate
                    let frameRate = try await videoTrack.load(.nominalFrameRate)
                    metadata.frameRate = frameRate
                    
                    // Get resolution
                    let size = try await videoTrack.load(.naturalSize)
                    metadata.resolution = "\(Int(size.width))x\(Int(size.height))"
                }
                
                // Extract timecode if available
                let timecode = await extractTimecode(from: asset)
                metadata.timecode = timecode
                
                // Extract text from first frame
                do {
                    let extractedText = try await extractTextFromFirstFrame(of: asset)
                    metadata.extractedText = extractedText
                    
                    // Try to identify clip name from extracted text
                    metadata.clipName = self.identifyClipName(from: extractedText)
                } catch {
                    print("Error extracting text: \(error.localizedDescription)")
                }
                
                // Return the metadata
                DispatchQueue.main.async {
                    completion(.success(metadata))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Extract timecode from video asset
    private func extractTimecode(from asset: AVAsset) async -> String? {
        do {
            let metadata = try await asset.loadMetadata(for: .quickTimeMetadata)
            
            for item in metadata {
                if item.commonKey?.rawValue == "timecode" {
                    if let timecodeValue = try await item.load(.value) as? String {
                        return timecodeValue
                    }
                }
            }
            
            return nil
        } catch {
            print("Error extracting timecode: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Extract text from the first frame of a video
    private func extractTextFromFirstFrame(of asset: AVAsset) async throws -> [String] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        // Use the new async API
        return try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: NSError(domain: "MetadataExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate image"]))
                    return
                }
                
                let image = CIImage(cgImage: cgImage)
                
                // Perform text recognition
                Task {
                    do {
                        let recognizedText = try await self.recognizeText(in: image)
                        continuation.resume(returning: recognizedText)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // Perform OCR on an image
    private func recognizeText(in image: CIImage) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let textRecognitionRequest = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedText)
            }
            
            textRecognitionRequest.recognitionLevel = .accurate
            
            let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try requestHandler.perform([textRecognitionRequest])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // Try to identify clip name from extracted text
    private func identifyClipName(from extractedText: [String]) -> String? {
        // Look for patterns like "Clip: ABC123" or similar
        for text in extractedText {
            // Check for common patterns
            if let clipNameRange = text.range(of: "Clip[:\\s]+([A-Za-z0-9_]+)", options: .regularExpression) {
                let clipNameText = String(text[clipNameRange])
                // Extract just the clip name part
                if let nameRange = clipNameText.range(of: "[A-Za-z0-9_]+$", options: .regularExpression) {
                    return String(clipNameText[nameRange])
                }
                return clipNameText
            }
            
            // Check for other common patterns
            if let clipNameRange = text.range(of: "Scene[:\\s]+([A-Za-z0-9_]+)", options: .regularExpression) {
                let clipNameText = String(text[clipNameRange])
                if let nameRange = clipNameText.range(of: "[A-Za-z0-9_]+$", options: .regularExpression) {
                    return String(clipNameText[nameRange])
                }
                return clipNameText
            }
        }
        
        return nil
    }
    
    // Match monitor files with DIT files
    func matchFiles(monitorFiles: [ClipMetadata], ditFiles: [ClipMetadata]) -> [MatchedPair] {
        var matches: [MatchedPair] = []
        
        for monitorFile in monitorFiles {
            // Find best matching DIT file
            if let bestMatch = findBestMatch(for: monitorFile, in: ditFiles) {
                matches.append(MatchedPair(
                    monitorFile: monitorFile,
                    ditFile: bestMatch.file,
                    matchConfidence: bestMatch.confidence
                ))
            }
        }
        
        return matches
    }
    
    // Find the best matching DIT file for a given monitor file
    private func findBestMatch(for monitorFile: ClipMetadata, in ditFiles: [ClipMetadata]) -> (file: ClipMetadata, confidence: Double)? {
        var bestMatch: (file: ClipMetadata, confidence: Double)? = nil
        
        for ditFile in ditFiles {
            let confidence = calculateMatchConfidence(monitorFile: monitorFile, ditFile: ditFile)
            
            if confidence > 0.7 { // Threshold for a good match
                if bestMatch == nil || confidence > bestMatch!.confidence {
                    bestMatch = (ditFile, confidence)
                }
            }
        }
        
        return bestMatch
    }
    
    // Calculate match confidence between monitor file and DIT file
    private func calculateMatchConfidence(monitorFile: ClipMetadata, ditFile: ClipMetadata) -> Double {
        var confidenceScore = 0.0
        
        // Compare durations if available
        if let monitorDuration = monitorFile.duration, let ditDuration = ditFile.duration {
            let durationDiff = abs(monitorDuration - ditDuration)
            if durationDiff < 1.0 { // Within 1 second
                confidenceScore += 0.4
            } else if durationDiff < 5.0 { // Within 5 seconds
                confidenceScore += 0.2
            }
        }
        
        // Compare timecodes if available
        if let monitorTimecode = monitorFile.timecode, let ditTimecode = ditFile.timecode, monitorTimecode == ditTimecode {
            confidenceScore += 0.3
        }
        
        // Compare clip names if available
        if let monitorClipName = monitorFile.clipName, let ditClipName = ditFile.clipName {
            if monitorClipName == ditClipName {
                confidenceScore += 0.3
            } else if ditClipName.contains(monitorClipName) || monitorClipName.contains(ditClipName) {
                confidenceScore += 0.2
            }
        }
        
        // Compare extracted text with filename
        for text in monitorFile.extractedText {
            if ditFile.filename.contains(text) {
                confidenceScore += 0.1
                break
            }
        }
        
        return min(confidenceScore, 1.0) // Cap at 1.0
    }
    
    // Generate XML for DaVinci Resolve
    func generateResolveXML(matches: [MatchedPair], outputURL: URL) -> Bool {
        // Basic XML structure for DaVinci Resolve
        var xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <fcpxml version="1.9">
            <resources>
        """
        
        // Add resources
        for match in matches {
            let monitorFile = match.monitorFile
            let ditFile = match.ditFile
            
            xmlContent += """
                <asset id="monitor_\(monitorFile.id)" name="\(monitorFile.filename)" src="file://\(monitorFile.path.path)" />
                <asset id="dit_\(ditFile.id)" name="\(ditFile.filename)" src="file://\(ditFile.path.path)" />
            """
        }
        
        xmlContent += """
            </resources>
            <library>
                <event name="Metadata Bridge">
                    <project name="Relinked Project">
                        <sequence>
                            <spine>
        """
        
        // Add clips
        for match in matches {
            let monitorFile = match.monitorFile
            let ditFile = match.ditFile
            
            // Use duration if available, otherwise default to 10 seconds
            let duration = monitorFile.duration ?? 10.0
            
            xmlContent += """
                                <clip name="\(monitorFile.filename)" offset="0s" duration="\(duration)s" originalAssetID="monitor_\(monitorFile.id)" newAssetID="dit_\(ditFile.id)" />
            """
        }
        
        xmlContent += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
        
        do {
            try xmlContent.write(to: outputURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error writing XML: \(error.localizedDescription)")
            return false
        }
    }
}