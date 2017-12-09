package uk.org.dsf.cordova.media;

import java.util.Map;
import java.util.HashMap;
import java.util.UUID;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * This class echoes a string called from JavaScript.
 */
public class MediaCentre extends CordovaPlugin {
    private Map<UUID, PlayerManager> players = new HashMap<UUID, PlayerManager> ();

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        try {
            if (action.equals("openPlayer")) {
                UUID id = UUID.randomUUID();
                PlayerManager player = new PlayerManager (args.getString(0), args.getJSONObject(1));
                player.setHandler ("error", callbackContext);
                players.put (id, player);
                // perform magic invocation to ensure callbackContext doesn't disappear
                PluginResult result = new PluginResult(PluginResult.Status.OK, id.toString());
                result.setKeepCallback(true);
                callbackContext.sendPluginResult(result);
            }
            else {
                UUID id = UUID.fromString(args.getString(0));
                PlayerManager manager = players.get(id);
                if (manager == null) {
                    callbackContext.error ("Unrecognized player ID " + id);
                }
                else if (action.equals ("setHandler")) {
                    // perform magic invocation to ensure callbackContext doesn't disappear
                    PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
                    result.setKeepCallback(true);
                    callbackContext.sendPluginResult(result);
                    // and pass control over to the PlayerManager
                    manager.setHandler (args.getString(1), callbackContext);
                }
                else if (action.equals ("dispose")) {
                    manager.dispose ();
                    players.remove (id);
                }
                else {
                    if (!manager.execute (action, args, callbackContext, players))
                        callbackContext.error ("Unknown action: " + action);
                }
            }
        }
        catch (Exception e) {
            // if the exception has a reasonably long message, just send the message, otherwise send the full exception
            // detail as a string
            callbackContext.error (e.getMessage() != null && e.getMessage().length() > 3 ? e.getMessage() : e.toString ());
        }
        return true;
    }
}
