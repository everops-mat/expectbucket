# SSH to Host and run command - Generic TCL Expect Script

The is a quick demostartion of how to use [Expect](https://wiki.tcl-lang.org/page/Expect) to ssh into a system and run a command to change a password. 

This is a generic script and we'll check echo the command.

## About Expect

Expect is a [TCL](http://tcl-lang.org) domain specfic lanauage (DSL) to 
interact with other programs. Since it is built on top of TCL, it uses TCL
commands AND additional commands specific to expect.

## Purpose

This script will log in to remote system via ssh, and run a command that requires with arguments. The script should exit 0 if the command run on the remote system was succesful and error out if it does not. Possible errors include:

* Not being able to connect via ssh.
* Not being able to run a command. 
* The command not running succesfully.
* Attempting to run the command errors out.

This script will simulate changing a password, where the remote command will accept input a `command -c CURRENT_PASSWORD -n NEW_PASSWORD`.

## Inputs

* host - the host to connect to.
* ssh_user - the ssh user not to connect to the host. It will be assumed that ssh authentication is setup to allow passwordless logins.
* ssh_pass - the ssh password for the ssh user.
* user - the user password to change
* current_password - the current password for `user`.
* new_password - the new password for `user`.

## Some useful procedures

### Out 

Accept a line as an argument and write to stderr

```tcl
<<out>>=
proc Out { line }  {
    puts stderr "$line"
}
@
```

### Usage

Accepts no arguments, prints out the usage for the script. Note that TCL 
only makes the argv0 variable in the main scope, it is not available in 
procedures. So, we need to use the `global argv0` to make it available
in the `Usage` procedure.

```tcl
<<usage>>=
proc Usage {} {
    global argv0 # we need this to for the usage. Only available in main scope.
    Out "[file tail $argv0] host ssh_user user current_password new_password"
    Out "host             - host to ssh to"
    Out "ssh_user         - user to use to connect to host"
    Out "ssh_pass         - password for user to use to connect to host"
    Out "user             - user to change password"
    Out "current_password - current password of user"
    Out "new_password     - new password for user"
    Out ""
    exit 1
}
@
```    

### Connect remote host

We'll use a ssh command of `ssh $ssh_user@$host`. Then we'll run this 
connect procedure to see if we logged in succesfully with the password.
We'll look for the prompt. 

In our case here, we need the exact prompt, not a regular expession for it.

```tcl
<<connect>>=
proc connect { password prompt } {

    # Attempt to log in with the password looking for the exact prompt.
    # If we get asked to accept a new host key, do so.
    # check for a timeout and if the connection drops.
    expect {
      -nocase "yes/no" {
           # if we get a question about the host key, accept it.
           exp_send "yes\r"
           exp_continue
       }
       -nocase "*assword:*" {
           # if we get something that looks like a password prompt
           # answer it.
           exp_send "$password\r"
           exp_continue
       }
       -exact $prompt {
           # we only return good if we get the prompt
           return 1
       }
       timeout { 
           # timeout!
           send_user "timeout, could not log in\n"
           return 0  
       }
       eof { 
           # The connection dropped! Curses! Foiled again!
           send_user "end of stream, could not log in\n"
           return 0  
       }
    }
    return 0
}
@
```

## Start of script

Here we'll start the script and add a usage procedure. We'll also check 
to make sure that the script is called with the proper arguments and o
exit if not.

If the the proper arguments are given, we'll set variables based on 
arguemnts.

```tcl
<<start>>=
#!/usr/bin/env expect -f
# Using the current environment, run expect as found in the PATH. 
# If there is a specific version of expect needed, change to the 
# proper path. (for example: /usr/local/bin/expect)
#
## procs
<<out>>

<<usage>>

<<connect>>

## check for arguments and set variables

if { $argc != 6 } {
    Usage
}

# If we are here, we have for arguments. 
# You could use set host [lindex $argv 0], set ssh_user [lindex $argv 1]
# but the foreach break trick here saves some typing.
foreach {host ssh_user ssh_pass user current_password new_password} $argv break
@
```

## addional variables

* We are going to hard-code `timeout` for the time being.
* We'll also hard code the expect `prompt`.
* set the `TERM` environment variable to dumb, this fixes some possible issues.
* Limit how much we'll match. 
* We set the exit code `ret` to 1 (failure). The only way it get set to 0
is if we run the command and it succeds.

```tcl
<<vars>>=
set timeout 5
set prompt "apc>"
set env(TERM) dumb
set match_max 100000
# the return code, only set to 0 if command excutes and without error
set ret 1
@
```

## Login to ssh host

We have check our arguments and setup or variables. Let's login.

```tcl
<<login>>=

## spawn the ssh command and get the spawn it. We'll need this 
## to make sure we close the connection correctly.
set pid [spawn ssh $ssh_user@$host]
set id $spawn_id

## run our connect procedure to send the password and get logged in.
if { [connect $ssh_pass $prompt] == 0 } { 
    send_user "Error loggin in to $host as $ssh_user\n"
    catch { 
        exp_close -i $id
        exp_wait -i $id
    }
    exit 111
}
@
```

## We are logged in. Let's do stuff!

```tcl
<<runcommand>>=
## sleep to make sure we are not going to fast
sleep 2
set send_slow {5 .01} # send slow should wait .01 msec after 5 chars
exp_send -s -- "~/bin/change_password $user $current_password $new_password\r"
expect {
    eof { 
        send_user "error running program, connection dropped\n"
        exit 111
    }
    timeout { 
        send_user "error running program, timed out\n"
        exit 111
    }
    -re ".*failed.*" {
        # if failed is in the return from the command, not that it failed.
        send_user "command failed\n"
    }
    -ex $prompt {
        # if we get here, we know the command ran without issue.
        set ret 0
    }
}
@
```

NOTE: The above make some assumptions about how the command fails. Here we 
only assume we'll get a prompt if the command succeds. This may need to be adjusted based on out the errors are reported.

## We are done, exit and clean up.

```tcl
<<done>>=
exp_send "exit\r"
catch { 
    exp_close -i $id
    exp_wait -i $id
}
@
```

## end

```tcl
<<end>>=
send_user "done!\n"
exit $ret
@
```

## Full program

```
<<generic.exp>>=
<<start>>
<<vars>>
<<login>>
<<runcommand>>
<<done>>
<<end>>
@
```

## Testing

I added the following script to a ssh host for testing. It will do the following:

* error out of the arguments are not right.
* timeout if the new password is set to timeout.
* fail if the old password is fail.
* otherwise report success.

```shell
<<changepass.sh>>=
#!/bin/sh
set -e

user=$1; shift
old=$1;  shift
new=$1;  shift

if [ "x$new" = "xtimeout" ] ; then 
  echo "timing out"
  sleep 30
  exit 0
fi

if [ "x$old" = "xfail" ] ; then
  echo "password changed failed for $user"
  exit 1
fi

exit 0
@
```

### To test

```shell
$ make generic.exp
$ tclsh ./scripts/tangle.tcl -R changepass.sh generic.md > changepass.sh

$ expect ./generic.exp testhost mek password theman oldpass ; echo $?
# should return 1 not enough arguments


$ expect ./generic.exp testhost mek password theman oldpass newpass ; echo $?
# should return 0 all good

$ expect ./generic.exp testhost mek password theman fail newpass ; echo $?
# should return 1 we are forcing a failure

$ expect ./generic.exp testhost mek password theman oldpass timeout; echo $?
# should return 111 we are forcing a time out.
```
