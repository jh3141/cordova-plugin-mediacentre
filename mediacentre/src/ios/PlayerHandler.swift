import Foundation
import UIKit
import AVKit
import AVFoundation
import os.log

class DSFPlayerHandler
{
    var handlerCommandIds = [String:String]();
    var handlerDelegate : CDVCommandDelegate!;
    var player : AVPlayer;
    var rate : Float = 1.0;
    
    init(forUrl: String, withMetadata: [String:String]) throws {
        os_log("DSFPlayerHandler.init forUrl: %@ (metadata contains %d entries)", forUrl, withMetadata.count);
        if let url = URL.init(string: forUrl) {
            player = AVPlayer(url: url);
            player.automaticallyWaitsToMinimizeStalling = false;
        }
        else {
            throw NSError(domain: "DSFPlayerHandler", code: 100, userInfo: [
                "message": "Invalid URL format"
                ]);
        }
    }
    
    func setHandler (_ handler: String, usingDelegate: CDVCommandDelegate, callbackId: String)
    {
        handlerDelegate = usingDelegate;
        handlerCommandIds[handler] = callbackId;
        sendValue (["set handler \(handler)"], toCallback: "playerStatus");
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
    
    func setRate (_ rate: Float)
    {
        self.rate = rate;
        if player.rate > 0 {
            player.rate = rate;
        }
    }
}
