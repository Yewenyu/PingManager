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
    @IBOutlet var periodTextField : UITextField!
    @IBOutlet var timeoutTextField : UITextField!
    var timeout : TimeInterval = 1
    var period : TimeInterval = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        ipsView.layer.borderColor = UIColor.black.cgColor
        ipsView.layer.borderWidth = 1
        pingResultView.layer.borderColor = UIColor.black.cgColor
        pingResultView.layer.borderWidth = 1
        periodTextField.text = period.description
        timeoutTextField.text = timeout.description
//        let ping = Ping()
//        ping.delegate = self
//        ping.host = "www.baidu.com"
//        PingMannager.shared.setup {
//            PingMannager.shared.timeout = 1
//            PingMannager.shared.pingPeriod = 0.2
//            PingMannager.shared.startPing()
//            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.4, execute: {
//                if PingMannager.shared.isPinging{
//                    PingMannager.shared.stopPing()
//                }
//            })
//        }
    }
    @IBAction func stopAction(_ button:UIButton){
        PingManager.shared.stopPing()
    }
    @IBAction func startAction(_ button:UIButton){
        let ipContent = ipsView.text
        if let ipArray = ipContent?.components(separatedBy: ","){
            for ip in ipArray{
                let ping = Ping()
                ping.delegate = self
                ping.host = ip
                PingManager.shared.add(ping)
            }
        }
        self.timeout = TimeInterval(self.timeoutTextField.text ?? self.timeout.description)!
        self.period = TimeInterval(self.periodTextField.text ?? self.period.description)!
        let timeout = self.timeout
        let period = self.period
        PingManager.shared.setup {
            $0.timeout = timeout
            $0.pingPeriod = period
            $0.startPing()
        }
        
    }

}
extension ViewController : PingDelegate{
    func stop(_ ping: Ping) {
        
    }
    
    func ping(_ pinger: Ping, didFailWithError error: Error) {
        
    }
    func ping(_ pinger: Ping, didTimeoutWith result: PingResult) {
        pingResult(result)
    }
    func ping(_ pinger: Ping, didReceiveReplyWith result: PingResult) {
        pingResult(result)
    }
    func ping(_ pinger: Ping, didReceiveUnexpectedReplyWith result: PingResult) {
        pingResult(result)
    }
    func pingResult(_ result:PingResult){
        var resultString = ""   
        if result.pingStatus == .success{
            resultString = "Host:\(result.host ?? "") ttl:\(result.ttl) time:\(Int(result.time * 1000))"
        }else{
            resultString = "Host:\(result.host ?? "") failed"
        }
        DispatchQueue.main.async {
            let oldString = self.pingResultView.text ?? ""
            self.pingResultView.text = resultString + "\n" + oldString
        }
        
    }
    
}
extension ViewController : UITextFieldDelegate{
    
}

