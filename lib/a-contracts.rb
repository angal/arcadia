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
end

class QuitEvent < ArcadiaEvent
end

# +------------------------------------------+
#     Extention Event (raised only by Arcadia)
#     do not raise! 
#     Every extensions listen on these events
# +------------------------------------------+

class BuildEvent < ArcadiaEvent
  attr_accessor :name
end 

# ExitQueryEvent is processed by arcadia-core 
# before process FinalizeEvent during quiet face.
# If listener(Extension) set can_exit property to false then 
# arcadia abort the quiet face. 
class ExitQueryEvent < ArcadiaEvent
  attr_accessor :can_exit
end

class FinalizeEvent < ArcadiaEvent
end


class NeedRubyGemWizardEvent < ArcadiaEvent
  class Result < Result
    attr_accessor :installed
  end
  attr_accessor :extension_name
  attr_accessor :gem_name
  attr_accessor :gem_repository
  attr_accessor :gem_min_version
  attr_accessor :gem_max_version
end

# +------------------------------------------+
#     Generic Layout Event 
#     
# +------------------------------------------+
class LayoutRaisingFrameEvent < ArcadiaEvent
  attr_accessor :extension_name
  attr_accessor :frame_name
end


#  +---------------------------------------------+
#         Buffer event
#  +---------------------------------------------+

class BufferEvent < ArcadiaEvent # Abstract
  attr_accessor :file, :title, :text, :row, :col 
  # if file==nil && title==nil buffer=current buffer
end

class NewBufferEvent < BufferEvent
end

class OpenBufferEvent < BufferEvent
end

class OpenBufferTransientEvent < OpenBufferEvent
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

#  +---------------------------------------------+
#         Debug event
#  +---------------------------------------------+

class DebugEvent < ArcadiaEvent
   attr_accessor :file, :row, :active
end

class SetBreakpointEvent < DebugEvent
   attr_accessor :active
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
   attr_accessor :msg, :level
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

class InputEvent < ArcadiaEvent
end

class InputEnterEvent < InputEvent
  attr_accessor :receiver
end

class InputExitEvent < InputEvent
  attr_accessor :receiver
end


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
  class Result < Result
    attr_accessor :value
  end
  attr_accessor :title, :msg, :type, :level
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


#  +---------------------------------------------+
#         Action event
#  +---------------------------------------------+

class ActionEvent < ArcadiaEvent
  attr_accessor :receiver
  attr_accessor :action
  attr_accessor :action_args
end