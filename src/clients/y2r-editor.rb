# encoding: utf-8

module YCP
  module Clients
    class Y2RViewer < Client
      YCP.import("UI")
      YCP.import("Wizard")
      YCP.import("Label")

      require "cheetah"

      ID_YCP = 'ycp-code'
      ID_RUBY = 'ruby-code'
      UI_TIMEOUT_MILISEC = 500

      def initialize
        # create a symlink to your y2r copy
        @y2bin = '/tmp/y2r/bin/y2r'
        @last_ycp_code = nil
      end

      def fill_up_dialog
        contents = HBox(
          VBox(
            MultiLineEdit(term(:id, ID_YCP), _('YCP'), "")
          ),
          VBox(
            MultiLineEdit(term(:id, ID_RUBY), _('Ruby'), "")
          )
        )
        caption = _('Y2R WYSIWYG')
        Wizard.SetContentsButtons(caption, contents, "", _('&Configure'), Label.QuitButton)
        Wizard.HideAbortButton
        UI.SetFocus(term(:id, ID_YCP))
      end

      def translate_ycp
        ycp_code = UI.QueryWidget(term(:id, ID_YCP), :Value)
        return if (ycp_code == @last_ycp_code)
        return if (ycp_code == '')

        Builtins.y2debug('Translating: %1', ycp_code)
        begin
          (ruby_code, ruby_err) = Cheetah.run(@y2bin, :stdin => ycp_code, :stdout => :capture, :stderr => :capture)
        rescue Cheetah::ExecutionFailed => e
          ruby_code = e.stdout || ""
          ruby_err  = e.stderr || ""
        end

        ruby_out = (ruby_err == "" ? "":"#{ruby_err}\n") + ruby_code
        UI.ChangeWidget(term(:id, ID_RUBY), :Value, ruby_out)
        @last_ycp_code = ycp_code
      end

      def main
        textdomain "y2r-tools"

        Wizard.CreateDialog
        fill_up_dialog

        while true
          returned = UI::TimeoutUserInput(UI_TIMEOUT_MILISEC)

          case returned
            when :next
              break
            when :timeout
              translate_ycp
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
