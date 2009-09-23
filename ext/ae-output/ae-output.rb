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
    
    @text = TkScrollText.new(right_frame,
      {'wrap'=>  'none'}.update(Arcadia.style('edit'))
    )
    @text.show
    @text.show_v_scroll
    @text.show_h_scroll

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
       'foreground' => 'red',
       'borderwidth'=>1,
       'relief'=> 'flat'
    )

    @text.tag_configure('bord_msg',
       #'foreground' => '#b9b8b9'
       'foreground' => '#7c9b10'
    )
    @text.tag_configure('sel', 
      'background'=>parent.conf('hightlight.sel.color.background'),
      'foreground'=>parent.conf('hightlight.sel.color.foreground')
    )
    pop_up_menu
  end

  def pop_up_menu
    @pop_up = TkMenu.new(
      :parent=>@text,
      :tearoff=>0,
      :title => 'Menu'
    )
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
      #EditorContract.instance.file_saved(self,'file' =>@file)
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
     _txt = "\n+--- "+format_time(_event.time)+" ---+\n"+_event.msg.strip+"\n"
     _index_begin = @main_frame.text.index('end')
     @main_frame.text.insert(_index_begin,_txt)
     _index_end = @main_frame.text.index('end')
     case _event.level
       when 'debug'
       		@main_frame.text.tag_remove('simple_msg',_index_begin, _index_end+ '  lineend')
       		@main_frame.text.tag_remove('error_msg',_index_begin, _index_end+ '  lineend')
       		@main_frame.text.tag_add('debug_msg',_index_begin, _index_end+ '  lineend')
       		parse_debug(_index_begin.split('.')[0].to_i) 
       when 'error'
       		@main_frame.text.tag_remove('simple_msg',_index_begin, _index_end+ '  lineend')
       		@main_frame.text.tag_remove('debug_msg',_index_begin, _index_end+ '  lineend')
       		@main_frame.text.tag_add('error_msg',_index_begin, _index_end+ '  lineend')
       		parse_debug(_index_begin.split('.')[0].to_i) 
       else
       		@main_frame.text.tag_remove('error_msg',_index_begin, _index_end+ '  lineend')
       		@main_frame.text.tag_remove('debug_msg',_index_begin, _index_end+ '  lineend')
       		@main_frame.text.tag_add('simple_msg',_index_begin, _index_end+ '  lineend')
     end
   		@main_frame.text.tag_add('bord_msg',_index_begin+' linestart', _index_begin+ '  lineend')
   		@main_frame.text.tag_add('bord_msg',_index_end+' -1 lines linestart', _index_end+ ' -1 lines  lineend')
   		@main_frame.text.see(_index_end)
   end
  
	def parse_debug(_from_row=0)
    _row = 0
    @cursor = @main_frame.text.cget('cursor')
    @j=0
    file_tag=Hash.new
    if String.method_defined?(:lines)
	lines = @main_frame.text.value.lines
    else
	lines = @main_frame.text.value
    end
    lines.each{|l|
      _row = _row+1
      if _row >= _from_row
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
     end
    }
	end

  def file_binding(_file, _line, _ibegin, _iend)
      tag_name = "tag_#{@j}"
      @main_frame.text.tag_configure(tag_name,
        'foreground' => '#800000',
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
