// Turns one polkit request's PAM conversation into what the sheet shows:
// a phase, a status line and its tone. Howdy (pam_howdy, first in
// /etc/pam.d/polkit-1) speaks first; pam_unix asks for the password only
// after Howdy gives up.
//
// It holds its own reference to the AuthFlow. The agent clears its `flow`
// as soon as a request completes, before the flow emits
// authenticationSucceeded, so a binding to agent.flow would miss the
// approval. The flow is deleteLater'd, so this reference stays valid for
// the signals that follow.
import QtQuick

QtObject {
    id: ctl

    property QtObject flow: null

    property string message
    property string actionId
    property string userName
    // starting | scanning | password | checking | approved
    property string phase: "starting"
    property string note
    // info | warn | error | ok
    property string tone: "info"
    property string placeholder: "Password"
    property bool echo: false
    // A wrong password restarts the PAM session, so Howdy looks again.
    property bool retrying: false

    signal askedForResponse
    signal rejected
    signal approved
    // Cancelled by the owner or by polkitd: close without ceremony.
    signal finished

    function begin(f) {
        flow = f;
        message = f.message;
        actionId = f.actionId;
        userName = f.selectedIdentity ? f.selectedIdentity.string : "";
        phase = "starting";
        note = "";
        tone = "info";
        placeholder = "Password";
        echo = false;
        retrying = false;
    }

    function submit(value) {
        if (!flow || phase !== "password")
            return;
        phase = "checking";
        note = "Checking…";
        tone = "info";
        flow.submit(value);
    }

    function cancel() {
        if (flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
        else
            finished();
    }

    // Howdy's own words (howdy/src/pam/main.cc), in plain language.
    function hear(text, isError) {
        if (text === "Attempting facial authentication") {
            phase = "scanning";
            note = retrying ? "Wrong password. Looking for you again…" : "Looking for you…";
            tone = retrying ? "error" : "info";
        } else if (text === "Failure, timeout reached") {
            note = "Didn't recognize you";
            tone = "warn";
        } else if (text === "Face detection image too dark") {
            note = "Camera covered or too dark";
            tone = "warn";
        } else if (text.startsWith("Identified face as ")) {
            note = "Recognized";
            tone = "ok";
        } else if (text !== "") {
            note = text;
            tone = isError ? "error" : "info";
        }
    }

    function ask(text, visible) {
        const label = (text || "").replace(/[:\s]+$/, "");
        if (label === "" || label === "Password")
            placeholder = userName ? "Password for " + userName : "Password";
        else
            placeholder = label;
        echo = visible;
        phase = "password";
        askedForResponse();
    }

    property Connections events: Connections {
        target: ctl.flow
        ignoreUnknownSignals: true

        function onSupplementaryMessageChanged() {
            ctl.hear(ctl.flow.supplementaryMessage, ctl.flow.supplementaryIsError);
        }
        function onIsResponseRequiredChanged() {
            if (ctl.flow.isResponseRequired)
                ctl.ask(ctl.flow.inputPrompt, ctl.flow.responseVisible);
        }
        function onAuthenticationFailed() {
            ctl.retrying = true;
            ctl.phase = "starting";
            ctl.note = "Wrong password";
            ctl.tone = "error";
            ctl.rejected();
        }
        function onAuthenticationSucceeded() {
            ctl.phase = "approved";
            ctl.note = "Approved";
            ctl.tone = "ok";
            ctl.approved();
        }
        function onIsCompletedChanged() {
            if (ctl.flow.isCompleted && !ctl.flow.isSuccessful)
                ctl.finished();
        }
    }
}
