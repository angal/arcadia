#
#   ae-shell.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "tk"
#require "base/a-utils"


class Shell < ArcadiaExt

  def on_before_build(_event)
    Arcadia.attach_listener(self, SystemExecEvent)
    #Arcadia.attach_listener(self, RunRubyFileEvent)
    Arcadia.attach_listener(self, RunCmdEvent)
  end

  def on_build(_event)
    @run_threads = Array.new
    @stdout_blocking = self.conf('stdout_blocking') == 'yes' 
    @stderr_blocking = self.conf('stderr_blocking') == 'yes' 
  end

  def on_system_exec(_event)
    begin
      _cmd_ = "#{_event.command}"
      if is_windows?
        io = IO.popen(_cmd_)
        Arcadia.console(self,'msg'=>io.read, 'level'=>'debug')
      else
        Process.fork{
          open(_cmd_,"r"){|f|
            Arcadia.console(self,'msg'=>f.read, 'level'=>'debug')
          }
        }
      end
    rescue Exception => e
      Arcadia.console(self,'msg'=>e, 'level'=>'debug')
    end
  end

#  @@next_number = 0
#  def on_run_ruby_file(_event)
#    _filename = _event.file
#    _filename = @arcadia['pers']['run.file.last'] if _filename == "*LAST"
#    if _filename && File.exists?(_filename)
#      begin
#        Arcadia.console(self,'msg'=>"Running #{_filename}...", 'level'=>'debug') # info?
#        start_time = Time.now
#        @arcadia['pers']['run.file.last']=_filename if _event.persistent
#        executable = @arcadia['conf']['shell.ruby']
#        executable = @arcadia['conf']['shell.rubyw'] if is_windows?
#        _cmd_ = "#{executable} -C'#{File.dirname(_filename)}' '#{_filename}'"
#        
#        if is_windows?
#          # use win32-process gem to startup a child process [not sure if linux needs something like this, too]
#          require 'win32/process'
#          require 'ruby-wmi'
#          output_file_name = "out_#{@@next_number += 1}_#{Process.pid}.txt"
#          output = File.open(output_file_name, 'wb')
#          child = Process.create :command_line => _cmd_,  :startup_info => {:stdout => output, :stderr => output}
#          #----
#          abort_action = proc{
#            Process.kill(9,child.process_id)
#          }
#          alive_check = proc{
#            WMI::Win32_Process.find(:first, :conditions => {:ProcessId => child.process_id})
#          }
#          Arcadia.process_event(SubProcessEvent.new(self,'name'=>_filename,'abort_action'=>abort_action, 'alive_check'=>alive_check))
#          #----
#          timer=nil
#          procy = proc {
#            still_alive = WMI::Win32_Process.find(:first, :conditions => {:ProcessId => child.process_id})
#            if !still_alive #&& File.exists?(output_file_name)
#              output.close
#              timer.stop
#              File.open(output_file_name, 'r') do |f|
#                _readed = f.read
#                _readed.strip!
#                _readed += "\n" + "Done with #{_filename} in #{Time.now - start_time}s"
#                Arcadia.console(self,'msg'=>_readed, 'level'=>'debug')
#                _event.add_result(self, 'output'=>_readed)
#              end
#              File.delete output_file_name
#            end
#          }
#
#          timer=TkAfter.new(1000,-1,procy) # -1 = repeating every 1000ms...
#          timer.start
#        else
#          _cmd_ = "|#{_cmd_} 2>&1"
#          Thread.new {
#            begin
#              th = Thread.current
#              fi = nil
#              fi_pid = nil
#              abort_action = proc{
#                unix_child_pids(fi_pid).each {|pid|
#                  Process.kill(9,pid.to_i)
#                }
#                #Kernel.system("kill -9 #{unix_child_pids(fi_pid).join(' ')} #{fi_pid}") if fi
#              }
#                
#              alive_check = proc{
#                num = `ps -p #{fi_pid}|wc -l`
#                num.to_i > 1
#              }
#              
#              #Arcadia.console(self,'msg'=>"#{th}", 'level'=>'debug', 'abort_action'=>abort_action)
#              open(_cmd_, "r"){|f|
#                fi = f
#                fi_pid = fi.pid
#    	           Arcadia.process_event(SubProcessEvent.new(self,'name'=>_filename,'abort_action'=>abort_action, 'alive_check'=>alive_check))
#                _readed = f.read
#                output_dump="End running #{_filename}:\n#{_readed}"
#                Arcadia.console(self,'msg'=>output_dump, 'level'=>'debug')
#                _event.add_result(self, 'output'=>_readed)
#              }
#              if _event.persistent == false && _filename[-2..-1] == '~~'
#                File.delete(_filename) if File.exist?(_filename)
#              end
#            rescue Exception => e
#              Arcadia.console(self,'msg'=>e.to_s, 'level'=>'debug')
#            end
#          }
#        end
#      rescue Exception => e
#        Arcadia.console(self,'msg'=>e.to_s, 'level'=>'debug')
#      end
#    end
#  end


  @@next_number = 0
  def on_run_cmd(_event)
    if _event.cmd
      begin
        output_mark = Arcadia.console(self,'msg'=>"Running #{_event.title}...", 'level'=>'debug') # info?
        start_time = Time.now
        @arcadia['pers']['run.file.last']=_event.file if _event.persistent
        @arcadia['pers']['run.cmd.last']=_event.cmd if _event.persistent
        if is_windows?
          # use win32-process gem to startup a child process [not sure if linux needs something like this, too]
          require 'win32/process'
          require 'ruby-wmi'
          output_file_name = "out_#{@@next_number += 1}_#{Process.pid}.txt"
          output = File.open(output_file_name, 'wb')
          child = Process.create :command_line => _event.cmd,  :startup_info => {:stdout => output, :stderr => output}
          #----
          abort_action = proc{
            Process.kill(9,child.process_id)
          }
          alive_check = proc{
            WMI::Win32_Process.find(:first, :conditions => {:ProcessId => child.process_id})
          }
          Arcadia.process_event(SubProcessEvent.new(self,'pid'=>child.process_id, 'name'=>_event.file,'abort_action'=>abort_action, 'alive_check'=>alive_check))
          #----
          timer=nil
          procy = proc {
            still_alive = WMI::Win32_Process.find(:first, :conditions => {:ProcessId => child.process_id})
            if !still_alive #&& File.exists?(output_file_name)
              output.close
              timer.stop
              File.open(output_file_name, 'r') do |f|
                _readed = f.read
                _readed.strip!
                _readed += "\n" + "Done with #{_event.title} in #{Time.now - start_time}s"
                output_mark = Arcadia.console(self,'msg'=>_readed, 'level'=>'debug', 'mark'=>output_mark)
                _event.add_result(self, 'output'=>_readed)
              end
              File.delete output_file_name
            end
          }

          timer=TkAfter.new(1000,-1,procy) # -1 = repeating every 1000ms...
          timer.start
        else
          require "open3"
          #_cmd_ = "|#{_event.cmd} 2>&1"
          _cmd_ = _event.cmd
          Thread.new {
            Thread.current.abort_on_exception = true
            begin
#              th = Thread.current
              fi = nil
              fi_pid = nil
              abort_action = proc{
                ArcadiaUtils.unix_child_pids(fi_pid).each {|pid|
                  Process.kill(9,pid.to_i)
                }
                Process.kill(9,fi_pid.to_i)
                #Kernel.system("kill -9 #{unix_child_pids(fi_pid).join(' ')} #{fi_pid}") if fi
              }
                
              alive_check = proc{
                num = `ps -p #{fi_pid}|wc -l` if fi_pid
                num.to_i > 1 && fi_pid
              }
              

              #Arcadia.console(self,'msg'=>"#{th}", 'level'=>'debug', 'abort_action'=>abort_action)

              Open3.popen3(_cmd_){|stdin, stdout, stderr, th|
                fi_pid = th.pid if th
                output_mark = Arcadia.console(self,'msg'=>" [pid #{fi_pid}]", 'level'=>'debug', 'mark'=>output_mark, 'append'=>true)
    	           Arcadia.process_event(SubProcessEvent.new(self, 'pid'=>fi_pid, 'name'=>_event.file,'abort_action'=>abort_action, 'alive_check'=>alive_check))
                
                if stdout  
                  if @stdout_blocking
                    output_dump = stdout.read
                    if output_dump && output_dump.length > 0 
                      output_mark = Arcadia.console(self,'msg'=>output_dump, 'level'=>'error', 'mark'=>output_mark)
                      _event.add_result(self, 'output'=>output_dump)
                    end
                  else
                    stdout.each do |output_dump|
                      output_mark = Arcadia.console(self,'msg'=>output_dump, 'level'=>'debug', 'mark'=>output_mark)
                      _event.add_result(self, 'output'=>output_dump)
                    end
                  end
                end
                
                if stderr
                  if @stderr_blocking
                    output_dump = stderr.read
                    if output_dump && output_dump.length > 0 
                      output_mark = Arcadia.console(self,'msg'=>output_dump, 'level'=>'error', 'mark'=>output_mark)
                      _event.add_result(self, 'output'=>output_dump)
                    end
                  else
                    stderr.each do |output_dump|
                      output_mark = Arcadia.console(self,'msg'=>output_dump, 'level'=>'error', 'mark'=>output_mark)
                      _event.add_result(self, 'output'=>output_dump)
                    end
                  end
                end
              }
              output_mark = Arcadia.console(self,'msg'=>"\nEnd running #{_event.title}:", 'level'=>'debug', 'mark'=>output_mark)


#              open(_cmd_, "r"){|f|
#                fi = f
#                fi_pid = fi.pid
#    	           Arcadia.process_event(SubProcessEvent.new(self,'name'=>_event.file,'abort_action'=>abort_action, 'alive_check'=>alive_check))
#                _readed = f.read
#                
#                #f.each{|line|
#                #  output_mark = Arcadia.console(self,'msg'=>line, 'level'=>'debug', 'mark'=>output_mark)
#                #}
#                #output_mark = Arcadia.console(self,'msg'=>"\nEnd running #{_event.file}:", 'level'=>'debug', 'mark'=>output_mark)
#                
#                output_dump="#{_readed}\nEnd running #{_event.file}:"
#                output_mark = Arcadia.console(self,'msg'=>output_dump, 'level'=>'debug', 'mark'=>output_mark)
#                _event.add_result(self, 'output'=>_readed)
#              }
              #p "da cancellare #{ _event.file } #{_event.file[-2..-1] == '~~'} #{_event.persistent == false}  #{File.exist?(_event.file)}"
              if _event.persistent == false && _event.file[-2..-1] == '~~'
                File.delete(_event.file) if File.exist?(_event.file)
              end
            rescue Exception => e
              output_mark = Arcadia.console(self,'msg'=>e.to_s, 'level'=>'debug', 'mark'=>output_mark)
            end
          }
        end
      rescue Exception => e
        output_mark = Arcadia.console(self,'msg'=>e.to_s, 'level'=>'debug', 'mark'=>output_mark)
      end
    end
  end
  
#  def unix_child_pids(_ppid)
#    ret = Array.new
#    readed = ''
#    open("|ps -o pid,ppid ax | grep #{_ppid}", "r"){|f|  readed = f.read  }
#    apids = readed.split
#    apids.each_with_index do |v,i|
#      ret << v if i % 2 == 0 && v != _ppid.to_s
#    end
#    subpids = Array.new
#    ret.each{|ccp|
#      subpids.concat(unix_child_pids(ccp))
#    }
#    ret.concat(subpids)
#  end
  
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
    RUBY_PLATFORM =~ /mingw|mswin/
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