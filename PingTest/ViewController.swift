//
//  ViewController.swift
//  PingTest
//
//  Created by wenyu on 2018/11/17.
//  Copyright © 2018年 wenyu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let ping = Ping()
        ping.delegate = self
        ping.host = "www.baidu.com"
        ping.timeout = 1
        PingMannager.shared.setup {
            PingMannager.shared.pingPeriod = 0.2
            PingMannager.shared.startPing()
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.4, execute: {
                if PingMannager.shared.isPinging{
                    PingMannager.shared.stopPing()
                }
            })
        }
    }

}
extension UIViewController : PingDelegate{
    func stop(_ ping: Ping) {
        
    }
    func ping(_ pinger: Ping, didReceiveReplyWith result: PingResult) {
        NSLog("\(result.sendDate!.description)"+"\(result.receiveDate!.description)")
    }
    
    
}

