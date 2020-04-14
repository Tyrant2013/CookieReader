//
//  ViewController.swift
//  CookieReader
//
//  Created by ZHXW on 2020/4/14.
//  Copyright © 2020 com. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if let path = Bundle.main.path(forResource: "Cookies", ofType: "binarycookies") {
            LocalCookieReader.read(from: path) { (cookies, error) in
                if let cookies = cookies {
                    cookies.forEach {
                        print($0.domain)
                    }
                }
                else {
                    print(error as Any)
                }
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

