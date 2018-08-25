//
// NSPersistentContainer.swift
//
// WidgetKit, Copyright (c) 2018 M8 Labs (http://m8labs.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Groot

public extension NSPersistentContainer {
    
    private static var defaultQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    static var `default`: NSPersistentContainer = {
        guard let model = NSManagedObjectModel.mergedModel(from: nil) else { fatalError("Model not found.") }
        return containerForModel(model)
    }()
    
    static var inMemory: NSPersistentContainer = {
        guard let model = NSManagedObjectModel.mergedModel(from: nil) else { fatalError("Model not found.") }
        return containerForModel(model, identifier: "inMemory", type: NSInMemoryStoreType)
    }()
    
    public static func containerForModel(_ model: NSManagedObjectModel,
                                         identifier: String = "Default",
                                         type: String = NSSQLiteStoreType) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: identifier, managedObjectModel: model)
        let defaultURL = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("\(identifier).sqlite")
        let description = NSPersistentStoreDescription(url: defaultURL)
        description.type = type
        description.shouldAddStoreAsynchronously = false
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores(completionHandler: { desc, error in
            if error != nil {
                print("Load store error'\(identifier)': \(error!)")
            } else {
                print("Loaded store '\(identifier)': \(desc)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
    
    func enqueueBackgroundTask(_ closure: @escaping (NSManagedObjectContext)->Void) {
        NSPersistentContainer.defaultQueue.addOperation {
            let context = self.newBackgroundContext()
            context.perform {
                closure(context)
            }
        }
    }
}

public extension NSPersistentContainer {
    
    public func objects(withEntityName name: String,
                        fromJSONArray array: JSONArray,
                        clearOld: Bool = false,
                        setters: [String: Any] = [:],
                        completion: @escaping ([NSManagedObject]?, Error?)->Void) {
        enqueueBackgroundTask { context in
            if clearOld {
                NSManagedObject.clear(entityName: name, context: context)
            }
            do {
                let objects = try GRTJSONSerialization.objects(withEntityName: name, fromJSONArray: array, in: context)
                objects.forEach { object in
                    setters.forEach { key, value in
                        object.setValue(value, forKey: key)
                    }
                }
                try context.save()
                let objectsIDs = objects.map({ $0.objectID })
                self.viewContext.perform {
                    let newObjects = objectsIDs.map {
                        self.viewContext.object(with: $0)
                    }
                    completion(newObjects, nil)
                }
            } catch {
                self.viewContext.perform { completion(nil, error) }
            }
        }
    }
    
    public func object(withEntityName name: String,
                       fromJSONDictionary dictionary: JSONDictionary,
                       clearOld: Bool = false,
                       setters: [String: Any] = [:],
                       completion: @escaping (NSManagedObject?, Error?)->Void) {
        enqueueBackgroundTask() { context in
            if clearOld {
                NSManagedObject.clear(entityName: name, context: context)
            }
            do {
                let object = try GRTJSONSerialization.object(withEntityName: name, fromJSONDictionary: dictionary, in: context)
                setters.forEach { key, value in
                    object.setValue(value, forKey: key)
                }
                try context.save()
                let objectID = object.objectID
                self.viewContext.perform {
                    let newObject = self.viewContext.object(with: objectID)
                    completion(newObject, nil)
                }
            } catch {
                self.viewContext.perform { completion(nil, error) }
            }
        }
    }
    
    public func clear(entities: [NSManagedObject.Type], completion: Completion? = nil) {
        let entityNames = entities.map { "\($0)" }
        clear(entityNames: entityNames, completion: completion)
    }
    
    public func clear(entityNames: [String]? = nil, completion: Completion? = nil) {
        let entityNames = (entityNames?.count ?? 0) > 0 ? entityNames! : managedObjectModel.entities.map { $0.name! }
        enqueueBackgroundTask() { context in
            for entityName in entityNames {
                NSManagedObject.clear(entityName: entityName, context: context)
            }
            do {
                try context.save()
                self.viewContext.perform {
                    completion?(nil, nil)
                }
            } catch {
                print(error)
                self.viewContext.perform {
                    completion?(nil, error)
                }
            }
        }
    }
}

public extension NSManagedObjectContext {
    
    static var main: NSManagedObjectContext {
        return NSPersistentContainer.default.viewContext
    }
    
    static var inMemory: NSManagedObjectContext {
        return NSPersistentContainer.inMemory.viewContext
    }
}
