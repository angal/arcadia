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
    super(Arcadia['toolbar'].frame, Arcadia.style('button').update("compound"=>'left', "background"=>'black',"activebackground"=>'black', 'relief'=>'groove'))
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


#class SubProcessWidget < TkFrame
#  attr_reader :event
#  def initialize(_parent=nil, _event=nil, *args)
#    super(_parent.frame.hinner_frame, Arcadia.style('panel'))
#    @parent = _parent
#    @event = _event
#    @progress  = TkVariable.new
#    @pb = Tk::BWidget::ProgressBar.new(
#      self, Arcadia.style('progress').update({
#        :variable=>@progress, 
#        :type=>'infinite', 
#        :maximum=>500})).place('width'=>-30,'relwidth' => '1','x' => 0,'y' => 2,'height' => 18)
#      #.pack('side' =>'left','fill'=>'x')
#
#      icon_button = TkButton.new(@pb){
#        background Arcadia.style('panel')['background']
#        relief 'flat'
#        image Arcadia.file_icon(_event.name)
#      }.pack
#      
#      b_command = proc{
#        message = "Really kill pid #{_event.pid} #{_event.name} ?"
#        r=Arcadia.dialog(self,
#            'type'=>'yes_no', 
#            'level'=>'warning',
#            'title'=> 'Confirm kill', 
#            'msg'=>message)
#        if r=="yes"
#          _event.abort_action.call
#        end
#      }
#      
#      
#    _b = Tk::BWidget::Button.new(self, 
#    #_b = TkButton.new(self, 
#         'command'=>b_command,
#         'borderwidth'=>0,
#         'background'=>Arcadia.conf('background'),
#         'helptext'=>"#{_event.name} [pid #{_event.pid}]",
#         'image'=> TkPhotoImage.new('data' => PROCESS_KILL_GIF),
#         'relief'=>'flat').pack('side' =>'right','padx'=>0)
#         #.pack('side' =>'left','padx'=>5)
#         #.place('x' => 2, 'width'=>20)
#    pack('side' =>'top','anchor'=>'nw','fill'=>'x','padx'=>5, 'pady'=>5)
#      #place('relwidth' => '1')
#    start_check  
#  end
#  
#  def start_check
#    @progress.numeric=0
#    if @event.timecheck
#      timecheck = @event.timecheck
#    else
#      timecheck = 1000
#    end
#    @timer = TkAfter.new
#    proc_check = proc{
#      alive = @event.alive_check.call
#      #p "ALIVE=#{alive}"
#      if !alive
#        @timer.stop
#        @parent.do_delete_process(self)
#        self.destroy
#      end
#      @progress.numeric += 1
#    }
#    @timer.set_procs(timecheck,-1,proc_check)
#    @timer.start
#  end  
#end