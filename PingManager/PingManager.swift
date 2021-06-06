//
//  PingManager.swift
//  ThreeTab
//
//  Created by wenyu on 2018/11/19.
//  Copyright © 2018年 ThreeTab. All rights reserved.
//

import Foundation

public class PingManager : NSObject{
    @objc public static let shared = PingManager()
    let readyGroup = DispatchGroup()
    let mainQueue = DispatchQueue(label: "NewPingMainQueue")
    
    public var isMemoryWarning : Bool{
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

    public var pings = [Ping]()
    
    var isSettingUp = false
    var isPinging = false
    public var pingPeriod : TimeInterval = 1
    public var timeout : TimeInterval = 1{
        didSet{
            for ping in pings{
                ping.timeout = timeout
            }
        }
    }
    @objc public func add(_ ping:Ping){
        pings.append(ping)
    }
    @objc public func add(pings:[Ping]){
        pings.forEach{
            add($0)
        }
    }
    @objc public func add(hosts:[String],delegate:PingDelegate? = nil){
        let pings = hosts.map{
            Ping($0).Delegate(delegate)
        }
        add(pings: pings)
    }
    
    
    public func setup(_ setupBlock:((PingManager)->())? = nil){
        
        var newPings = self.pings
        let pings = self.pings
        
        mainQueue.async {[weak self] in
            guard let self = self else{return}
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
            self.isSettingUp = false
            self.pings = newPings
            setupBlock?(self)
        }
        
    }
    public func startPing(){
        if !self.isPinging{
            self.isPinging = true
            send()
            listen()
            
        }
    }
    public func stopPing(){
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
        mainQueue.async {[weak self] in
            guard let pingManager =  self else {return}
            let time = pingManager.pingPeriod
            if pingManager.isPinging == true{
                pingManager.pings.removeAll(where: { (ping) -> Bool in
                    return ping.isPinging == false
                })
                if pingManager.pings.count > 0 {
                    let pings = [Ping](pingManager.pings)
                    for ping in pings{
                        ping.send()
                    }
                    pingManager.mainQueue.asyncAfter(deadline: .now() + time) {
                        pingManager.send()
                    }
                }
                
            }
        }
        
    }
    private func listen(){
        
        mainQueue.async {[weak self] in
            guard let pingManager =  self else{return}
            if pingManager.isPinging == true{
                pingManager.pings.removeAll(where: { (ping) -> Bool in
                    return ping.isPinging == false
                })
                if pingManager.pings.count > 0 {
                    let pings = [Ping](pingManager.pings)
                    for ping in pings{
                        ping.listenOnce()
                    }
                    pingManager.listen()
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

