y2r-tools
=========

Requirements
============

    yast2-ruby-bindings >= 1.0.0
    rybygem-cheetah

WYSIWYG Editor
==============

    sudo cp -v src/clients/* /usr/share/YaST2/clients
    yast2 y2r-editor

Note: You have to have y2r cloned to /tmp

    cd /tmp
    git clone git@github.com:yast/y2r.git
    cd y2r
    bundle install

TODO
====
Make it configurable - path to y2r
