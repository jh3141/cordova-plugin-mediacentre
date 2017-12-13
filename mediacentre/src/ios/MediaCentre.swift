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
        os_log("openPlayer - registering new player %@ (%d players registered on entry)", id.uuidString, players.count);
        DispatchQueue.global(qos: .userInitiated).async {
            do
            {
                let player = try DSFPlayerHandler(forUrl: url, withMetadata: metadata)
                DispatchQueue.main.async {
                    self.players[id] = player
                    self.commandDelegate!.send (
                        CDVPluginResult(status: CDVCommandStatus_OK, messageAs: id.uuidString),
                        callbackId: command.callbackId)
                }
            }
            catch let error as NSError
            {
                self.sendError(error.userInfo["message"] as! String, to: command)
            }
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

    func invokeWithId (usingIdFrom command: CDVInvokedUrlCommand, operation: (UUID) -> Void)
    {
        if command.arguments.count < 1 { sendError ("missing argument", to: command); return; }
        if command.arguments[0] is NSNull { sendError ("argument 0 must not be null", to: command); return; }
        if let id = (command.arguments[0] as? String).flatMap({ s in UUID(uuidString: s) })
        {
            operation (id)
        }
        else
        {
            sendError("argument 0 must be a valid UUID string", to: command);
        }
    }
    
    func invokeOnPlayer (usingIdFrom command: CDVInvokedUrlCommand, operation : (DSFPlayerHandler) -> Void)
    {
        invokeWithId (usingIdFrom: command) {
            id in
            if let player = players[id]
            {
                operation (player)
                sendOK (to: command)
            }
            else
            {
                sendError("no player found for specified UUID", to: command);
            }
        }
    }
    
    func invokeOnPlayer (usingIdFrom command: CDVInvokedUrlCommand, doubleOperation : (DSFPlayerHandler, Double) -> Void)
    {
        invokeOnPlayer(usingIdFrom: command, operation: {
            player in
            if let arg = command.arguments[1] as? Double
            {
                doubleOperation (player, arg)
            }
            else
            {
                sendError ("argument 1 should have been a double", to: command);
                // fixme: prevent this attempting to send an OK message too
            }
        })
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

    @objc(dispose:)
    func dispose (command: CDVInvokedUrlCommand)
    {
        invokeWithId(usingIdFrom: command) {
            id in players.removeValue(forKey: id)?.dispose()
        }
    }
    
    func sendOK (to command: CDVInvokedUrlCommand)
    {
        self.commandDelegate!.send (
            CDVPluginResult(status: CDVCommandStatus_OK),
            callbackId: command.callbackId);
    }

    func sendError (_ message:String, to command: CDVInvokedUrlCommand)
    {
        os_log("Sending error to caller: %s", message)
        self.commandDelegate!.send(
            CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message),
            callbackId: command.callbackId)
    }
}
