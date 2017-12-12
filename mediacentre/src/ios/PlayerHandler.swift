import Foundation
import UIKit
import AVKit
import AVFoundation
import os.log

@objc
class DSFPlayerHandler : NSObject
{
    var handlerCommandIds = [String:String]();
    var handlerDelegate : CDVCommandDelegate!;
    @objc
    var player : AVPlayer;
    var rate : Float = 1.0 {
        didSet {
            if player.rate > 0 {
                player.rate = rate;
            }
        }
    };
    var prerolled = false;
    var playing = false;
    var timeObserver : Any?;
    var positionUpdateFrequency : Double = 0 {
        didSet {
            if positionUpdateFrequency > 0 {
                if let activeObserver = timeObserver { player.removeTimeObserver(activeObserver) }
                timeObserver = player.addPeriodicTimeObserver(forInterval: updateFrequencyAsCMTime, queue: nil) {
                    [weak self] currentTime in self?.handlePlayerCurrentTimeChanged(currentTime)
                }
            }
        }
    }
    let defaultTimescale : CMTimeScale = 1000;
    var updateFrequencyAsCMTime : CMTime {
        get {
            return CMTime(seconds: positionUpdateFrequency, preferredTimescale: defaultTimescale)
        }
    }
    
    init(forUrl: String, withMetadata: [String:String]) throws {
        os_log("DSFPlayerHandler.init forUrl: %@ (metadata contains %d entries)", forUrl, withMetadata.count);
        if let url = URL.init(string: forUrl) {
            player = AVPlayer(url: url)
            super.init()
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial,.new], context: nil)
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.new], context: nil)
            player.currentItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), options: [.new], context: nil)
            player.automaticallyWaitsToMinimizeStalling = false
        }
        else {
            throw NSError(domain: "DSFPlayerHandler", code: 100, userInfo: [
                "message": "Invalid URL format"
            ]);
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        os_log("KVO observing change on %@, status=%d, new=%d/%g/%g",
               (keyPath ?? "(nil)"),
               player.status.rawValue,
               (change?[.newKey] as? Int)             ?? -1,
               (change?[.newKey] as? Float)           ?? Float.nan,
               (change?[.newKey] as? CMTime)?.seconds ?? Double.nan);
        if keyPath == #keyPath(AVPlayer.status) {
            handlePlayerStatusChanged ()
        }
        else if keyPath == #keyPath(AVPlayer.rate) {
            if player.rate == 0 { handlePlaybackStopped() }
            else if !playing { handlePlaybackStarted() }
        }
        else if keyPath == #keyPath(AVPlayerItem.duration) {
            handleItemDurationChanged ()
        }
    }
    
    func handlePlayerStatusChanged ()
    {
        os_log ("player status changed: %d", player.status.rawValue);
        if player.status == AVPlayerStatus.readyToPlay
        {
            if !prerolled
            {
                player.preroll(atRate: rate)
                prerolled = true
            }
            if positionUpdateFrequency == 0 { positionUpdateFrequency = 0.125; }
            sendValue(["loaded"], toCallback: "playerStatus")
        }
    }
    func handlePlaybackStopped ()
    {
        sendValue(["paused"], toCallback: "playerStatus")
        playing = false;
    }
    func handlePlaybackStarted ()
    {
        sendValue(["playing"], toCallback: "playerStatus")
        playing = true;
    }
    
    func handlePlayerCurrentTimeChanged (_ timestamp : CMTime)
    {
        sendValue([timestamp.seconds], toCallback: "playbackPosition")
    }
    func handleItemDurationChanged ()
    {
        sendValue([player.currentItem!.duration.seconds], toCallback: "duration")
    }
    
    func setHandler (_ handler: String, usingDelegate: CDVCommandDelegate, callbackId: String)
    {
        handlerDelegate = usingDelegate;
        handlerCommandIds[handler] = callbackId;
    }
    
    func sendValue (_ value: [Any], toCallback: String)
    {
        if let commandId = handlerCommandIds[toCallback] {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: value)!
            result.setKeepCallbackAs(true);
            handlerDelegate.send(result, callbackId: commandId)
        }
    }
    
    func play ()
    {
        player.playImmediately(atRate: rate)
    }
    
    func pause ()
    {
        player.pause()
    }
    
    func resume ()
    {
        player.playImmediately(atRate: rate)
    }
    
    func stop ()
    {
        player.pause(); // doesn't seem to be any way to actually stop it!
    }
    
    func seek (_ target: Double)
    {
        player.seek(to: CMTime(seconds: target, preferredTimescale: defaultTimescale))
    }
    
}
