# weasel-pagent-win32
Simple wrapper to bridge openssh win32 to pagent with help of weasel and PowerShell

When you haven't moved to the new native OpenSSH for Windows 10 https://github.com/PowerShell/openssh-portable and are still stuck on PuTTY and Pageant (and refuse to move away) this script can help you use the keys in your Pageant. It works in combination with weasel-pageant https://github.com/vuori/weasel-pageant. My usecase was trying out the VSCode Remote https://code.visualstudio.com/docs/remote/remote-overview. 

## Install
1. Download a release of `weasel-pageant` into a folder of your choice https://github.com/vuori/weasel-pageant
2. Download `weasel-pageant-win32.ps1` into the same folder
3. Open up a few powershell windows and run
`powershell -ExecutionPolicy ByPass -File weasel-pageant-win32.ps1`

You need more than one, because in case of agent forwarding, ssh.exe stays conencted to the named pipe and new connections from either other ssh.exe instances or agent forwarded ones will block indefinetely.

This is a temporary solution, I intend to frankenstein together parts of the openssh source, weasel in putty to make nice compact binary that can be perhaps run as try app.

## How does this work
I have dipped my hand into the inner workings of ssh and ssh-agent protocol many many years ago (https://github.com/zobo/putty/commits/rsa-cert-capi), so when faced with the dilemma of needeing to get the now Win10 native ssh.exe to use my existing ssh keys, or export and import my keys, I naturally took the hard way.

The idea of the agent is, that it holds your ssh keys, as securely as possible (whatever the implementation offers). The actual ssh process (or scp or sftp or whatever else) can ask the agent to perform a key signature. The real magic happens with agent forwarding, where the key signature request can come through may hops away, throught already established ssh conenctions. This way your private keys do not leave your "trusty" workstation.

The agent protocol in itself is very simple. Always a request-response operation. Each packet consists of a header-length and a body.

Now come the question of how this protocol is transported. In the original OpenSSH implementation within a \*nix enviroment this is done via AF_UNIX (a unix socket). Just open a terminal with agent forwarding or ssh-agent present, type `export` and look for `SSH_AUTH_SOCK` variable. This is the unix socket that directly talks the agent protocol.
On windows, things are different. Putty uses a combination of memory mapped files and `WM_COPYDATA`, whereas OpenSSH-win32 uses a named pipe at a known location `\\.\pipe\openssh-ssh-agent`. However in all cases, the trnasmitted protocol is identical!
This tells me that with some simple pipe manipulation, I can get ssh.exe to use keys in Pageant.

Enter `weasel-pageant`. I foudn this tool a while ago when playing a lot with `WSL`. It partially already does what we want to do right now, only it does it for ssh inside `WSL` that uses AF_UNIX. It has two components:
- a wsl side binary that listens on AF_UNIX for connections from wsl ssh
- a win32 side `helper.exe` that forwards requests to Pagent (remember `WM_COPYDATA`)

The win32 side `helper.exe` is exactly what we need, just need to implement a simple pump that will listen on the named pipe `\\.\pipe\openssh-ssh-agent` and forward data back and forth to `helper.exe`

Because this was going to be a initial hack, just to test it, I choose to write it in PowerShell (but sould have gone to C# rigth away...).
