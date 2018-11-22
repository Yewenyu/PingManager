//
//  PingManager.swift
//  ThreeTab
//
//  Created by wenyu on 2018/11/19.
//  Copyright © 2018年 ThreeTab. All rights reserved.
//

import UIKit

class NewGBPingMannager : NSObject{
    @objc static let shared = NewGBPingMannager()
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
    var zy_pings = [NewGBPing]()
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
            var zy_blocks = self.disposeBlocks
            zy_blocks.removeFirst()
            self.disposeBlocks = zy_blocks
        }
    }
    func setup(_ callBack:(()->())? = nil){
        var zy_newPings = zy_pings
        if self.disposeThread == nil{
            self.disposeThread = Thread(target: self, selector: #selector(self.disposeAction), object: nil)
            self.disposeThread?.name = "disposeThread"
            self.isDispose = true
            self.disposeThread?.start()
        }
        
        for zy_ping in zy_pings{
            readyGroup.enter()
            zy_ping.setup { (zy_success, zy_error) in
                if zy_success{
                    zy_ping.startPinging()
                }else{
                    zy_newPings.removeAll(where: { (zy_delete) -> Bool in
                        return zy_delete.host == zy_ping.host
                    })
                }
                
                
                self.readyGroup.leave()
            }
        }
        readyGroup.notify(queue: readyQueue) {
            self.isDispose = false
            self.disposeThread = nil
            self.zy_pings = zy_newPings
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
        isPinging = false
        self.sendThread = nil
        self.listenThread = nil
        self.disposeThread = nil
        self.sendBlocks.removeAll()
        self.listenBlocks.removeAll()
        self.disposeBlocks.removeAll()
        for zy_ping in zy_pings{
            zy_ping.stop()
        }
        self.zy_pings.removeAll()
    }
    
    @objc private func sendAction(){
        autoreleasepool {
            var zy_blocks = sendBlocks
            while isPinging,zy_blocks.count > 0{
                var i = 0
                while i < zy_blocks.count{
                    if let zy_block = zy_blocks[i] as? ()->(NewGBPing?){
                        let zy_ping = zy_block()
                        if zy_ping?.isPinging == false{
                            zy_blocks.remove(at: i)
                        }
                    }
                    i += 1
                }
                //                let lastCount = Thread.getThreadsCount()
                //                NSLog("Thread:"+lastCount.description)
                let runUntil = CFAbsoluteTimeGetCurrent() + self.pingPeriod;
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
            var zy_blocks = listenBlocks
            while isPinging,zy_blocks.count > 0{
                var i = 0
                
                while i < zy_blocks.count{
                    if let zy_block = zy_blocks[i] as? ()->(NewGBPing?){
                        let zy_ping = zy_block()
                        if zy_ping?.isPinging == false{
                            zy_blocks.remove(at: i)
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
                    let zy_blocks = self.getDisposeBlocks()
                    if let zy_block = zy_blocks.first as? ()->(){
                        zy_block()
                    }
                    self.removeDisposeBlocksFirst()
                }
            }
        }
    }
}

extension Thread{
    var sequenceNumber : Int{
        get{
            return self.value(forKeyPath: "private.seqNum") as? Int ?? 0
        }
    }
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

