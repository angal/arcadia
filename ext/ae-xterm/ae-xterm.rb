

class XTerm < ArcadiaExtPlus
  def on_before_build(_event)
    @has_xterm = !Arcadia.which("xterm").nil?
    @has_xdotool = !Arcadia.which("xdotool").nil?
    if !@has_xterm
      msg = "\"xterm\" application is required by XTerm, without it integrazione with terminal isn't supported!" 
      ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE,"title"=>"xterm missing!", "detail"=>msg).go!
    end
    if !@has_xdotool
      msg = "\"xdotool\" application is required by XTerm, without it integrazione with terminal isn't supported!" 
      ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE,"title"=>"xdotool missing!", "detail"=>msg).go!
    end
  end
  
  def on_build(_event)
    if main_instance? && @has_xterm && @has_xdotool
      Arcadia.attach_listener(self, XtermEvent)
    end
  end  
  
  def on_initialize(_event)
    # called at startup
    @xterm_pid = -1
    @finalizing = false
    @bind_after_run = false
    if conf("create") == "yes"
      Thread.new{
        do_run_xterm(conf('dir'))
        do_after_run_xterm
      }
    end
  end
  
  def on_finalize(_event)
    @finalizing = true
    killall_xterm
#    if @xterm_pid !=  -1
#      cmd = "xdotool windowkill #{@xterm_pid}"
#      system(cmd) 
#    end
  end  
  
  def killall_xterm
    fi_pids_string = open("|xdotool search --class #{xterm_class} "){|f|  f.read.strip }
    if fi_pids_string
      fi_pids_array = fi_pids_string.split
      fi_pids_array.each{|fi_pid| system("xdotool windowkill #{fi_pid}")
        p "KILLO XTERM #{xterm_class} pid #{fi_pid}"
      }
    end
  end
  
  def do_after_run_xterm
    if !@bind_after_run
      @bind_after_run = true
      frame.hinner_frame.bind_append("Configure", proc{|w,h| p "CONFIGURE";  resize(w,h)}, "%w %h")
      frame.hinner_frame.bind_append("Map", proc{p "MAPPO"; do_run_xterm(conf('dir')) if !xterm_runned?})
    end 
  end
  
  def xterm_class
    "xarc#{instance_index}"
  end
  
  def do_run_xterm(_dir='~')
    return if @running
    @running = true
    conf("create",'yes')
    conf("dir",_dir)
    self.frame.show_anyway
    killall_xterm
    id_int = eval(frame.hinner_frame.winfo_id).to_i
    p "CREO XTERM #{xterm_class} con id #{id_int}"
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
    while  @xterm_pid == -1 && t < maxtimes 
      open("|xdotool search --limit 1 --class #{xterm_class} "){|f|  fi_pid = f.read.strip if f }
      @xterm_pid = fi_pid
      t=t+1
    end
    resize()
    @running = false
#    frame.hinner_frame.bind_append("Configure", proc{|w,h| resize(w,h)}, "%w %h")
#    frame.hinner_frame.bind_append("Map", proc{ do_run_xterm(conf('dir'),instance_index) if !xterm_runned?}) 
  end
  
  def xterm_runned?
    @xterm_pid != -1
  end
  
  def do_xterm_exit
    if main_instance?
      conf("create",'no')
      hide_frame
    else
      clean_instance
    end
  end
  
  def resize(w=nil,h=nil)
    if @xterm_pid != -1
      w = TkWinfo.width(frame.hinner_frame) if w.nil?
      h = TkWinfo.height(frame.hinner_frame) if h.nil?
      cmd = "xdotool windowsize #{@xterm_pid} #{w} #{h}"
      system(cmd) 
    end
  end
  
  def on_xterm(_event)
    if xterm_runned?
      saved_main_conf = conf('create')
      conf("create",'no')
      new_instance = duplicate(_event.title)
      conf("create",saved_main_conf)
      if !new_instance.xterm_runned?
        Thread.new{
          new_instance.do_run_xterm(_event.dir)
          new_instance.do_after_run_xterm
        } 
      end
    else
      Thread.new{
        do_run_xterm(_event.dir)
        do_after_run_xterm
      }
    end
  end
  
end