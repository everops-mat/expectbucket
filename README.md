# expectbucket

Various Expect Scripts and templates I have put together

## Usage

There are markdown files that contain code. I included a [tangle](scripts/tangle.tcl) script to untangle the code from the markdown. 

These scripts will require [TCL](https://tcl-lang.org) and [Expect](https://www.nist.gov/services-resources/software/expect).

## generic

The [generic](generic.md) template is a good start. This will be able to
ssh to a remote system using a username and password. If the connection 
is setup to NOT require a password, it should still work. You can enter
a gibberish for the ssh password. 

You'll probably need to adjust how it figures out the remote command failed.

`make generic.exp` will generate the script. 

## chpass

The [chpass](chpass.md) script will look into a remote system and 
attempt to run `passwd` and change the password for that user.

Simulates:

```
$ ssh $user@$host
host$ passwd
old password: ****
new password: ****
reenter new password: ****
$
```

NOTE: This will still connect if ssh-key authenitcation is working, 
you'll still need to use the ssh_pass setting.
