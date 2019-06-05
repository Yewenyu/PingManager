//
//  PingManager.swift
//  ThreeTab
//
//  Created by wenyu on 2018/11/19.
//  Copyright © 2018年 ThreeTab. All rights reserved.
//

import UIKit

class PingMannager : NSObject{
    @objc static let shared = PingMannager()
    let sendQueue = DispatchQueue(label: "NewGBPingSendQueue")
    let readyGroup = DispatchGroup()
    let listenQueue = DispatchQueue(label: "NewGBPinglistenQueue")
    let mainQueue = DispatchQueue(label: "NewGBPingMainQueue")
    
    var isMemoryWarning : Bool{
        set{
            if newValue == true{
                lastMemoryWarningTime = Date().timeIntervalSince1970
                if self.isPinging{
                    self.stopPing()
                }
            }
        }
        get{
            if lastMemoryWarningTime == 0{
                return false
            }
            if Date().timeIntervalSince1970 - lastMemoryWarningTime < stopPingDuration{
                return true
            }else{
                lastMemoryWarningTime = 0
            }
            return false
        }
    }
    var stopPingDuration : TimeInterval = 60
    var lastMemoryWarningTime : TimeInterval = 0
    
    var sendThread : Thread?
    var listenThread :Thread?
    var setupThread : Thread?
    var pings = [Ping]()
    var disposeBlocks = [Any]()
    
    var isSettingUp = false
    var isPinging = false
    var pingPeriod : TimeInterval = 1
    var timeout : TimeInterval = 1{
        didSet{
            for ping in pings{
                ping.timeout = timeout
            }
        }
    }
    @objc func add(_ ping:Ping){
        ping.mainQueue = mainQueue
        ping.sendQueue = sendQueue
        ping.listenQueue = listenQueue
        pings.append(ping)
    }
    
    func setup(_ callBack:(()->())? = nil){
        
        var newPings = self.pings
        let pings = self.pings
        weak var weakSelf = self
        
        mainQueue.async {
            for ping in pings{
                weak var weakPing = ping
                let setupBlock = {()->() in
                    weakPing?.setup { (success, error) in
                        
                        if success{
                            weakPing?.startPinging()
                        }else{
                            newPings.removeAll(where: { (delete) -> Bool in
                                return delete.host == weakPing?.host
                            })
                        }
                        
                    }
                }
                setupBlock()
            }
            weakSelf?.isSettingUp = false
            
            weakSelf?.pings = newPings
            callBack?()
        }
        
    }
    func startPing(){
        if !self.isPinging{
            self.isPinging = true
            send()
            listen()
            //            if self.sendThread == nil{
            //                self.sendThread = Thread(target: self, selector: #selector(self.sendAction), object: nil)
            //                self.sendThread?.name = "sendThread"
            //                self.listenThread = Thread(target: self, selector: #selector(self.listenAction), object: nil)
            //                self.listenThread?.name = "listenThread"
            //
            //                self.listenThread?.start()
            //                self.sendThread?.start()
            //
            //            }
        }
    }
    func stopPing(){
        mainQueue.async {
            if self.isPinging{
                self.isPinging = false
                for ping in self.pings{
                    ping.stop()
                }
                self.pings.removeAll()
            }
        }
        
    }
    private func send(){
        weak var weakSelf =  self
        mainQueue.async {
            if weakSelf?.isPinging == true{
                weakSelf?.pings.removeAll(where: { (ping) -> Bool in
                    return ping.isPinging == false
                })
                if weakSelf?.pings.count ?? 0 > 0 {
                    let pings = self.pings
                    weakSelf?.sendQueue.async {
                        autoreleasepool{
                            let runUntil = CFAbsoluteTimeGetCurrent() + (weakSelf?.pingPeriod ?? 1)
                            for ping in pings{
                                ping.send()
                            }
                            var time : TimeInterval = 0;
                            while (runUntil > time) {
                                let runUntilDate = Date(timeIntervalSinceReferenceDate: runUntil)
                                RunLoop.current.run(until: runUntilDate)
                                time = CFAbsoluteTimeGetCurrent()
                            }
                            weakSelf?.send()
                        }
                    }
                }
                
            }
        }
        
    }
    private func listen(){
        weak var weakSelf =  self
        mainQueue.async {
            if weakSelf?.isPinging == true{
                weakSelf?.pings.removeAll(where: { (ping) -> Bool in
                    return ping.isPinging == false
                })
                if weakSelf?.pings.count ?? 0 > 0 {
                    let pings = self.pings
                    weakSelf?.listenQueue.async {
                        autoreleasepool{
                            for ping in pings{
                                ping.listenOnce()
                            }
                            weakSelf?.listen()
                        }
                    }
                }
                
            }
        }
    }
    @objc private func sendAction(){
        weak var weakSelf =  self
        autoreleasepool {
            if var pings = weakSelf?.pings{
                while true ==  weakSelf?.isPinging,pings.count > 0{
                    var i = 0
                    let runUntil = CFAbsoluteTimeGetCurrent() + (weakSelf?.pingPeriod ?? 1);
                    while i < pings.count{
                        let ping = pings[i]
                        ping.send()
                        if ping.isPinging == false{
                            pings.remove(at: i)
                            i -= 1
                        }
                        i += 1
                    }
                    var time : TimeInterval = 0;
                    while (runUntil > time) {
                        let runUntilDate = Date(timeIntervalSinceReferenceDate: runUntil)
                        RunLoop.current.run(until: runUntilDate)
                        time = CFAbsoluteTimeGetCurrent();
                    }
                }
                weakSelf?.sendThread?.cancel()
                weakSelf?.sendThread = nil
            }
            
        }
    }
    @objc private func listenAction(){
        weak var weakSelf =  self
        autoreleasepool {
            if var pings = weakSelf?.pings{
                while true == weakSelf?.isPinging,pings.count > 0{
                    var i = 0
                    while i < pings.count{
                        let ping = pings[i]
                        ping.listenOnce()
                        if ping.isPinging == false{
                            pings.remove(at: i)
                            i -= 1
                        }
                        i += 1
                    }
                }
            }
            
            weakSelf?.listenThread?.cancel()
            weakSelf?.listenThread = nil
        }
    }
    
}

extension Thread{
    
    static func getThreadsCount() -> Int{
        var threadList : thread_array_t?
        var threadCount = mach_msg_type_number_t()
        var task = task_t()
        
        var kernReturn = task_for_pid(mach_task_self_, getpid(), &task)
        if (kernReturn != KERN_SUCCESS) {
            return -1
        }
        
        kernReturn = task_threads(task, &threadList, &threadCount)
        if (kernReturn != KERN_SUCCESS) {
            return -1;
        }
        
        //        vm_deallocate (mach_task_self_, vm_address_t(threadList), threadCount * MemoryLayout<thread_act_t>.size);
        
        return Int(threadCount)
    }
}

