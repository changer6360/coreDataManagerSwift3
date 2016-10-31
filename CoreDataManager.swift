//
//  CoreDataManger.swift
//
//
//  Created by Jean-Louis Murphy on 2016-08-25.
//  Copyright © 2016 Jean-Louis Murphy. All rights reserved.
//

////////////////////////////////
/*
NOTES
 
 THIS MODEL BASICALLY TAKES THE APPLE AND THIRD-PARTY GUIDELINES TO CREATING A PERSISTENT STORE (CORE DATA LIBRARY FOR YOUR APP) BUT ADAPTED INTO SWIFT 3, TECHNICALLY, ANYONE CAN RE-CREATE THIS CLASS AFTER HAVING PUT ENOUGH TIME INTO IT, INITIATING IT'S CORE DATA PROPERTIES AND THE ENTITIES YOU WANT. THE HASSLE STEMS FROM TRANSLATING SWIFT 2 CD SYNTHAX TO SWIFT 3, WHICH ARE COMPLETELY DIFFERENT FOR THE CORE DATA FRAMEWORK.
 
 YOU MUST HAVE A VALID OBJECT MODEL FILE CREATED INSIDE YOUR PROJECT IN ORDER TO MAKE THIS WORK:
 REPLACE THE NAME OF THE DATA MODEL IN THE PLACEHOLD IN MANAGEDOBJECTMODEL
 
 HERE I USE AN EXAMPLE WITH A USER AND OMNIKEYS (STRINGS MAINLY) ENTITIES. BE MINDFULL OF UNWRAPPING VALUES WHEN NECESSARY
 
 NOTE THAT IT IS RECOMMENDED TO CREATED MANY MODELS AS MUCH AS IT IS TO CREATE MANY ENTITIES TO DIVERSIFY
 CALLING A METHOD IS DONE LIKE SO:
 
 -instantiate the class in the top level scope of whichever class you need to use CD:
 
 let coreDataManager (or any other equivalent) = CoreDataManager()
 
 -If you are using several managedObjectModels, it might be simpler for future synthax to create a class like this one for each of these models. This is because the managedObjectContext defined in the methods are implicitly using the managedObjectContext variable in this class ONLY. saving the trouble of calling up the managedObjectContext every single time you import Core Data in another swift file. If you follow this principle, then calling any given function is as simple as:
 
 let theTokenString = coreDataManager.omniTokenFromCore() 
 
 
 
 ""
 
 */

import UIKit
import CoreData

class CoreDataManager: NSObject {
    
    // YOU CAN CREATE AS MANY OBJECT MODELS AS YOU LIKE.. BUT BE MINDFUL OF THEIR PURPOSE WHEN CALLING THEM AS TO AVOID MINDBUSTING DEBBUGING SPREES
    lazy var manageObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "<THE NAME OF YOUR DATA MODEL>", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.manageObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("CDData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved Data"
        
        do {
            let options = [ NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true ]
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
        } catch {
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = dict["Failed to initialize the application's saved data"]
            dict[NSLocalizedFailureReasonErrorKey] = dict[failureReason]
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            NSLog("Unresolved error \(wrappedError)", "\(wrappedError.userInfo)")
            abort()
        }
        return coordinator
    }()
    
    private lazy var applicationDocumentsDirectory: NSURL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count - 1] as NSURL
    }()
    
    ///METHOD THAT CREATES THE STORE FOR THE GIVEN MANAGED OBJECT MODEL, NEED TO MAKE SURE THAT YOU HAVE EACH ENTITY YOU  WANT TO USE IN HERE. MUST BE CALLED AT FIRST INSTALL OF THE APP
    func seedPersistentStoreWithManagedObjectContext(managedObjectContext: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: strings.didSeedStore) else { UserDefaults.standard.set(false, forKey: strings.didSeedStore)
            return
        }
        let user = createRecordForEntity(entity: "UserProfile", inManagedObjectContext: managedObjectContext)
        let keys = createRecordForEntity(entity: "OmniKeys", inManagedObjectContext: managedObjectContext)
        
        if saveChanges() {
            UserDefaults.standard.set(true, forKey: strings.didSeedStore)//THIS IS A USERDEFAULT STRING VALUE.. NOT MANDATORY BUT USEFUL FOR LOGIC FLOWS WITHIN diFinishLaunchingWithOptions METHOD OF APPDELEGATE
            print("seededPersistentStore")
        }
    }
    
    //SELF EXPLANATORY
    func createRecordForEntity(entity: String, inManagedObjectContext managedObjectContext: NSManagedObjectContext) -> NSManagedObject {
        
        var result: NSManagedObject? = nil
        
        //create entity description
        let entityDescription = NSEntityDescription.entity(forEntityName: entity, in: managedObjectContext)
        
        if let entityDescription = entityDescription {
            
            result = NSManagedObject(entity: entityDescription, insertInto: managedObjectContext)
            
        }
        
        return result!
    }
    
    //THESE ARE SAMPLE METHODS I HAVE FOR FETCHING AND SAVING/UPDATING THE VALUE FOR AN ENTITY PROPERTY (NAMED "ACCTOKEN", A GIVEN STRING, IN THIS CASE).
    
    func omniTokenFromCore() -> String {
        var result = String()
        let request: NSFetchRequest<OmniKeys> = OmniKeys.fetchRequest()
        
        do {
            let records = try managedObjectContext.fetch(request) as [OmniKeys]
            if let then = records.first?.acctoken {
                result = then
                print("result is \(result)")
            } else {
                print("return failed since access token is nil")
            }
        } catch {
            print("could not save data to")
        }
        return result
    }
    
    func saveTokenToCore(_ token: String) {
        
        let request: NSFetchRequest<OmniKeys> = OmniKeys.fetchRequest()
        
        do {
            let records = try managedObjectContext.fetch(request) as [OmniKeys]
            records.first?.setValue(token, forKey: "acctoken")
            try managedObjectContext.save()
        } catch {
            print("could not save data to")
        }
    }
    
    //A CONDITIONAL WAY TO SAVE THE PERSISTENT STORE, TO AVOID POTENTIAL LAG DUE TO DISK ACTIVITY.
    func saveContext() {
        if managedObjectContext.hasChanges{
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror)", "\(nserror.userInfo)")
                abort()
            }
        }
    }
    
    //NEVER EVER HAVE THIS INSIDE A PRODUCTION VERSION OF AN APP, THIS IS FOR DEBUGGING AND ON THE FLY RESETTING OF THE PERSISTENT STORE WITHOUT RE-INSTALLATION. REQUIRES THAT YOU HAVE THE SEEDPERSISTENTSTORE INTEGRATED IN YOUR LAUNCH FLOW.
    func destroyStore() {
        do {
            try persistentStoreCoordinator.destroyPersistentStore(at: self.applicationDocumentsDirectory.appendingPathComponent("CDData.sqlite")!, ofType: NSSQLiteStoreType, options: nil)
        } catch {
            print("couldnt delete persistent store")
        }
    }
    
    func saveChanges() -> Bool {
        var result = true
        do {
            try managedObjectContext.save()
        } catch {
            result = false
            let saveError = error as NSError
            print("\(saveError), \(saveError.userInfo)")
        }
        return result
    }
    
    func saveData() {
        do {
            try managedObjectContext.save()
        } catch {
            print("appdelegateSave: Could not save all data")
        }
    }
}
