#
#   a-contracts.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

# Catalog of events used by arcadia obj. 
# Obj must comunicate through raise/catch event
# in order to guarantees decoupling

# +------------------------------------------+
#      Arcadia Event
# +------------------------------------------+

class ArcadiaEvent < Event
  # note--they all have attr_accessor :file, and :dir
  def go!
    Arcadia.process_event(self)
  end
  
  def shot!
    Arcadia.broadcast_event(self)
  end

end

class ArcadiaSysEvent < ArcadiaEvent
end


# +------------------------------------------+
#     Extention Event (raised only by Arcadia)
#     do not raise! 
#     Every extensions listen on these events
# +------------------------------------------+

class BuildEvent < ArcadiaSysEvent
  attr_accessor :name
end 

class InitializeEvent < ArcadiaSysEvent
end


# ExitQueryEvent is processed by arcadia-core 
# before process FinalizeEvent during quiet face.
# If listener(Extension) set can_exit property to false then 
# arcadia abort the quiet face. 
class ExitQueryEvent < ArcadiaSysEvent
  attr_accessor :can_exit
end

class QuitEvent < ArcadiaSysEvent
end

class FinalizeEvent < ArcadiaSysEvent
end

# used only by ArcadiaExtPlus
class ClearCacheInstanceEvent < ArcadiaSysEvent
end

class DestroyInstanceEvent < ArcadiaSysEvent
end

class ActivateInstanceEvent < ArcadiaSysEvent
  attr_accessor :name
end

class NeedRubyGemWizardEvent < ArcadiaSysEvent
  class Result < Result
    attr_accessor :installed
  end
  attr_accessor :extension_name
  attr_accessor :gem_name
  attr_accessor :gem_repository
  attr_accessor :gem_min_version
  attr_accessor :gem_max_version
  attr_accessor :gem_events
end

class ArcadiaProblemEvent < ArcadiaSysEvent
   DEPENDENCE_MISSING_TYPE = "DEPENDENCE_MISSING_TYPE"
   RUNTIME_ERROR_TYPE = "RUNTIME_ERROR_TYPE"
   attr_accessor :type, :level, :title, :detail
end

# +------------------------------------------+

# +------------------------------------------+
#     Generic Layout Event 
#     
# +------------------------------------------+
class LayoutRaisingFrameEvent < ArcadiaSysEvent
  attr_accessor :extension_name
  attr_accessor :frame_name
end

class LayoutChangedFrameEvent < ArcadiaSysEvent
end

class LayoutChangedDomainEvent < ArcadiaSysEvent
  attr_accessor :old_domain
  attr_accessor :new_domain
end

#  +---------------------------------------------+
#         Buffer event
#  +---------------------------------------------+

class BufferEvent < ArcadiaEvent # Abstract
  attr_accessor :file, :title, :text, :row, :col, :lang, :last_row, :last_col 
  # if file==nil && title==nil buffer=current buffer
end

class NewBufferEvent < BufferEvent
end

class OpenBufferEvent < BufferEvent
  attr_accessor :select_index, :debug
end

class OpenBufferTransientEvent < OpenBufferEvent
  # @transient is a boolean property setted to true during event elaboration if the file is considered transient  
  attr_accessor :transient 
end

class CloseBufferEvent < BufferEvent
end

class SaveBufferEvent < BufferEvent
end

class SaveAsBufferEvent < SaveBufferEvent
  attr_accessor :new_file	
end

class MoveBufferEvent < BufferEvent
  attr_accessor :old_file	
  attr_accessor :new_file	
end

class CloseCurrentTabEvent < BufferEvent
end

class GoToLineBufferEvent < BufferEvent
  attr_accessor :line
end

class PrettifyTextEvent < BufferEvent

end

class SearchBufferEvent < BufferEvent
  class Result < Result
    attr_accessor :row, :col
  end
  attr_accessor :what
end

class CompleteCodeEvent < BufferEvent
  class Result < Result
    attr_accessor :candidates
  end
end

class DocCodeEvent < BufferEvent
  class Result < Result
    attr_accessor :doc, :title
  end
  attr_accessor :xdoc, :ydoc, :doc_entry
end

class BufferRaisedEvent < BufferEvent
end

class NoBufferExistEvent < BufferEvent
end

class OneBufferExistEvent < BufferEvent
end

class BufferClosedEvent < BufferEvent
end

class DeleteFileBufferEvent < BufferEvent
end

#  +---------------------------------------------+
#         Bookmark event
#  +---------------------------------------------+

class BookmarkEvent < ArcadiaEvent
   #range  around row where event has effect 
   attr_accessor :id, :file, :row, :persistent, :range, :from_row, :to_row , :content
end

class SetBookmarkEvent < BookmarkEvent
end

class UnsetBookmarkEvent < BookmarkEvent
end

class ToggleBookmarkEvent < BookmarkEvent
end


#  +---------------------------------------------+
#         Debug event
#  +---------------------------------------------+

class DebugEvent < ArcadiaEvent
   attr_accessor :id, :file, :row, :active, :persistent
end

class SetBreakpointEvent < DebugEvent
   attr_accessor :line_code
end

class UnsetBreakpointEvent < DebugEvent
   attr_accessor :delete
end

class EvalExpressionEvent < DebugEvent
  attr_accessor :expression
end

class StartDebugEvent < DebugEvent
end

class StopDebugEvent < DebugEvent
end

class StepDebugEvent < DebugEvent
  class Result < Result
    attr_accessor :file, :row
  end
  # step_over, step_into, step_out, resume, where, quit
  attr_accessor :command
end

class DebugStepInfoEvent < DebugEvent
  attr_accessor :file, :row
end

#  +---------------------------------------------+
#         Message event (raised only by Arcadia)
#         to raise use: 
#         Arcadia.new_msg
#         Arcadia.new_debug_msg
#         Arcadia.new_error_msg
#  +---------------------------------------------+

class MsgEvent < ArcadiaEvent
   attr_accessor :msg, :level, :mark, :append
end

class SubProcessEvent < ArcadiaEvent
   attr_accessor :abort_action, :alive_check, :name, :pid, :timeout, :timecheck, :abort_dialog_yes, :anigif
end

class SubProcessProgressEvent < SubProcessEvent
  attr_accessor :max, :varprogress
end

#class DebugMsgEvent < MsgEvent
#end
#
#class ErrorMsgEvent < MsgEvent
#end

#  +---------------------------------------------+
#         Other event
#  +---------------------------------------------+

class SearchInFilesEvent < ArcadiaEvent
  # this message actually does before, on, after
  # in the time it takes to open the dialog
  # the dialog then receives its input [i.e. all the messages are done before the search is through]
  class Result < SearchBufferEvent::Result
    attr_accessor :file
  end
  attr_accessor :what, :files_filter, :dir
end

class AckInFilesEvent < ArcadiaEvent
  # don't subclass SearchInFilesEvent or listeners for SearchInFiles will also get our messages
  class Result < SearchBufferEvent::Result
    attr_accessor :file
  end
  attr_accessor :what, :files_filter, :dir
end

class SystemExecEvent < ArcadiaEvent
  class Result < Result
    attr_accessor :std_output, :std_error
  end
  attr_accessor :command
end

class RunRubyFileEvent < ArcadiaEvent
  class Result < Result
    attr_accessor :output
  end
  attr_accessor :file
  attr_accessor :persistent
end

class RunCmdEvent < ArcadiaEvent
  class Result < Result
    attr_accessor :output
  end
  attr_accessor :file
  attr_accessor :dir
  attr_accessor :cmd
  attr_accessor :title
  attr_accessor :persistent
  attr_accessor :runner_name
  attr_accessor :lang
  attr_accessor :prompt
end

class RunCmdStartedEvent < RunCmdEvent
end

class RunCmdEndedEvent < RunCmdEvent
end

class InputKeyboardQueryEvent < ArcadiaEvent
  class Result < Result
    attr_accessor :input
  end
  attr_accessor :pid
end

class InputEvent < ArcadiaEvent
end

class InputEnterEvent < InputEvent
  attr_accessor :receiver
end

class InputExitEvent < InputEvent
  attr_accessor :receiver
end

# FocusEvent
# Events for executing operation on focused widget
class FocusEvent < ArcadiaEvent
  attr_accessor :focus_widget
end
class CutTextEvent < FocusEvent; end
class CopyTextEvent < FocusEvent; end
class PasteTextEvent < FocusEvent; end
class UndoTextEvent < FocusEvent; end
class RedoTextEvent < FocusEvent; end
class SelectAllTextEvent < FocusEvent; end
class InvertSelectionTextEvent < FocusEvent; end
class UpperCaseTextEvent < FocusEvent; end
class LowerCaseTextEvent < FocusEvent; end

#class VirtualKeyboardEvent  < ArcadiaEvent
#end
#class VirtualKeyboardOnEvent < VirtualKeyboardEvent
#  attr_accessor :receiver
#end
#
#class VirtualKeyboardOffEvent < VirtualKeyboardEvent
#end


#  +---------------------------------------------+
#         Dialog event (raised only by Arcadia)
#         to raise use: 
#         Arcadia.ok
#         Arcadia.ok_cancel
#         Arcadia.yes_no_cancel
#         Arcadia.abort_retry_ignore
#  +---------------------------------------------+

# default actions_pattern  = 'OK'
class DialogEvent < ArcadiaEvent
  TYPE_PATTERNS = ['ok', 'yes_no', 'ok_cancel', 'yes_no_cancel', 'abort_retry_ignore']
  MSG_MAX_CHARS = 500
  TITLE_MAX_CHARS = 100
  class Result < Result
    attr_accessor :value
  end
  attr_accessor :title, :msg, :type, :level, :exception, :prompt
end

class SystemDialogEvent < DialogEvent
end

class HinnerDialogEvent < DialogEvent
end

#class QuestionDialogEvent < DialogEvent
#end
#
#class InfoDialogEvent < DialogEvent
#end
#
#class WarningDialogEvent < DialogEvent
#end
#
#class ErrorDialogEvent < DialogEvent
#end

# system integration Event
class TermEvent < ArcadiaEvent
  attr_accessor :title, :dir, :command
end

#  +---------------------------------------------+
#         Action event
#  +---------------------------------------------+

class ActionEvent < ArcadiaEvent
  attr_accessor :receiver
  attr_accessor :action
  attr_accessor :action_args
end