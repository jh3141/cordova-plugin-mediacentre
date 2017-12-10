import Foundation
import UIKit
import AVFoundation

@objc(DSFMediaCentre)
class DSFMediaCentre : CDVPlugin
{
    var players = [UUID: DSFPlayerHandler] ();

    @objc(openPlayer:)
    func openPlayer (CDVInvokedUrlCommand command)
    {
        let url = command.arguments[0] as String;
        let metadata = [String: String] ();
        let id = UUID();
        players[id] = DSFPlayerHandler(forUrl: url, withMetadata: metadata);
        self.commandDelegate!.send (
            CDVPluginResult(status: CDVCommandStatus_OK, messageAs: id.uuidString),
            callbackId: command.callbackId);
    }
}
