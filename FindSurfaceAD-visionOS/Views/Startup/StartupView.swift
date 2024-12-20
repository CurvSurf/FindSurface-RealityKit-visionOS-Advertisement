//
//  StartupView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import SwiftUI
import SwiftData
import _PhotosUI_SwiftUI

struct StartupView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    
    @Environment(SessionManager.self) private var sessionManager
    @Environment(AppModel.self) private var model
    
    @Query private var materialResourceURLs: [MaterialData]
    
    @State private var isResourceManagePresented: Bool = false
    
    var body: some View {
        let emptyResources = materialResourceURLs.isEmpty
        NavigationStack {
            VStack {
                
                MainPageView()
                    .padding(.top, 16)
                Spacer()
                
                Group {
                    if !sessionManager.canEnterImmersiveSpace {
                        PermissionRequestView()
                    } else {
                        VStack {
                            OpenUserGuideButton()
                            Button("Manage Resources") {
                                isResourceManagePresented = true
                            }
                            Text("⚠️Cannot enter the immersive space without resources to use.")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .opacity(emptyResources ? 1 : 0)
                            
                            EnterImmersiveSpaceButton(immersiveSpaceAvailable: sessionManager.canEnterImmersiveSpace)
                                .disabled(emptyResources)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationDestination(isPresented: $isResourceManagePresented) {
                ResourceImportView()
            }
        }
        .padding()
        .frame(width: 450, height: 500)
        .task {
            await initializeMaterialResources()
        }
        .onChange(of: materialResourceURLs) { oldURLs, newURLs in
            Task {
                await processMaterialResourceURLsUpdates(from: oldURLs, to: newURLs)
            }
        }
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active {
                Task {
                    await sessionManager.queryRequiredAuthorizations()
                }
            }
        }
        .task {
            if sessionManager.allRequiredProvidersAreSupported {
                await sessionManager.requestRequiredAuthorizations()
            }
        }
    }
    
    @MainActor
    private func initializeMaterialResources() async {
        guard materialResourceURLs.isEmpty == false else { return }
        let valid = materialResourceURLs.filter { url in
            FileManager.default.fileExists(atPath: url.url.path())
        }
        
        model.materialResources = await valid.asyncMap {
            let resource = try! await MaterialResource.generate(from: $0)
            $0.resource = resource
            return resource
        }
        
        let invalid = Set(materialResourceURLs).subtracting(valid)
        try! context.transaction {
            invalid.forEach(context.delete)
        }
    }
    
    @MainActor
    private func processMaterialResourceURLsUpdates(from oldURLs: [MaterialData],
                                                    to newURLs: [MaterialData]) async {
        let added = Set(newURLs).subtracting(oldURLs)
        let removed = Set(oldURLs).subtracting(newURLs)
        print("resource update: +\(added.map { $0.filename }.joined(separator: ", "))")
        print("resource update: -\(removed.map { $0.filename }.joined(separator: ", "))")
        let valid = added.filter {
            FileManager.default.fileExists(atPath: $0.url.path())
        }
        let invalidFilenames = added.subtracting(valid).map { $0.filename }
        
        if removed.isEmpty == false {
            model.materialResources.removeAll { removed.contains($0.data) }
        }
        if valid.isEmpty == false {
            model.materialResources.append(contentsOf: await valid.asyncMap {
                let resource = try! await MaterialResource.generate(from: $0)
                $0.resource = resource
                return resource
            })
        }
        if invalidFilenames.isEmpty == false {
            try! context.delete(model: MaterialData.self,
                                where: #Predicate { invalidFilenames.contains($0.filename) })
        }
    }
    
}

fileprivate struct OpenUserGuideButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("Open User Guide") {
            openWindow(sceneID: SceneID.userGuide, value: SceneID.userGuide)
        }
    }
}

fileprivate struct EnterImmersiveSpaceButton: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismiss) private var dismiss
    
    let immersiveSpaceAvailable: Bool
    
    @State private var openingImmersiveSpace: Bool = false
    
    var body: some View {
        let label = if immersiveSpaceAvailable == false {
            "Not Available"
        } else if openingImmersiveSpace {
            "Please Wait..."
        } else {
            "Enter"
        }
    
        Button(label) {
            Task { await tryOpenImmersiveSpace() }
        }
        .disabled(!immersiveSpaceAvailable || openingImmersiveSpace)
    }
    
    @MainActor
    private func tryOpenImmersiveSpace() async {
        switch await openImmersiveSpace(sceneID: SceneID.immersiveSpace, value: SceneID.immersiveSpace) {
        case .opened: dismiss()
        case .error: fallthrough
        case .userCancelled: fallthrough
        @unknown default: await dismissImmersiveSpace()
        }
    }
}


#Preview(windowStyle: .plain) {
    StartupView()
        .environment(SessionManager())
        .environment(AppModel())
}
