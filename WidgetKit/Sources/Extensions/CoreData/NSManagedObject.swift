//
// NSManagedObject.swift
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

public extension NSManagedObject {
    
    class func create<T: NSManagedObject>(context: NSManagedObjectContext = NSManagedObjectContext.main) -> T {
        let entityName = "\(self)"
        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        return object as! T
    }
    
    class func objects(of entityName: String,
                       with predicate: NSPredicate? = nil,
                       sortByFields: [String]? = nil,
                       sortAscending: Bool = true,
                       context: NSManagedObjectContext = NSManagedObjectContext.main) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: entityName, in: context)
        fetchRequest.predicate = predicate
        if let sortFields = sortByFields {
            var sortDescriptors = [NSSortDescriptor]()
            for fieldName: String in sortFields {
                sortDescriptors.append(NSSortDescriptor(key: fieldName.trimmingCharacters(in: CharacterSet.whitespaces), ascending: sortAscending))
            }
            fetchRequest.sortDescriptors = sortDescriptors
        }
        let objects = try? context.fetch(fetchRequest) as! [NSManagedObject]
        return objects ?? []
    }
    
    class func objects<T: NSManagedObject>(with predicate: NSPredicate? = nil,
                                           sortByFields: [String]? = nil,
                                           sortAscending: Bool = true,
                                           context: NSManagedObjectContext = NSManagedObjectContext.main) -> [T] {
        let entityName = "\(self)"
        return objects(of: entityName, with: predicate, sortByFields: sortByFields, sortAscending: sortAscending, context: context) as! [T]
    }
    
    class func all<T: NSManagedObject>(context: NSManagedObjectContext = NSManagedObjectContext.main) -> [T] {
        return objects(context: context) as! [T]
    }
    
    class func clear(entityName: String, context: NSManagedObjectContext) {
        let objects = self.objects(of: entityName, context: context)
        for object in objects {
            context.delete(object)
        }
    }
    
    func delete() {
        managedObjectContext?.delete(self)
        do {
            try managedObjectContext?.save()
        } catch {
            print(error)
        }
    }
}

@objc
public extension NSManagedObject {
    
    override var objectId: String {
        if let attrName = entity.userInfo?["identityAttribute"] as? String {
            if let objectId = value(forKey: attrName) as? String {
                return objectId
            }
        }
        return super.objectId
    }
    
    var owner: NSManagedObject? {
        if let relationshipName = entity.userInfo?["ownerRelationship"] as? String {
            if let owner = value(forKey: relationshipName) as? NSManagedObject {
                return owner
            }
        }
        return nil
    }
    
    var isMine: Bool {
        if let owner = owner, let isOwnerEntity = owner.entity.userInfo?["isOwnerEntity"] as? String {
            return NSString(string: isOwnerEntity).boolValue
        }
        return true
    }
}
