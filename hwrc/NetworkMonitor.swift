//
//  NetworkMonitor.swift
//  hwrc
//
//  Created by tap4fun on 2021/10/28.
//

import Foundation
import UIKit
import SystemConfiguration    // Settings Bundle


enum NetworkStatus: Int
{
    case NETWORK_NOT_REACHABLE    = 0
    case NETWORK_THRU_WIFI        = 1
    case NETWORK_THRU_WWAN        = 2
}

//! Swift obj reference --> Unmanaged C Pointer
func bridge<T : AnyObject>(obj : T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque())
    // return unsafeAddressOf(obj) // ***
}

//! Unmanaged C Pointer --> Swift obj reference
func bridge<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    // return unsafeBitCast(ptr, T.self) // ***
}

//! callback which can receive device's event of network status changing
func ReachabilityCallback(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?)
{
    let monitor: NetworkMonitor = bridge(ptr:info!);
    monitor.parseReachabilityFlags(flags:flags);
}

class NetworkMonitor {
    
    static let shared = NetworkMonitor()
    
    var mNetworkStatus: NetworkStatus
    var networkStatus: NetworkStatus
    {
        get { return mNetworkStatus }
    }
    private var mReachabilityPtr: SCNetworkReachability?
    
    private init() {
        mNetworkStatus = NetworkStatus.NETWORK_THRU_WIFI
        
        var zeroAddr = sockaddr()
        zeroAddr.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddr.sa_family = sa_family_t(AF_INET)
        mReachabilityPtr =  SCNetworkReachabilityCreateWithAddress(nil, &zeroAddr);
    }
    
    //! monitor device's network traffic path
    func startMonitorNetwork() {
        if mReachabilityPtr != nil {
            //
            getCurrentNetworkPath()
            
            let voidPtr = UnsafeMutableRawPointer(mutating:bridge(obj:self))
            var context = SCNetworkReachabilityContext(version: 0,            // fixed value
                                                       info: voidPtr,        // user-specified data
                                                       retain: nil,            // These 3 callbacks
                                                       release: nil,        // aren't necessary
                                                       copyDescription: nil)// for me.
            if SCNetworkReachabilitySetCallback(mReachabilityPtr!,
                                                ReachabilityCallback,    // callback when reachability changes
                                                &context)
            {
                SCNetworkReachabilityScheduleWithRunLoop(mReachabilityPtr!,
                                                         CFRunLoopGetCurrent(),
                                                         CFRunLoopMode.defaultMode.rawValue);
            }
        }
    }
    
    //! never get a chance to be invoked. Just place here as a reference.
    func stopMonitorNetwork() {
        if mReachabilityPtr != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(mReachabilityPtr!,
                                                       CFRunLoopGetCurrent(),
                                                       CFRunLoopMode.defaultMode.rawValue);
        }
    }
    
    func parseReachabilityFlags(flags: SCNetworkReachabilityFlags) {
        if flags.contains(.reachable) {
            mNetworkStatus = flags.contains(.isWWAN) ? .NETWORK_THRU_WWAN : .NETWORK_THRU_WIFI
        } else {
            mNetworkStatus = .NETWORK_NOT_REACHABLE;
        }
    }
    
    func getCurrentNetworkPath() {
        var flags = SCNetworkReachabilityFlags();
        SCNetworkReachabilityGetFlags(mReachabilityPtr!, &flags);
        parseReachabilityFlags(flags:flags)
    }
}
