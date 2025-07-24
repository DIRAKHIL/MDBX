//
//  ContentView.swift
//  MDB
//
//  Created by Akhil Maddali on 25/07/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ContentView: View {
    @State private var monitorFiles: [URL] = []
    @State private var ditFiles: [URL] = []
    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var showMonitorFilePicker = false
    @State private var showDITFilePicker = false
    @State private var showExportOptions = false
    @State private var showExportFilePicker = false
    @State private var exportType: ExportType = .resolveXML
    
    // Metadata extraction results
    @State private var monitorMetadata: [ClipMetadata] = []
    @State private var ditMetadata: [ClipMetadata] = []
    @State private var matches: [MatchedPair] = []
    
    enum ExportType {
        case resolveXML
        case csv
        case detailedReport
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Metadata Bridge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Connect monitor-recorded files with high-quality DIT footage")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Divider()
                
                // Monitor Files Section
                VStack(alignment: .leading) {
                    HStack {
                        Text("Monitor Files")
                            .font(.headline)
                        Spacer()
                        Button("Select Files") {
                            showMonitorFilePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if monitorFiles.isEmpty {
                        Text("No files selected")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        List {
                            ForEach(monitorFiles, id: \.self) { url in
                                Text(url.lastPathComponent)
                            }
                            .onDelete(perform: removeMonitorFiles)
                        }
                        .frame(height: 150)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // DIT Files Section
                VStack(alignment: .leading) {
                    HStack {
                        Text("DIT Files")
                            .font(.headline)
                        Spacer()
                        Button("Select Files") {
                            showDITFilePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if ditFiles.isEmpty {
                        Text("No files selected")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        List {
                            ForEach(ditFiles, id: \.self) { url in
                                Text(url.lastPathComponent)
                            }
                            .onDelete(perform: removeDITFiles)
                        }
                        .frame(height: 150)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                HStack {
                    // Process Button
                    Button(action: processFiles) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.trailing, 8)
                            Text("Processing...")
                        } else {
                            Text("Generate Metadata Bridge")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(monitorFiles.isEmpty || ditFiles.isEmpty || isProcessing)
                    
                    // Export Button (only visible after processing)
                    if !matches.isEmpty {
                        Button(action: { showExportOptions = true }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                
                if !processingStatus.isEmpty {
                    Text(processingStatus)
                        .foregroundColor(processingStatus.contains("Error") ? .red : .green)
                        .padding()
                }
                
                // Results Section (only visible after processing)
                if !matches.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Matched Files")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List {
                            ForEach(matches) { match in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(match.monitorFile.filename)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("→")
                                        Spacer()
                                        Text(match.ditFile.filename)
                                            .fontWeight(.medium)
                                    }
                                    
                                    HStack {
                                        Spacer()
                                        let confidencePercent = Int(match.matchConfidence * 100)
                                        Text("Match Confidence: \(confidencePercent)%")
                                            .font(.caption)
                                            .foregroundColor(getConfidenceColor(confidence: match.matchConfidence))
                                        Spacer()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(height: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Metadata Bridge")
            .fileImporter(
                isPresented: $showMonitorFilePicker,
                allowedContentTypes: [UTType.movie, UTType.video, UTType.image],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result: result, destination: &monitorFiles)
            }
            .fileImporter(
                isPresented: $showDITFilePicker,
                allowedContentTypes: [UTType.movie, UTType.video],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result: result, destination: &ditFiles)
            }
            .fileExporter(
                isPresented: $showExportFilePicker,
                document: exportDocument(),
                contentType: exportContentType(),
                defaultFilename: exportDefaultFilename()
            ) { result in
                switch result {
                case .success(let url):
                    processingStatus = "Successfully exported to \(url.lastPathComponent)"
                case .failure(let error):
                    processingStatus = "Error exporting: \(error.localizedDescription)"
                }
            }
            .confirmationDialog("Export Format", isPresented: $showExportOptions) {
                Button("DaVinci Resolve XML") {
                    exportType = .resolveXML
                    showExportFilePicker = true
                }
                
                Button("CSV File") {
                    exportType = .csv
                    showExportFilePicker = true
                }
                
                Button("Detailed Report") {
                    exportType = .detailedReport
                    showExportFilePicker = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>, destination: inout [URL]) {
        do {
            let urls = try result.get()
            destination.append(contentsOf: urls)
        } catch {
            processingStatus = "Error importing files: \(error.localizedDescription)"
        }
    }
    
    private func removeMonitorFiles(at offsets: IndexSet) {
        monitorFiles.remove(atOffsets: offsets)
    }
    
    private func removeDITFiles(at offsets: IndexSet) {
        ditFiles.remove(atOffsets: offsets)
    }
    
    private func processFiles() {
        guard !monitorFiles.isEmpty && !ditFiles.isEmpty else {
            processingStatus = "Please select both monitor and DIT files"
            return
        }
        
        isProcessing = true
        processingStatus = "Processing files..."
        
        // Clear previous results
        monitorMetadata = []
        ditMetadata = []
        matches = []
        
        let extractor = MetadataExtractor()
        let dispatchGroup = DispatchGroup()
        
        // Process monitor files
        for url in monitorFiles {
            dispatchGroup.enter()
            extractor.extractMetadata(from: url) { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let metadata):
                    DispatchQueue.main.async {
                        monitorMetadata.append(metadata)
                    }
                case .failure(let error):
                    print("Error extracting metadata from \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // Process DIT files
        for url in ditFiles {
            dispatchGroup.enter()
            extractor.extractMetadata(from: url) { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let metadata):
                    DispatchQueue.main.async {
                        ditMetadata.append(metadata)
                    }
                case .failure(let error):
                    print("Error extracting metadata from \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // When all files are processed, match them
        dispatchGroup.notify(queue: .main) {
            // Match files
            matches = extractor.matchFiles(monitorFiles: monitorMetadata, ditFiles: ditMetadata)
            
            isProcessing = false
            
            if matches.isEmpty {
                processingStatus = "No matches found. Try adjusting the files or metadata."
            } else {
                processingStatus = "Successfully matched \(matches.count) files"
            }
        }
    }
    
    // Helper functions for export
    private func exportDocument() -> FileDocument {
        // This is a placeholder - in a real app, you'd create a proper FileDocument
        // For simplicity, we're using a string-based approach
        let content: String
        
        switch exportType {
        case .resolveXML:
            content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<fcpxml version=\"1.9\">\n<!-- Placeholder XML content -->\n</fcpxml>"
        case .csv:
            content = "Monitor File,DIT File,Match Confidence\n"
        case .detailedReport:
            content = "Metadata Bridge Report\nGenerated on \(Date())\n"
        }
        
        return TextDocument(text: content)
    }
    
    private func exportContentType() -> UTType {
        switch exportType {
        case .resolveXML:
            return UTType.xml
        case .csv:
            return UTType.commaSeparatedText
        case .detailedReport:
            return UTType.plainText
        }
    }
    
    private func exportDefaultFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        switch exportType {
        case .resolveXML:
            return "metadata_bridge_\(dateString).xml"
        case .csv:
            return "metadata_bridge_\(dateString).csv"
        case .detailedReport:
            return "metadata_bridge_report_\(dateString).txt"
        }
    }
    
    private func getConfidenceColor(confidence: Double) -> Color {
        if confidence > 0.8 {
            return .green
        } else if confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// Simple FileDocument implementation for export
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .xml, .commaSeparatedText] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ContentView()
}
