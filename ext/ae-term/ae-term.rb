#
#   ae-term.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=..
#   &require_omissis=../lib/a-commons


class Term < ArcadiaExtPlus
  def on_before_build(_event)
    @has_xterm = !Arcadia.which("xterm").nil?
    @has_xdotool = !Arcadia.which("xdotool").nil?
    @can_run = @has_xterm || Arcadia.is_windows? 
    if !Arcadia.is_windows?
      if !@has_xterm
        msg = Arcadia.text("ext.term.dependences_missing.xterm.msg")
        ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE,"title"=>Arcadia.text("ext.term.dependences_missing.xterm.title"), "detail"=>msg).go!
      end
      if !@has_xdotool
        msg = Arcadia.text("ext.term.dependences_missing.xdotool.msg")
        ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE,"title"=>Arcadia.text("ext.term.dependences_missing.xdotool.title"), "detail"=>msg).go!
      end
    end
  end
  
  def on_build(_event)
    if main_instance? && @can_run
      Arcadia.attach_listener(self, TermEvent)
    end
  end  
  
  def on_initialize(_event)
    # called at startup
    return if Arcadia.is_windows?
    @xterm_pid = -1
    @finalizing = false
    @bind_after_run = false
    if conf("create") == "yes" && @has_xterm && @has_xdotool
      frame
      Thread.new{
        do_run_xterm(conf('dir'))
        do_after_run_xterm
      }
    end
  end
  
  def on_finalize(_event)
    return if Arcadia.is_windows?
    @finalizing = true
    killall_xterm if @has_xterm && @has_xdotool
  end  
  
  def killall_xterm
    return if !@has_xdotool
    fi_pids_string = open("|xdotool search --class #{xterm_class} "){|f|  f.read.strip }
    if fi_pids_string && fi_pids_string.length > 0
      fi_pids_array = fi_pids_string.split
      fi_pids_array.each{|fi_pid| system("xdotool windowkill #{fi_pid}")
        #p "KILLO XTERM #{xterm_class} pid #{fi_pid}"
      }
      #Arcadia.runtime_error_msg("kill per #{xterm_class} #{ fi_pids_string }")
    end
  end
  
  def do_after_run_xterm
    if !@bind_after_run
      @bind_after_run = true
      frame.hinner_frame.bind_append("Configure", proc{|w,h| resize(w,h)}, "%w %h")
      frame.hinner_frame.bind_append("Map", proc{do_run_xterm(conf('dir')) if !xterm_running?})
    end 
  end
  
  def xterm_class
    "xarc#{instance_index}"
  end
  
  def do_run_xterm(_dir='~')
    return if @running
    @running = true
    killall_xterm
    self.frame.show_anyway
    conf("create",'yes')
    conf("dir",_dir)
    id_int = eval(frame.hinner_frame.winfo_id).to_i
    
    #Arcadia.runtime_error_msg("CREO XTERM #{xterm_class} con id #{id_int}")
    cmd = "cd #{_dir} ; xterm -into #{id_int} -bg '#{conf('color.bg')}' -fg #{conf('color.fg')} -fa '#{conf('font')}' -class #{xterm_class}  +sb  +hold"
    fi_pid=-1
    Thread.new do
      #open("|#{cmd}"){|f|  @xterm_pid = f.read.strip if f }
      system(cmd)
      @xterm_pid = -1
      if !@finalizing
        do_xterm_exit
      end
    end
    maxtimes = 100
    t=0
    while  (@xterm_pid == -1 || @xterm_pid.nil? || @xterm_pid.length == 0) && t < maxtimes 
      open("|xdotool search --limit 1 --class #{xterm_class} "){|f|  fi_pid = f.read.strip if f }
      @xterm_pid = fi_pid
      t=t+1
    end
    #Arcadia.runtime_error_msg("assegno al xterm #{xterm_class} xterm_pid #{@xterm_pid}")
    resize()
    @running = false
  end
  
  def xterm_running?
    @xterm_pid != -1
  end
  
  def do_xterm_exit
    if main_instance?
      conf("create",'no')
#      hide_frame
      clean_instance
    else
      clean_instance
    end
  end
  
  def resize(w=nil,h=nil)
    return if !@has_xdotool
    if @xterm_pid != -1
      w = TkWinfo.width(frame.hinner_frame) if w.nil?
      h = TkWinfo.height(frame.hinner_frame) if h.nil?
      cmd = "xdotool windowsize #{@xterm_pid} #{w} #{h}"
      system(cmd) 
    end
  end
  
  def do_run_external_term(_dir)
    if Arcadia.is_windows?
      system("cd #{_dir} & start cmd")
    else
      system("cd #{_dir}; xterm &")
    end
  end
  
  def on_term(_event)
    if !@has_xdotool || Arcadia.is_windows?
      do_run_external_term(_event.dir)
    else 
      if xterm_running?
        saved_main_conf = conf('create')
        conf("create",'no')
        new_instance = duplicate
        conf("create",saved_main_conf)
        if !new_instance.xterm_running?
          new_instance.frame
          Thread.new{
            new_instance.do_run_xterm(_event.dir)
            new_instance.do_after_run_xterm
          } 
        end
      else
        frame
        Thread.new{
          do_run_xterm(_event.dir)
          do_after_run_xterm
        }
      end
    end
  end
  
end