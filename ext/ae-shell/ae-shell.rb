#
#   ae-shell.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "tk"
#require "base/a-utils"

class Shell < ArcadiaExt

  def on_before_build(_event)
    Arcadia.attach_listener(self, SystemExecEvent)
    Arcadia.attach_listener(self, RunRubyFileEvent)
  end

  def on_build(_event)
    @run_threads = Array.new
  end

  def on_system_exec(_event)
    begin
      #    _cmd_ = "|ruby #{File.dirname(__FILE__)}/sh.rb #{_event.command} 2>&1"
      #    p _cmd_
      #    Thread.new do
      #      open(_cmd_,"r"){|f|
      #          Arcadia.new_debug_msg(self, f.read)
      #      }
      #    end
      _cmd_ = "#{_event.command}"
      if is_windows?
        io = IO.popen(_cmd_)
      else
        Process.fork{
          open(_cmd_,"r"){|f|
            Arcadia.console(self,'msg'=>f.read, 'level'=>'debug')
            #Arcadia.new_debug_msg(self, f.read)
          }
        }
      end
    rescue Exception => e
      Arcadia.console(self,'msg'=>e, 'level'=>'debug')
      #Arcadia.new_debug_msg(self, e)
    end
  end

  @@next_number = 0
  def on_run_ruby_file(_event)
    _filename = _event.file
    _filename = @arcadia['pers']['run.file.last'] if _filename == "*LAST"
    if _filename && File.exists?(_filename)
      begin
        Arcadia.console(self,'msg'=>"Running #{_filename}...", 'level'=>'debug') # info?
        start_time = Time.now
        @arcadia['pers']['run.file.last']=_filename if _event.persistent
        executable = @arcadia['conf']['shell.ruby']
        executable = @arcadia['conf']['shell.rubyw'] if is_windows?
        _cmd_ = "#{executable} -C'#{File.dirname(_filename)}' '#{_filename}'"
        
        if is_windows?
          # use win32-process gem to startup a child process [not sure if linux needs something like this, too]
          require 'win32/process'
          require 'ruby-wmi'
          output_file_name = "out_#{@@next_number += 1}_#{Process.pid}.txt"
          output = File.open(output_file_name, 'wb')
          child = Process.create :command_line => _cmd_,  :startup_info => {:stdout => output, :stderr => output}
          
          timer=nil
          procy = proc {
            still_alive = WMI::Win32_Process.find(:first, :conditions => {:ProcessId => child.process_id})
            if(!still_alive)
              output.close
              timer.stop
              File.open(output_file_name, 'r') do |f|
                _readed = f.read
                _readed.strip!
                _readed += "\n" + "Done with #{_filename} in #{Time.now - start_time}s"
                Arcadia.console(self,'msg'=>_readed, 'level'=>'debug')
                _event.add_result(self, 'output'=>_readed)
              end
              File.delete output_file_name
            end
          }

          timer=TkAfter.new(1000,-1,procy) # -1 = repeating every 1000ms...
          timer.start
        else
          _cmd_ = "|#{_cmd_} 2>&1"
          Thread.new {
            begin
              open(_cmd_, "r"){|f|
                _readed = f.read
                Arcadia.console(self,'msg'=>_readed, 'level'=>'debug')
                _event.add_result(self, 'output'=>_readed)
              }
            rescue Exception => e
              Arcadia.console(self,'msg'=>e.to_s, 'level'=>'debug')
            end
          }
        end
      rescue Exception => e
        Arcadia.console(self,'msg'=>e.to_s, 'level'=>'debug')
      end
    end
  end

  def on_system_exec_bo(_event)
    command = "#{_event.command} 2>&1"
    (RUBY_PLATFORM.include?('mswin32'))?_cmd="cmd":_cmd='sh'
    if is_windows?
      Thread.new{
        Arcadia.console(self,'msg'=>'begin', 'level'=>'debug')
        #Arcadia.new_debug_msg(self, 'inizio')
        @io = IO.popen(_cmd,'r+')
        @io.puts(command)
        result = ''
        while line = @io.gets
          result << line
        end
        #Arcadia.new_debug_msg(self, result)
        Arcadia.console(self,'msg'=>result, 'level'=>'debug')

      }
    else
      Process.fork{
        open(_cmd_,"r"){|f|
          Arcadia.console(self,'msg'=>f.read, 'level'=>'debug')
          #Arcadia.new_debug_msg(self, f.read)
        }
      }
    end
  end



  def is_windows?
    !(RUBY_PLATFORM =~ /(win|w)32$/).nil?
    #RUBY_PLATFORM.include?('win')
  end


  def run_last
    run($arcadia['pers']['run.file.last'])
  end

  def run_current
    current_editor = $arcadia['editor'].raised
    run(current_editor.file) if current_editor
  end

  def stop
    @run_threads.each{|t|
      if t.alive?
        t.kill
      end
    }
    debug_quit if @adw
  end

  def run(_filename=nil)
    if _filename
      begin
        @arcadia['pers']['run.file.last']=_filename
        @run_threads << Thread.new do
          _cmd_ = "|"+$arcadia['conf']['shell.ruby']+" "+_filename+" 2>&1"
          #  Arcadia.new_debug_msg(self, _cmd_)
          @cmd = open(_cmd_,"r"){|f|
            Arcadia.console(self, 'msg'=>f.read ,'level'=>'debug')
            #Arcadia.new_debug_msg(self, f.read)
          }
        end
      rescue Exception => e
        Arcadia.console(self, 'msg'=>e ,'level'=>'debug')
        #Arcadia.new_debug_msg(self, e)
      end
    end
  end

end
