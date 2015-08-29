
STDOUT.sync=true
STDERR.sync=true
STDIN.sync=true

$max = 0

module IoSyncUtils
  def ensure_newline(*_opt)
    _opt = switch_ensure_newline(*_opt)
    _opt
  end
  
  def switch_ensure_newline(_opt)
    $max+=1
    exit if $max > 100
    if _opt
      if _opt.kind_of?(String)
        _opt = ensure_newline_string(_opt)
      elsif _opt.kind_of?(Array) 
        _opt = ensure_newline_array(_opt)
      end
    end
    _opt
  end

  def ensure_newline_string(_str)
    if _str && _str.length > 0 && _str.strip[-1..-1] != '\n'
      _str +="\n" 
    end
    _str
  end
  
  def ensure_newline_array(_arr)
    if _arr && _arr.length > 0
      _arr[_arr.length-1] = switch_ensure_newline(_arr[_arr.length-1]) 
    end
    _arr
  end
end


#class << STDOUT
#  include IoSyncUtils
#  alias_method :orig_print, :print
#  alias_method :orig_printf, :printf
#  alias_method :orig_syswrite, :syswrite
#
#  def print(*opts)
#    orig_print(ensure_newline(*opts))
#  end
#
#  def printf(format, *opts)
#    orig_printf(ensure_newline(format), *opts)
#  end
#
#  def syswrite(*opts)
#    orig_syswrite(ensure_newline(*opts))
#  end 
#end

require 'readline'

class << Readline
  include IoSyncUtils
  alias_method :orig_readline, :readline

  def Readline::readline(prompt, hist)
    Readline::orig_readline(ensure_newline(prompt), hist)
  end
end