<img src="icon.svg" width="16%" align="left">

_[Homebrew]_ Utils
==================
Utility `lib`rary for Homebrew [_tap_]s.

Install
-------
~~~ sh
git submodule add https://github.com/danielbayley/homebrew-utils lib
~~~
~~~ rb
system "git -C #{__dir__} submodule update --init --quiet"
require_relative "lib/utils"
~~~
or
~~~ rb
tap = Tap.fetch "danielbayley/utils"
system "brew tap #{tap.name} --quiet" unless tap.path.directory?
system "git -C   #{tap.path} submodule update --init --quiet"
require tap.path/"utils"
~~~

License
-------
[MIT] © [Daniel Bayley]

[MIT]:                LICENSE.md
[Daniel Bayley]:      https://github.com/danielbayley

[homebrew]:           https://brew.sh
[_tap_]:              https://docs.brew.sh/Taps
