import UIKit

enum FileType {
    case Drive, Folder, TextFile, ZipFile
}

enum Operation: Error {
    case PathNotFound
    case PathAlreadyExists
    case IllegalFileSystemOperation
    case NotATextFile
}

protocol Entity {
    func type() -> FileType
    func name() -> String
    func path() -> String
    func size() -> Float
}

protocol Parent {
    func children() -> [String: Entity]
    func addChld(key: String, value: Entity)
    func removeChild(key: String)
}

protocol Child {
    func parent() -> Entity?
    func setParent(parent: Entity)
}

func getPath(start: Entity) -> String {
    var path = start.name()
    guard let child = start as? Child else { return path }
    
    while (true) {
        guard let parent = child.parent() else { break }
        path = parent.name() + "\\" + path
    }
    return path
}

class System {
    var drive: Drive
    
    init(drive: Drive) {
        self.drive = drive
    }
    
    func create(type: FileType, name: String, pathOfParent: String) throws {
        guard let file = fileExists(path: pathOfParent) else { throw Operation.PathNotFound }
        guard let parent = file as? Parent else { throw Operation.IllegalFileSystemOperation }
        guard parent.children()[name] == nil else { throw Operation.PathAlreadyExists }
        
        var newFile: Entity
        switch type {
            case .Drive:
                throw Operation.IllegalFileSystemOperation
            case .Folder:
                newFile = Folder(parentFile: file, fileName: name, content: [String: Entity]())
            case .TextFile:
                newFile = TextFile(parentFile: file, fileName: name, content: "")
            case .ZipFile:
                newFile = ZipFile(parentFile: file, fileName: name, content: [String: Entity]())
        }
        
        parent.addChld(key: name, value: newFile)
    }
    
    func delete(path: String) throws {
        guard let file = fileExists(path: path), let child = file as? Child, let parent = child.parent() as? Parent else { throw Operation.PathNotFound }
        
        parent.removeChild(key: file.name())
    }
    
    func move(sourcePath: String, destinationPath: String) throws {
        // Check old parent
        guard let file = fileExists(path: sourcePath), let child = file as? Child, let parent = child.parent() as? Parent else { throw Operation.PathNotFound }
        
        // check new parent
        var pathNames = destinationPath.split(separator: "\\").map{ String($0) }
        pathNames.popLast()
        
        guard let parentFile = fileExists(path: pathNames.joined(separator: "\\")) else { throw Operation.PathNotFound }
        guard let newParent = parentFile as? Parent else { throw Operation.IllegalFileSystemOperation }
        guard newParent.children()[file.name()] == nil else { throw Operation.PathAlreadyExists }
    
        parent.removeChild(key: file.name())
        newParent.addChld(key: file.name(), value: file)
        child.setParent(parent: parentFile)
    }
    
    func writeToFile(path: String, content: String) throws {
        guard let file = fileExists(path: path) else { throw Operation.PathNotFound }
        guard let textFile = file as? TextFile else { throw Operation.NotATextFile }
        
        textFile.content = content
    }
    
    private func fileExists(path: String) -> Entity? {
        let pathEntities = path.split(separator: "\\").map { String($0) }
        
        guard pathEntities[0] == drive.name() else { return nil }
        
        if pathEntities.count == 1 { return drive }
        
        var current: Parent = drive
        let paths = pathEntities[1...(pathEntities.count - 1)]
        for (i, name) in paths.enumerated() {
            guard let entity = current.children()[name] else { return nil }

            if i == paths.count - 1 {
                return entity
            }
            
            guard let parent = entity as? Parent else { return nil }
            current = parent
        }
        
        return current as? Entity ?? nil
    }
    
    func printSystem(root: Entity, levels: Int) {
        guard let parent = root as? Parent else { return }

        for value in parent.children().values {
            print("\(String(repeating: "\t", count: levels)) name: \(value.name()), size:\(value.size())")
            
            printSystem(root: value, levels: levels + 1)
        }
        
    }
}

class Drive : Entity, Parent {
    var fileName : String
    var content = [String: Entity]()
    
    init(fileName: String, content: [String: Entity]) {
        self.fileName = fileName
        self.content = content
    }
    
    // Parent Protocol
    func children() -> [String : Entity] {
        return content
    }
    
    func addChld(key: String, value: Entity) {
        self.content[key] = value
    }
    
    func removeChild(key: String) {
        self.content[key] = nil
    }
    
    // Entity Protocol
    func type() -> FileType {
        .Drive
    }
    
    func name() -> String {
        return fileName
    }
    
    func path() -> String {
        return getPath(start: self)
    }
    
    func size() -> Float {
        return content.reduce(Float(0)) { $0 + $1.value.size() }
    }
    
}

class Folder : Entity, Parent, Child {
    var parentFile : Entity?
    var fileName : String
    var content = [String: Entity]()
    
    init(parentFile: Entity?, fileName: String, content: [String: Entity]) {
        self.parentFile = parentFile
        self.fileName = fileName
        self.content = content
    }
    
    // Parent Protocol
    func children() -> [String : Entity] {
        return content
    }
    
    func addChld(key: String, value: Entity) {
        self.content[key] = value
    }
    
    func removeChild(key: String) {
        self.content[key] = nil
    }
    
    // Child Protocol
    func parent() -> Entity? {
        return parentFile
    }
    
    func setParent(parent: Entity) {
        self.parentFile = parent
    }
    
    // Entity Protocol
    func type() -> FileType {
        return .Folder
    }
    
    func name() -> String {
        return fileName
    }
    
    func path() -> String {
        return getPath(start: self)
    }
    
    func size() -> Float {
        return content.reduce(Float(0)) { $0 + $1.value.size() }
    }
    
}

class TextFile : Entity, Child {
    var parentFile : Entity
    var fileName : String
    var content = String()
    
    init(parentFile: Entity, fileName: String, content: String) {
        self.parentFile = parentFile
        self.fileName = fileName
        self.content = content
    }
    
    // Child Protocol
    func parent() -> Entity? {
        return parentFile
    }
    
    func setParent(parent: Entity) {
        self.parentFile = parent
    }
    
    // Entity Protocol
    func type() -> FileType {
        return .TextFile
    }
    
    func name() -> String {
        return fileName
    }
    
    func path() -> String {
        return getPath(start: self)
    }
    
    func size() -> Float {
        return Float(content.count)
    }

}

class ZipFile : Entity, Parent, Child {
    var parentFile : Entity
    var fileName : String
    var content = [String: Entity]()
    
    init(parentFile: Entity, fileName: String, content: [String: Entity]) {
        self.parentFile = parentFile
        self.fileName = fileName
        self.content = content
    }
    
    // Parent Protocol
    func children() -> [String : Entity] {
        return content
    }
    
    func addChld(key: String, value: Entity) {
        self.content[key] = value
    }
    
    func removeChild(key: String) {
        self.content[key] = nil
    }
    
    // Child Protocol
    func parent() -> Entity? {
        return parentFile
    }
    
    func setParent(parent: Entity) {
        self.parentFile = parent
    }
    
    // Entity Protocol
    func type() -> FileType {
        return .Folder
    }
    
    func name() -> String {
        return fileName
    }
    
    func path() -> String {
        return getPath(start: self)
    }
    
    func size() -> Float {
        return content.reduce(Float(0)) { $0 + $1.value.size() } / 2
    }
}


var system = System(drive: Drive(fileName: "drive", content: [String: Entity]()))

"drive".split(separator: "\\")
try system.create(type: .Folder, name: "parentFolder", pathOfParent: "drive")
    try system.create(type: .ZipFile, name: "mainZip", pathOfParent: "drive\\parentFolder")
        try system.create(type: .TextFile, name: "text2", pathOfParent: "drive\\parentFolder\\mainZip")
        try system.writeToFile(path: "drive\\parentFolder\\mainZip\\text2", content: "this is some new content")
    try system.create(type: .TextFile, name: "mainText", pathOfParent: "drive\\parentFolder")
    try system.create(type: .Folder, name: "childFolder", pathOfParent: "drive\\parentFolder")
//        try system.create(type: .TextFile, name: "text2", pathOfParent: "drive\\parentFolder\\childFolder")
    try system.create(type: .TextFile, name: "anotherTextFile", pathOfParent: "drive\\parentFolder")
    try system.writeToFile(path: "drive\\parentFolder\\anotherTextFile", content: "Here is a ton of text for hallelujah. Wow lorem ipsum! Holy cow.")
try system.create(type: .ZipFile, name: "greaterZip", pathOfParent: "drive")

try system.move(sourcePath: "drive\\parentFolder\\anotherTextFile", destinationPath: "drive\\greaterZip\\anotherTextFile")

//try system.move(sourcePath: "drive\\parentFolder\\mainZip\\text2", destinationPath: "drive\\parentFolder\\childFolder\\text2")
//try system.delete(path: "drive\\parentFolder\\childFolder\\text2")

system.printSystem(root: system.drive, levels: 0)

/* Test Cases to consider
 Creating
    * can't create another drive
    * 
 
 Deleting
    * parent of child shows that child reference has been removed
 
 Removing
    * child of previous parent is properly removed
    * parent of child has been changed to new parent
 
 Writing
    * PathNotFound if file doesn't exist
    * NotATextFile if file exists, but isn't a text file
 
 ZipFile
    * Size parameter is properly implemented
 */





























