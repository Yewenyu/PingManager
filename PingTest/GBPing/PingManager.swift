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
    var disposeThread : Thread?
    var pings = [Ping]()
    var sendBlocks = [Any]()
    var listenBlocks = [Any]()
    var disposeBlocks = [Any]()
    
    var isDispose = false
    var isPinging = false
    var pingPeriod : TimeInterval = 1
    
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
        if self.disposeThread == nil{
            self.disposeThread = Thread(target: self, selector: #selector(self.disposeAction), object: nil)
            self.disposeThread?.name = "disposeThread"
            self.isDispose = true
            self.disposeThread?.start()
        }
        
        for ping in pings{
            readyGroup.enter()
            ping.setup { (success, error) in
                if success{
                    ping.startPinging()
                }else{
                    newPings.removeAll(where: { (delete) -> Bool in
                        return delete.host == ping.host
                    })
                }
                
                
                self.readyGroup.leave()
            }
        }
        readyGroup.notify(queue: readyQueue) {
            self.isDispose = false
            self.disposeThread = nil
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
            self.disposeThread = nil
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
            var blocks = sendBlocks
            while isPinging,blocks.count > 0{
                var i = 0
                let runUntil = CFAbsoluteTimeGetCurrent() + self.pingPeriod;
                while i < blocks.count{
                    if let block = blocks[i] as? ()->(Ping?){
                        let ping = block()
                        if ping?.isPinging == false{
                            blocks.remove(at: i)
                            i -= 1
                        }
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
            var blocks = listenBlocks
            while isPinging,blocks.count > 0{
                var i = 0
                
                while i < blocks.count{
                    if let block = blocks[i] as? ()->(Ping?){
                        let ping = block()
                        if ping?.isPinging == false{
                            blocks.remove(at: i)
                             i -= 1
                        }
                       
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

