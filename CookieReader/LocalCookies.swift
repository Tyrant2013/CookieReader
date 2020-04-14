//
//  LocalCookies.swift
//  CookieReader
//
//  Created by ZHXW on 2020/4/14.
//  Copyright © 2020 Freedom. All rights reserved.
//

import Foundation

struct LocalPage {
    var index: Int
    var size: Int
    var data: Data
    var cookieNum: Int
    var cookieOffset: [Int]
}

struct LocalCookie {
    var size: Int
    var expiration: Int64;
    var creation: Int64;
    var domain: String;
    var name: String;
    var path: String;
    var value: String;
    var secure: Bool = false;
    var http: Bool = false;
}

extension Data {
    func readBigInt32() -> Int {
        return Int(self[0]) << 24 | Int(self[1]) << 16 | Int(self[2]) << 8 | Int(self[3])
    }
    
    func readBigInt() -> Int {
        let hight4 = Int(self[0]) << 56 | Int(self[1]) << 48 | Int(self[2]) << 40 | Int(self[3]) << 32
        let low4 = Int(self[4]) << 24 | Int(self[5]) << 16 | Int(self[6]) << 8 | Int(self[7])
        return  hight4 | low4
    }
    
    func readLittleInt32() -> Int {
        return Int(self[3]) << 24 | Int(self[2]) << 16 | Int(self[1]) << 8 | Int(self[0])
    }
    
    func readLittleInt() -> Int {
        let hight4 = Int(self[7]) << 56 | Int(self[6]) << 48 | Int(self[5]) << 40 | Int(self[4]) << 32
        let low4 = Int(self[3]) << 24 | Int(self[2]) << 16 | Int(self[1]) << 8 | Int(self[0])
        return  hight4 | low4
    }
    
    func readLittleInt64() -> Int64 {
        let hight4 = Int64(self[7]) << 56 | Int64(self[6]) << 48 | Int64(self[5]) << 40 | Int64(self[4]) << 32
        let low4 = Int64(self[3]) << 24 | Int64(self[2]) << 16 | Int64(self[1]) << 8 | Int64(self[0])
        return  hight4 | low4
    }
}

class LocalCookieReader {
    
    class func read(from path: String, handler: @escaping (_ cookies: [LocalCookie]?, _ error: Error?) -> Void) {
        do {
            
            
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            
            /// 获取前 4 字节的标志符号
            let headData = data.dropLast(data.count - 4)
            if let str = String(data: headData, encoding: .utf8), str == "cook" {
                var cookies = [LocalCookie]()
                
                let dataHead = data.advanced(by: 4)
                /// 获取 Page 的数量
                let pageNum = dataHead.readBigInt32()
                
                /// 获取每个 Page 的大小
                let pageSizeData = data.advanced(by: 8)
                var pageSizeArr = [Int]()
                for page in 0..<pageNum {
                    let pageSizeData = pageSizeData.advanced(by: Int(page) * 4)
                    let pageSize = pageSizeData.readBigInt32()
                    pageSizeArr.append(pageSize)
                }
                
                /// 获取各个 Page 的 Data
                var pageData = pageSizeData.advanced(by: pageNum * 4)
                var pageDataArr = [LocalPage]()
                for (index, pageSize) in pageSizeArr.enumerated() {
                    let range = Range(NSRange(location: 0, length: pageSize))
                    let curPageData = pageData.subdata(in: range!)
                    
                    /// 解析每个 Page 的 Head 内容(Cookie 数量, 每个 Cookie 的 offset)
                    let cookieNum = curPageData.advanced(by: 4).readLittleInt32()
                    var cookieOffsets = [Int]()
                    for index in 0..<cookieNum {
                        let cookieOffset = curPageData.advanced(by: 8).advanced(by: index * 4).readLittleInt32()
                        cookieOffsets.append(cookieOffset)
                    }
                    let page = LocalPage(index: index, size: pageSize, data: curPageData, cookieNum: cookieNum, cookieOffset: cookieOffsets)
                    pageDataArr.append(page)
                    
                    for offset in cookieOffsets {
                        /// cookie 大小
                        let cookieSize = curPageData.advanced(by: offset).readLittleInt()
                        /// flags 数据, 4个字节, 后4个字节不是干嘛的
                        var move = offset + 8
                        let flags = curPageData.advanced(by: move).readLittleInt32()
                        let secure = flags == 1 || flags == 5
                        let http = flags == 4 || flags == 5
                        
                        /// domain
                        move += 8
                        let domainStart = curPageData.advanced(by: move).readLittleInt32()
                        /// name
                        move += 4
                        let nameStart = curPageData.advanced(by: move).readLittleInt32()
                        /// path
                        move += 4
                        let pathStart = curPageData.advanced(by: move).readLittleInt32()
                        /// value
                        move += 4
                        let valueStart = curPageData.advanced(by: move).readLittleInt32()
                        move += 4
                        /// 8个字节的结束标志
                        move += 8
                        /// 8个字节 double, 大端表示, 表示 expiry date of the cookie
                        move += 8
                        let expirDateInterval = curPageData.advanced(by: move).readLittleInt64()
                        /// 8个字节 double, 大端表示, 表示 last access time of the cookie
                        move += 8
                        let createDateInterval = curPageData.advanced(by: move).readLittleInt64()

                        /// domain 属性, null 结尾
                        /// name 属性, null 结尾
                        /// path 属性, null 结尾
                        /// value 属性, null 结尾
                        func parseCookie(_ data: Data, seek offset: Int) -> String? {
                            let cookieData = data.advanced(by: offset)
                            for index in 0..<cookieData.count {
                                if cookieData[index] == 0x00 {
                                    let valData = cookieData.dropLast(cookieData.count - index)
                                    if let str = String(data: valData, encoding: .ascii) {
                                        return str
                                    }
                                }
                            }
                            return nil
                        }
                        let domain = parseCookie(curPageData, seek: offset + domainStart)!
                        let name = parseCookie(curPageData, seek: offset + nameStart)!
                        let path = parseCookie(curPageData, seek: offset + pathStart)!
                        let value = parseCookie(curPageData, seek: offset + valueStart)!
                        let cookie = LocalCookie(size: cookieSize,
                                                 expiration: expirDateInterval,
                                                 creation: createDateInterval,
                                                 domain: domain,
                                                 name: name,
                                                 path: path,
                                                 value: value,
                                                 secure: secure,
                                                 http: http)
                        cookies.append(cookie)
                    }
                    
                    pageData = pageData.advanced(by: pageSize)
                }
                handler(cookies, nil)
            }
            else {
                print("非法数据")
            }
        }
        catch {
            handler(nil, error)
        }
    }
}
