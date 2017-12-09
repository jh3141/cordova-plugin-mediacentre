var exec = require('cordova/exec');

exports.openPlayer = function (url, metadata, statusHandler, success, error)
{
    function ignore () {}
    function commandInvocation (commandName)
    {
        return function (success) {
            exec (success ? success : ignore, result.sendError, 'mediacentre', commandName, [result.id]);
        };
    }
    function propertyInvocation (propertyName)
    {
        return function (value, success) {
            if (result.readyForPropertyChanges)
                exec (success ? success : ignore, result.sendError, 'mediacentre', propertyName, [result.id, value]);
            else
                result.requestedPropertyChanges.push ({ name: propertyName, value: value, success: success });
        }
    }
    var result = {
        id: null,
        status: null,
        metadata: metadata,
        readyForPropertyChanges: false,
        isBuffering: false,
        bufferPercent: 0,
        playbackPosition: 0,

        requestedPropertyChanges: [],

        onerror: error,
        onbufferupdated: null,
        onstartbuffering: null,
        onendbuffering: null,
        onplaybackpositionchange: null,
        ondurationchange: null,

        setStatus: function (status) {
            if (status === "loaded" && !this.readyForPropertyChanges)
            {
                this.readyForPropertyChanges = true;
                this.sendProperties ();
            }
            this.status = status;
            statusHandler(status);
        },

        init: function (id) {
            this.id = id;
            this.setStatus ("loading");
            exec (unpackArrayArgs(this.setStatus), this.sendError, 'mediacentre', 'setHandler', [id, "playerStatus"]);
            exec (unpackArrayArgs(this.setBuffer), this.sendError, 'mediacentre', 'setHandler', [id, "buffer"]);
            exec (unpackArrayArgs(this.setBuffering), this.sendError, 'mediacentre', 'setHandler', [id, "buffering"]);
            exec (unpackArrayArgs(this.setPlaybackPosition), this.sendError, 'mediacentre', 'setHandler', [id, "playbackPosition"]);
            exec (unpackArrayArgs(this.setDuration), this.sendError, 'mediacentre', 'setHandler', [id, "duration"]);
            success (this);
        },

        setBuffer: function (bufferPercent) {
            this.bufferPercent = bufferPercent;
            if (this.onbufferupdated) this.onbufferupdated(this, bufferPercent);
        },

        setBuffering: function (buffering) {
            this.isBuffering = buffering;
            if (buffering && this.onstartbuffering) this.onstartbuffering (this);
            if (!buffering && this.onendbuffering) this.onendbuffering (this);
        },

        setPlaybackPosition: function (position) {
            this.playbackPosition = position;
            if (this.onplaybackpositionchange) this.onplaybackpositionchange (this, position);
        },

        setDuration: function (duration) {
            this.duration = duration;
            if (this.ondurationchange) this.ondurationchange (this, duration);
        },

        sendError: function (error) {
            if (this.onerror)
                this.onerror(error);
            else
                console.warn ('media player error: ' + error);
        },

        play: commandInvocation('play'),
        pause: commandInvocation('pause'),
        resume: commandInvocation('resume'),
        stop: commandInvocation('stop'),
        seek: propertyInvocation('seek'),
        setRate: propertyInvocation('setRate'),
        setPositionUpdateFrequency: propertyInvocation('setPositionUpdateFrequency'),
        seekRelative: function (amount, success) {
            this.seek (this.playbackPosition + amount, success);
        },
        sendProperties ()
        {
            // send any queued property changes that couldn't be sent until player
            // preparation was finished
            this.requestedPropertyChanges.forEach(function (change) {
                result[change.name] (change.value, change.success);
            });
            this.requestedPropertyChanges = null;
        },
        chainTo (player)
        {
            if (player)
                exec (ignore, this.sendError, 'mediacentre', 'setChainedPlayer', [id, player.id]);
            else
                exec (ignore, this.sendError, 'mediacentre', 'setChainedPlayer', [id, null]);
        },
        dispose: commandInvocation('dispose')
    };

    // bind callbacks to the result object
    result.init = result.init.bind(result);
    result.setStatus = result.setStatus.bind(result);
    result.setBuffer = result.setBuffer.bind(result);
    result.setBuffering = result.setBuffering.bind(result);
    result.setPlaybackPosition = result.setPlaybackPosition.bind(result);
    result.setDuration = result.setDuration.bind(result);
    result.sendError = result.sendError.bind(result);

    result.setStatus ("waiting-for-init");
    exec(result.init, result.sendError, 'mediacentre', 'openPlayer', [url, metadata]);
    return result;
};

function unpackArrayArgs (fn)
{
    return function (arg) {
        if (Array.isArray(arg))
            fn.apply (null, arg);
        else
            fn (arg);
    }
}
