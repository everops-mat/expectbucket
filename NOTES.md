# Various notes

## when to sleep

When we spawn a process, the `expect` command will wait for the process 
to start before processing. Send (or `exp_send`) will not. This can cause
some odd things to happen on your first send to the process. It is good 
practice to sleep for a second or two before running your first send. 

For example, if you are ssh'ng into a box and then running some commands, 
you'll want to do something like.

* spawn ssh connection
* expect stuff to login
* sleep 2
* exp_send -- "command"

It also might be helpful, for some interactions, to have the send act *slow*.

Do do that, set `send_slow` and use the -s flag in `exp_send`.

```tcl
# wait .01 secs after each 5 chars sent
set send_slow { 5 .01 } # wait .01 secs after each 5 chars sent
# wait before first send
sleep 2
exp_send -s -- "my -command -and options"
expect {
 ...
}
```
