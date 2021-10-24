//
//  AssrtSubtitle.swift
//  iina
//
//  Created by Collider LI on 26/2/2018.
//  Copyright © 2018 lhc. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit

fileprivate let subsystem = Logger.Subsystem(rawValue: "assrt")

final class AssrtSubtitle: OnlineSubtitle {

  struct File {
    var url: URL
    var filename: String
  }

  @objc var id: Int
  @objc var nativeName: String
  @objc var uploadTime: String
  @objc var subType: String

  @objc var subLang: String?
  @objc var title: String?
  @objc var filename: String?
  @objc var size: String?
  @objc var url: URL?
  var fileList: [File]?

  init(index: Int, id: Int, nativeName: String, uploadTime: String, subType: String?, subLang: String?) {
    self.id = id
    self.nativeName = nativeName
    if self.nativeName.isEmpty {
      self.nativeName = "[No title]"
    }
    self.uploadTime = uploadTime
    if let subType = subType {
      self.subType = subType
    } else {
      self.subType = "Unknown"
    }
    self.subLang = subLang
    super.init(index: index)
  }

  override func download(callback: @escaping DownloadCallback) {
    if let fileList = fileList {
      // download from file list
      when(fulfilled: fileList.map { file -> Promise<URL> in
        Promise { resolver in
          AF.request(file.url).response {
            guard $0.error == nil, let data = $0.data else {
              resolver.reject(AssrtSupport.AssrtError.networkError)
              return
            }
            let subFilename = "[\(self.index)]\(file.filename)"
            if let url = data.saveToFolder(Utility.tempDirURL, filename: subFilename) {
              resolver.fulfill(url)
            }
          }
        }
      }).map { urls in
        callback(.ok(urls))
      }.catch { err in
        callback(.failed)
      }
    } else if let url = url, let filename = filename {
      // download from url
      AF.request(url).response {
        guard $0.error == nil, let data = $0.data else {
          callback(.failed)
          return
        }
        let subFilename = "[\(self.index)]\(filename)"
        if let url = data.saveToFolder(Utility.tempDirURL, filename: subFilename) {
          callback(.ok([url]))
        }
      }
    } else {
      callback(.failed)
      return
    }
  }

}


class AssrtSupport {

  typealias Subtitle = AssrtSubtitle

  enum AssrtError: Int, Error {
    case noSuchUser = 1
    case queryTooShort = 101
    case missingArg = 20000
    case invalidToken = 20001
    case endPointNotFound = 20400
    case subNotFound = 20900
    case serverError = 30000
    case databaseError = 30001
    case searchEngineError = 30002
    case tempUnavailable = 30300
    case exceedLimit = 30900

    case userCanceled = 80000
    // lower level error
    case wrongResponseFormat = 90000
    case networkError = 90001
  }

  private let searchApi = "https://api.assrt.net/v1/sub/search"
  private let detailApi = "https://api.assrt.net/v1/sub/detail"
  
  
  struct SearchApiResult: Decodable {
    let status: Int
    let sub: Sub
    
    struct Subtitle: Decodable {
      let id: Int
      let nativeName: String
      let uploadTime: String
      let subtype: String
      let lang: Lang
      
      enum CodingKeys: String, CodingKey {
        case id, subtype, lang, nativeName = "native_name", uploadTime = "upload_time"
        
      }
    }
    
    struct Sub: Decodable {
      let subs: [Subtitle]
    }
    
    struct Lang: Decodable {
      let desc: String
    }
  }
  
  struct DetailApiResult: Decodable {
    let status: Int
    let sub: Sub
    
    struct Subtitle: Decodable {
      let url: String
      let filename: String
      let filelist: [FileObject]
    }
    
    struct Sub: Decodable {
      let subs: [Subtitle]
    }
    
    struct FileObject: Decodable {
      let url: String
      let f: String
      let s: String
    }
  }

  var token: String
  var usesUserToken = false

  private let subChooseViewController = SubChooseViewController(source: .assrt)

  static let shared = AssrtSupport()

  init() {
    let userToken = Preference.string(for: .assrtToken)
    if let token = userToken, token.count == 32 {
      self.token = token
      usesUserToken = true
    } else {
      self.token = "5IzWrb2J099vmA96ECQXwdRSe9xdoBUv"
    }
  }

  func checkToken() -> Bool {
    if usesUserToken {
      return true
    }
    // show alert for unregistered users
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("alert.title_warning", comment: "Warning")
    alert.informativeText = String(format: NSLocalizedString("alert.assrt_register", comment: "alert.assrt_register"))
    alert.alertStyle = .warning
    alert.addButton(withTitle: NSLocalizedString("alert.assrt_register.register", comment: "alert.assrt_register.register"))
    alert.addButton(withTitle: NSLocalizedString("alert.assrt_register.try", comment: "alert.assrt_register.try"))
    let result = alert.runModal()
    if result == .alertFirstButtonReturn {
      // if user chose register
      NSWorkspace.shared.open(URL(string: AppData.assrtRegisterLink)!)
      var newToken = ""
      if Utility.quickPromptPanel("assrt_token_prompt", callback: { newToken = $0 }) {
        if newToken.count == 32 {
          Preference.set(newToken, for: .assrtToken)
          self.token = newToken
          return true
        } else {
          Utility.showAlert("assrt_token_invalid")
        }
      }
      return false
    }
    return true
  }

  func search(_ query: String) -> Promise<[AssrtSubtitle]> {
    return Promise { resolver in
      
      AF.request(searchApi,
                 method: .post,
                 parameters: ["q": query],
                 headers: .init(header)).responseDecodable(of: SearchApiResult.self) {
        
        guard let result = $0.value else {
          resolver.reject(AssrtError.networkError)
          return
        }
        if let error = AssrtError(rawValue: result.status) {
          resolver.reject(error)
          return
        }
        
        let subtitles = result.sub.subs.enumerated().map {
          AssrtSubtitle(index: $0.offset,
                        id: $0.element.id,
                        nativeName: $0.element.nativeName,
                        uploadTime: $0.element.uploadTime,
                        subType: $0.element.subtype,
                        subLang: $0.element.lang.desc)
        }
        resolver.fulfill(subtitles)
      }
    }
  }

  func showSubSelectWindow(with subs: [AssrtSubtitle]) -> Promise<[AssrtSubtitle]> {
    return Promise { resolver in
      // return when found 0 or 1 sub
      if subs.count <= 1 {
        resolver.fulfill(subs)
        return
      }
      subChooseViewController.subtitles = subs

      subChooseViewController.userDoneAction = { subs in
        resolver.fulfill(subs as! [AssrtSubtitle])
      }
      subChooseViewController.userCanceledAction = {
        resolver.reject(AssrtError.userCanceled)
      }
      PlayerCore.active.sendOSD(.foundSub(subs.count), autoHide: false, accessoryView: subChooseViewController.view)
      subChooseViewController.tableView.reloadData()
    }
  }

  func loadDetails(forSub sub: AssrtSubtitle) -> Promise<AssrtSubtitle> {
    return Promise { resolver in
      
      AF.request(detailApi,
                 method: .post,
                 parameters: ["id": sub.id],
                 headers: .init(header)).responseDecodable(of: DetailApiResult.self) {
        guard let result = $0.value else {
          resolver.reject(AssrtError.networkError)
          return
        }
        if let error = AssrtError(rawValue: result.status) {
          resolver.reject(error)
          return
        }
        guard result.sub.subs.count == 1,
              let subObj = result.sub.subs.first,
              let url = URL(string: subObj.url)
        else {
          resolver.reject(AssrtError.wrongResponseFormat)
          return
        }
        
        sub.url = url
        sub.filename = subObj.filename
        sub.fileList = subObj.filelist.map {
          AssrtSubtitle.File(url: URL(string: $0.url)!,
                             filename: $0.f)
        }
        resolver.fulfill(sub)
      }
    }
  }

  private var header: [String: String] {
    return ["Authorization": "Bearer \(token)"]
  }
}
