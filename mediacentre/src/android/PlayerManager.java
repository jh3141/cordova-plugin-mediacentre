/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
*/
package uk.org.dsf.cordova.media;

import android.annotation.TargetApi;
import android.media.AudioManager;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnBufferingUpdateListener;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.media.MediaPlayer.OnInfoListener;
import android.media.MediaPlayer.OnSeekCompleteListener;
import android.media.MediaRecorder;
import android.os.Environment;
import android.os.Build;

import org.apache.cordova.LOG;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;

import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * This class implements playback management from a single source URL.  It is based
 * on (but substantially modified from) the AudioPlayer class in cordova-plugin-media.
 * <p>
 * Major changes include:
 * <ul><li>Removed all recording-related code</li>
 *     <li>Remove local file playback - this class is only used for streaming media</li>
 *     <li>Simplified behaviour by automatically preparing the media player during construction</li>
 *     <li>Removed mechanism for deferring seeks until preparation completes: client has the responsibility
 *         of tracking state and applying property changes when they are permitted</li>
 *     <li>Updated to use new features as of Android 5.0 API (where available)</li></ul>
 */
public class PlayerManager implements OnBufferingUpdateListener, OnCompletionListener, OnPreparedListener, OnErrorListener, OnInfoListener, OnSeekCompleteListener {

    private static final String LOG_TAG = "PlayerManager";
    private HashMap<String,CallbackContext> handlers = new HashMap<String,CallbackContext> ();
    private MediaPlayer player = null;      // Audio player object
    private Thread positionUpdateThread;
    private volatile int positionUpdateFrequency = 125;
    private volatile boolean isStarting, isPausing, isStopping, isPaused;
    private volatile long lastPositionUpdateTime;

    /**
     * Constructor.
     */
    public PlayerManager(String url, JSONObject metadata) throws JSONException, IOException
    {
        player = new MediaPlayer();
        player.setOnErrorListener(this);
        player.setDataSource(url);
        player.setOnBufferingUpdateListener(this);
        player.setOnPreparedListener(this);
        player.setOnCompletionListener(this);
        player.setOnInfoListener(this);
        player.setOnSeekCompleteListener (this);
        if (Build.VERSION.SDK_INT >= 21 /* Android 5.0 */)
            player.setAudioAttributes(calculateAttributes (metadata));
        player.prepareAsync();
    }

    @TargetApi(21)
    public AudioAttributes calculateAttributes (JSONObject metadata) throws JSONException
    {
        AudioAttributes.Builder attributeBuilder = new AudioAttributes.Builder ();
        String streamType = metadata.optString ("streamType", "music");
        if (streamType.equals ("music"))
            attributeBuilder.setContentType (AudioAttributes.CONTENT_TYPE_MUSIC);
        else if (streamType.equals ("speech"))
            attributeBuilder.setContentType (AudioAttributes.CONTENT_TYPE_SPEECH);
        else if (streamType.equals ("sound"))
            attributeBuilder.setContentType (AudioAttributes.CONTENT_TYPE_SONIFICATION);
        String usage = metadata.optString ("usage", "media");
        if (usage.equals ("media"))
            attributeBuilder.setUsage(AudioAttributes.USAGE_MEDIA);
        else if (usage.equals ("game"))
            attributeBuilder.setUsage(AudioAttributes.USAGE_GAME);
        else if (usage.equals ("notification"))
            attributeBuilder.setUsage(AudioAttributes.USAGE_NOTIFICATION);
        else if (usage.equals ("alarm"))
            attributeBuilder.setUsage(AudioAttributes.USAGE_ALARM);
        //else if (usage.equals ("assistance"))
        //    attributeBuilder.setUsage(AudioAttributes.USAGE_ASSISTANT);
        return attributeBuilder.build ();
    }

    /**
     * Specifies a callback context for a given type of notification
     */
    public void setHandler (String notificationType, CallbackContext context)
    {
        CallbackContext old = handlers.get (context);
        if (old != null) finalizeCallbackContext(old);
        handlers.put(notificationType, context);
    }

    /**
     * Destroy player and stop audio playing or recording.
     */
    public void dispose () {
        // Stop any play or record
        if (player != null) {
            if (player.isPlaying()) {
                player.stop ();
            }
            player.release();
            player = null;
        }
        if (this.positionUpdateThread != null) positionUpdateThread.interrupt (); // force update now
        for (CallbackContext handler : handlers.values())
            finalizeCallbackContext (handler);
        handlers.clear ();
    }

    /** Terminate connection to a callback context */
    private void finalizeCallbackContext (CallbackContext context)
    {
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        context.sendPluginResult (result);
    }

    /**
     * Called to execute commands
     * @param action the command to execute
     * @param args   command arguments (starting with argument index 1)
     * @param callbackContext context for sending response
     * @param players  map of IDs to other player objects (for actions that reference other players)
     * @return true if the command was recognised, false otherwise.
     */
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext, Map<UUID,PlayerManager> players) throws JSONException {
        /*
        actions that need to be handled are:

        play: commandInvocation('play'),
        pause: commandInvocation('pause'),
        resume: commandInvocation('resume'),
        stop: commandInvocation('stop'),
        seek: propertyInvocation('seek'),
        setRate: propertyInvocation('setRate'),
        setPositionUpdateFrequency: propertyInvocation('setPositionUpdateFrequency'),
        exec (ignore, this.sendError, 'mediacentre', 'setChainedPlayer', [id, player.id]);
        */

        if (action.equals ("play")) {
            sendNotification ("playerStatus", "starting");
            player.start ();
            prepareUpdateThread ();
        }
        else if (action.equals ("pause")) {
            player.pause ();
            isPausing = true;
        }
        else if (action.equals ("resume")) {
            player.start ();
            isStarting = true;
        }
        else if (action.equals ("stop")) {
            player.stop ();
            isStopping = true;
        }
        else if (action.equals ("seek")) {
            player.seekTo ((int) (args.getDouble(1) * 1000));
        }
        else if (action.equals ("setRate")) {
            if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M) {
                LOG.d(LOG_TAG, "AudioPlayer Warning: Request to set playback rate not supported on current OS version");
                return false;
            }
            player.setPlaybackParams (this.player.getPlaybackParams().setSpeed((float)args.getDouble(1)));
        }
        else if (action.equals ("setPositionUpdateFrequency")) {
            this.positionUpdateFrequency = (int)(args.getDouble(1) * 1000);
            if (this.positionUpdateThread != null) positionUpdateThread.interrupt ();
        }
        else if (action.equals ("setChainedPlayer")) {
            if (args.isNull(1))
                player.setNextMediaPlayer (null);
            else
            {
                UUID id = UUID.fromString(args.getString(1));
                player.setNextMediaPlayer (players.get(id).prepareForChaining ());
            }
        }
        else
            return false;
        callbackContext.success();
        return true;
    }

    public MediaPlayer prepareForChaining ()
    {
        if (player == null || player.isPlaying()) return null;
        prepareUpdateThread ();
        return player;
    }

    private void prepareUpdateThread ()
    {
        isStarting = true;
        lastPositionUpdateTime = System.currentTimeMillis();
        if (positionUpdateThread == null || !positionUpdateThread.isAlive()) {
            positionUpdateThread = new Thread (positionUpdater);
            positionUpdateThread.start ();
        }
    }

    /** Callback to be called when buffering status has changed */
    public void onBufferingUpdate (MediaPlayer player, int percent)
    {
        sendNotification ("buffer", (Integer)percent);
    }

    /**
     * Callback to be invoked when playback of a media source has completed.
     *
     * @param player           The MediaPlayer that reached the end of the file
     */
    public void onCompletion(MediaPlayer player) {
        sendNotification ("playerStatus", "stopped");
        if (this.positionUpdateThread != null) positionUpdateThread.interrupt (); // force check for stopped state now
    }

    /** Callback to be called when miscellaneous changes occur */
    public boolean onInfo (MediaPlayer player, int what, int extra)
    {
        switch (what)
        {
            case MediaPlayer.MEDIA_INFO_BUFFERING_START:
                sendNotification ("buffering", Boolean.TRUE);
                return true;
            case MediaPlayer.MEDIA_INFO_BUFFERING_END:
                sendNotification ("buffering", Boolean.FALSE);
                return true;
        }
        return false;
    }

    /**
     * Callback to be invoked when the media source is ready for playback.
     *
     * @param player           The MediaPlayer that is ready for playback
     */
    public void onPrepared(MediaPlayer player) {
        // Send status notification to JavaScript
        sendNotification("duration", (Double)getDurationInSeconds());
        sendNotification("playerStatus", "loaded");
    }

    /**
     * By default Android returns the length of audio in mills but we want seconds
     *
     * @return length of clip in seconds (using double rather than float, as Double
     * can be stored in a JSONArray but Float can't).
     */
    private double getDurationInSeconds() {
        return (this.player.getDuration() / 1000.0);
    }

    /**
     * Callback to be invoked when there has been an error during an asynchronous operation
     *  (other errors will throw exceptions at method call time).
     *
     * @param player           the MediaPlayer the error pertains to
     * @param arg1              the type of error that has occurred: (MEDIA_ERROR_UNKNOWN, MEDIA_ERROR_SERVER_DIED)
     * @param arg2              an extra code, specific to the error.
     */
    public boolean onError(MediaPlayer player, int arg1, int arg2) {
        LOG.d(LOG_TAG, "PlayerManager.onError(" + arg1 + ", " + arg2 + ")");

        sendErrorStatus("MediaPlayer error " + arg1 + ":" + arg2);
        this.dispose();

        return false;
    }

    /**
     * Callback invoked when seek operations finish, thus we immediately need to
     * update the current playback position
     */
    public void onSeekComplete (MediaPlayer player) {
        sendPositionUpdateNow ();
    }

    private void sendErrorStatus(String message) {
        sendNotificationWithStatus ("error", PluginResult.Status.ERROR, message);
    }

    private void sendNotification (String handler, Object... parameters)
    {
        sendNotificationWithStatus (handler, PluginResult.Status.OK, parameters);
    }

    private void sendNotificationWithStatus (String handler, PluginResult.Status status, Object... parameters)
    {
        CallbackContext callbackContext = handlers.get(handler);
        if (callbackContext == null) return;
        PluginResult result = new PluginResult (status, new JSONArray(Arrays.asList(parameters)));
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);
    }

    public void sendPositionUpdateNow ()
    {
        lastPositionUpdateTime = System.currentTimeMillis ();
        sendNotification ("playbackPosition", player.getTimestamp().getAnchorMediaTimeUs() / 1000000.0);
    }

    private Runnable positionUpdater = new Runnable () {
        public void run () {
            while (player != null)
            {
                long iterationTimestamp = System.currentTimeMillis ();
                try {
                    boolean playing = player.isPlaying ();
                    if ((isStarting || isPaused) && playing) {
                        sendNotification ("playerStatus", "playing");
                        isStarting = false;
                        isPaused = false;
                    } else if (isStopping && ! playing) {
                        sendNotification ("playerStatus", "stopped");
                        isPaused = false;
                    } else if (isPausing && ! playing) {
                        sendNotification ("playerStatus", "paused");
                        isPaused = true;
                    }

                    if (!playing && !(isStarting || isPaused)) break;
                } catch (IllegalStateException e) {
                    // can happen either before playback preparation is started or after
                    // resources are released.
                    if (! isStarting) {
                        sendNotification ("playerStatus", "stopped");
                        return;
                    }
                }

                if (iterationTimestamp > lastPositionUpdateTime + positionUpdateFrequency)
                {
                    sendPositionUpdateNow ();
                }

                try
                {
                    long delayTime = lastPositionUpdateTime + positionUpdateFrequency - iterationTimestamp;
                    if (delayTime < 0) delayTime = 1;
                    Thread.sleep (delayTime);
                }
                catch (InterruptedException e) { }
            }
        }
    };
}
