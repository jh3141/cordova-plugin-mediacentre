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
    
    @objc(play:)
    func play(command: CDVInvokedUrlCommand)
    {
        let id = UUID(uuidString: command.arguments[0] as! String)!;
        let player = players[id]!;
        player.play();
        sendOK (to: command);
    }

    @objc(pause:)
    func pause(command: CDVInvokedUrlCommand)
    {
        let id = UUID(uuidString: command.arguments[0] as! String)!;
        let player = players[id]!;
        player.play();
        sendOK (to: command);
    }

    
    func sendOK (to command: CDVInvokedUrlCommand)
    {
        self.commandDelegate!.send (
            CDVPluginResult(status: CDVCommandStatus_OK),
            callbackId: command.callbackId);
    }
}
