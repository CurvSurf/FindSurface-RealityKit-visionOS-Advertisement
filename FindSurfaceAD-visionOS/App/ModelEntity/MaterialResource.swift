//
//  MaterialResource.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/29/24.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import RealityKit

@Observable
final class MaterialResource: Identifiable, Hashable, Equatable {
    
    let data: MaterialData
    let thumbnail: UIImage
    let material: any RealityKit.Material
    let audioResource: AudioFileResource?
    
    private init(_ data: MaterialData,
                 _ thumbnail: UIImage,
                 _ material: any RealityKit.Material,
                 _ audioResource: AudioFileResource? = nil) {
        self.data = data
        self.thumbnail = thumbnail
        self.material = material
        self.audioResource = audioResource
    }
    
    var id: String {
        data.filename
    }
    
    var filename: String {
        data.filename
    }
    
    static func == (lhs: MaterialResource, rhs: MaterialResource) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
    }
    
    static func generate(from data: MaterialData) async throws -> MaterialResource {
        
        let url = data.url
        guard let uttype = UTType(filenameExtension: url.pathExtension) else {
            throw Error.invalidExtension
        }
        
        if uttype.isSubtype(of: .image) {
            let (thumbnail, material) = try await generateImageMaterial(from: url)
            return MaterialResource(data, thumbnail, material)
        } else if uttype.isSubtype(of: .video) || uttype.isSubtype(of: .movie) {
            let (thumbnail, material, audioResource) = try await generateVideoMaterial(from: url)
            return MaterialResource(data, thumbnail, material, audioResource)
        } else {
            throw Error.unsupportedFileType
        }
    }
    
    static private func generateImageMaterial(from url: URL) async throws -> (UIImage, any RealityKit.Material) {
        let imageData: Data
        do {
            imageData = try Data(contentsOf: url)
        } catch {
            throw Error.failedToLoadDataFromURL(error)
        }
        
        guard let thumbnail = UIImage(data: imageData) else {
            throw Error.failedToCreateUIImage
        }
        
        guard let cgImage = thumbnail.cgImage else {
            throw Error.failedToGetCGImage
        }
        
        let textureResource: TextureResource
        do {
            textureResource = try await TextureResource(image: cgImage,
                                                        options: .init(semantic: .color))
        } catch {
            throw Error.failedToCreateTextureResource(error)
        }
        
        var material = UnlitMaterial()
        material.color.texture = .init(textureResource)
        
        return (thumbnail, material)
    }
    
    static private func generateVideoMaterial(from url: URL) async throws -> (UIImage, any RealityKit.Material, AudioFileResource) {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        let cgImage: CGImage
        do {
            cgImage = try await imageGenerator.image(at: .zero).image
        } catch {
            throw Error.failedToFetchImage(error)
        }
        
        let thumbnail = UIImage(cgImage: cgImage)
        
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        let material = await VideoMaterial(avPlayer: player)
        
        let audioResource: AudioFileResource
        do {
            audioResource = try await AudioFileResource(contentsOf: url, configuration: .init(loadingStrategy: .preload, shouldLoop: false))
        } catch {
            throw Error.failedToCreateAudioFileResource(error)
        }
        
        return (thumbnail, material, audioResource)
    }
    
    enum Error: Swift.Error {
        case invalidExtension
        case unsupportedFileType
        case failedToLoadDataFromURL(any Swift.Error)
        case failedToCreateUIImage
        case failedToGetCGImage
        case failedToCreateTextureResource(any Swift.Error)
        case failedToFetchImage(any Swift.Error)
        case failedToCreateAudioFileResource(any Swift.Error)
    }
}
