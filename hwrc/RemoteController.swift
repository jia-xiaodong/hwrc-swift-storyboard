//
//  RemoteController.swift
//  hwrc
//
//  Created by tap4fun on 2021/10/28.
//

import Foundation
import UIKit


// These magic numbers are extracted from http://health.vmall.com/mediaQ/controller.jsp
enum ActionCode: Int
{
    case ACTION_NULL        = -1
    case ACTION_OK            = 0
    case ACTION_LEFT        = 1
    case ACTION_DOWN        = 2
    case ACTION_RIGHT        = 3
    case ACTION_UP            = 4
    case ACTION_BACK        = 5
    case ACTION_HOME        = 6
    case ACTION_MENU        = 7
    case ACTION_POWER        = 8
    case ACTION_VOL_UP        = 9
    case ACTION_VOL_DOWN    = 10
}

let DEFAULT_IP_ADDRESS = "192.168.1.102";    // for Huawei set-top box

class RemoteController {
    
    //! IP address of Huawei set-top box
    private var mBoxIPAddress: String
    var BoxIPAddress: String
    {
        get { return mBoxIPAddress }
        set { mBoxIPAddress = newValue }
    }
    
    var mURLSession: URLSession
    private var mIgnoreNetError: Bool = false
    var IgnoreNetError: Bool
    {
        get { return mIgnoreNetError }
        set { mIgnoreNetError = newValue }
    }
    
    static let shared = RemoteController()
    
    private init() {
        mBoxIPAddress = DEFAULT_IP_ADDRESS
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1.0
        mURLSession = URLSession(configuration: config,
                                   delegate: nil,        // we don't need delegate to monitor task status,
                                   delegateQueue: nil)   // so ignore this queue, too.
    }
    
    //! all commands of Huawei remote control are executed (sent) here!
    func performAction(code: ActionCode)
    {
        // remote control must work under same local Wifi network to the Huawei set-top box.
        if NetworkMonitor.shared.networkStatus != .NETWORK_THRU_WIFI {
            return
        }
        //debugPrint("[Action] code=\(code)")

        /* dispatch command to main queue so as to avoid UI blocking.
        *
        * App Transport Security blocks cleartext HTTP request by default iOS Device Policy.
        * In order to send Huawei HTTP command, below setting must be present in Info.plist file:
        *   {
        *      "App Transport Security Settings": {
        *         "Allow Arbitrary Loads": YES
        *      }
        *   }
        */
        let url = URL(string: "http://\(mBoxIPAddress):7766/remote?key=\(code.rawValue)")
        let task = mURLSession.dataTask(with:url!) {(data, response, error) in
            if error == nil {
                return
            }
            
            if self.mIgnoreNetError {
                return
            }
            
            /*
                Display localized message-box to user in main thread (Thread 1).
                If not in main thread, it will damage the Auto Layout engine and may crash.
                Note: completion handler runs in sub-thread!
                So we need dispatch Alert Message Box to main thread.
            */
            DispatchQueue.main.async {
                let strTitle = NSLocalizedString("Set-top Box Remote", comment: "app full name")
                let alert = UIAlertController(title: strTitle,
                    message: error!.localizedDescription,
                    preferredStyle:.alert)
                let strOk = NSLocalizedString("OK", comment: "OK")
                alert.addAction(UIAlertAction(title: strOk, style: .default, handler: nil))
                
                let viewController = UIApplication.shared.windows.first!.rootViewController
                viewController?.present(alert, animated:true, completion:nil)
            }
        }
        task.resume()
    }
}
