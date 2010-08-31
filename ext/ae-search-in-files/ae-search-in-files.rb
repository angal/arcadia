#
#   ae-search-in-files.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

class SearchInFilesService < ArcadiaExt

  def on_before_build(_event)
    Arcadia.attach_listener(SearchInFilesListener.new(self),SearchInFilesEvent)
  end

end

class SearchInFilesListener
  def initialize(_service)
    @service = _service
    create_find 'Search in files'
  end

  def on_before_search_in_files(_event)
    if _event.what.nil?
      if _event.dir
        @find.e_dir.text(_event.dir)
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
    @find = FindFrame.new(@service.arcadia.layout.root)
    @find.on_close=proc{@find.hide}
    @find.hide
    @find.b_go.bind('1', proc{Thread.new{update_all_combo;do_find}}) # add trigger to button    
    
    enter_proc = proc {|e|
      case e.keysym
      when 'Return'
        if @find.visible?
          update_all_combo    
          do_find
        end
        Tk.callback_break
      end
    }
    
    for method in [:e_what_entry, :e_filter_entry, :e_dir_entry] do
      @find.send(method).bind_append('KeyPress') { |*args| enter_proc.call *args } # ltodo why can't we pass it in like &enter_proc?
    end
    @find.title(title)
  end
  private :create_find

  def update_what_combo(_txt)
    values = @find.e_what.cget('values')
    if (values != nil && !values.include?(_txt))
      @find.e_what.insert('end', _txt)
    end
  end

  def update_filter_combo(_txt)
    values = @find.e_filter.cget('values')
    if (values != nil && !values.include?(_txt))
      @find.e_filter.insert('end', _txt)
    end
  end

  def update_dir_combo(_txt)
    values = @find.e_dir.cget('values')
    if (values != nil && !values.include?(_txt))
      @find.e_dir.insert('end', _txt)
    end
  end
  
  def update_all_combo
    update_what_combo(@find.e_what.text)
    update_filter_combo(@find.e_filter.text)
    update_dir_combo(@find.e_dir.text)
  end
  
  def do_find
    return if @find.e_what.text.strip.length == 0  || @find.e_filter.text.strip.length == 0  || @find.e_dir.text.strip.length == 0
    @find.hide
    if !defined?(@search_output)
      @search_output = SearchOutput.new(@service)
    end
    @service.frame.show_anyway
    begin
    
      MonitorLastUsedDir.set_last @find.e_dir.text # save it away TODO make it into a message
      
      _search_title = 'search result for : "'+@find.e_what.text+'" in :"'+@find.e_dir.text+'"'+' ['+@find.e_filter.text+']'
      _filter = @find.e_dir.text+'/**/'+@find.e_filter.text
      _files = Dir[_filter]
      _node = @search_output.new_result(_search_title, _files.length)
      progress_stop=false
      @progress_bar = TkProgressframe.new(@service.arcadia.layout.root, _files.length)		  
      @progress_bar.title('Searching')
      @progress_bar.on_cancel=proc{progress_stop=true}
      #@progress_bar.on_cancel=proc{cancel}
      pattern = Regexp.new(@find.e_what.text)
      _files.each do |_filename|
          File.open(_filename) do |file|
            file.grep(pattern) do |line|
              @search_output.add_result(_node, _filename, file.lineno.to_s, line)
              break if progress_stop
            end
          end
          @progress_bar.progress
          break if progress_stop
      end
    rescue Exception => e
      Arcadia.console(self, 'msg'=>e.message, 'level'=>'error')
      #Arcadia.new_error_msg(self, e.message)
    ensure
      @progress_bar.destroy if @progress_bar
    end

  end
  
  
end

class SearchOutput
  def initialize(_ext)
    @sequence = 0
    @ext = _ext
    left_frame = TkFrame.new(@ext.frame.hinner_frame, Arcadia.style('panel')).place('x' => '0','y' => '0','relheight' => '1','width' => '25')
    #right_frame = TkFrame.new(@ext.frame).place('x' => '25','y' => '0','relwidth' => '1', 'relheight' => '1', 'width' => '-25')
    @results = {}
    _open_file = proc do |tree, sel|
      n_parent, n = sel.split('@@@')
      Arcadia.process_event(OpenBufferTransientEvent.new(self,'file'=>@results[n_parent][n][0], 'row'=>@results[n_parent][n][1]))  if n && @results[n_parent][n]
      #EditorContract.instance.open_file(self, 'file'=>@results[n_parent][n][0], 'line'=>@results[n_parent][n][1]) if n && @results[n_parent][n]
    end

    @tree = Tk::BWidget::Tree.new(@ext.frame.hinner_frame, Arcadia.style('treepanel')){
      #background '#FFFFFF'
      #relief 'flat'
      #showlines true
      #linesfill '#e7de8f'
      selectcommand _open_file 
      deltay 15
    }.place('x' => '25','y' => '0','relwidth' => '1', 'relheight' => '1', 'width' => '-40', 'height'=>'-15')
    @tree.extend(TkScrollableWidget).show
    
    _proc_clear = proc{clear_tree}
    
    @button_u = Tk::BWidget::Button.new(left_frame, Arcadia.style('toolbarbutton')){
      image  TkPhotoImage.new('dat' => CLEAR_GIF)
      helptext 'Clear'
      foreground 'blue'
      command _proc_clear
      relief 'groove'
      pack('side' =>'top', 'anchor'=>'n',:padx=>0, :pady=>0)
    }
    
#    @found_color='#3f941b'
#    @not_found_color= 'red'
#    @item_color='#6fc875'
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
  attr_reader :e_what_entry, :e_filter_entry, :e_dir_entry
  attr_reader :b_go
  def initialize(_parent)
    super(_parent)
    y0 = 10
    d = 23    
    TkLabel.new(self.frame, Arcadia.style('label')){
      text 'Find what:'
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
    @e_what = Tk::BWidget::ComboBox.new(self.frame, Arcadia.style('combobox')){
      editable true
      justify  'left'
      autocomplete 'true'
      expand 'tab'
      takefocus 'true'
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_what_entry = TkWinfo.children(@e_what)[0]
    # this means "after each key press 
    @e_what_entry.bind_append("1",proc{Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>@e_what_entry))})
    
    y0 = y0 + d
    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text 'Files filter:'
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
   
    @e_filter = Tk::BWidget::ComboBox.new(self.frame, Arcadia.style('combobox')){
      editable true
      justify  'left'
      autocomplete 'true'
      expand 'tab'
      takefocus 'true'
            #pack('padx'=>10, 'fill'=>'x')
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_filter_entry = TkWinfo.children(@e_filter)[0]
    @e_filter_entry.bind_append("1",proc{Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>@e_filter_entry))})

    @e_filter.insert('end', '*.*')
    @e_filter.insert('end', '*.rb')
    @e_filter.text('*.rb')
    y0 = y0 + d

    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text 'Directory:'
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d

    _h_frame = TkFrame.new(self.frame, Arcadia.style('panel')).place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    @e_dir = Tk::BWidget::ComboBox.new(_h_frame, Arcadia.style('combobox')){
      editable true
      justify  'left'
      autocomplete 'true'
      expand 'tab'
      takefocus 'true'
      pack('fill'=>'x')
      #pack('fill'=>'x')
      #place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_dir.text(MonitorLastUsedDir.get_last_dir)
    @e_dir_entry = TkWinfo.children(@e_dir)[0]

    @b_dir = TkButton.new(@e_dir, Arcadia.style('button') ){
      compound  'none'
      default  'disabled'
      text  '...'
      pack('side'=>'right')
      #pack('side'=>'right','ipadx'=>5, 'padx'=>5)
    }.bind('1', proc{
         change_dir
         Tk.callback_break
    })
    
    y0 = y0 + d
    y0 = y0 + d
    @buttons_frame = TkFrame.new(self.frame, Arcadia.style('panel')).pack('fill'=>'x', 'side'=>'bottom')	

    @b_go = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
      compound  'none'
      default  'disabled'
      text  'Find'
      #overrelief  'raised'
      #justify  'center'
      pack('side'=>'right','ipadx'=>5, 'padx'=>5)
    }
    place('x'=>100,'y'=>100,'height'=> 220,'width'=> 300)
  end

  def change_dir
    _d = Tk.chooseDirectory('initialdir'=>@e_dir.text,'mustexist'=>true)
    if _d && _d.strip.length > 0
      @e_dir.text(_d)
    end
  end
  
  def show
    super
    self.focus
    @e_what.focus
    @e_what_entry.selection_range(0,'end')
  end
end