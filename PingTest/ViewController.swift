//
//  ViewController.swift
//  PingTest
//
//  Created by wenyu on 2018/11/17.
//  Copyright © 2018年 wenyu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var ipsView : UITextView!
    @IBOutlet var pingResultView : UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        ipsView.layer.borderColor = UIColor.black.cgColor
        ipsView.layer.borderWidth = 1
        pingResultView.layer.borderColor = UIColor.black.cgColor
        pingResultView.layer.borderWidth = 1
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
    @IBAction func enterAction(_ button:UIButton){
        let ipContent = ipsView.text
        if let ipArray = ipContent?.components(separatedBy: ","){
            for ip in ipArray
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
extension UIViewController : UITextViewDelegate{
    
}

