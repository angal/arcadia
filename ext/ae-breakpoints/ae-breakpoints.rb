#
#   ae-breakpoints.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

class Breakpoints < ArcadiaExt
  def on_before_build(_event)
    @ui_builded = false
    @breakpoints =Array.new
    Arcadia.attach_listener(self, DebugEvent)
  end

  def on_build(_event)
     build_ui 
#    load_persistent_breakpoints
  end
  
  def on_initialize(_event)
    load_persistent_breakpoints
  end  
  
  def on_finalize(_event)
    _breakpoints = '';
    @breakpoints.each{|point|
      if point[:file] != nil
        _breakpoints=_breakpoints+'|' if _breakpoints.strip.length > 0
        _breakpoints=_breakpoints + "#{point[:file]}@@@#{point[:line]}@@@#{point[:active]}"
      end
    }
    Arcadia.persistent('breakpoints', _breakpoints)
  end

  def load_persistent_breakpoints
    b = Arcadia.persistent('breakpoints')
    if b
      _files_list =b.split("|")
      _files_list.each do |value| 
        _file,_line,_active = value.split('@@@')
        if _file && _line && _active
          Arcadia.process_event(SetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_line, 'active'=>_active.to_i))
        end
      end
    end
  end


  def ensure_build_ui
    if !@ui_builded
      build_ui
    end
  end  

  def build_ui
    @tree_break = BWidgetTreePatched.new(self.frame.hinner_frame, Arcadia.style('treepanel')){
      #showlines true
      deltay 18
      padx 25
      #selectcommand proc{ do_select_item.call(self) } 
    }.place('relwidth' => 1,'relheight' => '1')
    build_popup
    @ui_builded = true
  end


  def unbuild_ui
    if @ui_builded
     
      @ui_builded = false
    end
  end
  
  def goto_select_item
    _file, _line = get_tree_selection
    if _file && _line
      Arcadia.process_event(OpenBufferEvent.new(self,'file'=>_file, 'row'=>_line))
    elsif _file
      Arcadia.process_event(OpenBufferEvent.new(self,'file'=>_file, 'row'=>0))
    end
  end

  def clear_node(_file=nil, _line=nil, _delete=false)
    if _file && _line
       Arcadia.process_event(UnsetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_line, 'delete'=>_delete))
    elsif _file
       _node_name = file2node_name(_file)
       sons = @tree_break.nodes(_node_name)
       if sons
         sons.each{|son|
           _nil, _l = son.split('_')
           Arcadia.process_event(UnsetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_l, 'delete'=>_delete)) if _l
         }
      end
    end
  end
  
  def raise_clear_selected(_delete=false)
    _file, _line = get_tree_selection
    clear_node(_file, _line, _delete)
  end

  def clear_all(_delete=false)
    nodes = @tree_break.nodes('root')
    nodes.each{|n|
      _file, _line = node2file_line(n)
      clear_node(_file, _line, _delete)
    }
  end
  
  def build_popup
    _pop_up = TkMenu.new(
      :parent=>@tree_break,
      :tearoff=>0,
      :title => 'Menu'
    )
    _pop_up.extend(TkAutoPostMenu)
    _pop_up.configure(Arcadia.style('menu'))
    _title_item = _pop_up.insert('end',
      :command,
      :label=>'...',
      :state=>'disabled',
      :background=>Arcadia.conf('titlelabel.background'),
      :hidemargin => true
    )

    _pop_up.insert('end',
      :command,
      :label=> Arcadia.text('ext.breakpoints.menu.clear_selected'),
      :hidemargin => false,
      :command=> proc{raise_clear_selected}
    )

    _pop_up.insert('end',
      :command,
      :label=> Arcadia.text('ext.breakpoints.menu.delete_selected'),
      :hidemargin => false,
      :command=> proc{raise_clear_selected(true)}
    )

    _pop_up.insert('end',
      :command,
      :label=> Arcadia.text('ext.breakpoints.menu.delete_all'),
      :hidemargin => false,
      :command=> proc{clear_all(true)}
    )

    _pop_up.insert('end',
      :command,
      :label=>Arcadia.text('ext.breakpoints.menu.goto_selected'),
      :hidemargin => false,
      :command=> proc{goto_select_item}
    )


    @tree_break.textbind_append("Button-3",
      proc{|*x|
        _x = TkWinfo.pointerx(@tree_break)
        _y = TkWinfo.pointery(@tree_break)
        #_selected = @tree_break.selection_get[0]
        _selected = @tree_break.selected
        _file, _line = get_tree_selection
        _label = _file
        if _line
          _label << " line: #{_line}"
        end
        _pop_up.entryconfigure(0,'label'=>_label)

        _pop_up.popup(_x,_y)
      })
  end
  
  def get_tree_selection
    #_selected = @tree_break.selection_get[0]
    _selected = @tree_break.selected
    if _selected
      return node2file_line(_selected)
    else
      return Array.new
    end
  end

  def node2file_line(_node)
    _ret = Array.new
    _node_name, _line = _node.split('_')
    _ret << @tree_break.itemcget(_node_name, 'text')
    _ret << _line if _line
    _ret
  end

  def on_debug(_event)
    return if _event.file.nil?
    case _event
      when SetBreakpointEvent
        ensure_build_ui
        @breakpoints.delete_if{|b| (b[:file]==_event.file && b[:line]==_event.row)}
        @breakpoints << {:file=>_event.file,:line=>_event.row, :active=>_event.active}
        self.breakpoint_add(File.expand_path(_event.file), _event.row, _event.line_code, _event.active==1)
      when UnsetBreakpointEvent
        if @ui_builded
          if _event.delete
            @breakpoints.delete_if{|b| (b[:file]==_event.file && b[:line]==_event.row)}
          else
            @breakpoints.collect! {|b| 
              if b[:file]==_event.file && b[:line]==_event.row
                b[:active]=0
              end
              b
            } 
          end
          self.breakpoint_del(File.expand_path(_event.file), _event.row, _event.delete)
          #self.breakpoint_del(File.expand_path(_event.file), _event.row, _event.sender != self)
        end
    end
  end
  
  def on_debug_step_info(_event)
    #Arcadia.console(self, :msg=> "ae-breakpoints -> DebugStepInfoEvent")
    if @ui_builded
      self.breakpoint_select(_event.file, _event.row)
    end
  end

  def file2node_name(_file)
    _file = File.expand_path(_file)
    #_file = File.basename(_file)
    _s = ""
    _file.gsub("_",_s).gsub("/",_s).gsub(".",_s).gsub(":",_s).gsub("\\",_s).gsub("-",_s)
  end

  def new_check_button(_node_name, _value=1)
    _command = proc {|_checkbutton|
      _file_node_name, _line = _node_name.split('_')
      _file = @tree_break.itemcget(_file_node_name, 'text')
      if _checkbutton.cget('variable').value.to_i==0
        if _file && _line
          Arcadia.process_event(UnsetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_line))
        elsif _file
          sons = @tree_break.nodes(_node_name)
          if sons
             sons.each{|son|
                _nil, _l = son.split('_')
                Arcadia.process_event(UnsetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_l)) if _l
             }
          end
        end
      else
        if _file && _line
          Arcadia.process_event(SetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_line, 'active'=>1))
        elsif _file
          sons = @tree_break.nodes(_node_name)
          if sons
             sons.each{|son|
                _nil, _l = son.split('_')
                Arcadia.process_event(SetBreakpointEvent.new(self, 'file'=>_file, 'row'=>_l, 'active'=>1)) if _l
             }
          end
        end
        
      end
    } 
    TkCheckButton.new(@tree_break, Arcadia.style('checkbox')){
      #text _label
      indicatoron  true
      padx 0
      pady 0
      variable TkVariable.new(_value)
      background   Arcadia.style('treepanel')['background']
      borderwidth 0
      command proc{_command.call(self)}
      relief 'flat'
    }
#    _item_on_img = TkPhotoImage.new('dat' => ON_GIF)
#    @item_off_img = TkPhotoImage.new('dat' => OFF_GIF)
#    @b_item_onoff = TkButton.new(@tree_break, Arcadia.style('button')){
#        image  _item_on_img
#        anchor 'nw'
#    }.bind("1",proc{   })
  end
  
  def line2node_name(_parent, _line)
    "#{_parent}_#{_line.to_s}"
  end
  
  def breakpoint_add(_file,_line, _code, _active=true)
    _file_node = file2node_name(_file) 
    _line_node = line2node_name(_file_node, _line)
    (_active)?_check_value=1 : _check_value=0
    if !@tree_break.exist?(_file_node)
      @tree_break.insert('end', 'root' ,_file_node, {
        'open'=>true,
        'anchor'=>'w',
        'text' =>  _file,
        'deltax'=>-1,
        'window' => new_check_button(_file_node, _check_value)
      }.update(Arcadia.style('treeitem')))
    elsif _active
      _check = @tree_break.itemcget(_file_node, 'window')
      _check.cget('variable').value=1
    end
    
    if !@tree_break.exist?(_line_node)
      @tree_break.insert('end', _file_node ,_line_node, {
        'open'=>true,
        'anchor'=>'w',
        'text' =>  "line: #{_line} --> #{_code}",
        'deltax'=>-1,
        'window' => new_check_button(_line_node, _check_value)
      }.update(Arcadia.style('treeitem')))
      @tree_break.reorder(_file_node,@tree_break.nodes(_file_node).sort)
    elsif _active
      _check = @tree_break.itemcget(_line_node, 'window')
      _check.cget('variable').value=1 
    end
  end

  def breakpoint_del(_file,_line, _delete=false)
    _file_node = file2node_name(_file) 
    _line_node = line2node_name(_file_node, _line)
    if @tree_break.exist?(_line_node)
      begin
        if _delete
          _sc = @tree_break.cget('selectcommand')
          @tree_break.configure('selectcommand'=>nil)
          @tree_break.delete(_line_node)
        else
          _check = @tree_break.itemcget(_line_node, 'window')
          _check.cget('variable').value=0 
        end
        _bro = @tree_break.nodes(_file_node)
        if _bro.nil? || _bro.length == 0 
          if _delete
            @tree_break.delete(_file_node) 
          else
            _check = @tree_break.itemcget(_file_node, 'window')
            _check.cget('variable').value=0 
          end
        elsif _bro.length > 0 && !_delete
          is_checked = false
          _bro.each{|n|
            _check = @tree_break.itemcget(n, 'window')
            v = _check.cget('variable').value
            is_checked = is_checked || v.to_i==1
          }
          if !is_checked
            _check = @tree_break.itemcget(_file_node, 'window')
            _check.cget('variable').value=0 
          end
        end
      ensure
        @tree_break.configure('selectcommand'=>_sc) if _delete
      end

    end
  end

  def breakpoint_select(_file, _line)
    _file_node = file2node_name(_file) 
    _line_node = line2node_name(_file_node, _line)
    @tree_break.selection_clear
    #p "line node = #{_line_node}"
    if @tree_break.exist?(_line_node)
      @tree_break.open_tree(_file_node, false)
      @tree_break.selection_add(_line_node)
      @tree_break.see(_line_node)
    end
  end

  
  def breakpoint_list_free
    @tree_break.delete(@tree_break.nodes('root'))
  end
  
  
end