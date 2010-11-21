#
#   ae-output.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=../..
#   &require_omissis=conf/arcadia.init
#   &require_omissis=lib/a-commons

require "tk"
#require "base/a-utils"

class OutputView
  attr_reader :text
  def initialize(parent=nil)
    left_frame = TkFrame.new(parent.frame.hinner_frame, Arcadia.style('panel')).place('x' => '0','y' => '0','relheight' => '1','width' => '25')
    right_frame = TkFrame.new(parent.frame.hinner_frame, Arcadia.style('panel')).place('x' => '25','y' => '0','relheight' => '1','relwidth' => '1','width' => '-25')

    @button_u = Tk::BWidget::Button.new(left_frame, Arcadia.style('toolbarbutton')){
      image  TkPhotoImage.new('dat' => CLEAR_GIF)
      helptext 'Clear'
      #foreground 'blue'
      command proc{parent.main_frame.text.delete('1.0','end')}
      #relief 'groove'
      pack('side' =>'top', 'anchor'=>'n',:padx=>0, :pady=>0)
    }
    
    @text = TkArcadiaText.new(right_frame,
      {'wrap'=>  'none'}.update(Arcadia.style('edit'))
    )
    @text.extend(TkScrollableWidget).show

    @text.tag_configure('simple_msg',
    #   'background' => '#d9d994',
       'borderwidth'=>1,
       'relief'=> 'flat'
    )
    @text.tag_configure('debug_msg',
    #   'background' => '#f6c9f6',
    #   'foreground' => '#000000',
       'borderwidth'=>1,
       'relief'=> 'flat'
    )
    @text.tag_configure('error_msg',
     #  'background' => '#f6c9f6',
       'foreground' => Arcadia.conf('hightlight.string.foreground'),
       'borderwidth'=>1,
       'relief'=> 'flat'
    )
    @text.tag_configure('bord_msg',
       #'foreground' => '#b9b8b9'
       'foreground' => Arcadia.conf('hightlight.comment.foreground')
    )
    @text.tag_configure('sel', 
      'background'=>Arcadia.conf('hightlight.sel.background'),
      'foreground'=>Arcadia.conf('hightlight.sel.foreground')
    )
    pop_up_menu
  end

  def pop_up_menu
    @pop_up = TkMenu.new(
      :parent=>@text,
      :tearoff=>0,
      :title => 'Menu'
    )
    @pop_up.extend(TkAutoPostMenu)
    @pop_up.configure(Arcadia.style('menu'))
    
    @pop_up.insert('end',
      :command,
      :state=>'disabled',
      :label=>'Output',
      :background=>Arcadia.conf('titlelabel.background'),
      :font => "#{Arcadia.conf('menu.font')} bold",
      :hidemargin => true
    )

    
    #Arcadia.instance.main_menu.update_style(@pop_up)
    @pop_up.insert('end',
      :command,
      :label=>'Save',
      :hidemargin => false,
      :command=> proc{save_as}
    )



    @pop_up.insert('end',
      :command,
      :label=>'Set wrap',
      :hidemargin => false,
      :command=> proc{@text.configure('wrap'=>'word');@text.hide_h_scroll}
    )

    @pop_up.insert('end',
      :command,
      :label=>'Set no wrap',
      :hidemargin => false,
      :command=> proc{@text.configure('wrap'=>'none');@text.show_h_scroll}
    )



    
    @text.bind("Button-3",
      proc{|x,y|
        _x = TkWinfo.pointerx(@text)
        _y = TkWinfo.pointery(@text)
        @pop_up.popup(_x,_y)
      },
    "%x %y")
  end

  def save
    if !@file
      save_as
    else
      f = File.new(@file, "w")
      begin
        if f
          f.syswrite(@text.value)
        end
      ensure
        f.close unless f.nil?
      end
    end
  end

  def save_as
    @file = Tk.getSaveFile("filetypes"=>[["Ruby Files", [".rb", ".rbw"]],["All Files", [".*"]]])
    @file = nil if @file == ""  # cancelled
    if @file
      save
    end
  end

  
end

class Output < ArcadiaExt
  attr_reader :main_frame
  MARKSUF='mark-'
	def on_before_build(_event)
    #ArcadiaContractListener.new(self, MsgContract, :do_msg_event)
    Arcadia.attach_listener(self, MsgEvent)
    #_frame = @arcadia.layout.register_panel('_rome_',@name, 'Output')
    @main_frame = OutputView.new(self)
    @run_threads = Array.new
	end


  def on_after_build(_event)
    self.frame.show
  end

	def format_time(_time)
	  _time.strftime("at %a %d-%b-%Y %H:%M:%S")
	end
  
   def on_msg(_event)
     self.frame.show
     if _event.mark
       _mark_index = _event.mark.sub(MARKSUF,'');
       _index_begin = "#{_mark_index} + 1 lines + 1 chars"
       #_index_begin = "#{@main_frame.text.index(_event.mark)} + 1 lines + 1 chars"
#       _b = Tk::BWidget::Button.new(@main_frame.text, 
#         'helptext'=>Time.now.strftime("-> %d-%b-%Y %H:%M:%S"),
#         'background'=>Arcadia.style('edit')['background'], 
#         'borderwidth'=>0,
#         'image'=> TkPhotoImage.new('data' => ITEM_LOG_GIF),
#         'relief'=>'flat')
#       TkTextWindow.new(@main_frame.text, _index_begin, 'window'=> _b)
#       TkTextImage.new(@main_frame.text, _index_begin, 'padx'=>0, 'pady'=>0, 'image'=> TkPhotoImage.new('data' => ITEM_LOG_GIF))
     else
       @main_frame.text.insert("end","\n")
       _index_begin = @main_frame.text.index('end')
       TkTextImage.new(@main_frame.text, _index_begin, 'padx'=>0, 'pady'=>0, 'image'=> TkPhotoImage.new('data' => ITEM_START_LOG_GIF))
       @main_frame.text.insert("end"," +--- #{format_time(_event.time)} ---+\n", 'bord_msg')
     end
     if _event.append
       _index_begin = "#{@main_frame.text.index(_index_begin)} - 2 lines lineend"
       _txt = _event.msg
     elsif _event.msg[-1] == "\n"
       _txt = _event.msg
     else
       _txt = "#{_event.msg}\n"
     end
     if _event.level == 'error'
       TkTextImage.new(@main_frame.text, _index_begin, 'padx'=>0, 'pady'=>0, 'image'=> TkPhotoImage.new('data' => ERROR_9X9_GIF))
     end
     @main_frame.text.insert(_index_begin,_txt, "#{_event.level}_msg")
     _index_end = @main_frame.text.index('end')
     if ['debug','error'].include?(_event.level)
       parse_debug(_index_begin.split('.')[0].to_i, _index_end.split('.')[0].to_i)
   		end
   		@main_frame.text.see(_index_end)
   		@main_frame.text.mark_unset(_event.mark)
   		_event.mark="#{MARKSUF}#{_index_end}"
   		@main_frame.text.mark_set(_event.mark, "#{_index_end} - 1 lines -1 chars")
#     if _event.instance_of?(MsgRunEvent)
#       _b = TkButton.new(@main_frame.text, 
#         'command'=>proc{_event.abort_action.call;_b.destroy},
#         'image'=> TkPhotoImage.new('data' => CLOSE_GIF),
#         'relief'=>'groove')
#       TkTextWindow.new(@main_frame.text, 'end', 'window'=> _b)
#     end
   end
  
	def parse_debug(_from_row=0, _to_row=-1)
    return if _from_row == _to_row
    _row = _from_row
    @cursor = @main_frame.text.cget('cursor')
    @j=0
    file_tag=Hash.new
    if String.method_defined?(:lines)
      lines = @main_frame.text.value.lines.to_a[_from_row.._to_row]
    else
      lines = @main_frame.text.value.to_a[_from_row.._to_row]
    end
    lines.each{|l|
      _row = _row+1
      #if _row >= _from_row
        _end = 0
        #m = /([\.\/]*[\/A-Za-z_\-\.]*[\.\/\w\d]*\.rb):(\d*)/.match(l)
        re = Regexp.new('([\w\:]*[\.\/]*[\/A-Za-z_\-\.]*[\.\/\w\d]*):(\d*)')
        m = re.match(l)
        #m = /([\.\/]*[\/A-Za-z_\-\.]*[\.\/\w\d]*):(\d*)/.match(l)
        while m
          _txt = m.post_match
          if m[1] && m[2]
            _file = m[1]
            if File.exist?(_file)
              @j=@j+1
              _line = m[2]
              _ibegin = _row.to_s+'.'+(m.begin(1)+_end).to_s
              _iend = _row.to_s+'.'+(m.end(2)+_end).to_s
              file_binding(_file, _line, _ibegin, _iend)              
            end
            _end = m.end(2) + _end
  

         end
      	  m = re.match(_txt)
       end
     #end
    }
	end

  def file_binding(_file, _line, _ibegin, _iend)
      _line = '0' if _line.nil? || _line.strip.length == 0
      tag_name = "tag_#{@j}"
      @main_frame.text.tag_configure(tag_name,
        'foreground' => Arcadia.conf('hightlight.link.foreground'),
        'borderwidth'=>0,
        'relief'=>'flat',
        'underline'=>true
      )
      @main_frame.text.tag_add(tag_name,_ibegin,_iend)
      @main_frame.text.tag_bind(tag_name,"Double-ButtonPress-1",
        proc{
          Arcadia.process_event(OpenBufferTransientEvent.new(self,'file'=>_file, 'row'=>_line))
        }
      )
      @main_frame.text.tag_bind(tag_name,"Enter",
        proc{@main_frame.text.configure('cursor'=> 'hand2')}
      )
      @main_frame.text.tag_bind(tag_name,"Leave",
        proc{@main_frame.text.configure('cursor'=> @cursor)}
      )
   
  end

  def out(_txt=nil, _tag=nil)
    if @main_frame && _txt
      if _tag
        @main_frame.text.insert('end',_txt, _tag)
      else
        @main_frame.text.insert('end',_txt)
      end
    end
  end

  def outln(_txt=nil, _tag=nil)
    self.out(_txt+"\n",_tag)
  end

end