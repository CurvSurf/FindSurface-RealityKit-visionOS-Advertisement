//
//  StatusView.swift
//  FindSurfaceRR-visionOS
//
//  Created by CurvSurf-SGKim on 9/2/24.
//

import Foundation
import SwiftUI

struct StatusView: View {
    
    @Environment(FoundTimer.self) private var timer
    @Environment(AppModel.self) private var state
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let fps = String(format: "%d fps", Int(timer.foundFps.rounded()))
            Label(fps, systemImage: "f.square.fill")
                .imageScale(.large)
                .font(.body.bold().monospaced())
            
            let points = "\(state.meshVertexManager.vertexCount) pts."
            Label(points, systemImage: "p.square.fill")
                .imageScale(.large)
                .font(.body.bold().monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            FPSGraphView(queue: timer.fpsRecords,
                         lowerbound: 0.0,
                         upperbound: 400,
                         unlimited: true)
            .padding(1)
        )
        .background(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 1))
        .padding(.top)
    }
}

fileprivate let timer = FoundTimer(eventsCount: 5)

#Preview {
    
    StatusView()
        .environment(timer)
        .environment(AppModel())
        .task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            timer.record(found: true)
            for _ in 0...180 {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.002...0.008) * 1_000_000_000))
                timer.record(found: true)
            }
        }
        .frame(width: 380)
}