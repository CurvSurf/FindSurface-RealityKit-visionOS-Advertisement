//
//  CapsuleButtons.swift
//  FindSurfaceRR-visionOS
//
//  Created by CurvSurf-SGKim on 7/16/24.
//

import Foundation
import SwiftUI

fileprivate struct StringMaxLengthPreferenceKey: PreferenceKey {
    static var defaultValue: Int = 0
    static func reduce(value: inout Int, nextValue: () -> Int) {
        value = max(value, nextValue())
    }
}

fileprivate struct StringMaxLengthEnvironmentKey: EnvironmentKey {
    static var defaultValue: Int = 0
}

extension EnvironmentValues {
    var stringMaxLength: Int {
        get { self[StringMaxLengthEnvironmentKey.self] }
        set { self[StringMaxLengthEnvironmentKey.self] = newValue }
    }
}

struct StringMaxLengthBroadcast: ViewModifier {
    
    @State private var length: Int = 0
    
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(StringMaxLengthPreferenceKey.self) { length in
                self.length = length
            }
            .environment(\.stringMaxLength, length)
    }
}

extension View {
    func broadcastStringMaxLength() -> some View {
        modifier(StringMaxLengthBroadcast())
    }
}

fileprivate struct CapsuleImageButton: View {
    
    @Environment(\.stringMaxLength) private var maxLength
    
    let label: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void
    
    init(label: String, 
         systemImage: String,
         role: ButtonRole? = nil,
         action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }
    
    var body: some View {
        Button(role: role) {
            action()
        } label: {
            let minLength = label.count
            let padding = String(repeating: " ", count: max(maxLength - minLength, 0))
            let text = "\(label)\(padding)"
            Label(text, systemImage: systemImage)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity)
                .padding(8)
                .preference(key: StringMaxLengthPreferenceKey.self, value: minLength)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Capsule().stroke(.white, lineWidth: 1))
        .hoverEffect(.highlight)
    }
}

struct UndoButton: View {
    
    @Environment(AppModel.self) private var model
    
    var body: some View {
        CapsuleImageButton(label: "Undo", systemImage: "arrow.uturn.backward", role: .destructive) {
            if let id = model.geometryManager.undoStack.last {
                Task {
                    try? await model.worldAnchorUpdater.removeAnchor(forID: id)
                }
            }
        }
        .disabled(model.geometryManager.undoStack.isEmpty)
    }
}

struct ClearButton: View {
    
    @Environment(AppModel.self) private var model
    
    var body: some View {
        CapsuleImageButton(label: "Clear", systemImage: "trash", role: .destructive) {
            model.shouldShowConfirmationDialog = true
        }
        .disabled(model.geometryManager.geometryEntityMap.isEmpty)
    }
}

fileprivate struct CapsuleImageToggleButton: View {
    
    @Environment(\.stringMaxLength) private var maxLength
    
    @Binding var isOn: Bool
    let label: String
    let statusLabels: (Bool) -> String
    let systemImage: (Bool) -> String
    let foregroundColor: Color
    
    init(isOn: Binding<Bool>, 
         label: String,
         foregroundColor: Color = .white,
         statusLabels: @escaping (Bool) -> String,
         systemImage: @escaping (Bool) -> String) {
        self._isOn = isOn
        self.label = label
        self.statusLabels = statusLabels
        self.systemImage = systemImage
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        
        Toggle(isOn: $isOn) {
            let statusTrue = statusLabels(true)
            let statusFalse = statusLabels(false)
            let status = isOn ? statusTrue : statusFalse
            let minLength = label.count + max(statusTrue.count, statusFalse.count) + 2
            let actualLength = label.count + status.count + 2
            let padding = String(repeating: " ", count: max(maxLength - actualLength, 0))
            let text = "\(label): \(padding)\(status)"
            Label(text, systemImage: systemImage(isOn))
                .font(.body.monospaced())
                .foregroundStyle(isOn ? foregroundColor : .gray)
                .frame(maxWidth: .infinity)
                .padding(8)
                .preference(key: StringMaxLengthPreferenceKey.self, value: minLength)
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Capsule().stroke(.white, lineWidth: 1))
        .hoverEffect(.highlight)
    }
}

struct MeshToggleButton: View {
    @Environment(AppModel.self) private var model
    
    var body: some View {
        @Bindable var model = model
        CapsuleImageToggleButton(isOn: $model.meshVertexManager.shouldShowMesh,
                                 label: "Mesh",
                                 foregroundColor: .green) { enabled in
            enabled ? "Shown" : "Hidden"
        } systemImage: { enabled in
            enabled ? "eye" : "eye.slash"
        }
        .onChange(of: model.meshVertexManager.shouldShowMesh) { old, new in
            if old && !new && model.findSurfaceEnabled {
                model.findSurfaceEnabled = false
            }
        }
    }
}

struct PreviewToggleButton: View {
    
    @Environment(AppModel.self) private var model
    
    var body: some View {
        @Bindable var model = model
        CapsuleImageToggleButton(isOn: $model.findSurfaceEnabled,
                                 label: "Preview",
                                 foregroundColor: .green) { enabled in
            enabled ? "On" : "Off"
        } systemImage: { enabled in
            enabled ? "lightswitch.on" : "lightswitch.off"
        }
        .onChange(of: model.findSurfaceEnabled) { old, new in
            if !old && new && !model.meshVertexManager.shouldShowMesh {
                model.meshVertexManager.shouldShowMesh = true
            }
        }
    }
}

struct GeometryToggleButton: View {
    @Environment(AppModel.self) private var model
    
    var body: some View {
        @Bindable var model = model
        CapsuleImageToggleButton(isOn: $model.geometryManager.shouldShowGeometryEntities,
                                 label: "Geometry",
                                 foregroundColor: .green) { enabled in
            enabled ? "On" : "Off"
        } systemImage: { enabled in
            enabled ? "basketball" : "basketball.fill"
        }
        .onChange(of: model.geometryManager.shouldShowGeometryEntities) {
            let shouldEnableOcclusion = !model.geometryManager.shouldShowGeometryEntities
            for entity in model.geometryManager.objectEntityMap.values {
                entity.enableOcclusion = shouldEnableOcclusion
            }
        }
    }
}
