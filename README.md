Pinger
======

Couple of projects for monitoring host availability with `ping` command.

Written for fun for production purposes.

Enjoy.


lua-nginx-pinger-frontend
-------------------------

Simple-functionality front-end for [Pinger Service](https://github.com/ganzal/php-pinger-service).


### Components


#### host-status

Simple response on `HEAD` or `GET` requests for particular format URIs like
`https://example.com/host-status/LABEL/`.

Available responses are:

|HTTP Response Status|Text<sup>[1]</sup>|Desctiption|
|-----|-----|-----|
|`200`|`Online`|Host available.|
|`503`|`Offline`|Last ping has no response.|
|`404`|`Not found`|Host was not found in cache.|
|`400`|`Invalid URI format`|Request passed to Pinger but URI does not match expected (configurable, see below) format.|
|`405`|`Method not allowed`|Request with HTTP method neither `HEAD` nor `GET` has been blocked.|
|`500`|*multiple*|Different system errors.|

<sup>**[1]**</sup> Plain text response body available only for `GET` requests.


### Requirements

1. [nginx](http://nginx.org/) webserver compiled with [Lua](http://www.lua.org/) support (eg. [openresty](http://openresty.org/)).
2. [Redis](https://redis.io/) server (on back-end actually).


### Installation

1. Copy LUA files to prefered location.
(eg. `/usr/share/com-ganzal/lua-nginx-pinger-frontend/`)
2. Add minimum required configuration to server/location block.
See [src/example.com-nginx.conf](src/example.com-nginx.conf) for some examples.
3. Restart nginx (eg. `service nginx restart`).


### TODO

* Human-friendly interface (*Maybe*)
* Install/Uninstall scripts and helpers (*Even if I think that instructions listed above is just enough to success*)
* Debian/Ubuntu packages (*Why not?*)
* Unit-tests (*Why not?*)


## License

MIT License: see the [LICENSE](LICENSE) file.

*eof*
