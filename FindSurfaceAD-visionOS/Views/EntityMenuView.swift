//
//  EntityMenuView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/13/24.
//

import SwiftUI

import RealityFoundation

fileprivate struct DismissButton: View {
    
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
                .imageScale(.large)
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct PlayPauseButton: View {
    
    @Binding var isPlaying: Bool
    let action: (Bool) -> Void
    
    var body: some View {
        Button {
            isPlaying.toggle()
            action(isPlaying)
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .imageScale(.large)
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct RewindButton: View {
    
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "backward.end.fill")
                .imageScale(.large)
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct DeleteEntityButton: View {
    
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "trash.fill")
                .imageScale(.large)
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct EntityMenuView: View {
    
    @Environment(AppModel.self) private var model
    
    var body: some View {
        @Bindable var model = model
        HStack(spacing: 16) {
            
            DismissButton {
                model.geometryManager.currentEntity = nil
            }
            
            if model.geometryManager.currentEntity?.player != nil {
                PlayPauseButton(isPlaying: $model.geometryManager.isCurrentEntityPlaying) { isPlaying in
                    model.geometryManager.isCurrentEntityPlaying = isPlaying
                }
                
                RewindButton {
                    model.geometryManager.currentEntity?.rewindContent()
                }
            }
            
            DeleteEntityButton {
                Task {
                    if let id = model.geometryManager.currentEntityID {
                        try? await model.worldAnchorUpdater.removeAnchor(forID: id)
                    }
                }
            }
        }
        .padding(8)
        .background {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                        .opacity(0.18)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white, lineWidth: 1.5)
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                }
            }
        }
    }
}


#Preview {
    EntityMenuView()
        .environment(AppModel())
}
