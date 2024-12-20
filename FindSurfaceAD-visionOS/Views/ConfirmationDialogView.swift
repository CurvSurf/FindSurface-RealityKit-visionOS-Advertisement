//
//  ConfirmationDialogView.swift
//  FindSurfaceRR-visionOS
//
//  Created by CurvSurf-SGKim on 9/3/24.
//

import Foundation
import SwiftUI

struct ConfirmationDialogView: View {
    
    @Environment(AppModel.self) private var model
    
    var body: some View {
        VStack {
            Text("Before Deleting...")
                .font(.title)
            
            Divider()
                .overlay(Color.white)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            Text("Are you sure to delete \(model.geometryManager.geometryEntityMap.count) objects?")
                .padding(.bottom, 8)
            
            Text("This will **delete** the geometries **permanently**\nand you cannot undo this action.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            Divider()
                .overlay(Color.white)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            HStack(spacing: 24) {
                Button(role: .destructive) {
                    Task {
                        try? await model.worldAnchorUpdater.removeAllAnchors()
                        model.shouldShowConfirmationDialog = false
                    }
                } label: {
                    Text("Delete")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Capsule().stroke(.white, lineWidth: 1))
                .hoverEffect(.highlight)
                
                Button(role: .cancel) {
                    model.shouldShowConfirmationDialog = false
                } label: {
                    Text("Cancel")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Capsule().stroke(.white, lineWidth: 1))
                .hoverEffect(.highlight)
            }
        }
        .padding()
        .background(.blue.opacity(0.1))
        .border(Color.white)
        .frame(width: 320)
    }
}

#Preview(windowStyle: .plain) {
    ConfirmationDialogView()
        .environment(AppModel())
}
