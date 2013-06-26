y2r-tools
=========

Requirements
============

    yast2-ruby-bindings >= 1.0.0
    rybygem-cheetah
    rubygem-safe_yaml

WYSIWYG Editor
==============

    sudo cp -v src/clients/* /usr/share/YaST2/clients
    yast2 y2r-editor

Note: You have to have y2r cloned to /tmp

    cd /tmp
    git clone git@github.com:yast/y2r.git
    cd y2r
    bundle install

Configuration
=============
y2r-editor can be configured using the [Configure] button.
You can also edit saved options in YAML-based config file
later: ${YOUR_HOME}/.y2rconfig

y2r arguments can be set in `y2r_args`, for example

    # To include the installed modules as directory where to search for modules
    y2r_args: ["--module-path", "/usr/share/YaST2/modules/"]
