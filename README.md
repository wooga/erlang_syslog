### Enable UDP

Ensure that syslogd has udp sockets enabled:
[OS X](http://stackoverflow.com/questions/1185554/how-to-enable-syslogd-to-receive-udp-logs-from-routers-in-osx)

### Build

    make
    
### Log

    0> {ok, Pid} = syslog:start_link().
    {ok, <0.74.0>}
    1> syslog:send("my message", []).
    ok
    
### Logged

    $ syslog
    ...
    Tue Mar 16 18:36:48 192.168.1.101  wombat[4294967295] <Info>: happy
