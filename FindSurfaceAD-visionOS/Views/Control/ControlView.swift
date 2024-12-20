//
//  ControlView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/13/24.
//

import SwiftUI

import FindSurface_visionOS
import RealityFoundation

struct MaterialListView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        
        ScrollView(.horizontal) {
            HStack {
                ForEach(model.materialResources, id: \.id) { resource in
                    VStack {
                        Image(uiImage: resource.thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16 * 9, height: 9 * 9)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(resource.filename)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 16 * 9)
                    }
                    .overlay(
                        overlayHighlight(resource)
                    )
                    .onAppear {
                        model.currentResource = model.materialResources.first
                    }
                    .onTapGesture {
                        model.currentResource = resource
                    }
                    .onLongPressGesture {
                        if let material = resource.material as? VideoMaterial,
                           let player = material.avPlayer {
                            if player.timeControlStatus == .playing {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }
                    }
                    .hoverEffect()
                }
            }
        }
        .padding()
        .overlay {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white, lineWidth: 1)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
            }
        }
    }
    
    @ViewBuilder
    private func overlayHighlight(_ resource: MaterialResource) -> some View {
        if resource == model.currentResource {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white, lineWidth: 1)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
            }
        }
    }
}

struct ControlView: View {
    
    @Environment(AppModel.self) private var model
    @Environment(FindSurface.self) private var findSurface
    
    var body: some View {
        @Bindable var findSurface = findSurface
        VStack {
            HStack {
                Text("Controls")
                    .font(.title.monospaced())
                Spacer()
            }
            VStack(alignment: .leading) {
                FeatureTypePicker(type: $findSurface.targetFeature,
                                  types: [.plane, .sphere, .cylinder, .cone, .torus])
                
                MaterialListView()
                
                ControlViewTextField(label: "     Accuracy [cm]",
                                     value: $findSurface.measurementAccuracy.mapMeterToCentimeter(),
                                     lowerbound: 0.3,
                                     upperbound: 10.0)
                ControlViewTextField(label: "Mean Distance [cm]",
                                     value: $findSurface.meanDistance.mapMeterToCentimeter(),
                                     lowerbound: 1.0,
                                     upperbound: 50.0)
                ControlViewTextField(label: "  Seed Radius [cm]",
                                     value: $findSurface.seedRadius.mapMeterToCentimeter(),
                                     lowerbound: 5.0,
                                     upperbound: 1000.0)
                
                ControlViewLevelPicker(label: "Lateral Extension", level: $findSurface.lateralExtension)
                
                ControlViewLevelPicker(label: " Radial Expansion", level: $findSurface.radialExpansion)
                
                GeometryToggleButton()
                
                MeshToggleButton()
                
                PreviewToggleButton()
                
                HStack {
                    UndoButton()
                    ClearButton()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white, lineWidth: 1)
        )
        .frame(width: 380)
        .disabled(model.shouldShowConfirmationDialog)
        .blur(radius: model.shouldShowConfirmationDialog ? 3.0 : 0.0)
    }
}

extension SearchLevel {
    
    var label: String {
        switch self {
        case .off: return "Off"
        case .lv1: return "Level 1"
        case .lv2: return "Level 2"
        case .lv3: return "Level 3"
        case .lv4: return "Level 4"
        case .lv5: return "Level 5"
        case .lv6: return "Level 6"
        case .lv7: return "Level 7"
        case .lv8: return "Level 8"
        case .lv9: return "Level 9"
        case .lv10: return "Level 10"
        }
    }
}

fileprivate struct ControlViewMonospacedLabel: View {
    let text: String
    let groupName: String
    var body: some View {
        Text(text)
            .font(.subheadline.monospaced())
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: true, vertical: false)
            .lineLimit(1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .joinWidthMinMaxGroup(name: groupName)
    }
}

fileprivate struct ControlViewTextField: View {
    
    let label: String
    @Binding var value: Float
    let lowerbound: Float
    let upperbound: Float
    
    @FocusState private var focused: Bool
    
    var body: some View {
        HStack {
            ControlViewMonospacedLabel(text: label, groupName: "ControlViewTextField")
            TextField("", value: $value, formatter: .decimal(1))
            .focused($focused)
            .onChange(of: focused) { old, new in
                if old && !new {
                    value = min(max(value, lowerbound), upperbound)
                }
            }
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .keyboardType(.decimalPad)
            .font(.caption.monospaced())
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
            .padding(.vertical, 2)
        }
    }
}

fileprivate struct ControlViewLevelPicker: View {
    
    let label: String
    @Binding var level: SearchLevel
    
    var body: some View {
        HStack {
            ZStack {
                ControlViewMonospacedLabel(text: "\(label): \(SearchLevel.lv10)", groupName: "ControlViewLevelPicker")
                    .hidden()
                
                ControlViewMonospacedLabel(text: "\(label): \(level)", groupName: "ControlViewLevelPicker")
            }
            let rawBinding = $level.wrap { level in
                level.rawValue
            } unwrap: { rawValue in
                SearchLevel(rawValue: rawValue)!
            }

            Stepper("", value: rawBinding, in: 0...10)
                .controlSize(.mini)
        }
    }
}

#Preview {
    ControlView()
        .environment(AppModel())
        .environment(FindSurface.instance)
}
