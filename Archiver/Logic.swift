//
//  Logic.swift
//  Archiver
//
//  Created by Yeezus on 15/04/2023.
//

import Foundation
import AppKit

@MainActor
class LogicHandler: ObservableObject {
    
    @Published var inPath: [String] = []
    @Published var progress: Double {
        didSet {
            if progress > 1 {
                progress = 1
            }
        }
    }
    @Published var step: Double
    @Published var isArchivingCompleted = false
    @Published var archivingStatus: String
    
    init(inPath: [String] = [], archivingStatus: String = "") {
        self.inPath = inPath
        self.progress = 0
        self.step = 0
        self.archivingStatus = archivingStatus
    }
    
    func startArchiving() {
        Task {
            await archiveFolders()
            DispatchQueue.main.async {
                self.isArchivingCompleted = true
                self.archivingStatus = "Archiving completed successfully!"
                self.inPath.removeAll(keepingCapacity: true)
            }
        }
    }
    
    func archiveFolders() async {
        for (index, path) in inPath.enumerated() {
            let folderName = URL(fileURLWithPath: path).lastPathComponent
            DispatchQueue.main.async {
                self.archivingStatus = "Compressing folder \(index + 1) of \(self.inPath.count): \(folderName) 😤"
            }
            await archiveImages(in: path)
        }
    }
    
    func archiveImages(in folderPath: String) async {
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        let folderURL = URL(fileURLWithPath: folderPath)
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: folderPath)
            let imageFiles = contents.filter { file in
                let fileExtension = file.split(separator: ".").last?.lowercased()
                return fileExtension.map { imageExtensions.contains($0) } ?? false
            }
            
            let sortedImageFiles = imageFiles.sorted()
            
            guard !sortedImageFiles.isEmpty else {
                print("No image files found in the folder.")
                return
            }
            
            let tempDirectoryURL = folderURL.appendingPathComponent("temp_conversion", isDirectory: true)
            
            try? fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
            
            return await withCheckedContinuation { continuation in
                var convertedFilesMap: [(original: String, converted: URL)] = []
                let group = DispatchGroup()
                let queue = DispatchQueue(label: "com.imageconversion.queue", attributes: .concurrent)
                
                for (index, imageFile) in sortedImageFiles.enumerated() {
                    group.enter()
                    queue.async {
                        let imageURL = folderURL.appendingPathComponent(imageFile)
                        
                        let paddedIndex = String(format: "%04d", index)
                        let convertedImageName = "\(paddedIndex)_\(imageFile).jpg"
                        let convertedImageURL = tempDirectoryURL.appendingPathComponent(convertedImageName)
                        
                        if let image = NSImage(contentsOf: imageURL) {
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                                    try? jpegData.write(to: convertedImageURL)
                                    
                                    DispatchQueue.main.async {
                                        convertedFilesMap.append((original: imageFile, converted: convertedImageURL))
                                    }
                                }
                            }
                        }
                        
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    let sortedConvertedFiles = convertedFilesMap.sorted { $0.0 < $1.0 }.map { $0.1.path }
                    let archiveName = folderURL.lastPathComponent + ".cbz"
                    let archivePath = folderURL.deletingLastPathComponent().appendingPathComponent(archiveName).path
                    
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["zip", "-j", archivePath] + sortedConvertedFiles
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        
                        try? fileManager.removeItem(at: tempDirectoryURL)
                        
                        if process.terminationStatus == 0 {
                            print("Successfully created the archive at: \(archivePath)")
                        } else {
                            print("An error occurred while creating the archive.")
                        }
                        
                        continuation.resume()
                    } catch {
                        print("An error occurred: \(error.localizedDescription)")
                        continuation.resume()
                    }
                }
            }
        } catch {
            print("An error occurred: \(error.localizedDescription)")
        }
    }

    func selectFolders(completion: @escaping ([URL]) -> Void) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = true
            
            let result = openPanel.runModal()
            if result == .OK {
                completion(openPanel.urls)
            } else {
                completion([])
            }
        }
    }
    
    func blackMagic() {
        inPath.removeAll()
        selectFolders { [self] folderURLs in
            if !folderURLs.isEmpty {
                for folderURL in folderURLs {
                    let folderPath = folderURL.path
                    let folderName = folderURL.lastPathComponent

                    print("Selected folder: \(folderName)")
                    inPath.append(folderPath)
                }
            } else {
                print("No folders were selected.")
            }
        }
    }
}
