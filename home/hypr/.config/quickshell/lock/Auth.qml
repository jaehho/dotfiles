// The lock screen's two PAM checks (shell.qml says why there are two):
// the PIN, typed into `buffer` and checked on Enter, and face unlock
// beside it. `secure` (the compositor holds the lock) starts the first
// look; `released` says the screen can unlock, once its content has
// faded.
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: auth

    property bool secure: false
    // What has been typed.
    property string buffer: ""
    // idle | checking | wrong | unlocking
    property string phase: "idle"
    // What PAM said of a failed PIN (faillock's lockout), else "".
    property string note: ""
    // looking | matched | off
    property string face: "off"

    // The PIN's PAM service, and face unlock's, with their directories
    // ("" is /etc/pam.d).
    property string pinConfig: "hyprlock"
    property string pinDirectory: ""
    property string faceConfig: "face"
    property string faceDirectory: Quickshell.shellPath("pam")

    signal wrongPin
    signal released

    function type(text) {
        if (auth.phase === "checking" || auth.phase === "unlocking")
            return;
        if (auth.phase === "wrong") {
            auth.phase = "idle";
            auth.note = "";
        }
        auth.buffer += text;
    }

    function erase(all) {
        if (auth.phase === "checking" || auth.phase === "unlocking")
            return;
        auth.buffer = all ? "" : auth.buffer.slice(0, -1);
    }

    function submit() {
        if (auth.phase === "checking" || auth.phase === "unlocking" || auth.buffer === "")
            return;
        auth.phase = "checking";
        auth.note = "";
        pinCheck.start();
    }

    // Face unlock looks again, unless it is looking or has matched.
    function lookAgain() {
        if (auth.secure && !faceCheck.active && auth.face !== "matched" && auth.phase !== "unlocking")
            faceCheck.start();
    }

    function unlock() {
        if (auth.phase === "unlocking")
            return;
        auth.phase = "unlocking";
        auth.buffer = "";
        if (faceCheck.active)
            faceCheck.abort();
        if (pinCheck.active)
            pinCheck.abort();
        release.start();
    }

    onSecureChanged: auth.lookAgain()

    PamContext {
        id: pinCheck

        config: auth.pinConfig
        configDirectory: auth.pinDirectory !== "" ? auth.pinDirectory : "/etc/pam.d"

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(auth.buffer);
            auth.buffer = "";
        }

        onMessageChanged: {
            if (messageIsError || message.startsWith("The account is locked"))
                auth.note = message;
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                auth.unlock();
                return;
            }
            auth.buffer = "";
            auth.phase = "wrong";
            if (result === PamResult.MaxTries && auth.note === "")
                auth.note = "Too many tries. Wait, then try again.";
            auth.wrongPin();
        }

        onError: error => {
            console.warn("lock: the PIN check failed to run:", error);
            auth.buffer = "";
            auth.phase = "wrong";
            auth.note = "The PIN check didn't run. Try again.";
            auth.wrongPin();
        }
    }

    PamContext {
        id: faceCheck

        config: auth.faceConfig
        configDirectory: auth.faceDirectory

        onActiveChanged: {
            if (active)
                auth.face = "looking";
            else if (auth.face === "looking")
                auth.face = "off";
        }

        // Howdy asks nothing; anything that does is not ours to answer.
        onResponseRequiredChanged: if (responseRequired)
            abort()

        onCompleted: result => {
            if (result === PamResult.Success) {
                auth.face = "matched";
                auth.unlock();
            } else {
                auth.face = "off";
            }
        }

        onError: error => {
            console.warn("lock: face unlock failed to run:", error);
            auth.face = "off";
        }
    }

    // Long enough for the content to fade (Theme.motion.fast).
    Timer {
        id: release
        interval: Theme.motion.fast + 50
        onTriggered: auth.released()
    }
}
