//
//  ContentView.swift
//  AndroidRestore
//
//  Created by Lrdsnow on 9/26/24.
//

import SwiftUI
import Foundation
import SwiftProtobuf

struct AppDomainData: Identifiable {
    var id: String { get { return bundleID } set {} }
    var bundleID: String // app id
    var paths: [String] // path
    var fileIDs: [String:String] // id:path
}

struct ImageDomainData: Identifiable {
    var id: String { get { return fileID } set {} }
    var fileID: String
    var fileName: String
}

struct ManifestView: View {
    var backupPath: String
    @State private var appData: [AppDomainData] = []
    @State private var documents: AppDomainData? = nil
    @State private var images: [ImageDomainData] = []
    @State private var notes: [_Note] = []
    
    var body: some View {
        VStack {
            if !appData.isEmpty || (documents != nil) || !images.isEmpty {
                List {
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.headline)
                        ForEach(notes, id:\.self) { note in
                            Text("- \(note.title).txt")
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Images")
                            .font(.headline)
                        ForEach(images) { image in
                            Text("- \(image.fileName)")
                        }
                    }
                    if let documents = documents {
                        VStack(alignment: .leading) {
                            Text("Documents")
                                .font(.headline)
                            ForEach(documents.paths, id:\.self) { path in
                                Text("- \(path)")
                            }
                        }
                    }
                    ForEach(appData) { file in
                        VStack(alignment: .leading) {
                            Text(file.bundleID)
                                .font(.headline)
                            ForEach(file.paths, id:\.self) { path in
                                Text("- \(path)")
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Manifest.db")
        .onAppear(perform: {
            Task.detached {
                let backupFiles = loadBackupFiles(backupPath: backupPath)
                DispatchQueue.main.async {
                    appData = backupFiles.appData
                    documents = backupFiles.documents
                    images = backupFiles.images
                    notes = backupFiles.notes
                }
                
            }
        })
    }
}

func loadBackupFiles(backupPath: String) -> (appData: [AppDomainData], documents: AppDomainData?, images: [ImageDomainData], notes: [_Note]) {
    var appData: [AppDomainData] = []
    var documents: AppDomainData? = nil
    var images: [ImageDomainData] = []
    var notes: [_Note] = []
    
    let backupFiles = loadManifest(backupPath: backupPath)
    for file in backupFiles {
        if !file.relativePath.isEmpty {
            // Apps
            if file.domain.contains("AppDomain-") && !file.domain.contains("apple") && file.relativePath.contains("Documents/") {
                let bundleID = file.domain.components(separatedBy: "-").last ?? "unknown"
                let path = file.relativePath
                    .replacingFirstOccurrence(of: "Documents/", with: "")
                    .replacingFirstOccurrence(of: "File Provider Storage/", with: "")
                DispatchQueue.main.async {
                    if let existingDataIndex = appData.firstIndex(where: { $0.bundleID == bundleID }) {
                        appData[existingDataIndex].fileIDs[file.fileID] = path
                        appData[existingDataIndex].paths.append(path)
                    } else {
                        appData.append(AppDomainData(bundleID: bundleID, paths: [path], fileIDs: [file.fileID:path]))
                    }
                }
            }
            // Docs
            if file.domain.contains("AppDomainGroup-group.com.apple.FileProvider.LocalStorage") && !file.relativePath.contains(".Trash") && (file.relativePath != "File Provider Storage") {
                let bundleID = file.domain.components(separatedBy: "-").last ?? "unknown"
                let path = file.relativePath
                    .replacingFirstOccurrence(of: "File Provider Storage/", with: "")
                    .replacingFirstOccurrence(of: "Downloads/", with: "Download/")
                DispatchQueue.main.async {
                    if documents != nil {
                        documents!.fileIDs[file.fileID] = path
                        documents!.paths.append(path)
                    } else {
                        documents = AppDomainData(bundleID: bundleID, paths: [path], fileIDs: [file.fileID:path])
                    }
                }
            }
            // Images
            if file.domain.contains("CameraRollDomain") && file.relativePath.contains("DCIM") && !file.relativePath.contains("Thumbnails") &&
                (
                    file.relativePath.lowercased().contains(".jpg") ||
                    file.relativePath.lowercased().contains(".png") ||
                    file.relativePath.lowercased().contains(".heic") ||
                    file.relativePath.lowercased().contains(".mov") ||
                    file.relativePath.lowercased().contains(".mp4")
                ) {
                let fileName = file.relativePath.components(separatedBy: "/").last ?? "unknown.png"
                DispatchQueue.main.async {
                    if !images.contains(where: { $0.fileName == fileName }) {
                        images.append(ImageDomainData(fileID: file.fileID, fileName: fileName))
                    }
                }
            }
            // Notes
            if file.relativePath.contains("NoteStore.sqlite") {
                notes = loadNotes(notesPath: "\(backupPath)/\(file.fileID.prefix(2))/\(file.fileID)")
            }
        }
    }
    
    return (appData, documents, images, notes)
}

struct ApplicationsView: View {
    @State var apps: [String: PlaceHolderApp]

    var body: some View {
        VStack {
            // Sort the apps based on availability
            let sortedApps = apps.sorted { lhs, rhs in
                let leftAvailability = lhs.value.available
                let rightAvailability = rhs.value.available
                
                // Sorting logic based on availability strings
                if leftAvailability == "found" && rightAvailability != "found" {
                    return true // left is found, right is not
                } else if leftAvailability != "found" && rightAvailability == "found" {
                    return false // right is found, left is not
                } else if leftAvailability == "unsure" && rightAvailability != "unsure" {
                    return true // left is unsure, right is something else
                } else if leftAvailability != "unsure" && rightAvailability == "unsure" {
                    return false // right is unsure, left is something else
                } else {
                    return false // Keep original order for other cases
                }
            }

            if !sortedApps.isEmpty {
                List {
                    ForEach(sortedApps, id: \.key) { (bundleID, app) in
                        ApplicationsViewRow(bundleID: bundleID, app: app)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            loadAppAvailability()
        }
    }
    
    private func loadAppAvailability() {
        let dispatchGroup = DispatchGroup() // Create a DispatchGroup to track completion
        
        for (bundleID, app) in apps {
            dispatchGroup.enter() // Enter the group for each app
            
            let searchID = bundleID.replacingOccurrences(of: ".ios.", with: "").replacingOccurrences(of: ".ios", with: "")
            checkAppAvailability(bundleId: searchID, appName: (app.iTunesMetadata["itemName"] as? String ?? ""), completion: { available, possible_id, confident in
                DispatchQueue.main.async {
                    apps[bundleID]?.available = available // available is a string
                    apps[bundleID]?.confidentAvailable = confident
                    apps[bundleID]?.potentialBundleID = possible_id
                    apps[bundleID]?.checkedAvailablility = true

                    dispatchGroup.leave() // Leave the group once the check is complete
                }
            })
        }

        dispatchGroup.notify(queue: .main) {
            print("All apps have been checked for availability.")
            var final_dict = ""
            for app in apps {
                if let potentialBundleID = app.value.potentialBundleID {
                    final_dict += "\"\(app.key)\":\"\(potentialBundleID)\",\n"
                }
            }
            print(final_dict)
        }
    }
}

struct ApplicationsViewRow: View {
    var bundleID: String
    var app: PlaceHolderApp

    var body: some View {
        HStack {
            if let uiImage = NSImage(data: app.PlaceholderIcon) {
                Image(nsImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            }
            VStack(alignment: .leading) {
                if let name = app.iTunesMetadata["itemName"] as? String {
                    Text(name).fontWeight(.bold)
                }
                Text(bundleID)
                switch app.available {
                case "found":
                    Text("Available on Google Play").foregroundColor(.green)
                case "unsure":
                    if app.confidentAvailable {
                        Text("Potentially Found (Confident): \(app.potentialBundleID ?? "unknown")").foregroundColor(.green)
                    } else {
                        Text("Potentially Found?: \(app.potentialBundleID ?? "unknown")").foregroundColor(.orange)
                    }
                default:
                    Text("Unavailable on Google Play").foregroundColor(.red)
                }
            }
        }
    }
}

func loadBackups() -> [Backup] {
    let fileManager = FileManager.default
    let backupDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MobileSync/Backup/")
    var backups: [Backup] = []

    do {
        let backupFolders = try fileManager.contentsOfDirectory(atPath: backupDirectory.path)
        
        for folder in backupFolders {
            let backupPath = backupDirectory.appendingPathComponent(folder)
            let infoPlistPath = backupPath.appendingPathComponent("Info.plist")
            if fileManager.fileExists(atPath: infoPlistPath.path),
               let data = try? Data(contentsOf: infoPlistPath),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                
                var applications: [String: PlaceHolderApp] = [:]
                if let appsDict = plist["Applications"] as? [String: [String: Any]] {
                    for (appName, appInfo) in appsDict {
                        let placeholderApp = PlaceHolderApp(
                            IsDemotedApp: appInfo["IsDemotedApp"] as? Bool,
                            ApplicationSINF: appInfo["ApplicationSINF"] as? Data,
                            PlaceholderIcon: appInfo["PlaceholderIcon"] as? Data ?? Data(),
                            iTunesMetadata: (try? PropertyListSerialization.propertyList(from: appInfo["iTunesMetadata"] as? Data ?? Data(), options: [], format: nil) as? [String:Any]) ?? [:]
                        )
                        applications[appName] = placeholderApp
                    }
                }
                
                let backup = Backup(
                    applications: applications,
                    deviceName: plist["Device Name"] as? String ?? "Unknown",
                    displayName: plist["Display Name"] as? String ?? "Unknown",
                    buildVersion: plist["Build Version"] as? String ?? "Unknown",
                    productName: plist["Product Name"] as? String ?? "Unknown",
                    productType: plist["Product Type"] as? String ?? "Unknown",
                    productVersion: plist["Product Version"] as? String ?? "Unknown",
                    serialNumber: plist["Serial Number"] as? String ?? "Unknown",
                    lastBackupDate: plist["Last Backup Date"] as? Date,
                    infoDict: plist,
                    path: backupPath.path
                )
                
                backups.append(backup)
            }
        }
    } catch {
        print("Error loading backups: \(error.localizedDescription)")
    }
    
    return backups
}

struct ContentView: View {
    @State private var backups: [Backup] = []

    var body: some View {
        NavigationStack {
            List(backups) { backup in
                NavigationLink(destination: BackupDetailView(backup: backup)) {
                    VStack(alignment: .leading) {
                        Text(backup.deviceName)
                            .font(.headline)
                        Text(backup.displayName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("iOS Backups")
            .onAppear(perform: {
                backups = loadBackups()
            })
        }
    }


}

struct BackupDetailView: View {
    var backup: Backup

    var body: some View {
        List {
            Section(header: Text("Device Information")) {
                Text("Device Name: \(backup.deviceName)")
                Text("Display Name: \(backup.displayName)")
                Text("Build Version: \(backup.buildVersion)")
                Text("Product Name: \(backup.productName)")
                Text("Product Type: \(backup.productType)")
                Text("Product Version: \(backup.productVersion)")
                Text("Serial Number: \(backup.serialNumber)")
                if let lastBackupDate = backup.lastBackupDate {
                    Text("Last Backup Date: \(lastBackupDate.formatted())")
                }
            }
            
            NavigationLink(destination: {
                ManifestView(backupPath: backup.path)
            }, label: {
                Text("Manifest")
            })
            
            NavigationLink(destination: {
                ApplicationsView(apps: backup.applications)
            }, label: {
                Text("Apps")
            })
            
            Section(header: Text("Full Info")) {
                ForEach(backup.infoDict.keys.sorted(), id: \.self) { key in
                    if let value = backup.infoDict[key] {
                        Text("\(key): \(String(describing: value))")
                    }
                }
            }
        }
        .navigationTitle(backup.deviceName)
    }
}

@main
struct BackupReaderApp: App {
    var body: some Scene {
        WindowGroup {
            DeviceListView()
            //ContentView()
        }
    }
}

struct Device: Identifiable {
    let id = UUID()
    let name: String
    let serial: String
}

class DeviceViewModel: ObservableObject {
    @Published var devices: [Device] = []
    private var timer: Timer?

    init() {
        startDeviceDetection()
    }

    func startDeviceDetection() {
        fetchDevices()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.fetchDevices()
        }
    }

    func stopDeviceDetection() {
        timer?.invalidate()
    }

    private func fetchDevices() {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/adb")
        process.arguments = ["devices", "-l"]
        process.standardOutput = pipe

        do {
            try process.run()
            //process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let outputString = String(data: data, encoding: .utf8) {
                parseDevices(from: outputString)
            }
        } catch {
            print("Error: \(error)")
        }
    }

    private func parseDevices(from output: String) {
        let lines = output.split(separator: "\n")
        var newDevices: [Device] = []

        for line in lines {
            let components = line.replacingOccurrences(of: "            ", with: " ").split(separator: " ")
            if components.count >= 3, components[1] == "device" {
                let serial = String(components[0])
                let product = String(components[2]).replacingOccurrences(of: "product:", with: "")
                let model = String(components[3]).replacingOccurrences(of: "model:", with: "")
                let deviceName = fetchDeviceName(for: serial)
                let name = deviceName.isEmpty ? "\(model)" : "\(deviceName)"
                newDevices.append(Device(name: name, serial: serial))
            }
        }

        DispatchQueue.main.async {
            self.devices = newDevices
        }
    }

    private func fetchDeviceName(for serial: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/adb")
        process.arguments = ["-s", serial, "shell", "settings", "get", "global", "device_name"]
        process.standardOutput = pipe

        do {
            try process.run()
            //process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let outputString = String(data: data, encoding: .utf8) {
                return outputString.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Error fetching device name: \(error)")
        }

        return ""
    }

    deinit {
        stopDeviceDetection()
    }
}

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceViewModel()
    @State private var selectedDevice = "None"
    @State private var backups: [Backup] = []
    @State private var selectedBackup = "None"
    // restore options
    @State private var restoreImages = true
    @State private var restoreNotes = true
    @State private var restorePureNotes = false
    @State private var restoreAppData = true
    @State private var restoreApps = false
    @State private var restoreUserFiles = true
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                Picker(selection: $selectedDevice, content: {
                    Text("None").tag("None")
                    ForEach(viewModel.devices) { device in
                        Text("\(device.name) (\(device.serial))").tag(device.serial)
                    }
                }, label: {
                    Text("Target:")
                })
                Picker(selection: $selectedBackup, content: {
                    Text("None").tag("None")
                    ForEach(backups) { backup in
                        Text("\(backup.displayName)").tag(backup.displayName)
                    }
                }, label: {
                    Text("Backup:")
                })
                //
                Toggle(isOn: $restoreImages, label: {
                    Text("Restore Images")
                })
                Toggle(isOn: $restoreNotes, label: {
                    Text("Restore Notes")
                })
                Toggle(isOn: $restorePureNotes, label: {
                    Text("Use PureNotes")
                }).disabled(!restoreNotes)
                Toggle(isOn: $restoreUserFiles, label: {
                    Text("Restore User Files")
                })
                Toggle(isOn: $restoreAppData, label: {
                    Text("Restore App Data")
                })
                Toggle(isOn: $restoreApps, label: {
                    Text("Restore Apps")
                }).disabled(true)
                //
                Button(action: {
                    var restoreOptions: [BackupOptions] = []
                    if restoreImages { restoreOptions.append(.images) }
                    if restoreNotes { if restorePureNotes { restoreOptions.append(.pureNotes) } else { restoreOptions.append(.notes) } }
                    if restoreUserFiles { restoreOptions.append(.documents) }
                    if restoreAppData { restoreOptions.append(.appData) }
                    if restoreApps { restoreOptions.append(.apps) }
                    Task.detached {
                        await restoreDevice(serial: selectedDevice, backup: backups.first(where: { $0.displayName == selectedBackup })!, backupOptions: restoreOptions)
                    }
                }, label: {
                    Text("Restore")
                }).disabled(selectedBackup == "None" || selectedDevice == "None")
            }
            .padding()
            .navigationTitle("AndroidRestore")
        }.onAppear() {
            Task.detached {
                let backups = loadBackups()
                DispatchQueue.main.async {
                    self.backups = backups
                }
            }
        }
    }
}

func pushToDevice(serial: String, from sourcePath: String, to destinationPath: String) -> String {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/adb")
    process.arguments = ["-s", serial, "push", sourcePath, destinationPath]
    process.standardOutput = pipe
    process.standardError = pipe  // Capture both stdout and stderr in case of an error

    do {
        try process.run()
        //process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let outputString = String(data: data, encoding: .utf8) {
            return outputString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    } catch {
        print("Error: \(error)")
        return "Error: \(error.localizedDescription)"
    }

    return "Unknown error occurred"
}

func mkdirAndroid(serial: String, dir destinationPath: String) -> String {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/adb")
    process.arguments = ["-s", serial, "shell", "mkdir", "-p", destinationPath]
    process.standardOutput = pipe
    process.standardError = pipe  // Capture both stdout and stderr in case of an error

    do {
        try process.run()
        //process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let outputString = String(data: data, encoding: .utf8) {
            return outputString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    } catch {
        print("Error: \(error)")
        return "Error: \(error.localizedDescription)"
    }

    return "Unknown error occurred"
}

enum BackupOptions {
    case images
    case notes
    case pureNotes
    case appData
    case apps
    case documents
}

func restoreDevice(serial: String, backup: Backup, backupOptions: [BackupOptions] = [.images, .notes]) {
    print("Getting Backup Files...")
    let backupFiles = loadBackupFiles(backupPath: backup.path)
    
    Task.detached {
        if backupOptions.contains(.images) {
            print("Restoring Images...")
            for image in backupFiles.images {
                let fromPath = "\(backup.path)/\(image.fileID.prefix(2))/\(image.fileID)"
                let toPath = "/sdcard/Pictures/\(image.fileName)"
                let result = pushToDevice(serial: serial, from: fromPath, to: toPath)
                print(result)
            }
            print("Finished Restoring Images!")
        }
    }
    
    Task.detached {
        if backupOptions.contains(.documents) {
            print("Restoring User Files...")
            if let docs = backupFiles.documents {
                for fileID in docs.fileIDs.keys {
                    let fromPath = "\(backup.path)/\(fileID.prefix(2))/\(fileID)"
                    let toPath = "/sdcard/\(docs.fileIDs[fileID] ?? "unknown.bin")"
                    mkdirAndroid(serial: serial, dir: URL(fileURLWithPath: toPath).deletingLastPathComponent().path)
                    if FileManager.default.fileExists(atPath: fromPath) {
                        pushToDevice(serial: serial, from: fromPath, to: toPath)
                    }
                }
            }
            print("Finished Restoring User Files!")
        }
    }
    
    Task.detached {
        let pureNotes = backupOptions.contains(.pureNotes)
        if backupOptions.contains(.notes) || pureNotes {
            print("Restoring Notes...")
            if pureNotes {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(backupFiles.notes) {
                    let fromPath = FileManager.default.temporaryDirectory.appendingPathComponent("PureNotes.json")
                    let toPath = "/sdcard/Documents/PureNotes.json"
                    do {
                        try data.write(to: fromPath)
                        pushToDevice(serial: serial, from: fromPath.path, to: toPath)
                    } catch {}
                }
            } else {
                mkdirAndroid(serial: serial, dir: "/sdcard/Notes")
                for note in backupFiles.notes {
                    let fromPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).txt")
                    let toPath = "/sdcard/Notes/\("\(note.title.components(separatedBy: CharacterSet(charactersIn: "\\/\"!.?#%^&*()@$|<>:;'[]{}")).joined()).txt")"
                    do {
                        try note.text.write(to: fromPath, atomically: true, encoding: .utf8)
                        pushToDevice(serial: serial, from: fromPath.path, to: toPath)
                    } catch {}
                }
            }
            print("Finished Restoring Notes!")
        }
    }
    
    Task.detached {
        if backupOptions.contains(.appData) {
            print("Restoring App Data...")
            for appData in backupFiles.appData {
                if let bundleID = randomAppBundleIDs[appData.bundleID] {
                    print("Restoring App Data for \(bundleID) (\(appData.bundleID))...")
                    let baseToPath = "/sdcard/Android/data/\(bundleID)/files"
                    mkdirAndroid(serial: serial, dir: baseToPath)
                    for fileID in appData.fileIDs.keys {
                        let fromPath = "\(backup.path)/\(fileID.prefix(2))/\(fileID)"
                        let toPath = "\(baseToPath)/\(appData.fileIDs[fileID] ?? "unknown.bin")"
                        mkdirAndroid(serial: serial, dir: URL(fileURLWithPath: toPath).deletingLastPathComponent().path)
                        if FileManager.default.fileExists(atPath: fromPath) {
                            pushToDevice(serial: serial, from: fromPath, to: toPath)
                        }
                    }
                }
            }
        }
    }
}
