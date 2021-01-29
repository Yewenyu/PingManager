//
//  PingResult.swift
//  PingTest
//
//  Created by wenyu on 2018/11/25.
//  Copyright © 2018年 wenyu. All rights reserved.
//

import Foundation

public enum PingStatus{
    case pending
    case success
    case fail
}

public class PingResult: NSObject {

    public var sequenceNumber : UInt = 0
    public var payloadSize : UInt = 0
    public var ttl : UInt = 0
    public var host : String?
    public var sendDate : Date?
    public var receiveDate : Date?{
        didSet{
            if let receiveDate = receiveDate?.timeIntervalSince1970,let sendDate = sendDate?.timeIntervalSince1970{
                time = receiveDate - sendDate
            }
        }
    }
    public var time : TimeInterval = 0
    public var rtt : TimeInterval{
        get{
            if let sendDate = sendDate{
                return receiveDate?.timeIntervalSince(sendDate) ?? 0
            }
            return 0
        }
    }
    public var pingStatus = PingStatus.pending
    
    public required override init() {
        super.init()
    }
    
    func copy() -> Self {
        let newResult = type(of: self).init()
        newResult.sequenceNumber = sequenceNumber
        newResult.payloadSize = payloadSize
        newResult.ttl = ttl
        newResult.host = host
        newResult.sendDate = sendDate
        newResult.receiveDate = receiveDate
        newResult.time = time
        newResult.pingStatus = pingStatus
        return newResult
    }
}
