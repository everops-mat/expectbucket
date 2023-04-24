# SSH to Host and change the user's password using passwd

The is a quick demostartion of how to use [Expect](https://wiki.tcl-lang.org/page/Expect) to ssh into a system and run a command to change a password. 

## About Expect

Expect is a [TCL](http://tcl-lang.org) domain specfic lanauage (DSL) to 
interact with other programs. Since it is built on top of TCL, it uses TCL
commands AND additional commands specific to expect.

## Purpose

This script will log in to remote system via ssh, and run passwd to change
the password for the ssh user. 

The script should exit 0 if the command run on the remote system was 
succesful non-zeorr if an error occures.

Possible errors include:

* Not being able to connect via ssh.
* Not being able to run a command. 
* The command not running succesfully.
* Attempting to run the command errors out.

The script will run passwd on the remote host. It is assumed the ssh_pass
will be used as the prompt for the old password in passwd.

## Inputs

* host - the host to connect to.
* ssh_user - the ssh user not to connect to the host. It will be assumed that ssh authentication is setup to allow passwordless logins.
* ssh_pass - the ssh password for the ssh user.
  * This will be used as the original password.
* new_password - the new password for `user`.

## How it should work

```shell
[mek@rocky ~]$ passwd 
Changing password for user mek.
Current password: 
New password: 
Retype new password: 
passwd: all authentication tokens updated successfully.
```

## If changing the password fails
[mek@rocky ~]$ passwd 
Changing password for user mek.
Current password: 
New password: 
Retype new password: 
Sorry, passwords do not match.
passwd: Authentication token manipulation error
```

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
    Out "ssh_pass         - password for user to use to connect to host will also be used for the current_password"
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
    # we'll return 1 if success, zero if there is an error
    expect {
      -nocase "yes/no" {
           # if we get a question about the host key, accept it.
           exp_send "yes\r"
           exp_continue
       }
      -nocase "y/n" {
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
       -re $prompt {
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
       return 1
    }
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

if { $argc != 4 } {
    Usage
}

# If we are here, we have for arguments. 
# You could use set host [lindex $argv 0], set ssh_user [lindex $argv 1]
# but the foreach break trick here saves some typing.
foreach {host ssh_user ssh_pass new_password} $argv break
@
```

## addional variables

* We are going to hard-code `timeout` for the time being.
* We'll also hard code the expect `prompt`.
* set the `TERM` environment variable to dump, this fixes some possible issues.
* Limit how much we'll match. 
* We set the exit code `ret` to 1 (failure). The only way it get set to 0
is if we run the command and it succeds.

```tcl
<<vars>>=
set timeout 5
set prompt "(%|\\\$|#) "
set env(TERM) dump
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
exp_send "passwd\r"
while { 1 } { 
    expect {
        eof { 
            send_user "error running program, connection dropped\n"
            set ret 111
            break
        }
        timeout { 
            send_user "error running program, timed out\n"
            set ret 111
            break
        }
        # prompted for the current password
        -nocase -re "current password:" {
            exp_send "$ssh_pass\r"
        }
        # prompted for the new password. Should happen twice.
        -nocase -re "new password:" {
            exp_send "$new_password\r"
        }
        # check for error or success
        -re "error" {
            send_user "password change for $ssh_user failed\n"
            break
        }
        -re "success" {
            send_user "password change succesful for $ssh_user\n"
            # successful, so we want to exit with 0
            set ret 0
            break
        } 
        -re $prompt {
            # if we run the command and get here, opps.
            send_user "this show not happen\n"
            break
        }
    }
}
@
```

NOTE: The above make some assumptions about how the command fails. Here we 
we assume a message with error in it means the command failed. We also 
assume the successful message will contain success. 

YMMV

## We are done, exit and clean up.

```tcl
<<done>>=
catch { 
    exp_send "exit\r"
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
<<chpass.exp>>=
<<start>>
<<vars>>
<<login>>
<<runcommand>>
<<done>>
<<end>>
@
```

## Testing

TODO
