# encoding: utf-8

module YCP
  module Clients
    class Y2RViewer < Client
      YCP.import("UI")
      YCP.import("Wizard")
      YCP.import("Label")

      require 'cheetah'
      require 'fileutils'
      require 'yaml'

      # Config file storing user configuration
      CONFIG_FILE = '.y2rconfig'
      # Delay between checks whether user is still typing
      USER_TYPING_TIMEOUT = 400

      module Default
        TRANSLATION_TIMEOUT = 400
        Y2R_BIN = '/usr/bin/y2r'
      end

      module IDs
        YCP = :ycp_code
	LOAD = :ycp_load
        RUBY = :ruby_code
        CONFIGURE = :configure
        PATH_TO_Y2R = 'path_to_y2r'
        Y2R_ARGS = 'y2r_args'
        TRANSLATION_TIMEOUT = 'timeout'
        OK_BUTTON = :ok
        CANCEL_BUTTON = :cancel
      end

      def initialize
        # should be installer here later
        @y2r_bin = Default::Y2R_BIN
        @y2r_args = []
        @last_ycp_code = ''
        @ui_timeout_milisec = Default::TRANSLATION_TIMEOUT
        @user_config = File.join(ENV['HOME'], CONFIG_FILE)
      end

      def open_main_dialog
        contents = HBox(
          VBox(
            MultiLineEdit(term(:id, IDs::YCP), _('YCP'), ''),
            PushButton(term(:id, IDs::LOAD), _('Load File'))
          ),
          VBox(
            MultiLineEdit(term(:id, IDs::RUBY), _('Ruby'), '')
          )
        )
        caption = _('Y2R WYSIWYG Editor')
        dialog_help = _("<p>Just type some <b>YCP</b> code into <b>YCP</b> text field
        and it will be automatically translated to <b>Ruby</b>.</p>") +
        _("<p>Use <b>Configure</b> button to set a non-default settings.</p>")
        Wizard.SetContentsButtons(caption, contents, dialog_help, '', Label.QuitButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(IDs::CONFIGURE, _('&Configure'))
        UI.SetFocus(term(:id, IDs::YCP))
      end

      def fillup_ruby_textarea(text)
        UI.ChangeWidget(term(:id, IDs::RUBY), :Value, text)
      end

      def user_is_still_typing(ycp_code_old)
        returned = UI::TimeoutUserInput(USER_TYPING_TIMEOUT)
        if returned == :timeout
          ycp_code_new = UI.QueryWidget(term(:id, IDs::YCP), :Value)
          # the code has changed
          return ycp_code_old != ycp_code_new
        end

        false
      end

      def translate_ycp
        ycp_code = UI.QueryWidget(term(:id, IDs::YCP), :Value)
        return if (ycp_code == @last_ycp_code)
        if (ycp_code == '')
          fillup_ruby_textarea('')
          return
        end
        return if user_is_still_typing(ycp_code)

        Builtins.y2debug('Translating: %1', ycp_code)
        cmd = ([@y2r_bin] + [@y2r_args]).flatten
        begin
          (ruby_code, ruby_err) = Cheetah.run(cmd, :stdin => ycp_code, :stdout => :capture, :stderr => :capture)
        rescue Cheetah::ExecutionFailed => e
          ruby_code = e.stdout || ""
          ruby_err  = (e.stderr != "" ? e.stderr : nil) || e.message || ""
        end

        ruby_out = (ruby_err == "" ? "":"#{ruby_err}\n") + ruby_code
        fillup_ruby_textarea(ruby_out)
        @last_ycp_code = ycp_code
      end

      def read_user_settings
        unless File.exists?(@user_config)
          Builtins.y2milestone "User config #{@user_config} not found, using default values"
          return
        end

        config = begin
          YAML.load(File.open(@user_config))
        rescue ArgumentError => e
          Bultins.y2error "Could not parse user config file #{@user_config}: #{e.message}"
          return
        end

        Builtins.y2milestone("User config: %1", config)

        @y2r_bin = config[IDs::PATH_TO_Y2R]
        @y2r_args = config[IDs::Y2R_ARGS]
        @ui_timeout_milisec = config[IDs::TRANSLATION_TIMEOUT]
      end

      def save_user_settings
        config = {
          IDs::PATH_TO_Y2R => @y2r_bin,
          IDs::Y2R_ARGS => @y2r_args,
          IDs::TRANSLATION_TIMEOUT => @ui_timeout_milisec,
        }

        ret = true

        begin
          File.open(@user_config, "w") {
            |f|
            f.write(config.to_yaml)
          }
        rescue Exception => e
          ret = false
          Builtins.y2error("Cannot write config #{config.inspect} to file #{@user_config}: #{e.message}")
          Report::Error(
            _("Cannot write configuration to file #{@user_config}.\nReason: #{e.message}")
          )
        end
      end

      def handle_configuration
        dialog = VBox(
          MarginBox(1, 1,
            VBox(
              HSpacing(50),
              Left(term(:InputField, term(:id, IDs::PATH_TO_Y2R), term(:opt, :hstretch), _('Path to y2r Including Options'), @y2r_bin)),
              VSpacing(0.6),
              Left(Label(_("To configure the y2r arguments, edit #{@user_config} file\nand set #{IDs::Y2R_ARGS}: ['list', 'of', 'args']."))),
              VSpacing(0.6),
              Left(IntField(term(:id, IDs::TRANSLATION_TIMEOUT), _('Translate Each *n* msec'), 0, 60000, @ui_timeout_milisec)),
            )
          ),
          term(:ButtonBox,
            PushButton(term(:id, IDs::OK_BUTTON), term(:opt, :default, :key_F10), Label.OKButton),
            PushButton(term(:id, IDs::CANCEL_BUTTON), term(:opt, :key_F9), Label.CancelButton)
          )
        )

        UI.OpenDialog dialog
        user_ret = UI.UserInput

        if (user_ret == IDs::OK_BUTTON)
          new_y2r_bin = UI.QueryWidget(term(:id, IDs::PATH_TO_Y2R), :Value) || Default::Y2R_BUN
          new_timeout = UI.QueryWidget(term(:id, IDs::TRANSLATION_TIMEOUT), :Value) || Default::TRANSLATION_TIMEOUT

          # settings have changed
          if (new_y2r_bin != @y2r_bin || new_timeout != @ui_timeout_milisec)
            @y2r_bin = new_y2r_bin
            @ui_timeout_milisec = new_timeout
            save_user_settings
            trigger_translation
          end
        end

        UI.CloseDialog
      end

      def handle_ycp_load
        dialog = VBox(
          MarginBox(1, 1,
            HBox(
              VBox(
                HSpacing(40),
                InputField(term(:id, :filename), term(:opt, :hstretch), _('File Name'), "")
              ),
              PushButton(term(:id, :browse), _('Browse')
            )
          )),
          term(:ButtonBox,
            PushButton(term(:id, IDs::OK_BUTTON), term(:opt, :default, :key_F10), Label.OKButton),
            PushButton(term(:id, IDs::CANCEL_BUTTON), term(:opt, :key_F9), Label.CancelButton)
          )
        )

        UI.OpenDialog dialog

        while true
          user_ret = UI.UserInput
          filename = UI.QueryWidget(term(:id, :filename), :Value) || "/"
          if user_ret == IDs::OK_BUTTON || user_ret == IDs::CANCEL_BUTTON
            break
          end
          if user_ret == :browse
            filename = UI.AskForExistingFile(filename, "*.ycp", _("Chose the YCP file")) || filename
	    UI.ChangeWidget(term(:id, :filename), :Value, filename)
          end
        end

        UI.CloseDialog
        if (user_ret == IDs::OK_BUTTON)
          file = SCR.Read(path(".target.string"), filename)
          UI.ChangeWidget(term(:id, :ycp_code), :Value, file)
        end
      end

      def trigger_translation
        @last_ycp_code = ''
      end

      def main
        textdomain "y2r-tools"

        Wizard.CreateDialog
        open_main_dialog
        read_user_settings

        while true
          returned = UI::TimeoutUserInput(@ui_timeout_milisec)

          case returned
            when :next
              break
            when :timeout
              # TODO: skip if user is still writing
              translate_ycp
            when :configure
              handle_configuration
	    when :ycp_load
              handle_ycp_load
            else
              Builtins.y2error('Unknown user input: %1', returned)
          end
        end

        UI.CloseDialog
      end
    end
  end
end

YCP::Clients::Y2RViewer.new.main
