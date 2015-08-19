#
#   ae-search-in-files.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

class SearchInFiles < ArcadiaExt

  def on_before_build(_event)
    create_find Arcadia.text('ext.search_in_files.title')
    Arcadia.attach_listener(self, SearchInFilesEvent)
  end
  
  def on_before_search_in_files(_event)
    if _event.what.nil?
      if _event.dir
        @find.e_dir.value=_event.dir
      end
      @find.show
    end
  end
  
  #def on_search_in_files(_event)
    #Arcadia.new_msg(self, "... ti ho fregato!")
  #end

  #def on_after_search_in_files(_event)
  #end

  def create_find title
    @find = FindFrame.new(self.arcadia.layout.root)
    @find.on_close=proc{@find.hide}
    @find.hide
    @find.b_go.bind('1', proc{update_all_combo;do_find}) # add trigger to button    
    #@find.b_go.bind('1', proc{Thread.new{update_all_combo;do_find}}) # add trigger to button    
    
    enter_proc = proc {|_keysym|
      case _keysym
      when 'Return'
        if @find.visible?
          update_all_combo    
          do_find
        end
        Tk.callback_break
      end
    }
    
    #for method in [:e_what_entry, :e_filter_entry, :e_dir_entry] do
    for method in [:e_what, :e_filter, :e_dir] do
      @find.send(method).bind_append('KeyPress', "%K") { |_keysym| enter_proc.call _keysym } # ltodo why can't we pass it in like &enter_proc?
    end
    @find.title(title)
  end
  private :create_find

  def update_combo(_combobox=nil)
    return if _combobox.nil?
    values = _combobox.cget('values')
    if (values != nil && !values.include?(_combobox.value))
      values << _combobox.value
      _combobox.values=values
    end
  end

#  def update_what_combo(_txt)
#    values = @find.e_what.cget('values')
#    if (values != nil && !values.include?(_txt))
#      values << @find.e_what.value
#      @find.e_what.values=values
#      #@find.e_what.insert('end', _txt)
#    end
#  end

#  def update_filter_combo(_txt)
#    values = @find.e_filter.cget('values')
#    if (values != nil && !values.include?(_txt))
#      values << @find.e_filter.value
#      @find.e_filter.insert('end', _txt)
#      #@find.e_filter.insert('end', _txt)
#    end
#  end
#
#  def update_dir_combo(_txt)
#    values = @find.e_dir.cget('values')
#    if (values != nil && !values.include?(_txt))
#      @find.e_dir.insert('end', _txt)
#    end
#  end
  
  def update_all_combo
    update_combo(@find.e_what)
    update_combo(@find.e_filter)
    update_combo(@find.e_dir)
  end
  
  def do_find
    return if @find.e_what.value.strip.length == 0  || @find.e_filter.value.strip.length == 0  || @find.e_dir.value.strip.length == 0
    @find.hide
    if !defined?(@search_output)
      @search_output = SearchOutput.new(self)
    end
    self.frame.show_anyway
    Thread.new do
      begin    
        MonitorLastUsedDir.set_last @find.e_dir.value # save it away TODO make it into a message
        _search_title = Arcadia.text('ext.search_in_files.search_result_title', [@find.e_what.value, @find.e_dir.value, @find.e_filter.value])
        _filter = @find.e_dir.value+'/**/'+@find.e_filter.value
        _files = Dir[_filter]
        _node = @search_output.new_result(_search_title, _files.length)
        progress_stop=false
        hint = "#{Arcadia.text('ext.search_in_files.progress.title')} '#{@find.e_what.value}' into '#{@find.e_dir.value}'"
        progress_bar = self.frame.root.add_progress(self.frame.name, _files.length, proc{progress_stop=true}, hint)
        pattern = Regexp.new(@find.e_what.value)
        _files.each do |_filename|
            next if File.ftype(_filename) != 'file'
            begin
              File.open(_filename) do |file|
                file.grep(pattern) do |line|
                  @search_output.add_result(_node, _filename, file.lineno.to_s, line)
                  break if progress_stop
                end
              end
            rescue ArgumentError => e
              # bynary file probably
            rescue Exception => e
              Arcadia.console(self, 'msg'=>"#{_filename} :#{e.class}: #{e.message}", 'level'=>'error')
            ensure
              progress_bar.progress
              break if progress_stop
            end
        end
      rescue Exception => e
        Arcadia.console(self, 'msg'=>e.message, 'level'=>'error')
        #Arcadia.new_error_msg(self, e.message)
      ensure
        self.frame.root.destroy_progress(self.frame.name, progress_bar) if progress_bar
        #progress_bar.destroy if progress_bar
        self.frame.show_anyway
      end
    end
  end

end

class SearchOutput
  def initialize(_ext)
    @sequence = 0
    @ext = _ext
#    left_frame = TkFrame.new(@ext.frame.hinner_frame, Arcadia.style('panel')).place('x' => '0','y' => '0','relheight' => '1','width' => '25')
    @results = {}
    _open_file = proc do |tree, sel|
      n_parent, n = sel.split('@@@')
      Arcadia.process_event(OpenBufferTransientEvent.new(self,'file'=>@results[n_parent][n][0], 'row'=>@results[n_parent][n][1]))  if n && @results[n_parent][n]
    end
    @tree = BWidgetTreePatched.new(@ext.frame.hinner_frame, Arcadia.style('treepanel')){
    #@tree = BWidgetTreePatched.new(@ext.hinner_dialog, Arcadia.style('treepanel')){
    #@tree = BWidgetTreePatched.new(@ext.hinner_splitted_dialog, Arcadia.style('treepanel')){
      selectcommand(_open_file)
      deltay 15
    }
#    @tree.extend(TkScrollableWidget).show(25,0)
    @tree.extend(TkScrollableWidget).show(0,0)
    
#    _proc_clear = proc{clear_tree}

    _ext.frame.root.add_button(_ext.name,  Arcadia.text('ext.search_in_files.button.clear.hint'), proc{clear_tree}, CLEAR_GIF) if _ext

    
#    @button_u = Tk::BWidget::Button.new(left_frame, Arcadia.style('toolbarbutton')){
#      image  Arcadia.image_res(CLEAR_GIF)
#      helptext 'ext.search_in_files.button.clear.hint'
#      command _proc_clear
#      relief 'groove'
#      pack('side' =>'top', 'anchor'=>'n',:padx=>0, :pady=>0)
#    }
    
    @found_color=Arcadia.conf('activeforeground')
    @not_found_color= Arcadia.conf('hightlight.comment.foreground')
    @item_color=Arcadia.conf('treeitem.fill')
  end  
  
  def clear_tree
    @tree.delete(@tree.nodes('root'))
    @results.clear
  end
  
  def new_node_name
    @sequence = @sequence + 1
    return 'n'+@sequence.to_s
  end
  
  def new_result(_text, _length=0)
    @results.each_key{|key| @tree.close_tree(key)}
    _r_node = new_node_name
    @text_result = _text
    #_text = _text + ' { '+_length.to_s+' found }'
    #_length > 0 ? _color='#3f941b':_color = 'red'
    @tree.insert('end', 'root' ,_r_node, {
      'fill'=>@not_found_color,
      'open'=>true,
      'anchor'=>'w',
      'font' => "#{Arcadia.conf('treeitem.font')} bold",
      'text' =>  _text
    })
    Tk.update
    @results[_r_node]={}
    @count = 0
    @tree.set_focus
    return _r_node
  end
  
  def add_result(_node, _file, _line='', _line_text='')
    @count = @count+1
    @tree.itemconfigure(_node, 'fill'=>@found_color, 'text'=>@text_result+' { '+@count.to_s+' found }')
    _text = _file+':'+_line+' : '+_line_text
    _node_name = new_node_name
    @tree.insert('end', _node ,_node+'@@@'+_node_name, {
      'fill'=>@item_color,
      'anchor'=>'w',
      'font' => Arcadia.conf('treeitem.font'),
      'text' =>  _text.strip
    })
    @results[_node][_node_name]=[_file,_line]
    Tk.update
  end

  def add_result(_node, _file, _line='', _line_text='')
    @count = @count+1
    @tree.itemconfigure(_node, 'fill'=>@found_color, 'text'=>@text_result+' { '+@count.to_s+' found }')
    _text = _file+':'+_line+' : '+_line_text
    _node_name = new_node_name
    @tree.insert('end', _node ,_node+'@@@'+_node_name, {
      'fill'=>@item_color,
      'anchor'=>'w',
      'font' => Arcadia.conf('treeitem.font'),
      'text' =>  _text.strip
    })
    @results[_node][_node_name]=[_file,_line]
    Tk.update
  end
  
end

class FindFrame < TkFloatTitledFrame
  attr_reader :e_what, :e_filter, :e_dir
#  attr_reader :e_what_entry, :e_filter_entry, :e_dir_entry
  attr_reader :b_go
  def initialize(_parent)
    super(_parent)
    y0 = 10
    d = 23    
    TkLabel.new(self.frame, Arcadia.style('label')){
      text Arcadia.text('ext.search_in_files.search.label.find_what')
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
    #@e_what = Tk::BWidget::ComboBox.new(self.frame, Arcadia.style('combobox')){
    @e_what = Arcadia.wf.combobox(self.frame){
      #editable true
      justify  'left'
      #autocomplete 'true'
      #expand 'tab'
      exportselection true
      width 100
      takefocus 'true'
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    
    @e_what.extend(TkInputThrow)


#    @e_what_entry = TkWinfo.children(@e_what)[0]
#    # this means "after each key press 
#    @e_what_entry.extend(TkInputThrow)
    
    y0 = y0 + d
    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text Arcadia.text('ext.search_in_files.search.label.files_filter')
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
   
    #@e_filter = Tk::BWidget::ComboBox.new(self.frame, Arcadia.style('combobox')){
    @e_filter = Arcadia.wf.combobox(self.frame){
      #editable true
      justify  'left'
      #autocomplete 'true'
      #expand 'tab'
      exportselection true
      width 100
      takefocus 'true'
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_filter.extend(TkInputThrow)

#    @e_filter_entry = TkWinfo.children(@e_filter)[0]
#    @e_filter_entry.extend(TkInputThrow)

    @e_filter.values = ['*.rb', '*.*']
    @e_filter.value = @e_filter.values[0]
#    @e_filter.insert('end', '*.*')
#    @e_filter.insert('end', '*.rb')
#    @e_filter.text('*.rb')

    y0 = y0 + d

    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text Arcadia.text('ext.search_in_files.search.label.dir')
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d

    _h_frame = TkFrame.new(self.frame, Arcadia.style('panel')).place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)

    #@e_dir = Tk::BWidget::ComboBox.new(_h_frame, Arcadia.style('combobox')){
    @e_dir = Arcadia.wf.combobox(_h_frame){
      #editable true
      justify  'left'
      #autocomplete 'true'
      #expand 'tab'
      exportselection true
      width 100
      takefocus 'true'
      pack('fill'=>'x')
      #pack('fill'=>'x')
      #place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_dir.value = MonitorLastUsedDir.get_last_dir

#    @e_dir.text(MonitorLastUsedDir.get_last_dir)
#    @e_dir_entry = TkWinfo.children(@e_dir)[0]

    #@b_dir = TkButton.new(@e_dir, Arcadia.style('button') ){
    @b_dir = Arcadia.wf.button(@e_dir){
      compound  'none'
      default  'disabled'
      text  '...'
      width 3
      pack('side'=>'right', 'padx'=>18)
      #pack('side'=>'right','ipadx'=>5, 'padx'=>5)
    }.bind('1', proc{
         change_dir
         Tk.callback_break
    })
    
    y0 = y0 + d
    y0 = y0 + d
    @buttons_frame = TkFrame.new(self.frame, Arcadia.style('panel')).pack('fill'=>'x', 'side'=>'bottom')	

    #@b_go = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
    @b_go = Arcadia.wf.button(@buttons_frame){|_b_go|
      compound  'none'
      default  'disabled'
      text  Arcadia.text('ext.search_in_files.search.button.find')
      #overrelief  'raised'
      #justify  'center'
      pack('side'=>'right','ipadx'=>5, 'padx'=>5)
    }
    place('x'=>100,'y'=>100,'height'=> 220,'width'=> 350)
  end

  def change_dir
    #_d = Tk.chooseDirectory('initialdir'=>@e_dir.text,'mustexist'=>true)
    _d = Arcadia.select_dir_dialog(@e_dir.value, true)
    if _d && _d.strip.length > 0
      @e_dir.value = _d
      values = @e_dir.values
      if (values != nil && !values.include?(_d))
         values << _d
         @e_dir.values=values
      end      
    end
  end
  
  def show
    super
    self.focus
    @e_what.focus
    @e_what.select_throw
    @e_what.selection_range(0,'end')
#    @e_what_entry.select_throw
#    @e_what_entry.selection_range(0,'end')
  end
end