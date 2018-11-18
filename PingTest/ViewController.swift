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
        var ping = NewGBPing()
        ping.delegate = self
        ping.host = "www.baidu.com"
        ping.timeout = 1
        NewGBPingMannager.shared.setup {
            NewGBPingMannager.shared.pingPeriod = 0.2
            NewGBPingMannager.shared.startPing()
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.4, execute: {
                if NewGBPingMannager.shared.isPinging{
                    NewGBPingMannager.shared.stopPing()
                }
            })
        }
    }

}
extension UIViewController : GBPingDelegate{
    public func ping(_ pinger: GBPing, didReceiveReplyWith summary: GBPingSummary) {
        NSLog("\(summary.sendDate!.description)"+"\(summary.receiveDate!.description)")
    }
}

