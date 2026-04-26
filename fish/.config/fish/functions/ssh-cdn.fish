function ssh-cdn
    set -l zone us-east4-b
    set -l name cdn-project

    set -l state (gcloud compute instances describe $name --zone=$zone --format='value(status)' 2>/dev/null)
    if test "$state" != RUNNING
        gcloud compute instances start $name --zone=$zone
    end

    gcloud compute ssh $name --zone=$zone $argv
end
