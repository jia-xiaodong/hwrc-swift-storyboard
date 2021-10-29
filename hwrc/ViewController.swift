//
//  ViewController.swift
//  hwrc
//
//  Created by tap4fun on 2021/10/28.
//

import UIKit

//! user can pan his finger to four directions
enum ActionDirection
{
    case DIRECTION_INVALID
    case DIRECTION_LEFT
    case DIRECTION_DOWN
    case DIRECTION_RIGHT
    case DIRECTION_UP
    
    func toActionCode() -> ActionCode {
        switch self {
        case .DIRECTION_LEFT:
            return .ACTION_LEFT
        case .DIRECTION_RIGHT:
            return .ACTION_RIGHT
        case .DIRECTION_UP:
            return .ACTION_UP
        case .DIRECTION_DOWN:
            return .ACTION_DOWN
        default:
            return .ACTION_NULL
        }
    }
}

/*
  TODO: I copied the code from Internet and it works. But I can't understand
  below mess of slashes. What a regex syntax it's using?
  \\.    literal "." (period)
  \\d    ?
*/
func isValidIPv4Address(addr: String) -> Bool {
    let regex = "^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\." +
        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\." +
        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\." +
        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$"
    let predicate = NSPredicate(format:"SELF MATCHES %@", regex)
    return predicate.evaluate(with:addr)
}

class ViewController: UIViewController {
    
    private var mCurrDirection, mPrevDirection: ActionDirection
    var CurrentDir: ActionDirection
    {
        get { return mCurrDirection }
        set { mCurrDirection = newValue }
    }
    var PreviousDir: ActionDirection
    {
        get { return mPrevDirection }
        set { mPrevDirection = newValue }
    }
    
    //! process long-press gesture when finger panning
    var mDirectionRepeater: Timer?
    
    //! Single-tap or Double-tap OK
    var mIsDoubleTapOK: Bool
    var mTapGesture: UITapGestureRecognizer
    
    //! User Settings
    let KEY_BOX_IP_ADDRESS = "box_ip_address"
    let KEY_DOUBLE_TAP_OK = "double_tap_ok";
    let KEY_DISABLE_ERR_MSG = "disable_error_message"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        loadUserConfig()
        detectGestureArea()
        setupGestures()
        
        NetworkMonitor.shared.startMonitorNetwork()
    }
    
    var mConfigNeedReload = false
    var ConfigNeedReload: Bool {
        get { return mConfigNeedReload }
        set { mConfigNeedReload = newValue }
    }
    
    //! gesture area
    private var mGestureRectTop: CGFloat    // Y-coordinate
    
    // FIXME: why is it required? What is NSCoder?
    required init?(coder aDecoder: NSCoder) {
        mCurrDirection = ActionDirection.DIRECTION_INVALID
        mPrevDirection = mCurrDirection
        mDirectionRepeater = nil
        mIsDoubleTapOK = false
        mTapGesture = UITapGestureRecognizer()
        mGestureRectTop = CGFloat(0)
        
        //! FIXME: must be placed at bottom.
        //! If placed topmost, compiler won't happy. Why?
        super.init(coder: aDecoder)
    }
    
    //! tap and pan gesture recognizers cover whole area of UIView page. But upper
    //! screen is full of buttons. So we mannually ignore the UIButton area. You
    //! can find bypass code in func handleTap(_:).
    func detectGestureArea() {
        var positions = [CGFloat]()
        for i in self.view.subviews where i is UIButton {
            if i.tag == 0 {
                positions.append(i.frame.maxY)
            }
        }
        mGestureRectTop = positions.max()!
    }
    
    func setupGestures() {
        // pinch open: volume up; pinch close: volume down
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        self.view.addGestureRecognizer(pinch)
        
        // pan to up, down, left and right direction
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.view.addGestureRecognizer(pan)
        
        mDirectionRepeater = Timer(fireAt: Date.distantFuture,  // pause at start
                                   interval: 0.2,
                                   target: self,
                                   selector: #selector(handleLongPress(_:)),
                                   userInfo: nil,
                                   repeats: true)
        // schedule it to "common" RunLoop to avoid UI intervention
        if let timer = mDirectionRepeater {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    @IBAction func powerClicked(sender: UIButton) {
        RemoteController.shared.performAction(code:.ACTION_POWER)
    }
    
    @IBAction func homeClicked(sender: UIButton) {
        RemoteController.shared.performAction(code:.ACTION_HOME)
    }
    
    @IBAction func menuClicked(sender: UIButton) {
        RemoteController.shared.performAction(code:.ACTION_MENU)
    }
    
    @IBAction func volDownClicked(sender: UIButton) {
        RemoteController.shared.performAction(code:.ACTION_VOL_DOWN)
    }
    
    @IBAction func volUpClicked(sender: UIButton) {
        RemoteController.shared.performAction(code:.ACTION_VOL_UP)
    }
    
    @IBAction func backClicked(sender: UIButton) {
        RemoteController.shared.performAction(code:.ACTION_BACK)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let pt = gesture.location(in:self.view)
        if (pt.y > mGestureRectTop)
        {
            RemoteController.shared.performAction(code:.ACTION_OK);
        }
    }
    
    //! control volume
    // FIXME: how to debug this "pinch" behavior in simulator?
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .ended {
            let action:ActionCode = gesture.scale > 1.0 ? .ACTION_VOL_UP : .ACTION_VOL_DOWN
            RemoteController.shared.performAction(code:action)
        }
    }
    
    //! process pan gestures of UP, DOWN, LEFT and RIGHT.
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            mCurrDirection = .DIRECTION_INVALID
            mPrevDirection = .DIRECTION_INVALID
        } else if gesture.state == .changed {
            let pt = gesture.translation(in:self.view)
            let xabs = abs(pt.x);
            let yabs = abs(pt.y);
            if (xabs > yabs)
            {
                mCurrDirection = pt.x > 0 ? .DIRECTION_RIGHT : .DIRECTION_LEFT
            }
            else if (xabs < yabs)
            {
                mCurrDirection = pt.y > 0 ? .DIRECTION_DOWN : .DIRECTION_UP;
            }
        
            if (mPrevDirection != mCurrDirection)
            {
                //! Firstly, respond to user's input
                RemoteController.shared.performAction(code:mCurrDirection.toActionCode())
            
                /*
                Secondly, begin to monitor user's long press.
                If user keeps initial direction for more than 0.5 second, accelerate that input.
                If user releases finger within 0.5 second, below pausePanTimer will invalidate timer.
                */
                mDirectionRepeater?.fireDate = Date.init(timeIntervalSinceNow: 0.5)
                mPrevDirection = mCurrDirection;
            }
        } else if gesture.state == .ended {
            mCurrDirection = .DIRECTION_INVALID
            mPrevDirection = .DIRECTION_INVALID
            pausePanTimer()
        }
    }
    
    //! release Timer resources, because they don't support re-schedule operation. So we have to
    //! make new ones when we need them again.
    func pausePanTimer() {
        mDirectionRepeater?.fireDate = Date.distantFuture
    }
    
    @objc func handleLongPress(_ timer: Timer) {
        let action = mCurrDirection.toActionCode()
        if action != .ACTION_NULL {
            RemoteController.shared.performAction(code:action)
        }
    }
    
    //! User Settings in "iPhone Settings" page
    //
    // === Important Points about Settings Bundle and Its Debug ===
    //
    // As long as you add a Settings.bundle to your project, it would show off
    // in iPhone Settings page definitely. If you open iPhone Settings page but
    // find nothing except a blank page, the reason might be:
    // 1. Root.plist has wrong-format setting, remove them one by one to check
    //    which one is wrong. If any one of them is of wrong format, the whole
    //    page becomes blank.
    // 2. If you want new Root.plist to take effect, you should relaunch iPhone
    //    Settings app to force it to read settings again.
    //
    // Once your settings can display completely in iPhone Settings page, it's
    // time to read them programmatically. If you cannot read any setting value
    // from NSUserDefaults, it's because your settings don't exist in UserDefault.
    // To make it created there, you should go to iPhone Settings page and make
    // some change.
    //
    func loadUserConfig() {
        let config = UserDefaults.standard
        
        //! [1] Box IP address
        let ipAddr = config.string(forKey:KEY_BOX_IP_ADDRESS)
        if ipAddr != nil {
            if isValidIPv4Address(addr:ipAddr!) && ipAddr != RemoteController.shared.BoxIPAddress {
                RemoteController.shared.BoxIPAddress = ipAddr!
            }
        }
        
        //! [2] Is double-tap / single-tap effective
        let isDoubleTap = config.bool(forKey:KEY_DOUBLE_TAP_OK)
        let owned = self.view.gestureRecognizers
        let installed = (owned == nil ? false : owned!.contains(mTapGesture))
        if isDoubleTap != mIsDoubleTapOK || !installed {
            mIsDoubleTapOK = isDoubleTap
            mTapGesture.removeTarget(self, action: #selector(handleTap))
            mTapGesture.addTarget(self, action: #selector(handleTap(_:)))
            mTapGesture.numberOfTapsRequired = (isDoubleTap ? 2 : 1)
        }
        if !installed {
            self.view.addGestureRecognizer(mTapGesture)
        }
        
        //! You can suppress all network error message if you have faith in your Wifi.
        RemoteController.shared.IgnoreNetError = config.bool(forKey:KEY_DISABLE_ERR_MSG)
    }
}

