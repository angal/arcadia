#
#   ae-subprocess-inspector.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "#{Dir.pwd}/lib/anigif"

class SubProcessInspector < ArcadiaExt
	attr_reader :processs
	def on_before_build(_event)
    @processs = [] 
    Arcadia.attach_listener(self, SubProcessEvent)
  end
  
  def on_sub_process(_event)
    #self.frame.show_anyway
    @processs << SubProcessWidget.new(self, _event)
  end
  
  def on_exit_query(_event)
    _event.can_exit=true
    @processs.each{|pr|
      if !pr.nil? 
        message = Arcadia.text("ext.spi.d.exit_query.msg")
        r=Arcadia.hinner_dialog(self,
            'type'=>'yes_no', 
            'level'=>'warning',
            'title'=> Arcadia.text("ext.spi.d.exit_query.title"), 
            'msg'=>message)
        if r=="no"
          _event.can_exit=false
          _event.break
        end
        break   
      end
    }
  end
  
  def on_finalize(_event)
    @processs.each{|pr|
      pr.event.abort_action.call if !pr.nil?
    }
  end
  
  def do_delete_process(_process)
    @processs.delete(_process)
    if @processs.length == 0
      #self.frame.free
    end
  end
      
end

class SubProcessWidget < Tk::BWidget::Button
  attr_reader :event
  def initialize(_parent=nil, _event=nil, *args)
    super(Arcadia['toolbar'].frame, Arcadia.style('button').update("compound"=>'left', "background"=>Arcadia.conf("background"),"activebackground"=>'black', 'relief'=>'groove'))
    @parent = _parent
    @event = _event
    b_command = proc{
      message = Arcadia.text('ext.spi.d.kill.msg', [_event.pid, _event.name])
      r=Arcadia.hinner_dialog(self,
          'type'=>'yes_no', 
          'level'=>'warning',
          'title'=> Arcadia.text('ext.spi.d.kill.title'), 
          'msg'=>message)
      if r=="yes"
        _event.abort_action.call
      end
    }
    command b_command
    begin
      text File.basename(_event.name)
    rescue
      text _event.name
    end  
    helptext "#{_event.name} [pid #{_event.pid}]"
    pack('side' =>'left', :padx=>2, :pady=>0)
    Tk::Anigif.image(self, "#{Dir.pwd}/ext/ae-subprocess-inspector/process.res")
    start_check  
  end
  
  def start_check
    if @event.timecheck
      timecheck = @event.timecheck
    else
      timecheck = 1000
    end
    @timer = TkAfter.new
    proc_check = proc{
      alive = @event.alive_check.call
      #p "ALIVE=#{alive}"
      if !alive
        @timer.stop
        @parent.do_delete_process(self)
        self.destroy
      end
    }
    @timer.set_procs(timecheck,-1,proc_check)
    @timer.start
  end  
end
