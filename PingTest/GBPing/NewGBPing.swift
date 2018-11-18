//
//  NewGBPing.swift
//  ThreeTab
//
//  Created by wenyu on 2018/11/14.
//  Copyright © 2018年 ThreeTab. All rights reserved.
//

import UIKit

let kPendingPingsCleanupGrace : TimeInterval = 1.0
let kDefaultPayloadSize = 56
let kDefaultTTL = 49
let kDefaultPingPeriod : TimeInterval = 1.0
let kDefaultTimeout : TimeInterval = 2.0

class NewGBPing: GBPing {

    static var pingThreadCount = 0
    
    var pingThreadCount = 0
    override init() {
        super.init()
        NewGBPing.pingThreadCount += 1
        pingThreadCount = NewGBPing.pingThreadCount
//        self.isListenThread = false
        self.isPinging = true
        weak var zy_ping = self
        let sendBlock = { () -> NewGBPing? in
            zy_ping?.send()
            return zy_ping
        }
        let listenBlock = { () -> NewGBPing? in
            zy_ping?.listenOnce()
            return zy_ping
        }
        NewGBPingMannager.shared.sendBlocks.append(sendBlock)
        NewGBPingMannager.shared.listenBlocks.append(listenBlock)
        NewGBPingMannager.shared.zy_pings.append(self)
        
    }
    override func startPinging() {
        self.isPinging = true
    }
    override func stop() {
        if isPinging,let stop = self.delegate?.stop{
            self.isPinging = false
            stop(self)
        }
        
    }
    
    override func send() {
        
        super.send()
        
        pingThreadCount += 1
//        NSLog(pingThreadCount.description)
//        self.listenOnce()
//        let current = Thread.current.name
//        if current != pingThreadCount.description{
//            Thread.current.name = pingThreadCount.description
//            NSLog(pingThreadCount.description)
//        }
        
        
    }
    override func listenOnce() {
        
        super.listenOnce()
//        send11()
        
    }
    deinit {
        
        NewGBPing.pingThreadCount -= 1
        
    }
    let INET6_ADDRSTRLEN = 64
    
    
    static func icmp4HeaderOffsetInPacket(_ packet : Data) -> UInt{
        var result : UInt
        var ipPtr : IPHeader
//    const struct IPHeader * ipPtr;
        var ipHeaderLength : size_t
        result = UInt(NSNotFound)
        if packet.count >= MemoryLayout<IPHeader>.size + MemoryLayout<ICMPHeader>.size{
            ipPtr = (packet as NSData).bytes.bindMemory(to: IPHeader.self, capacity:packet.count).pointee
            
            assert((ipPtr.versionAndHeaderLength & 0xF0) == 0x40)
            assert(ipPtr.ptl == 1)
            ipHeaderLength = Int((ipPtr.versionAndHeaderLength & 0x0F)) * MemoryLayout<UInt32>.size
            if packet.count >= ipHeaderLength + MemoryLayout<ICMPHeader>.size{
                result = UInt(ipHeaderLength)
            }
        }
        return result
    }
    static func icmp4InPacket(packet:Data) -> ICMPHeader?{
        var result : ICMPHeader? = nil
        var icmpHeaderOffset : UInt
        
        icmpHeaderOffset = self.icmp4HeaderOffsetInPacket(packet)
        if icmpHeaderOffset != NSNotFound {
            let bytes = (packet as NSData).bytes
            result = bytes.bindMemory(to: ICMPHeader.self, capacity: packet.count).pointee
        }
        return result
    }
    static func sourceAddressInPacket(_ packet:Data) ->String?{
    // Returns the source address of the IP packet
        var ipPtr : UnsafePointer<IPHeader>
        if packet.count >= MemoryLayout<IPHeader>.size{
            ipPtr = (packet as NSData).bytes.bindMemory(to: IPHeader.self, capacity: packet.count)
            
            let sourceAddress = ipPtr.pointee.sourceAddress//dont need to swap byte order those cuz theyre the smallest atomic unit (1 byte)
            let ipString = "\(sourceAddress.0).\(sourceAddress.1).\(sourceAddress.2).\(sourceAddress.3)"
            
            return ipString
        }
        return nil;
    }
    // This is the standard BSD checksum code, modified to use modern types.
    
    var hostAddressFamily : sa_family_t {
        get{
            var result : sa_family_t = sa_family_t(AF_UNSPEC)
            if self.hostAddress.count >= MemoryLayout<sockaddr>.size{
                result = (self.hostAddress as NSData).bytes.bindMemory(to: sockaddr.self, capacity: self.hostAddress.count).pointee.sa_family
            }
            return result
        }
    }
    // Returns true if the packet looks like a valid ping zy_response packet destined
    // for us.
    enum kICMPv4Type : UInt8{
 
        case EchoRequest = 8
        case EchoReply   = 0
    }
    enum kICMPv6Type : UInt8{
        case EchoRequest = 128
        case EchoReply   = 129
    }
    func isValidPing4ResponsePacket(_ packet : Data) -> Bool{
        var packet = packet
        var result = false
        var icmpHeaderOffset : UInt
        var icmpPtr : ICMPHeader
        var receivedChecksum:UInt16
        var calculatedChecksum:UInt16
        
        icmpHeaderOffset = NewGBPing.icmp4HeaderOffsetInPacket(packet)
    
        if icmpHeaderOffset != NSNotFound{
            var pointer = (packet as NSData).bytes.bindMemory(to: ICMPHeader.self, capacity: packet.count)
            pointer = pointer + Int(icmpHeaderOffset)
            icmpPtr = pointer.pointee
//    icmpPtr = (struct ICMPHeader *) (((uint8_t *)[packet mutableBytes]) + icmpHeaderOffset);
            receivedChecksum = icmpPtr.checksum
            icmpPtr.checksum  = 0
            calculatedChecksum = COperation.in_cksum(&icmpPtr, bufferLen: packet.count - Int(icmpHeaderOffset))
            icmpPtr.checksum  = receivedChecksum
    
            if receivedChecksum == calculatedChecksum{
                if icmpPtr.type == kICMPv4Type.EchoReply.rawValue, icmpPtr.code == 0 {
                    
                    if CFSwapInt16(icmpPtr.identifier) == self.identifier  {
                        if CFSwapInt16(icmpPtr.sequenceNumber) < self.nextSequenceNumber{
                            result = true
                        }
                    }
                }
            }
        }
        return result
    }
    
    // Returns true if the IPv6 packet looks like a valid ping zy_response packet destined
    // for us.
    func isValidPing6ResponsePacket(_ packet:Data)->Bool{
        var result = false
        var icmpPtr : UnsafePointer<ICMPHeader>

        if packet.count >= MemoryLayout<ICMPHeader>.size {
            icmpPtr = (packet as NSData).bytes.bindMemory(to: ICMPHeader.self, capacity: packet.count)
            if icmpPtr.pointee.type == kICMPv4Type.EchoReply.rawValue,icmpPtr.pointee.code == 0{
                if CFSwapInt16(icmpPtr.pointee.identifier) == self.identifier{
                    if CFSwapInt16(icmpPtr.pointee.sequenceNumber) < self.nextSequenceNumber{
                        result = true
                    }
                }
            }
        }
        return result
    
    }
    func isValidPingResponsePacket(_ packet: Data)->Bool{
        var result : Bool
    
        switch self.hostAddressFamily{
        case sa_family_t(AF_INET):
            result = self.isValidPing4ResponsePacket(packet)
            break
        case sa_family_t(AF_INET6):
            result = self.isValidPing6ResponsePacket(packet)
            break
        default:
            result = false
            break
        }
        return result
    }
    

    func send11(){
        var err : Int
        var ss = sockaddr_storage()
        let addr = UnsafeMutablePointer<sockaddr_storage>(&ss)
        var addrLen : socklen_t
        var bytesRead : ssize_t
        let kBufferSize = 65535
        let buffer = malloc(kBufferSize)
        
        assert((buffer != nil))
        
        //read the data.
        addrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let addrSockaddr = UnsafeMutableRawPointer(addr).bindMemory(to: sockaddr.self, capacity: Int(addrLen))
        
        
        bytesRead = recvfrom(self.socket, buffer, kBufferSize, 0, addrSockaddr, &addrLen)
        err = 0;
        if bytesRead < 0 {
            err = -1;
        }
        
        //process the data we read.
        if bytesRead > 0 {
            var hoststr = CChar()
//            char hoststr[INET6_ADDRSTRLEN];
            var sin : sockaddr_in = UnsafeMutableRawPointer(addrSockaddr).bindMemory(to: sockaddr_in.self, capacity: Int(addrLen)).pointee
            inet_ntop(Int32(sin.sin_family), &(sin.sin_addr), &hoststr, socklen_t(INET6_ADDRSTRLEN))
//            struct sockaddr_in *sin = (struct sockaddr_in *)&addr;
//            inet_ntop(sin->sin_family, &(sin->sin_addr), hoststr, INET6_ADDRSTRLEN);
            let host = String(utf8String: &hoststr)
            
            if(host == hostAddressString) { // only make sense where received packet comes from expected source
                
                let receiveDate = Date()
                var packet = Data(bytes: buffer!, count: bytesRead)
                
//                assert((packet));
                
                //complete the ping summary
//                const struct ICMPHeader *headerPointer;
                var headerPointer : ICMPHeader?
                
                if sin.sin_family == AF_INET{
                    headerPointer = NewGBPing.icmp4InPacket(packet: packet)
                } else {
                    headerPointer = (packet as NSData).bytes.bindMemory(to: ICMPHeader.self, capacity: packet.count).pointee
                    
                }
                
                let segNo = CFSwapInt16(headerPointer!.sequenceNumber)
//                NSUInteger seqNo = (NSUInteger)OSSwapBigToHostInt16(headerPointer->sequenceNumber);
                let key = NSNumber(value: segNo)
//                NSNumber *key = @(seqNo);
                let pingSummary =  (self.pendingPings[key] as? GBPingSummary)?.copy() as? GBPingSummary
//                GBPingSummary *pingSummary = [(GBPingSummary *)self.pendingPings[key] copy];
                
                if pingSummary != nil{
                    
                    if self.isValidPingResponsePacket(packet){
                        //override the source address (we might have sent to google.com and 172.123.213.192 replied)
                        pingSummary!.receiveDate = receiveDate
                        // IP can't be read from header for ICMPv6
                        if sin.sin_family == sa_family_t(AF_INET) {
                            
                            pingSummary?.host = NewGBPing.sourceAddressInPacket(packet)
                            
                            //set ttl from zy_response (different servers may respond with different ttls)
                            let ipPtr : UnsafePointer<IPHeader>
                            
                            if packet.count >= MemoryLayout<IPHeader>.size {
                                
                                ipPtr = (packet as NSData).bytes.bindMemory(to: IPHeader.self, capacity: packet.count)
                                pingSummary?.ttl = UInt(ipPtr.pointee.timeToLive);
                            }
                        }
                        
                        pingSummary?.status = GBPingStatusSuccess
                        let timer = self.timeoutTimers[key] as! Timer
                        timer.invalidate()
                        self.timeoutTimers.removeObject(forKey: key)
                        DispatchQueue.main.async {
                            self.delegate?.ping?(self, didReceiveReplyWith: pingSummary!)
                        }
                    }else {
                        pingSummary?.status = GBPingStatusFail;
                        
                        DispatchQueue.main.async {
                            self.delegate?.ping?(self, didReceiveUnexpectedReplyWith: pingSummary!)
                        }
                        
                    }
                }
            }
        }
        else {
            
            //we failed to read the data, so shut everything down.
            if (err == 0) {
                err = Int(EPIPE);
            }
            
            if self.isStopped{
                DispatchQueue.main.async {
                    self.delegate?.ping?(self, didFailWithError: NSError.init(domain: NSPOSIXErrorDomain, code: err, userInfo: nil))
                }
            }
            self.stop()
        }
        free(buffer)
    }
    
    func generateDataWithLength(length:UInt) -> NSData {
    //create a buffer full of 7's of specified length
        var tempBuffer = [UInt8]()
        memset(&tempBuffer, 7, Int(length))
    
        return Data(bytes: tempBuffer) as NSData
    }
    func pingPacketWithType(_ type: UInt8, _ payload:NSData ,_ requiresChecksum:Bool)  -> NSData{
        var packet: NSMutableData
        var icmpPtr : UnsafeMutablePointer<ICMPHeader>
        
        packet = NSMutableData(length: MemoryLayout<ICMPHeader>.size + payload.length)!
    
        icmpPtr = packet.mutableBytes.bindMemory(to: ICMPHeader.self, capacity: packet.length)
        icmpPtr.pointee.type = type
        icmpPtr.pointee.code = 0
        icmpPtr.pointee.checksum = 0
        icmpPtr.pointee.identifier  = CFSwapInt16(self.identifier)
        icmpPtr.pointee.sequenceNumber = CFSwapInt16(UInt16(self.nextSequenceNumber))
        memcpy(&icmpPtr[1], payload.bytes, payload.length);
        if requiresChecksum {
            // The IP checksum routine returns a 16-bit number that's already in correct byte order
            // (due to wacky 1's complement maths), so we just put it into the packet as a 16-bit unit.
            
            icmpPtr.pointee.checksum = COperation.in_cksum(packet.bytes, bufferLen: packet.length)
        }
        return packet
    
    }
    func send123(){
        if self.isPinging {
    
            var err :Int
            var packet: NSData = NSData()
            var bytesSent:ssize_t
    
            // Construct the ping packet.
            let payload = self.generateDataWithLength(length: self.payloadSize)
            
            let hostAddressFamily = self.hostAddressFamily
            switch hostAddressFamily{
            case sa_family_t(AF_INET):
                packet = self.pingPacketWithType(kICMPv4Type.EchoRequest.rawValue, payload, true)
                break
            case sa_family_t(AF_INET6):
                packet = pingPacketWithType(kICMPv6Type.EchoRequest.rawValue, payload, true)
                break
                
            default:
                break
            }
    
            let newPingSummary = GBPingSummary()
            
            // Send the packet.
            if self.socket == 0{
                bytesSent = -1
                err = Int(EBADF)
            }else{
                
                //record the send date
                let sendDate = Date()
                
                //construct ping summary, as much as it can
                newPingSummary.sequenceNumber = self.nextSequenceNumber
                newPingSummary.host = self.host
                newPingSummary.sendDate = sendDate
                newPingSummary.ttl = self.ttl
                newPingSummary.payloadSize = self.payloadSize
                newPingSummary.status = GBPingStatusPending
                
                //add it to pending pings
                let key = NSNumber(value: self.nextSequenceNumber)
                self.pendingPings[key] = newPingSummary
                
                //increment sequence number
                self.nextSequenceNumber += 1
                
                //we create a copy, this one will be passed out to other threads
                let pingSummaryCopy = newPingSummary.copy() as? GBPingSummary
                
                //we need to clean up our list of pending pings, and we do that after the timeout has elapsed (+ some grace period)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (self.timeout + kPendingPingsCleanupGrace) * Double(NSEC_PER_SEC)) {
                    self.pendingPings.removeObject(forKey: key)
                }
                
                
                //add a timeout timer
                //add a timeout timer
                let timeoutTimer = Timer(timeInterval: self.timeout, target: BlockOperation(block: {
                    newPingSummary.status = GBPingStatusFail
                    DispatchQueue.main.async {
                        self.delegate?.ping?(self, didTimeoutWith: pingSummaryCopy!)
                    }
                    self.timeoutTimers.removeObject(forKey: key)
                }), selector: #selector(BlockOperation.main), userInfo: nil, repeats: false)
                RunLoop.main.add(timeoutTimer, forMode: .commonModes)
                
                self.timeoutTimers[key] = timeoutTimer
                //keep a local ref to it
                self.delegate?.ping?(self, didSendPingWith: pingSummaryCopy!)
                let hostAddress = self.hostAddress as NSData
                bytesSent = sendto(self.socket, packet.bytes, packet.length, 0, hostAddress.bytes.bindMemory(to: sockaddr.self, capacity: hostAddress.length), socklen_t(hostAddress.length))
                err = 0
                if bytesSent < 0 {
                    err = Int(errno)
                }
                if bytesSent > 0,Int(bytesSent) == packet.length {
                    //noop, we already notified delegate about sending of the ping
                }else{
                    //complete the error
                    if (err == 0) {
                        err = Int(ENOBUFS)    // This is not a hugely descriptor error, alas.
                    }
                    
                    //little log
                    if (self.debug) {
                        NSLog("GBPing: failed to send packet with error code: %d", err)
                    }
                    
                    //change status
                    newPingSummary.status = GBPingStatusFail
                    let pingSummaryCopyAfterFailure = newPingSummary.copy() as? GBPingSummary
                    
                    self.delegate?.ping?(self, didFailToSendPingWith: newPingSummary, error: NSError(domain: NSPOSIXErrorDomain, code: err, userInfo: nil))
                }
            }
        }
    }
}


class NewGBPingMannager : NSObject{
    @objc static let shared = NewGBPingMannager()
    let readyQueue = DispatchQueue(label: "NewGBPingReadyQueue")
    let readyGroup = DispatchGroup()
    let disposeQueue = DispatchQueue(label: "NewGBPingDisposeQueue")
    
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
