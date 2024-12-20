//
//  MainPageView.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/27/24.
//

import SwiftUI


struct MainPageView: View {
    
    var body: some View {
        VStack {
            AppTitle()
            IntroductionText()
            Proclaimer()
        }
        .padding()
    }
    
    
    private struct AppTitle: View {
        var body: some View {
            Text("FindSurfaceAD for visionOS")
                .font(.title)
                .padding(.bottom, 10)
        }
    }

    private struct IntroductionText: View {
        var body: some View {
            Text("Display photos and videos on geometry surfaces using FindSurface's measurement functionality.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .frame(width: 400)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
        }
    }

    private struct Proclaimer: View {
        var body: some View {
            VStack {
                Text("PROCLAIMER")
                    .font(.footnote.bold())
                Text("This app uses the vertex data extracted from MeshAnchor, so it may not detect or accurately detect objects with a size (approximate diameter or width) less than 1 meter.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .frame(width: 400)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

}
