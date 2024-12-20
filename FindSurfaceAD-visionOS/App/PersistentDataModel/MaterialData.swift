//
//  MaterialModel.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/29/24.
//
import SwiftData
import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import AVFoundation

@Model
final class MaterialData: Equatable {
    @Attribute(.unique) private(set) var filename: String
    
    @Transient lazy var url: URL = {
        URL.documentsDirectory.appendingPathComponent(filename)
    }()
    @Transient weak var resource: MaterialResource? = nil
    
    init(_ url: URL) {
        self.filename = url.lastPathComponent
    }
}

