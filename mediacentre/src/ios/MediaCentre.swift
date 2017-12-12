import Foundation
import UIKit
import AVFoundation
import os.log

@objc(DSFMediaCentre)
class DSFMediaCentre : CDVPlugin
{
    var players : [UUID: DSFPlayerHandler]!;
    
    override func pluginInitialize() {
        players = [:];
    }
    
    @objc(openPlayer:)
    func openPlayer (command: CDVInvokedUrlCommand)
    {
        let url = command.arguments[0] as! String;
        let metadata = [String: String] ();
        let id = UUID();
        do
        {
            let player = try DSFPlayerHandler(forUrl: url, withMetadata: metadata);
            os_log("openPlayer - registering new player %@ (%d players registered on entry)", id.uuidString, players.count);
            players[id] = player;
            self.commandDelegate!.send (
                CDVPluginResult(status: CDVCommandStatus_OK, messageAs: id.uuidString),
                callbackId: command.callbackId);
        }
        catch let error as NSError
        {
            self.commandDelegate!.send(
                CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.userInfo["message"] as! String),
                callbackId: command.callbackId);
        }
    }
    
    @objc(setHandler:)
    func setHandler(command: CDVInvokedUrlCommand)
    {
        let id = UUID(uuidString: command.arguments[0] as! String)!;
        let player = players[id]!;
        player.setHandler (command.arguments[1] as! String,
                           usingDelegate: self.commandDelegate!,
                           callbackId: command.callbackId);
        let result = CDVPluginResult(status: CDVCommandStatus_NO_RESULT)!;
        result.setKeepCallbackAs(true);
        self.commandDelegate!.send(result, callbackId: command.callbackId);
    }
    
    func invokeOnPlayer (usingIdFrom command: CDVInvokedUrlCommand, operation : (DSFPlayerHandler) -> Void)
    {
        // FIXME handle argument errors
        let id = UUID(uuidString: command.arguments[0] as! String)!;
        let player = players[id]!;
        operation (player);
        sendOK (to: command);
    }
    func invokeOnPlayer (usingIdFrom command: CDVInvokedUrlCommand, doubleOperation : (DSFPlayerHandler, Double) -> Void)
    {
        os_log("double operation invoked, %@", command);
        // FIXME handle argument errors
        let id = UUID(uuidString: command.arguments[0] as! String)!;
        let player = players[id]!;
        let arg = command.arguments[1] as! Double;
        doubleOperation (player, arg);
        sendOK (to: command);
    }

    @objc(play:)
    func play(command: CDVInvokedUrlCommand)
    {
        invokeOnPlayer (usingIdFrom: command) {
            player in player.play()
        }
    }
    
    @objc(pause:)
    func pause(command: CDVInvokedUrlCommand)
    {
        invokeOnPlayer (usingIdFrom: command) {
            player in player.pause()
        }
    }

    @objc(resume:)
    func resume(command: CDVInvokedUrlCommand)
    {
        invokeOnPlayer (usingIdFrom: command) {
            player in player.resume()
        }
    }

    @objc(stop:)
    func stop(command: CDVInvokedUrlCommand)
    {
        invokeOnPlayer (usingIdFrom: command) {
            player in player.stop()
        }
    }
    
    @objc(seek:)
    func seek(command : CDVInvokedUrlCommand)
    {
        os_log("seek invoked")
        invokeOnPlayer(usingIdFrom: command) {
            player, target in player.seek(target)
        }
    }
    
    @objc(setRate:)
    func setRate(command : CDVInvokedUrlCommand)
    {
        invokeOnPlayer(usingIdFrom: command) {
            player, target in player.rate = Float(target)
        }
    }

    @objc(setPositionUpdateFrequency:)
    func setPositionUpdateFrequency(command : CDVInvokedUrlCommand)
    {
        invokeOnPlayer(usingIdFrom: command) {
            player, target in player.positionUpdateFrequency = target
        }
    }

    func sendOK (to command: CDVInvokedUrlCommand)
    {
        self.commandDelegate!.send (
            CDVPluginResult(status: CDVCommandStatus_OK),
            callbackId: command.callbackId);
    }
}
