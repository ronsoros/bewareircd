beware ircd 1.6.3 source code

this is tested to compile on Borland delphi 6, delphi xe5, and on freepascal 2.4.0

tested on windows 7, linux (debian) and mac OS X


homepage: http://ircd.bircd.org/

this project uses lcore: http://www.lcore.org/



recommended way to compile on freepascal on linux/*nix:

make sure lcore is in the directory where "compile" expects it (../libs/lcore), then run compile.

recommended way to compile in delphi on windows:

make sure lcore is where the projects expect it (..\libs\lcore) or edit the project settings.

open and compile bcreationdate.dpr and run bcreationdate.exe. then, open and compile bircd.dpr. also open and compile mkpasswd.dpr.



there are a number of conditional defines which for example make it easy to disable something at compile time, 
and this way get a smaller exe file which has only what you need. their use other than the defaults is untested and not guaranteed to do something useful.

* shortstrings
causes string properties in tuser/tchannel to be faster "short" strings instead of dynamic length strings.
20 kb bigger exe file.

* shortnumerics
use P10 short numerics (SCC)
should not be set. use ini setting instead.

* noipv6
disables support for ipv6 address support/logic, and server-server protocol. should not be set, so as to allow ipv6 anywhere on the net.

* nohis
no head in sand code

* novhost
no support for virtual host of any kind (user mode +x, +h, /sethost, etc)

* nodnsquery
don't use async DNS object to resolve hostnames

* no21011
no ircu2.10.11 features, commands, etc.

* noservcmds
no dalnet services commands (/chanserv, /nickserv, /memoserv)

* nosvsnick
no svsnick command

* nosethost
defined by default. disable sethost command. if enabled, needs vhost enabled

* bdebug
enable some debug code. raw server traffic to/from server links in &debug.server.name channel.

* noini
no support for ini files and options command, all commands must be edited in bconfig. 10 kb smaller exe.

* nowinnt
no support for running as NT service
