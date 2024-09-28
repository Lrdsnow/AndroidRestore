//
//  BackupManifest.swift
//  AndroidRestore
//
//  Created by Lrdsnow on 9/26/24.
//

import SQLite
import Foundation
import Gzip
import SwiftProtobuf

typealias Expression = SQLite.Expression

struct BackupFile: Identifiable {
    var id = UUID()
    var fileID: String
    var domain: String
    var relativePath: String
    var flags: Int64
}

func loadManifest(backupPath: String, encryptionKey: String? = nil) -> [BackupFile] {
    let manifestPath = "\(backupPath)/Manifest.db"
    var backupFiles: [BackupFile] = []
    
    do {
        // Establish a connection to the database
        let db = try Connection(manifestPath)
        
        // Set the encryption key if provided
        if let key = encryptionKey {
            try db.run("PRAGMA key = '\(key)';")
        }
        
        let filesTable = Table("Files")
        
        // Define expressions for each column
        let fileID = Expression<String>("fileID")
        let domain = Expression<String>("domain")
        let relativePath = Expression<String>("relativePath")
        let flags = Expression<Int64>("flags")
        
        // Query the files table
        for file in try db.prepare(filesTable) {
            let backupFile = BackupFile(
                fileID: try file.get(fileID),
                domain: try file.get(domain),
                relativePath: try file.get(relativePath),
                flags: try file.get(flags)
            )
            backupFiles.append(backupFile)
        }
    } catch {
        print("Failed to load Manifest.db: \(error)")
    }
    return backupFiles
}

struct _Note: Hashable, Identifiable, Codable {
    var id: Int
    var title: String
    var text: String
    var snippet: String
    var modifyDate: Double
}

func loadNotes(notesPath: String) -> [_Note] {
    var Notes: [_Note] = []
    var NotesByID: [Int:(String, Double, String)] = [:]
    
    do {
        let db = try Connection(notesPath)
        
        let icloudSyncTable = Table("ZICCLOUDSYNCINGOBJECT")
        let noteDataTable = Table("ZICNOTEDATA")
        
        // icloud sync
        let zNoteData = Expression<Int>("ZNOTEDATA")
        let zTitle = Expression<String>("ZTITLE1")
        let zFolderModificationDate = Expression<Double>("ZFOLDERMODIFICATIONDATE")
        let zSnippet = Expression<String>("ZSNIPPET")
        // note data
        let zPK = Expression<Int>("Z_PK")
        let zData = Expression<Data>("ZDATA")
        
        for _note in try db.prepare(icloudSyncTable) {
            let title = (try? _note.get(zTitle)) ?? ""
            if !title.isEmpty,
               let id = try? _note.get(zNoteData),
               let modifyDate = try? _note.get(zFolderModificationDate),
               let snippet = try? _note.get(zSnippet) {
                NotesByID[id] = (title, modifyDate, snippet)
            }
        }
        for _note in try db.prepare(noteDataTable) {
            if let id = try? _note.get(zPK),
               let title = NotesByID[id]?.0,
               let modifyDate = NotesByID[id]?.1,
               let snippet = NotesByID[id]?.2,
               let data = try? _note.get(zData),
               let decompressedData = try? data.gunzipped(),
               let text = getNoteText(data: decompressedData) {
                Notes.append(_Note(id: id, title: title, text: text, snippet: snippet, modifyDate: modifyDate))
            }
        }
    } catch {
        print("Failed to load Notes: \(error)")
    }
    
    return Notes
}

func getNoteText(data: Data) -> String? {
    do {
        let noteStoreProto = try NoteStoreProto(serializedData: data)
        let note = noteStoreProto.document.note
        return note.noteText
    } catch {
        print("Failed to decode protobuf: \(error)")
    }
    return nil
}


struct Backup: Identifiable {
    var id = UUID()
    var applications: [String:PlaceHolderApp]
    var deviceName: String
    var displayName: String
    var buildVersion: String
    var productName: String
    var productType: String
    var productVersion: String
    var serialNumber: String
    var lastBackupDate: Date?
    var infoDict: [String: Any]
    var path: String
}

struct PlaceHolderApp {
    var IsDemotedApp: Bool? = nil
    var ApplicationSINF: Data? = nil
    var PlaceholderIcon: Data
    var iTunesMetadata: [String:Any]
    var available: String = "notfound"
    var potentialBundleID: String? = nil
    var confidentAvailable: Bool = false
    var checkedAvailablility: Bool = false
}
