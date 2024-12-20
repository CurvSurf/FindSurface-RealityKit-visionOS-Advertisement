//
//  PersistentContainer.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/28/24.
//

import SwiftData

@MainActor
final class PersistentDataModel {
    
    static let shared = PersistentDataModel()
    
    let container: ModelContainer
    let context: ModelContext
    
    private init() {
        do {
            let schema = Schema([ObjectData.self, MaterialData.self])
            let modelConfiguration = ModelConfiguration(schema: schema)
            let container = try ModelContainer(for: schema,
                                               configurations: modelConfiguration)
            
            let context = container.mainContext
            try! context.save()
            
            let resourceURLs = {
                do {
                    let descriptor = FetchDescriptor<MaterialData>(predicate: .true)
                    return try context.fetch(descriptor)
                } catch {
                    fatalError("Failed to fetch resource urls: \(error)")
                }
            }()
            
            let persistentObjects = {
                do {
                    let descriptor = FetchDescriptor<ObjectData>(predicate: .true)
                    return try context.fetch(descriptor)
                } catch {
                    fatalError("Failed to fetch persistent objects: \(error)")
                }
            }()
            
            self.container = container
            self.context = context
            self.objectData = persistentObjects
            self.materialData = resourceURLs
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
    }
    
    var objectData: [ObjectData] {
        didSet {
            let oldSet = Set(oldValue)
            let newSet = Set(objectData)
            let removed = oldSet.subtracting(newSet)
            let added = newSet.subtracting(oldSet)
            
            try! context.transaction {
                removed.forEach(context.delete)
                added.forEach(context.insert)
            }
        }
    }
    
    var materialData: [MaterialData] {
        didSet {
            let oldSet = Set(oldValue)
            let newSet = Set(materialData)
            let removed = oldSet.subtracting(newSet)
            let added = newSet.subtracting(oldSet)
            
            try! context.transaction {
                removed.forEach(context.delete)
                added.forEach(context.insert)
            }
        }
    }
}
