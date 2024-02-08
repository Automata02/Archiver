//
//  ContentView.swift
//  Archiver
//
//  Created by Yeezus on 15/04/2023.
//

import SwiftUI

struct ContentView: View {
    @State var isShowingProgressView: Bool = false
    @ObservedObject var logicHandler = LogicHandler()
    
    var body: some View {
        VStack {
            Button("Select Folders") {
                logicHandler.blackMagic()
            }
            ZStack {
                List {
                    if logicHandler.inPath.isEmpty {
                        Text(logicHandler.isArchivingCompleted ? "Archiving has finished." : "No Folders Selected.")
                            .foregroundColor(Color(.disabledControlTextColor))
                    } else {
                        Text("Selected folder count: \(logicHandler.inPath.count)")
                            .font(.caption)
                        ForEach(logicHandler.inPath, id: \.self) { path in
                            Text(path)
                        }
                    }
                }
                .cornerRadius(5)
                .opacity(isShowingProgressView ? 0.3 : 1)
                .blur(radius: isShowingProgressView ? 2 : 0)
                VStack {
                    ProgressView(value: logicHandler.progress)
                        .zIndex(1)
                        .progressViewStyle(.circular)
                        .onChange(of: logicHandler.isArchivingCompleted) { isCompleted in
                            if isCompleted {
                                isShowingProgressView = false
                                logicHandler.isArchivingCompleted = false
                            }
                        }
                    Text(logicHandler.archivingStatus)
                        .padding(.top, 5)
                }
                .padding()
                .background(.regularMaterial)
                .opacity(isShowingProgressView ? 1 : 0)
                .cornerRadius(5)
            }
            HStack {
                Button("Cancel") { logicHandler.inPath.removeAll(keepingCapacity: false) }
                    .buttonStyle(.bordered)
                Button("Start") {
                    isShowingProgressView = true
                    logicHandler.startArchiving()
                }
                .buttonStyle(.borderedProminent)
                .disabled(logicHandler.inPath.isEmpty ? true : false)
            }
            .padding(.top, 10)
        }
        .padding(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            logicHandler: LogicHandler(
                inPath: [
                    "/Users/yeezus/Downloads/first",
                    "/Users/yeezus/Downloads/second",
                    "/Users/yeezus/Downloads/third_has_a_very_very_very_very_very_long_name"
                ],
                archivingStatus: "Compressing folder 1 of 3.😤"
            )
        )
    }
}

