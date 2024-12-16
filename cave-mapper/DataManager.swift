//
//  DataManager.swift
//  cave-mapper
//
//  Created by Andrey Manolov on 20.11.24.
//
import Foundation



class DataManager {
    private static let pointNumberKey = "pointNumberKey"
    private static let savedDataKey = "savedDataKey"

    static func save(savedData: SavedData) {
        var savedDataArray = loadSavedData()
        savedDataArray.append(savedData)
        if let encodedData = try? JSONEncoder().encode(savedDataArray) {
            UserDefaults.standard.set(encodedData, forKey: savedDataKey)
        }
    }

    static func loadSavedData() -> [SavedData] {
        if let savedData = UserDefaults.standard.data(forKey: savedDataKey),
           let decodedData = try? JSONDecoder().decode([SavedData].self, from: savedData) {
            return decodedData
        }
        return []
    }

    static func savePointNumber(_ pointNumber: Int) {
        UserDefaults.standard.set(pointNumber, forKey: pointNumberKey)
    }

    static func loadPointNumber() -> Int {
        return UserDefaults.standard.integer(forKey: pointNumberKey)
    }
    
    

    static func resetAllData() {
        UserDefaults.standard.removeObject(forKey: pointNumberKey)
        UserDefaults.standard.removeObject(forKey: savedDataKey)
        print("All data has been reset.")
    }
    
    static func loadLastSavedDepth() -> Double {
        let savedDataArray = loadSavedData()
        
        // Filter the array to include only entries where rtype is "manual"
        let manualEntries = savedDataArray.filter { $0.rtype == "manual" }
        
        // Return the depth of the last manual entry or 0.0 if none exist
        return manualEntries.last?.depth ?? 0.0
    }
    
    
    static func loadLastSavedDistance() -> Double {
        let savedDataArray = loadSavedData()
        
        // Filter the array to include only entries where rtype is "manual"
//        let manualEntries = savedDataArray.filter { $0.rtype == "manual" }
        
        // Return the depth of the last manual entry or 0.0 if none exist
        return savedDataArray.last?.distance ?? 0.0
    }


    
    
    
}

