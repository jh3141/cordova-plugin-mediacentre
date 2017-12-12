document.addEventListener('deviceready', function () {
    var index = 0;
    var tracks = 15;
    function makePlayer () {
        ++index;
        if (index > tracks) index = 1;
        document.getElementById ("track").selectedIndex = (index - 1);
        var player = cordova.plugins.mediacentre.openPlayer (
                'https://archive.org/download/tsp1997-01-08.flac16/tsp1997-01-08d1t' + (index < 10 ? '0' : '') + index + '.mp3',
                {},
                onstatuschange, onsuccess, onerror);

        player.onbufferupdated = onbufferupdated;
        player.onstartbuffering = onstartbuffering;
        player.onendbuffering = onendbuffering;
        player.onplaybackpositionchange = onplaybackpositionchange;
        player.ondurationchange = ondurationchange;
        return player;
    }
    var player = makePlayer ();
    var duration = 1;
    var loadingTimestamp = null;

    document.getElementById('play').onclick = play;
    document.getElementById('pause').onclick = pause;
    document.getElementById('resume').onclick = resume;
    document.getElementById('stop').onclick = stop;
    document.getElementById('seek').onclick = seek;
    document.getElementById('setRate').onclick = changeRate;
    document.getElementById('track').onchange = changeTrack;
    function onstatuschange (status) {
        document.getElementById('status').innerHTML = status;
        if (status == 'stopped') {
            player.dispose ();
            player = makePlayer ();
        }
        if (status == 'loaded' && document.getElementById('autoplay').checked) {
            player.play ();
        }
        if (status == 'loading') {
            loadingTimestamp = new Date().getTime();
        }
        if (status == 'playing' && loadingTimestamp !== null)
        {
            document.getElementById('status').innerHTML = "playback started after " + (new Date().getTime() - loadingTimestamp) + "ms";
            loadingTimestamp = null;
        }
    }
    function onbufferupdated (player, percent) { document.getElementById('buffer').innerHTML = "" + percent; }
    function onstartbuffering (player) { document.getElementById('buffering').innerHTML = "BUFFERING"; }
    function onendbuffering (player) { document.getElementById('buffering').innerHTML = "ok"; }
    function onplaybackpositionchange (player, pos) {
        document.getElementById('position').innerHTML = "" + pos;
        document.getElementById('positionpercent').innerHTML = "" + ((pos/duration)*100);
    }
    function ondurationchange (player, dur) {
        duration = dur;
        document.getElementById('duration').innerHTML = "" + dur;
    }
    function onerror (message) {
        document.getElementById('error').innerHTML = "Error: " + message;
    }
    function onsuccess (message) {
        document.getElementById('error').innerHTML = "OK: " + message;
    }

    function play () {
        console.log ('starting to play with player: ', player);
        player.play ();
    }
    function pause () { player.pause (); }
    function resume () { player.resume (); }
    function stop () { player.stop (); }
    function seek () { player.seek (document.getElementById('seekTo').value/1); }
    function changeRate () { player.setRate (document.getElementById('rate').value/1); }
    function changeTrack () {
        var newTrack = document.getElementById('track').selectedIndex;
        if (newTrack == index - 1) return;
        player.stop ();
        player.dispose ();
        index = newTrack - 1;
        player = makePlayer ();
    }
}, false);
