//
//  AppModel.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import SwiftUI
import ARKit
import RealityKit
import AVKit

import FindSurface_visionOS

/// Maintains app-wide state
@Observable
final class AppModel {
    
    private let findSurface = FindSurface.instance
    
    private let sceneReconstruction: SceneReconstructionProvider
    private let worldTracking: WorldTrackingProvider
    private let handTracking: HandTrackingProvider
    var dataProviders: [DataProvider] { [sceneReconstruction, worldTracking, handTracking] }
    
    private let meshAnchorUpdater: MeshAnchorUpdater
    let worldAnchorUpdater: WorldAnchorUpdater
    private let deviceAnchorUpdater: DeviceAnchorUpdater
    private let handAnchorUpdater: HandAnchorUpdater

    let rootEntity: Entity
    
    var meshVertexManager: MeshVertexManager
    var geometryManager: GeometryManager
    private let previewEntity: PreviewEntity
    
    let controlWindow: ControlWindow
    private var shouldInitializeControlWindowPosition: Bool = true
    
    private let triangleHighlighter: TriangleHighlighter
    
    let seedRadiusIndicator: SeedRadiusIndicator
    let pickingIndicator: ModelEntity
    
    let statusWindow: StatusWindow
    
    let timer = FoundTimer(eventsCount: 180)

    let warningWindow: WarningWindow
    
    let sceneBoundaryEntity: SceneBoundaryEntity
    
    private var _latestResult: (FindSurface.Result, simd_float3, Double)? = nil
    
    private func getLatestResult(_ location: simd_float3) -> FindSurface.Result? {
        guard let _latestResult else { return nil }
        let (result, latestLocation, timestamp) = _latestResult
        
        if case .none(_) = result { return nil }
        
        let current = Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
        guard current - timestamp < 200.0 else { return nil }
        
        guard distance_squared(location, latestLocation) < 0.01 else { return nil }
        
        return result
    }
    
    private func setLatestResult(_ result: FindSurface.Result?, _ location: simd_float3) {
        if let result {
            let timestamp = Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
            _latestResult = (result, location, timestamp)
        } else {
            _latestResult = nil
        }
    }
    
    var currentResource: MaterialResource? = nil
    var materialResources: [MaterialResource] = []
    
    init() {
        
        let sceneReconstruction = SceneReconstructionProvider()
        let worldTracking = WorldTrackingProvider()
        let handTracking = HandTrackingProvider()
        
        let meshAnchorUpdater = MeshAnchorUpdater(sceneReconstruction)
        let worldAnchorUpdater = WorldAnchorUpdater(worldTracking)
        let deviceAnchorUpdater = DeviceAnchorUpdater(worldTracking)
        let handAnchorUpdater = HandAnchorUpdater(handTracking)
        
        let rootEntity = Entity()
        rootEntity.name = "Root Entity"
        
        let meshVertexManager = MeshVertexManager()
        rootEntity.addChild(meshVertexManager.rootEntity)
        
        let geometryManager = GeometryManager()
        rootEntity.addChild(geometryManager.rootEntity)
        
        let previewEntity = PreviewEntity()
        rootEntity.addChild(previewEntity)
        
        let controlWindow = ControlWindow()
        rootEntity.addChild(controlWindow)
        
        let triangleHighlighter = TriangleHighlighter()
        rootEntity.addChild(triangleHighlighter)
        
        let seedRadiusIndicator = SeedRadiusIndicator()
        rootEntity.addChild(seedRadiusIndicator)
        
        let pickingIndicator = ModelEntity(mesh: .generateSphere(radius: 0.01),
                                           materials: [UnlitMaterial(color: .black)])
        pickingIndicator.components.set(OpacityComponent(opacity: 0.5))
        rootEntity.addChild(pickingIndicator)
        
        let statusWindow = StatusWindow()
        rootEntity.addChild(statusWindow)
        
        let warningWindow = WarningWindow()
        rootEntity.addChild(warningWindow)
        
        let sceneBoundaryEntity = SceneBoundaryEntity()
        rootEntity.addChild(sceneBoundaryEntity)
        
        self.sceneReconstruction = sceneReconstruction
        self.worldTracking = worldTracking
        self.handTracking = handTracking
        
        self.meshAnchorUpdater = meshAnchorUpdater
        self.worldAnchorUpdater = worldAnchorUpdater
        self.deviceAnchorUpdater = deviceAnchorUpdater
        self.handAnchorUpdater = handAnchorUpdater
        
        self.rootEntity = rootEntity
        
        self.meshVertexManager = meshVertexManager
        self.geometryManager = geometryManager
        self.previewEntity = previewEntity
        self.controlWindow = controlWindow
        self.triangleHighlighter = triangleHighlighter
        self.seedRadiusIndicator = seedRadiusIndicator
        self.pickingIndicator = pickingIndicator
        self.statusWindow = statusWindow
        self.warningWindow = warningWindow
        self.sceneBoundaryEntity = sceneBoundaryEntity
    }
    
    private var findSurfaceSemaphore = DispatchSemaphore(value: 1)
    private var loopTask: Task<(), Never>? = nil
    var findSurfaceEnabled: Bool = false {
        didSet {
            previewEntity.isVisible = findSurfaceEnabled
        }
    }
    var shouldTakeNextPreviewAsResult: Bool = false
    
    @MainActor
    func processSceneReconstructionUpdates() async {
        await meshAnchorUpdater.updateAnchors(added: meshVertexManager.anchorAdded(_:),
                                              updated: meshVertexManager.anchorUpdated(_:),
                                              removed: meshVertexManager.anchorRemoved(_:))
    }
    
    @MainActor
    func processWorldTrackingUpdates() async {
        await worldAnchorUpdater.updateAnchors { anchor in
            if (await geometryManager.anchorAdded(anchor)) == false {
                try? await worldAnchorUpdater.removeAnchor(anchor)
            }
        } updated: { anchor in
            await geometryManager.anchorUpdated(anchor)
        } removed: { anchor in
            await geometryManager.anchorRemoved(anchor)
        }
    }
    
    @MainActor
    func processDeviceTrackingUpdates() async {
        await deviceAnchorUpdater.updateAnchor { transform in
            if self.shouldInitializeControlWindowPosition {
                self.shouldInitializeControlWindowPosition = false
                self.locateControlWindowAroundDevice(transform)
            }
            
            self.warningWindow.look(at: transform.position, and: -transform.basisZ)
            self.warningWindow.checkCount(self.meshVertexManager.vertexCount)
            
            await self.geometryManager.highlightObject(transform)
            
            self.sceneBoundaryEntity.detectDeviceAnchor(transform.position)
        }
    }
    
    @MainActor
    func processHandTrackingUpdates() async {
        await handAnchorUpdater.updateAnchors { event, chirality, hand in
            let deviceTransform = deviceAnchorUpdater.transform
            switch chirality {
            case .right:
                controlWindow.look(at: deviceTransform, from: hand)
            case .left:
                statusWindow.look(at: deviceTransform, from: hand)
            }
        }
    }
    
    @MainActor
    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { [self] value in
                seedRadiusIndicator.locate(from: handAnchorUpdater.leftHand,
                                           handAnchorUpdater.rightHand,
                                           Float(value.magnification),
                                           and: deviceAnchorUpdater.transform)
            }
            .onEnded { [self] value in
                seedRadiusIndicator.updateFinished()
            }
    }
    
    @MainActor
    func restartFindSurfaceLoop() async {
        if let loopTask {
            loopTask.cancel()
        }
        loopTask = Task.detached {
            while Task.isCancelled == false {
                await self.performFindSurface()
            }
        }
    }
    
    @MainActor
    func handleLongPress() async {
        let deviceTransform = deviceAnchorUpdater.transform
        let devicePosition = deviceTransform.position
        let deviceDirection = -deviceTransform.basisZ
        
        guard let hits = geometryManager.rootEntity.scene?.raycast(origin: devicePosition,
                                                                         direction: deviceDirection,
                                                                         query: .all),
              let _entity = hits.first(where: { $0.entity is VirtualObjectEntity })?.entity,
              let entity = _entity as? VirtualObjectEntity & HasPlayableComponent & HasCustomHighlightComponent else {
            geometryManager.currentEntity = nil
            return
        }
        
        geometryManager.locateEntityMenuWindow(devicePosition, entity: entity)
    }
    
    private func performFindSurface() async {
        
        guard Task.isCancelled == false else { return }
        
        let deviceTransform = deviceAnchorUpdater.transform
        let devicePosition = deviceTransform.position
        let deviceDirection = -deviceTransform.basisZ
        
        let targetFeature = findSurface.targetFeature
        
        var result: FindSurface.Result? = nil
        
        guard let hit = await meshVertexManager.raycast(origin: devicePosition, direction: deviceDirection),
              let points = await meshVertexManager.nearestTriangleVertices(hit) else {
            
            timer.record(found: false)
            await previewEntity.setPreviewVisibility()
            await pickingIndicator.setPosition(devicePosition + deviceDirection, relativeTo: nil)
            return
        }
        
        await triangleHighlighter.updateTriangle(points.0, points.1, points.2)
        
        let location = hit.position
        await pickingIndicator.setPosition(location, relativeTo: nil)
        
        guard findSurfaceEnabled else {
            return
        }
        
        await criticalSection {
            do {
                let _result = try await findSurface.perform {
                    let meshPoints = meshVertexManager.vertices
                    guard let index = meshPoints.firstIndex(of: points.0) else { return nil }
                    return (meshPoints, index)
                }
                
                guard let _result else { return }
                
                result = _result
                return
            } catch {
                return
            }
        }
        
        guard let result else {
            timer.record(found: false)
            await previewEntity.setPreviewVisibility()

            return
        }
        
        guard Task.isCancelled == false else { return }

        Task {
            await processFindSurfaceResult(result, deviceTransform, targetFeature, location)
        }
    }
    
    private func criticalSection(_ block: () async -> Void) async {
        await findSurfaceSemaphore.wait()
        
        defer { findSurfaceSemaphore.signal() }
        
        return await block()
    }
    
    private func processFindSurfaceResult(_ result: FindSurface.Result,
                                          _ deviceTransform: simd_float4x4,
                                          _ targetFeature: FeatureType,
                                          _ location: simd_float3) async {
        
        var result = result
        
        result.alignGeometryAndTransformInliers(gesturePosition: location,
                                                devicePosition: deviceTransform.position,
                                                true, 0.10)
        
        if case .none(_) = result {
            timer.record(found: false)
        } else {
            timer.record(found: true)
            setLatestResult(result, location)
        }
        
        if shouldTakeNextPreviewAsResult {
            shouldTakeNextPreviewAsResult = false
            
            if case .none = result {
                if let latestResult = getLatestResult(location) {
                    setLatestResult(nil, .zero)
                    result = latestResult
                } else {
                    AudioServicesPlaySystemSound(1053)
                    return
                }
            }
            
            AudioServicesPlaySystemSound(1100)
            
            let worldAnchor = await geometryManager.addPendingObject(result,
                                                                     resource: currentResource!,
                                                                     gesturePosition: location,
                                                                     deviceTransform: deviceTransform)
            do {
                try await worldAnchorUpdater.addAnchor(worldAnchor)
            } catch {
                geometryManager.removePendingObject(forKey: worldAnchor.id)
            }
        } else {
            await previewEntity.update(result, currentResource)
        }
    }
    
    private func locateControlWindowAroundDevice(_ deviceTransform: simd_float4x4) {
        let devicePosition = deviceTransform.position
        let deviceForward = -deviceTransform.basisZ
        let deviceRight = deviceTransform.basisX
        
        let location = devicePosition + 0.7 * normalize(deviceForward * 2.0 + deviceRight)
        controlWindow.look(at: devicePosition, from: location, relativeTo: nil, forward: .positiveZ)
    }
    
    private var startTime: UInt64 = 0
    private var escapeLoop: Bool = false
    
    deinit {
        escapeLoop = true
    }
    
    @MainActor
    func animation() async {
        startTime = DispatchTime.now().uptimeNanoseconds
        repeat {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000 / 90)
            } catch {}
            
            if escapeLoop { return }
            
            let currentTime = DispatchTime.now().uptimeNanoseconds
            let elapsedTime = Double(currentTime - startTime) / 1_000_000_000
            
            for entity in geometryManager.objectEntityMap.values {
                if let sphere = entity as? SphereScreenEntity {
                    sphere.setAnimationTime(elapsedTime)
                } else if let cylinder = entity as? CylinderScreenEntity {
                    cylinder.setAnimationTime(elapsedTime)
                } else if let cone = entity as? ConeScreenEntity {
                    cone.setAnimationTime(elapsedTime)
                }
            }
            
        } while true
    }
    
    var shouldShowConfirmationDialog: Bool {
        get {
            access(keyPath: \.shouldShowConfirmationDialog)
            return controlWindow.confirmView?.isVisible ?? false
        }
        set {
            withMutation(keyPath: \.shouldShowConfirmationDialog) {
                controlWindow.confirmView?.isVisible = newValue
            }
        }
    }
}

extension DispatchSemaphore {
    
    func wait() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.wait()
                continuation.resume()
            }
        }
    }
}
