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

Note: You have to have y2r cloned somewhere

    git clone git@github.com:yast/y2r.git
    cd y2r
    bundle install

Then run the editor and configure path to y2r, that will be somewehre at
${cloned_y2r_repository}/bin/y2r

Configuration
=============
y2r-editor can be configured using the `[Configure]` button in application.
You can also edit saved options in YAML-based config file
at `${YOUR_HOME}/.y2rconfig`

y2r arguments can be set in `y2r_args`, for example

    # To include the installed modules as directory where to search for modules
    y2r_args: ["--module-path", "/usr/share/YaST2/modules/"]
