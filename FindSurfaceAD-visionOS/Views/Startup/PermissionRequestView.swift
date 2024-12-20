//
//  PermissionRequestView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/8/24.
//

import SwiftUI

struct PermissionRequestView: View {
    var body: some View {
        VStack {
            Title()
            BodyText()
            RequiredPermissionList()
            OpenSettingsButton()
        }
        .padding(.vertical, 8)
        .frame(width: 360)
    }
    
    private struct Title: View {
        var body: some View {
            Text("⚠️ Permissions Not Granted ⚠️")
                .foregroundStyle(.red)
                .padding(.top, 8)
                .padding(.bottom, 2)
        }
    }
    
    private struct BodyText: View {
        var body: some View {
            Text("Please tap **Open Settings** button below to open the Settings app and enable the following permissions:")
                .font(.footnote)
                .fontWeight(.light)
                .padding(.horizontal, 30)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private struct RequiredPermissionList: View {
        @Environment(SessionManager.self) private var sessionManager
        
        var body: some View {
            VStack(alignment: .leading) {
                if sessionManager.handTrackingAllowed == false {
                    HandTrackingPermissionItem()
                }
                if sessionManager.worldSensingAllowed == false {
                    WorldSensingPermissionItem()
                }
            }
        }
        
        private struct HandTrackingPermissionItem: View {
            var body: some View {
                Label {
                    Text("Hand Structure And Movements")
                } icon: {
                    Image(systemName: "hand.point.up.fill")
                        .rotationEffect(.degrees(-15))
                        .iconBackground()
                        .padding(.leading, 2.1)
                        .padding(.trailing, 2)
                }
            }
        }
        
        private struct WorldSensingPermissionItem: View {
            var body: some View {
                Label {
                    Text("Surroundings")
                } icon: {
                    Image(systemName: "camera.metering.multispot")
                        .iconBackground()
                }
            }
        }
    }
    
    private struct OpenSettingsButton: View {
        var body: some View {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}

fileprivate struct IconBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .imageScale(.small)
            .padding(6)
            .background(
                LinearGradient(colors: [.cyan, .blue],
                               startPoint: .top,
                               endPoint: .bottom)
            )
            .clipShape(.circle)
    }
}

extension View {
    fileprivate func iconBackground() -> some View {
        modifier(IconBackground())
    }
}

#Preview {
    PermissionRequestView()
        .environment(SessionManager())
        .glassBackgroundEffect()
}
