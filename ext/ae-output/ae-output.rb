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
  attr_accessor :input_buffer
  def initialize(parent=nil)
    #left_frame = TkFrame.new(parent.frame.hinner_frame, Arcadia.style('panel')).place('x' => '0','y' => '0','relheight' => '1','width' => '25')
    #right_frame = TkFrame.new(parent.frame.hinner_frame, Arcadia.style('panel')).place('x' => '25','y' => '0','relheight' => '1','relwidth' => '1','width' => '-25')
    @auto_open_file = false
    @parent = parent
    parent.frame.root.add_button(
      parent.name,
      Arcadia.text('ext.output.button.clear.hint'),
      proc{parent.main_frame.text.delete('1.0','end')}, 
      CLEAR_GIF)

#----
    @ck = parent.frame.root.add_check_button(
      parent.name,
      Arcadia.text('ext.output.checkbutton.auto_open_file.hint'),
      proc{ @auto_open_file = @ck.cget('onvalue')==@ck.cget('variable').value.to_i},
      GO_UP_GIF)
#---
    @text = TkArcadiaText.new(parent.frame.hinner_frame,
    {'wrap'=>  'none'}.update(Arcadia.style('edit'))
    )
    @text.extend(TkScrollableWidget).show
    @text.extend(TkInputThrow)
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
    @text.tag_configure('system_error_msg',
    'background' => Arcadia.conf('hightlight.system_error.background'),
    'foreground' => Arcadia.conf('hightlight.system_error.foreground'),
    'borderwidth'=>1,
    'relief'=> 'groove'
    )
    @text.tag_configure('info_msg',
    'foreground' => Arcadia.conf('hightlight.edge.foreground')
    )
    @text.tag_configure('prompt',
      'foreground' => Arcadia.conf('hightlight.prompt.foreground')
    )
    @text.tag_configure('sel',
    'background'=>Arcadia.conf('hightlight.sel.background'),
    'foreground'=>Arcadia.conf('hightlight.sel.foreground')
    )
    @text.bind_append("KeyPress", "%K"){|_keysym| input(_keysym)}
    @input_buffer = nil
    pop_up_menu        
  end
  
  def auto_open_file?
    @auto_open_file
  end

  def input(_char)
    case _char
      when 'Return'
        @input_buffer = @text.get("insert linestart","insert").sub(@parent.prompt,'').strip
    end
  end


  def pop_up_menu
    #@pop_up = TkMenu.new(
    @pop_up = Arcadia.wf.menu(
    :parent=>@text,
    :tearoff=>0,
    :title => 'Menu'
    )
    #@pop_up.extend(TkAutoPostMenu)
    #@pop_up.configure(Arcadia.style('menu'))

    @pop_up.insert('end',
    :command,
    :state=>'disabled',
    :label=>Arcadia.text('ext.output.menu.output'),
    :background=>Arcadia.conf('titlelabel.background'),
    :font => "#{Arcadia.conf('menu.font')} bold",
    :hidemargin => true
    )


    #Arcadia.instance.main_menu.update_style(@pop_up)
    @pop_up.insert('end',
    :command,
    :label=>Arcadia.text('ext.output.menu.save'),
    :hidemargin => false,
    :command=> proc{save_as}
    )



    @pop_up.insert('end',
    :command,
    :label=>Arcadia.text('ext.output.menu.wrap'),
    :hidemargin => false,
    :command=> proc{@text.configure('wrap'=>'word');@text.hide_h_scroll}
    )

    @pop_up.insert('end',
    :command,
    :label=>Arcadia.text('ext.output.menu.nowrap'),
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
    @file = Arcadia.save_file_dialog
    #Tk.getSaveFile("filetypes"=>[["Ruby Files", [".rb", ".rbw"]],["All Files", [".*"]]])
    @file = nil if @file == ""  # cancelled
    if @file
      save
    end
  end


end

class Output < ArcadiaExt
  attr_reader :main_frame
  attr_reader :prompt
  MARKSUF='mark-'
#  PROMPT_SIMBOL='$'
  PROMPT_SIMBOL='>'
  def on_before_build(_event)
    #ArcadiaContractListener.new(self, MsgContract, :do_msg_event)
    @tag_seq = 0
    @writing=false
    @prompt_active = false
    @prompt = PROMPT_SIMBOL 
    Arcadia.attach_listener(self, MsgEvent)
    Arcadia.attach_listener(self, InputKeyboardQueryEvent)
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
    self.frame.show if !self.frame.raised?
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
#      TkTextImage.new(@main_frame.text, _index_begin, 'padx'=>0, 'pady'=>0, 'image'=> Arcadia.image_res(ITEM_START_LOG_GIF))
#      sync_insert("end"," +--- #{format_time(_event.time)} ---+\n", 'info_msg')
      sync_insert("end","===== #{format_time(_event.time)} ======\n", 'info_msg')
    end
    if _event.append
      _index_begin = "#{@main_frame.text.index(_index_begin)} - 2 lines lineend"
      _txt = _event.msg
    elsif _event.msg[-1] == "\n"
      _txt = _event.msg
    else
      _txt = "#{_event.msg}\n"
    end
#    if _event.level == 'error'
#      TkTextImage.new(@main_frame.text, _index_begin, 'padx'=>0, 'pady'=>0, 'image'=> TkPhotoImage.new('data' => ERROR_9X9_GIF))
#    end
    #@main_frame.text.insert(_index_begin,_txt, "#{_event.level}_msg")
    sync_insert(_index_begin,_txt, "#{_event.level}_msg")
    _index_end = @main_frame.text.index('end')
    if ['debug','error'].include?(_event.level)
      parse_begin_row = _index_begin.split('.')[0].to_i-2
      parse_end_row = _index_end.split('.')[0].to_i
      parse_debug(parse_begin_row, parse_end_row)
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

  def sync_insert(_index, _txt, _tag=nil)
    begin
      while @writing
        sleep(0.1)
      end
      @writing = true
      if @prompt_active
        start =  @main_frame.text.get("#{_index} -1 lines linestart", _index).strip
        if start == @prompt.strip
          _index = "#{_index} -1 lines linestart"
        end
      end
      if _tag
        @main_frame.text.insert(_index, _txt, _tag)
      else
        @main_frame.text.insert(_index, _txt)
      end
    ensure
      @writing = false
    end
  end

  def on_input_keyboard_query(_event)
    if _event.pid
      @prompt = "~#{_event.pid} #{PROMPT_SIMBOL} "
    end
    @prompt_active = true
    sync_insert("end", @prompt, 'prompt')
    @main_frame.text.focus
    @main_frame.text.see("end")
    prompt_index = @main_frame.text.index("insert")
    @main_frame.input_buffer = nil
    while @main_frame.input_buffer.nil? && !_event.is_breaked?
      sleep(0.1)
    end
    if !_event.is_breaked?
      _event.add_result(self, 'input'=>@main_frame.input_buffer)
      @main_frame.text.tag_add("prompt","#{prompt_index} linestart","#{prompt_index} lineend")
    else
      if @main_frame.text.get("end -1 lines linestart", "end -1 lines lineend").strip == @prompt.strip
        @main_frame.text.delete("end -1 lines linestart", "end -1 lines lineend")
      end
    end
    @main_frame.input_buffer = nil
    @prompt_active = false
  end


  def parse_debug(_from_row=0, _to_row=-1)
    return if _from_row == _to_row
    _row = _from_row
    @cursor = @main_frame.text.cget('cursor')
    file_tag=Hash.new
    if String.method_defined?(:lines)
      lines = @main_frame.text.value.lines.to_a[_from_row.._to_row]
    else
      lines = @main_frame.text.value.to_a[_from_row.._to_row]
    end
    
  #  p "parso "
    
    if lines
      lines.each{|l|
        _row = _row+1
        #if _row >= _from_row
        _end = 0
        #m = /([\.\/]*[\/A-Za-z_\-\.]*[\.\/\w\d]*\.rb):(\d*)/.match(l)
        re = Regexp.new('([\w\:]*[\.\/]*[\/A-Za-z0-9_\-\.\~]*[\.\/\w\d]*[(<<current buffer>>)]*):(\d*)')
        m = re.match(l)
        #m = /([\.\/]*[\/A-Za-z_\-\.]*[\.\/\w\d]*):(\d*)/.match(l)
        while m
          _txt = m.post_match
          if m[1] && m[2]
            _file = m[1]
            if File.exist?(_file) || _file=="<<current buffer>>"  
               _line = m[2]
              _ibegin = _row.to_s+'.'+(m.begin(1)+_end).to_s
              _iend = _row.to_s+'.'+(m.end(2)+_end).to_s
              file_binding(_file, _line, _ibegin, _iend)
            end
            _end = m.end(2) + _end
          end
          m = re.match(_txt)
        end
        #m = re.match(_txt)
        #end
      }
    end
  end
  
  def next_tag_name
    @tag_seq = @tag_seq + 1 
    "tag_#{@tag_seq}"
  end

  def file_binding(_file, _line, _ibegin, _iend)
    if defined?(@file_binding)
      while @file_binding
        sleep(1)
      end
    end
    @file_binding=true
    begin
      if _file == '<<current buffer>>'
        _file = "*CURR"
      end
      _line = '0' if _line.nil? || _line.strip.length == 0
      tag_name = next_tag_name
      @main_frame.text.tag_configure(tag_name,
        'foreground' => Arcadia.conf('hightlight.link.foreground'),
        'borderwidth'=>0,
        'relief'=>'flat',
        'underline'=>true
      )
      @main_frame.text.tag_add(tag_name,_ibegin,_iend)
      #@main_frame.text.tag_bind(tag_name,"Double-ButtonPress-1",
      @main_frame.text.tag_bind(tag_name,"ButtonPress-1",
        proc{OpenBufferTransientEvent.new(self,'file'=>_file, 'row'=>_line).go!}
#        proc{OpenBufferEvent.new(self,'file'=>_file, 'row'=>_line).go!}
      )
      @main_frame.text.tag_bind(tag_name,"Enter",
        proc{@main_frame.text.configure('cursor'=> 'hand2')}
      )
      @main_frame.text.tag_bind(tag_name,"Leave",
        proc{@main_frame.text.configure('cursor'=> @cursor)}
      )
  
      if @main_frame.auto_open_file?
        OpenBufferEvent.new(self,'file'=>_file, 'row'=>_line, 'debug'=>'yes').go!
#        OpenBufferEvent.new(self,'file'=>_file, 'row'=>_line).go!
        self.frame.show
        @main_frame.text.set_focus
        @main_frame.text.see("end")
      end
    ensure
      @file_binding = false
    end
  end

  def out(_txt=nil, _tag=nil)
    if @main_frame && _txt
      sync_insert('end', _txt, _tag)
#      if _tag
#        @main_frame.text.insert('end',_txt, _tag)
#      else
#        @main_frame.text.insert('end',_txt)
#      end
    end
  end

  def outln(_txt=nil, _tag=nil)
    self.out(_txt+"\n",_tag)
  end

end