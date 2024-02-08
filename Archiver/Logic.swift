//
//  Logic.swift
//  Archiver
//
//  Created by Yeezus on 15/04/2023.
//

import Foundation
import AppKit

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
    
    func resetSteps() {
        step = 0
        progress = 0
    }
    
    func startArchiving() {
        Task {
            await archiveFolders()
            DispatchQueue.main.async {
                self.isArchivingCompleted = true
                self.inPath.removeAll(keepingCapacity: true)
                self.resetSteps()
            }
        }
    }
    
    func archiveFolders() async {
        for (index, path) in inPath.enumerated() {
            DispatchQueue.main.async {
                self.archivingStatus = "Compressing folder \(index + 1) of \(self.inPath.count).😤"
            }
            await archiveImages(in: path)
        }
    }
    
    func archiveImages(in folderPath: String) async {
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: folderPath)
            let imageFiles = contents.filter { file in
                let fileExtension = file.split(separator: ".").last?.lowercased()
                return fileExtension.map { imageExtensions.contains($0) } ?? false
            }
            
            guard !imageFiles.isEmpty else {
                print("No image files found in the folder.")
                return
            }
            
            let folderURL = URL(fileURLWithPath: folderPath)
            let archiveName = folderURL.lastPathComponent + ".cbz"
            let archivePath = folderURL.deletingLastPathComponent().appendingPathComponent(archiveName).path
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["zip", "-j", archivePath] + imageFiles.map { folderPath + "/" + $0 }
            
            try process.run()
            process.waitUntilExit()
            
            await updateProgressSmoothly(increment: step, duration: 1.0)
            
            if process.terminationStatus == 0 {
                print("Successfully created the archive at: \(archivePath)")
            } else {
                print("An error occurred while creating the archive.")
            }
        } catch {
            print("An error occurred: \(error.localizedDescription)")
        }
    }
    
    func updateProgressSmoothly(increment: Double, duration: TimeInterval) async {
        let numberOfUpdates = 50
        let timeBetweenUpdates = duration / Double(numberOfUpdates)
        let progressIncrement = increment / Double(numberOfUpdates)
            
        for _ in 0..<numberOfUpdates {
            do {
                try await Task.sleep(nanoseconds: UInt64(timeBetweenUpdates * 1_000_000_000))
            } catch {
                print("Something went wrong with the timer.")
            }
            DispatchQueue.main.async {
                    self.progress += progressIncrement
            }
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
            step = 1.0 / Double(inPath.count)
        }
    }
}
