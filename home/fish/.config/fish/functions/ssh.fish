function ssh --wraps ssh --description 'SSH wrapper; uses sshpass for password-auth hosts'
    if contains -- ice $argv
        sshpass -f ~/.ssh/jump_pass /usr/bin/ssh $argv
    else
        /usr/bin/ssh $argv
    end
end
