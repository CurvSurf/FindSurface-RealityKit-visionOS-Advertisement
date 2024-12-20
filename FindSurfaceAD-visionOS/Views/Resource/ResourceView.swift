//
//  ResourceView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/8/24.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ResourceImportView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    
    @Query private var materialResourceURLs: [MaterialData]
    @Environment(\.modelContext) private var context

    @Environment(AppModel.self) private var model
    
    @State private var photosPickerItems: [PhotosPickerItem] = []
    
    var body: some View {
        VStack {
            VStack {
                if materialResourceURLs.isEmpty {
                    Spacer()
                    Text("Resource list is empty.")
                    Spacer()
                } else {
                    ResourceList()
                }
            }
            .navigationTitle("Resources")
            .toolbar {
                EditButton()
                    .disabled(materialResourceURLs.isEmpty)
            }
            PhotosPickerButton(items: $photosPickerItems)
        }
        .padding()
        .onChange(of: photosPickerItems) {
            guard photosPickerItems.isEmpty == false else { return }
            Task {
                await handleResourceSelections(photosPickerItems)
            }
        }
    }
    
    private struct PhotosPickerButton: View {
        @Binding var items: [PhotosPickerItem]
        var body: some View {
            PhotosPicker(selection: $items,
                         matching: .any(of: [.images, .videos]),
                         photoLibrary: .shared()) {
                Label {
                    Text("Import Images & Videos")
                } icon: {
                    Image(systemName: "photo.badge.plus")
                        .scaledToFit()
                        .padding(.trailing)
                }
                .photosPickerStyle(.presentation)
            }
        }
    }
    
    @MainActor
    private func handleResourceSelections(_ items: [PhotosPickerItem]) async {
        let result = Set<MaterialData>(materialResourceURLs)
        do {
            let urls = try await items.asyncMap { item in
                if item.supportedContentTypes.contains(.png),
                   let imageURL = try await item.loadTransferable(type: ImageURL.self) {
                    return MaterialData(imageURL.url)
                } else if item.supportedContentTypes.contains(.mpeg4Movie),
                          let videoURL = try await item.loadTransferable(type: VideoURL.self) {
                    return MaterialData(videoURL.url)
                }
                return nil
            }
            .compactMap { $0 }
            .filter { url in !result.contains { $0.filename == url.filename } }
            
            try context.transaction {
                urls.forEach(context.insert)
            }
        } catch {
            fatalError("Failed to load resources: \(error)")
        }
    }
}

struct ResourceList: View {

    @Environment(\.modelContext) private var context
    
    @Environment(AppModel.self) private var model
    @State private var selectedResources: Set<MaterialResource> = []
    
    @State private var showAlert: Bool = false
    @State private var message: String = ""
    
    var body: some View {
        
        List {
            ForEach(model.materialResources, id: \.id) { resource in
                HStack {
                    let uiImage = resource.thumbnail// ?? UIImage(systemName: "questionmark")!
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 96)
                    
                    Text(resource.filename)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .hoverEffect()
            }
            .onDelete { indexSet in
                try! context.transaction {
                    indexSet.forEach { index in
                        let itemToDelete = model.materialResources[index].data
                        do {
                            try FileManager.default.removeItem(at: itemToDelete.url)
                        } catch {
                            message = "\(error)"
                            showAlert = true
                        }
                        context.delete(itemToDelete)
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                .init(title: Text("Error"), message: Text(message))
            }
        }
    }
}

import CoreTransferable
struct VideoURL: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            var filename = received.file.lastPathComponent
            if filename.contains(" ") {
                filename.replace(" ", with: "_")
            }
            let copy = URL.documentsDirectory.appending(path: filename)
            
            if FileManager.default.fileExists(atPath: copy.path()) == false {
                do {
                    try FileManager.default.copyItem(at: received.file, to: copy)
                } catch {
                    fatalError("Failed to copy file: \(error)")
                }
            }
            
            return VideoURL(url: copy)
        }
    }
}

struct ImageURL: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { image in
            SentTransferredFile(image.url)
        } importing: { received in
            var filename = received.file.lastPathComponent
            if filename.contains(" ") {
                filename.replace(" ", with: "_")
            }
            let copy = URL.documentsDirectory.appending(path: filename)
            
            if FileManager.default.fileExists(atPath: copy.path()) == false {
                try FileManager.default.copyItem(at: received.file, to: copy)
            }
            
            return ImageURL(url: copy)
        }
    }
}
