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
    var stopping = false;
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
    var atEndOfItem : Bool {
        get
        {
            if let item = player.currentItem
            {
                return item.forwardPlaybackEndTime.seconds < player.currentTime().seconds + 1
            }
            else
            {
                return false;
            }
        }
    }
    let defaultTimescale : CMTimeScale = 1000;
    var updateFrequencyAsCMTime : CMTime {
        get {
            return CMTime(seconds: positionUpdateFrequency, preferredTimescale: defaultTimescale)
        }
    }
    var pausing = false;
    var lastPlayerStatus = ""
    let EAGER_READAHEAD = TimeInterval(300)
    let LIMITED_READAHEAD = TimeInterval(100)
    let DEFAULT_THROUGHPUT : Double = 900000
    init(forUrl urlstr: String, withMetadata metadata: [String:Any]) throws {
        os_log("DSFPlayerHandler.init forUrl: %@ (metadata contains %d entries)", urlstr, metadata.count);
        if let url = URL.init(string: urlstr) {
            player = AVPlayer(url: url)
            super.init()
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial,.new], context: nil)
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.new], context: nil)
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: nil)
            player.currentItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), options: [.new], context: nil)
            player.currentItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), options: [.new], context: nil)
            player.automaticallyWaitsToMinimizeStalling = (metadata["minimizeStalling"] as? Bool) ?? false
            let eagerStreaming = (metadata["eagerStreaming"] as? Bool) ?? true
            player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = eagerStreaming
            let defaultBufferMax = eagerStreaming ? EAGER_READAHEAD : LIMITED_READAHEAD
            player.currentItem?.preferredForwardBufferDuration = (metadata["maxBufferReadahead"] as? Double) ?? defaultBufferMax
            player.currentItem?.preferredPeakBitRate = (metadata["maxNetworkThroughput"] as? Double) ?? DEFAULT_THROUGHPUT
        }
        else {
            throw NSError(domain: "DSFPlayerHandler", code: 100, userInfo: [
                "message": "Invalid URL format"
            ]);
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        os_log("KVO observing change on %@, status=%d, new=%d/%g/%g",
               (keyPath ?? "(nil)"),
               player.status.rawValue,
               (change?[.newKey] as? Int)             ?? -1,
               (change?[.newKey] as? Float)           ?? Float.nan,
               (change?[.newKey] as? CMTime)?.seconds ?? Double.nan);
        if keyPath == #keyPath(AVPlayer.status)
        {
            handlePlayerStatusChanged ()
        }
        else if keyPath == #keyPath(AVPlayer.rate)
        {
            if player.rate == 0 { handlePlaybackStopped() }
            else if !playing { handlePlaybackStarted() }
        }
        else if keyPath == #keyPath(AVPlayer.timeControlStatus)
        {
            handleBufferingStatusChanged ()
        }
        else if keyPath == #keyPath(AVPlayerItem.duration)
        {
            handleItemDurationChanged ()
        }
        else if keyPath == #keyPath(AVPlayerItem.loadedTimeRanges)
        {
            handleBufferedRangeChanged ()
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
        sendValue([stopping || atEndOfItem ? "stopped" : "paused"], toCallback: "playerStatus")
        pausing = false;
        stopping = false;
        playing = false;
    }
    func handlePlaybackStarted ()
    {
        sendValue(["playing"], toCallback: "playerStatus")
        playing = true;
    }
    
    func handlePlayerCurrentTimeChanged (_ timestamp : CMTime)
    {
        if lastPlayerStatus != "playing", player.rate > 0 { sendValue(["playing"], toCallback: "playerStatus") }
        sendValue([timestamp.seconds], toCallback: "playbackPosition")
    }
    func handleItemDurationChanged ()
    {
        sendValue([player.currentItem!.duration.seconds], toCallback: "duration")
    }
    func handleBufferingStatusChanged ()
    {
        playing = player.timeControlStatus == .playing
        sendValue([player.timeControlStatus == .waitingToPlayAtSpecifiedRate], toCallback: "buffering")
    }
    func timeToPercent (_ timestamp:CMTime) -> Double
    {
        return (100 * timestamp.seconds) / player.currentItem!.duration.seconds
    }
    func handleBufferedRangeChanged ()
    {
        let item = player.currentItem!
        let currentRange = item.loadedTimeRanges.filter {
            val in val.timeRangeValue.containsTime(player.currentTime())
        }.first
        sendValue([(currentRange?.timeRangeValue.end).map(timeToPercent) ?? 0], toCallback: "buffer")
    }
    func setHandler (_ handler: String, usingDelegate: CDVCommandDelegate, callbackId: String)
    {
        handlerDelegate = usingDelegate;
        handlerCommandIds[handler] = callbackId;
    }
    
    func sendValue (_ value: [Any], toCallback: String)
    {
        if toCallback == "playerStatus", let val = value[0] as? String
        {
            lastPlayerStatus = val
        }
        
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
        pausing = true;
        player.pause()
    }
    
    func resume ()
    {
        player.playImmediately(atRate: rate)
    }
    
    func stop ()
    {
        pausing = false;
        stopping = true;
        player.pause(); // doesn't seem to be any way to actually stop it!
    }
    
    func seek (_ target: Double)
    {
        player.seek(to: CMTime(seconds: target, preferredTimescale: defaultTimescale))
    }

    func dispose ()
    {
        player.cancelPendingPrerolls()
        if player.rate > 0 { player.pause() }
        player.currentItem?.asset.cancelLoading()
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus))
        player.currentItem!.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration))
        player.currentItem!.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
        timeObserver.map(player.removeTimeObserver)
        handlerDelegate = nil
        handlerCommandIds.removeAll()
    }
}
