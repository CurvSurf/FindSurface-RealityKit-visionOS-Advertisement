//
//  ImmersiveView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import SwiftUI
import RealityKit
import AVFoundation

import _PhotosUI_SwiftUI

import FindSurface_visionOS
struct ImmersiveView: View {
    
    private enum AttachmentKey: Hashable, CaseIterable {
        case control
        case radius
        case status
        case confirm
        case warning
        case entityMenu
    }
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    
    @Environment(AppModel.self) private var appModel
    @Environment(FindSurface.self) private var findSurface
    @Environment(SessionManager.self) private var sessionManager
    @Environment(ScenePhaseTracker.self) private var scenePhaesTracker
    
    var body: some View {
        RealityView { content, attachments in
            await make(&content, attachments)
        } attachments: {
            attachments()
        }
        .upperLimbVisibility(.automatic)
        .task {
            await sessionManager.monitorSessionEvents(onError: { _ in () })
        }
        .task {
            await appModel.processSceneReconstructionUpdates()
        }
        .task {
            await appModel.processWorldTrackingUpdates()
        }
        .task {
            await appModel.processDeviceTrackingUpdates()
        }
        .task {
            await appModel.processHandTrackingUpdates()
        }
        .task {
            await appModel.restartFindSurfaceLoop()
        }
        .onSpatialTapGesture(target: appModel.meshVertexManager.rootEntity, action: onTapGesture(_:_:))
        .gesture(
            LongPressGesture()
                .targetedToAnyEntity()
                .onEnded { event in
                    Task {
                        await appModel.handleLongPress()
                    }
                }
        )
        .gesture(appModel.magnifyGesture)
        .task {
            await appModel.animation()
        }
        .onAppear {
            FindSurface.instance.loadFromUserDefaults()
        }
        .onDisappear {
            FindSurface.instance.saveToUserDefaults()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                
            } else {
                FindSurface.instance.saveToUserDefaults()
            }
        }
    }
    
    private func make(_ content: inout RealityViewContent, _ attachments: RealityViewAttachments) async {

        content.add(appModel.rootEntity)
        
        if let controls = attachments.entity(for: "controls") {
            appModel.controlWindow.controlView = controls
        }
        
        if let radiusAttachment = attachments.entity(for: AttachmentKey.radius) {
            appModel.seedRadiusIndicator.label = radiusAttachment
        }
        
        if let statusAttachment = attachments.entity(for: AttachmentKey.status) {
            appModel.statusWindow.statusView = statusAttachment
        }
        
        if let confirmAttachment = attachments.entity(for: AttachmentKey.confirm) {
            appModel.controlWindow.confirmView = confirmAttachment
        }
        
        if let warningAttachment = attachments.entity(for: AttachmentKey.warning) {
            appModel.warningWindow.warningView = warningAttachment
        }
        
        if let entityMenuAttachment = attachments.entity(for: AttachmentKey.entityMenu) {
            appModel.geometryManager.entityMenuWindow.menuView = entityMenuAttachment
        }
        
        Task {
            await sessionManager.run(with: appModel.dataProviders)
        }
    }
    
    @AttachmentContentBuilder
    private func attachments() -> some AttachmentContent {
        Attachment(id: "controls") {
            ControlView()
                .environment(appModel)
                .environment(FindSurface.instance)
        }
        
        Attachment(id: AttachmentKey.confirm) {
            ConfirmationDialogView()
                .environment(appModel)
        }
        
        Attachment(id: AttachmentKey.radius) {
            RadiusLabel()
                .environment(findSurface)
        }
        
        Attachment(id: AttachmentKey.status) {
            StatusView()
                .environment(appModel)
                .environment(appModel.timer)
                .frame(width: 320)
        }
        
        Attachment(id: AttachmentKey.warning) {
            WarningView()
                .environment(appModel)
                .glassBackgroundEffect()
        }

        Attachment(id: AttachmentKey.entityMenu) {
            EntityMenuView()
                .environment(appModel)
        }
    }
    
    private func onTapGesture(_ location: simd_float3, _ entity: Entity) {
        
        var atLeastOneSelectionDismissed = false
        if appModel.geometryManager.currentEntity != nil {
            appModel.geometryManager.currentEntity = nil
            atLeastOneSelectionDismissed = true
        }
        
        if appModel.shouldShowConfirmationDialog {
            appModel.shouldShowConfirmationDialog = false
            atLeastOneSelectionDismissed = true
        }
        
        if atLeastOneSelectionDismissed {
            return
        }
        
        if appModel.findSurfaceEnabled {
            appModel.shouldTakeNextPreviewAsResult = true
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}

