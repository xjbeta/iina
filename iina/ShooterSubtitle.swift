//
//  ShooterSubtitle.swift
//  iina
//
//  Created by lhc on 10/1/2017.
//  Copyright © 2017 lhc. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit

final class ShooterSubtitle: OnlineSubtitle {

  var desc: String
  var delay: Int
  var files: [SubFile]

  struct SubFile {
    var ext: String
    var path: String
  }

  init(index: Int, desc: String, delay: Int, files: [SubFile]) {
    self.desc = desc
    self.delay = delay
    self.files = files
    super.init(index: index)
  }

  override func download(callback: @escaping DownloadCallback) {
    AF.request((files[0].path)).response {
      guard $0.error == nil else {
        callback(.failed)
        return
      }
      
      guard let data = $0.data,
            let field = $0.response?.headers["Content-Disposition"] else {
        callback(.failed)
        return
      }
      let unicodeArray: [UInt8] = field.unicodeScalars.map { UInt8($0.value) }
      let unicodeStr = String(bytes: unicodeArray, encoding: String.Encoding.utf8)!
      var fileName = Regex.httpFileName.captures(in: unicodeStr)[at: 1] ?? ""
      
      fileName = "[\(self.index)]\(fileName)"
      if let url = data.saveToFolder(Utility.tempDirURL, filename: fileName) {
        callback(.ok([url]))
      }
    }
  }

}


class ShooterSupport {
  
  struct ApiPathResult: Decodable {
    let desc: String?
    let delay: Int?
    let files: [File]
    
    enum CodingKeys: String, CodingKey {
      case desc = "Desc", delay = "Delay", files = "Files"
    }
    
    struct File: Decodable {
      let ext: String
      let link: String
      
      enum CodingKeys: String, CodingKey {
        case ext = "Ext", link = "Link"
      }
    }
  }
  

  struct FileInfo {
    var hashValue: String
    var path: String

    var dictionary: [String: Any] {
      get {
        return [
          "filehash": hashValue,
          "pathinfo": path,
          "format": "json"
        ]
      }
    }
  }

  enum ShooterError: Error {
    // file error
    case cannotReadFile
    case fileTooSmall
    case networkError
  }

  typealias ResponseData = [[String: Any]]
  typealias ResponseFilesData = [[String: String]]

  private let chunkSize: Int = 4096
  private let apiPath = "https://www.shooter.cn/api/subapi.php"

  private var language: String?

  init(language: String? = nil) {
    self.language = language
  }

  func hash(_ url: URL) -> Promise<FileInfo> {
    return Promise { resolver in
      guard let file = try? FileHandle(forReadingFrom: url) else {
        resolver.reject(ShooterError.cannotReadFile)
        return
      }

      file.seekToEndOfFile()
      let fileSize: UInt64 = file.offsetInFile

      guard fileSize >= 12288 else {
        resolver.reject(ShooterError.fileTooSmall)
        return
      }

      let offsets: [UInt64] = [
        4096,
        fileSize / 3 * 2,
        fileSize / 3,
        fileSize - 8192
      ]

      let hash = offsets.map { offset -> String in
        file.seek(toFileOffset: offset)
        return file.readData(ofLength: chunkSize).md5
        }.joined(separator: ";")

      file.closeFile()

      resolver.fulfill(FileInfo(hashValue: hash, path: url.path))
    }
  }

  func request(_ info: FileInfo) -> Promise<[ShooterSubtitle]> {
    return Promise { resolver in
      AF.request(apiPath,
                 method: .post,
                 parameters: info.dictionary,
                 requestModifier: { $0.timeoutInterval = 10 }
      ).responseDecodable(of: [ApiPathResult].self) {
        guard $0.error == nil, let json = $0.value else {
          resolver.reject(ShooterError.networkError)
          return
        }
        
        let subtitles = json.enumerated().map {
          ShooterSubtitle(index: $0.offset,
                          desc: $0.element.desc ?? "",
                          delay: $0.element.delay ?? 0,
                          files: $0.element.files.map({
            ShooterSubtitle.SubFile(ext: $0.ext,
                                    path: $0.link)
          }))
        }
        
        resolver.fulfill(subtitles)
      }
    }
  }

}
