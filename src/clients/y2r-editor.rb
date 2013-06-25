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

      CONFIG_FILE = '.y2rconfig'
      USER_TYPING_TIMEOUT = 350

      module Default
        TRANSLATION_TIMEOUT = 400
        Y2R_BIN = '/usr/bin/y2r'
      end

      module IDs
        YCP = :ycp_code
        RUBY = :ruby_code
        CONFIGURE = :configure
        PATH_TO_Y2R = 'path_to_y2r'
        TRANSLATION_TIMEOUT = 'timeout'
        OK_BUTTON = :ok
        CANCEL_BUTTON = :cancel
      end

      def initialize
        # should be installer here later
        @y2bin = Default::Y2R_BIN
        @last_ycp_code = ''
        @ui_timeout_milisec = Default::TRANSLATION_TIMEOUT
        @user_config = File.join(ENV['HOME'], CONFIG_FILE)
      end

      def open_main_dialog
        contents = HBox(
          VBox(
            MultiLineEdit(term(:id, IDs::YCP), _('YCP'), '')
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

      def user_is_still_typing(ycp_code_1)
        returned = UI::TimeoutUserInput(USER_TYPING_TIMEOUT)
        if returned == :timeout
          ycp_code_2 = UI.QueryWidget(term(:id, IDs::YCP), :Value)
          # the code has changed
          return true if ycp_code_1 != ycp_code_2
        end

        false
      end

      def translate_ycp
        ycp_code = UI.QueryWidget(term(:id, IDs::YCP), :Value)
        return if (ycp_code == @last_ycp_code)
        fillup_ruby_textarea('') and return if (ycp_code == '')
        return if user_is_still_typing(ycp_code)

        Builtins.y2debug('Translating: %1', ycp_code)
        begin
          (ruby_code, ruby_err) = Cheetah.run(@y2bin, :stdin => ycp_code, :stdout => :capture, :stderr => :capture)
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

        @y2bin = config[IDs::PATH_TO_Y2R]
        @ui_timeout_milisec = config[IDs::TRANSLATION_TIMEOUT]
      end

      def save_user_settings
        config = {
          IDs::PATH_TO_Y2R => @y2bin,
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

        ret
      end

      def handle_configuration
        dialog = VBox(
          MarginBox(1, 1,
            VBox(
              HSpacing(50),
              Left(term(:InputField, term(:id, IDs::PATH_TO_Y2R), term(:opt, :hstretch), _('Path to y2r Including Options'), @y2bin)),
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
          new_y2bin = UI.QueryWidget(term(:id, IDs::PATH_TO_Y2R), :Value) || Default::Y2R_BUN
          new_timeout = UI.QueryWidget(term(:id, IDs::TRANSLATION_TIMEOUT), :Value) || Default::TRANSLATION_TIMEOUT

          # settings have changed
          if (new_y2bin != @y2bin || new_timeout != @ui_timeout_milisec)
            @y2bin = new_y2bin
            @ui_timeout_milisec = new_timeout
            save_user_settings
            trigger_translation
          end
        end

        UI.CloseDialog
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
