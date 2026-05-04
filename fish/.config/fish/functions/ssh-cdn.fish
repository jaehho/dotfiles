function ssh-cdn
    set -l zone us-east4-b
    set -l name cdn-project

    set -l state (gcloud compute instances describe $name --zone=$zone --format='value(status)' 2>/dev/null)
    if test "$state" != RUNNING
        gcloud compute instances start $name --zone=$zone
    end

    # Mount cdn at ~/cdn as a side effect. --no-block returns immediately;
    # the systemd unit will run sshfs in the background and auto-unmount
    # when the instance stops. Idempotent — no-op if already mounted.
    systemctl --user start --no-block sshfs-cdn.service 2>/dev/null

    gcloud compute ssh $name --zone=$zone $argv
end
