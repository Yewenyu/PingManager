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
    let readyQueue = DispatchQueue(label: "NewGBPingReadyQueue")
    let readyGroup = DispatchGroup()
    let disposeQueue = DispatchQueue(label: "NewGBPingDisposeQueue")
    
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
    var sendBlocks = [Any]()
    var listenBlocks = [Any]()
    var disposeBlocks = [Any]()
    
    var isDispose = false
    var isPinging = false
    var pingPeriod : TimeInterval = 1
    var timeout : TimeInterval = 1{
        didSet{
            for ping in pings{
                ping.timeout = timeout
            }
        }
    }
    
    @objc func addDisposeBlock(_ block: @escaping ()->()){
        disposeQueue.sync {
            self.disposeBlocks.append(block)
        }
        
    }
    func getDisposeBlocks() -> [Any]{
        var result = self.disposeBlocks
        disposeQueue.sync {
            result = self.disposeBlocks
        }
        return result
    }
    func removeDisposeBlocksFirst(){
        disposeQueue.sync {
            var blocks = self.disposeBlocks
            blocks.removeFirst()
            self.disposeBlocks = blocks
        }
    }
    func setup(_ callBack:(()->())? = nil){
        var newPings = pings
        if self.setupThread == nil{
            self.setupThread = Thread(target: self, selector: #selector(self.disposeAction), object: nil)
            self.setupThread?.name = "disposeThread"
            self.isDispose = true
            self.setupThread?.start()
        }
        
        for ping in pings{
            readyGroup.enter()
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
                    self.readyGroup.leave()
                }
            }
            self.disposeBlocks.append(setupBlock)
            
        }
        readyGroup.notify(queue: readyQueue) {
            self.isDispose = false
            self.setupThread = nil
            self.pings = newPings
            callBack?()
        }
        
    }
    func startPing(){
        if !self.isPinging{
            self.isPinging = true
            if self.sendThread == nil{
                self.sendThread = Thread(target: self, selector: #selector(self.sendAction), object: nil)
                self.sendThread?.name = "sendThread"
                self.listenThread = Thread(target: self, selector: #selector(self.listenAction), object: nil)
                self.listenThread?.name = "listenThread"
                
                self.listenThread?.start()
                self.sendThread?.start()
                
            }
        }
    }
    func stopPing(){
        if isPinging{
            isPinging = false
            self.sendThread = nil
            self.listenThread = nil
            self.setupThread = nil
            self.sendBlocks.removeAll()
            self.listenBlocks.removeAll()
            self.disposeBlocks.removeAll()
            for ping in pings{
                ping.stop()
            }
            self.pings.removeAll()
        }
    }
    
    @objc private func sendAction(){
        autoreleasepool {
            var pings = self.pings
            while isPinging,pings.count > 0{
                var i = 0
                let runUntil = CFAbsoluteTimeGetCurrent() + self.pingPeriod;
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
        }
    }
    @objc private func listenAction(){
        autoreleasepool {
            var pings = self.pings
            while isPinging,pings.count > 0{
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
    }
    @objc private func disposeAction(){
        autoreleasepool {
            while isDispose{
                while self.getDisposeBlocks().count > 0{
                    let blocks = self.getDisposeBlocks()
                    if let block = blocks.first as? ()->(){
                        block()
                    }
                    self.removeDisposeBlocksFirst()
                }
            }
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

