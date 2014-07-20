#
#   ae-file-history.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=../..
#   &require_omissis=conf/arcadia.init
#   &require_omissis=lib/a-commons
#   &require_omissis=lib/a-tkcommons
#   &require_omissis=lib/a-core


class TreeNode
  attr_reader :sons
  attr_reader :parent
  attr_reader :kind
  attr_reader :rif, :label, :helptext
  attr_writer :rif, :label, :helptext
  def initialize(parent=nil, kind='KClass')
    @sons = Array.new
    @parent = parent
    @kind = kind
    @label = ''
    if @parent !=nil
      @parent.sons << self
    end
    yield(self) if block_given?
  end

  def <=> (other)
    self.label.strip <=> other.label.strip
  end
	
	def dir(_path)
	  node = nil
	  parent = self
	  sons.each{|_tree|
       ["\\","/"].include?(_path[0,1])?_index = 1:_index=0
	     if _path[_index.._tree.label.length-1+_index] == _tree.label 
				 res = _path[_tree.label.length+_index.._path.length-1]
				 if ["\\","/"].include?(res[0,1])
              parent = _tree
              node= _tree.dir(res)
				 end
			 end
			 break if node != nil
	  }
	  if node == nil
	    if _path == '/' || _path == '\\'
	       # ok -- we have the root
	    elsif _path.length > 0 && (_path.include?("/")||_path.include?("\\"))
	      _path.include?("/")?_sep="/":_sep="\\"
	      _parent_length = _path.length - _path.split(_sep)[-1].length
	      _parent_path = _path[0.._parent_length-2]
	      if _parent_path != _path
	        parent = parent.dir(_parent_path)
    	      _path = _path[_parent_length-1.._path.length-1]
	      end
	    end
	    node = TreeNode.new(parent,'KDir') do |_node|
      		_node.label=_path
   		   if ["\\","/"].include?(_node.label[0,1])
   		     _node.label = _node.label[1..-1]
   		   end
   		   parent.rif == "root"?parent_rif = "":parent_rif=parent.rif
      		_node.rif= (parent_rif+_path).sub(":",'%%%')
	    end
	  end
	  return node
	end


end



class FilesHistrory < ArcadiaExt
  attr_reader :htree

  def sync_on
    @sync = true
    select_file_without_event(@last_file) if @last_file
  end

  def sync_off
    @sync = false
  end

  def on_before_build(_event)
    @bookmarks =Array.new
    Arcadia.attach_listener(self, BufferRaisedEvent)
    Arcadia.attach_listener(self, BookmarkEvent)
  end

  def on_build(_event)
    @h_stack = Hash.new
    @h_stack_changed = false
    @bookmarks_frame = TkFrame.new(self.frame.hinner_frame)    
    @history_frame = TkFrame.new(self.frame.hinner_frame).pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')    
    @panel = self.frame.root.add_panel(self.frame.name, "sync");
    @cb_sync = TkCheckButton.new(@panel, Arcadia.style('checkbox').update('background'=>@panel.background)){
      text  'Sync'
      justify  'left'
      indicatoron 0
      offrelief 'flat'
      image Arcadia.image_res(SYNC_GIF)
      pack
    }

    Tk::BWidget::DynamicHelp::add(@cb_sync, 
      'text'=>Arcadia.text('ext.file_history.button.link.hint'))

    do_check = proc {
      if @cb_sync.cget('onvalue')==@cb_sync.cget('variable').value.to_i
        sync_on
      else
        sync_off
      end
    }
    @sync = false
    @cb_sync.command(do_check)
    
    @list_label=Arcadia.text("ext.file_history.button.show_as_list.hint")
    @tree_label=Arcadia.text("ext.file_history.button.show_as_tree.hint")
    @is_tree = conf("view") == "tree"
    if @is_tree 
      image = LIST_VIEW_GIF
      label = @list_label
    else
      image = TREE_VIEW_GIF
      label = @tree_label
    end
    
    @btoggle_list_tree = frame.root.add_button(self.name, label, proc{toggle_list_tree}, image)
    
    do_select_item = proc{|_self|
      _selected = @htree.selected
      _dir, _file = _selected.sub("%%%",":").split('@@@')
      if _file
        _file = File.expand_path( _file  , _dir ) 
#	    else
#	      _file = Tk.getOpenFile('initialdir'=>_dir)
	    end
	    if _file && _file.strip.length > 0 
	      Arcadia.process_event(OpenBufferTransientEvent.new(self,'file'=>_file))
      end
    }
    
    do_open_folder = proc{|_node|
      children = @htree.nodes(_node)
      if children.length == 1 
        @htree.open_tree(children[0],false)
      end
    }    

    @font =  Arcadia.conf('treeitem.font')
    @font_b = "#{Arcadia.conf('treeitem.font')} bold"
    @font_italic = "#{Arcadia.conf('treeitem.font')} italic"
    
	  @htree = BWidgetTreePatched.new(@history_frame, Arcadia.style('treepanel')){
      showlines false
      deltay 18
      crosscloseimage  Arcadia.image_res(PLUS_GIF)
      crossopenimage  Arcadia.image_res(MINUS_GIF)
      opencmd proc{|node| do_open_folder.call(node)} 
      selectcommand proc{ do_select_item.call(self) } 
#      place('relwidth' => 1,'relheight' => '1', 'x' => '0','y' => '22', 'height' => -22)
    }
    @htree.extend(TkScrollableWidget)

    do_double_click = proc{
        #_selected = @htree.selection_get[0]
        _selected = @htree.selected
        _dir, _file = _selected.sub("%%%",":").split('@@@')
        if _dir && _file.nil? && File.ftype(node2file(_dir)) == 'directory'
	        _file = Arcadia.open_file_dialog(node2file(_dir))
	        #Tk.getOpenFile('initialdir'=>node2file(_dir))
      	    if _file && _file.strip.length > 0 
      	       Arcadia.process_event(OpenBufferTransientEvent.new(self,'file'=>_file))
           end
#          if !_selected.nil? && @htree.open?(node2file(_selected))
#            @htree.close_tree(node2file(_selected))
#          elsif !_selected.nil?
#            @htree.open_tree(node2file(_selected),false) 
#            do_open_folder.call(_selected)
#          end
        end
    }
    
    @htree.textbind_append('Double-1',do_double_click)
     
    @history_lines = []
    @last_list_lines = []
    refresh_history_lines
   
    build_tree
    pop_up_menu_tree
    
    @hlist = TkText.new(@history_frame, Arcadia.style('text')){|j|
      wrap 'none'
      font @font_italic
      cursor nil
    }
    @hlist.bind_append('KeyPress'){|e| Tk.callback_break }
    @hlist.bind_append('KeyRelease'){|e| Tk.callback_break }
    @hlist.extend(TkScrollableWidget)
    @hlist.tag_configure("file_selected", 'foreground' => Arcadia.conf('hightlight.link.foreground'))
	  build_list
	  if @is_tree 
	    @htree.show
	  else
	    @hlist.show
	  end
	end

  def on_initialize(_event)
    load_persistent_bookmarks
  end  

	
	def on_bookmark(_event)
    return if _event.file.nil?
    case _event
      when ToggleBookmarkEvent
        self.frame.show_anyway
        # set or unset ?
        to_set = true
        to_del_detail = nil
        @bookmarks.each{|detail|
          if detail[:file] == _event.file && (_event.from_row.to_i >= detail[:from_line].to_i - _event.range) && (_event.to_row.to_i <= detail[:to_line].to_i + _event.range)  
            to_set = false
            to_del_detail = detail
          end
          break if !to_set 
        }
        if to_set
          SetBookmarkEvent.new(self,
            'file'=>_event.file, 
            'from_row'=>_event.from_row, 
            'to_row'=>_event.to_row,
            'range'=>_event.range,
            'persistent'=>_event.persistent,
            'id'=>_event.id).go!
        else
          UnsetBookmarkEvent.new(self,
            'file'=>_event.file, 
            'from_row'=>to_del_detail[:from_line], 
            'to_row'=>to_del_detail[:to_line],
            'range'=>_event.range,
            'persistent'=>_event.persistent,
            'id'=>_event.id).go!
        end    
      when SetBookmarkEvent
        @bookmarks_frame.pack('before'=>@history_frame,'side' =>'top','anchor'=>'nw', 'fill'=>'x', :padx=>0, :pady=>0)     if @bookmarks.empty? 
        if _event.persistent
          bookmark = {:file=>_event.file}
          caption = File.basename(_event.file)
        else
          bookmark = {:file=>"__TMP__#{_event.id}"}
          caption = _event.id
        end
        caption = (_event.from_row == _event.to_row) ? "#{caption} [#{_event.from_row}] #{_event.content.strip if _event.content}":"#{caption} [#{_event.from_row}, #{_event.to_row}] #{str=_event.content.split("\n")[0] if _event.content;str.strip if str}"
        bookmark[:from_line] = _event.from_row
        bookmark[:to_line] = _event.to_row
        bookmark[:persistent] = _event.persistent
        bookmark[:widget] = Tk::BWidget::Button.new(@bookmarks_frame, Arcadia.style('toolbarbutton')){
          image Arcadia.image_res(BOOKMARK_GIF)
          compound 'left'
          anchor "w"
          command proc{OpenBufferTransientEvent.new(self,'file'=>_event.file, 'row'=> _event.from_row).go!}
          #width 20
          #height 20
          helptext  _event.content
          text caption
        }.pack('side' =>'top','anchor'=>'nw', 'fill'=>'x', :padx=>0, :pady=>0)    

        Tk::BWidget::Button.new(bookmark[:widget], Arcadia.style('toolbarbutton')){
          image  TkPhotoImage.new('dat' => CLOSE_GIF)
          command proc{UnsetBookmarkEvent.new(self,
            'file'=>_event.file, 
            'from_row'=>_event.from_row,
            'to_row'=>_event.to_row).go!}
          #width 20
          height 16
        }.pack('side' =>'right','anchor'=>'e', 'fill'=>'y', :padx=>0, :pady=>0)    
        
        @bookmarks << bookmark
      when UnsetBookmarkEvent
        @bookmarks.delete_if{|b| 
          if (b[:file]==_event.file && b[:from_line]==_event.from_row)
            b[:widget].destroy
            true
          else
            false
          end
        }
        @bookmarks_frame.unpack if @bookmarks.empty? 
	 end
	
	end
  
	def toggle_list_tree
    Tk::BWidget::DynamicHelp::delete(@btoggle_list_tree)
	  if @is_tree
	    @htree.hide
	    @hlist.show
	    label = @tree_label
	    image = Arcadia.image_res(TREE_VIEW_GIF)
	  else
	    @hlist.hide
	    @htree.show
	    label = @list_label
	    image = Arcadia.image_res(LIST_VIEW_GIF)
	  end
    @btoggle_list_tree.configure(:image=> image)
    Tk::BWidget::DynamicHelp::add(@btoggle_list_tree, 'text'=>label)
    @is_tree = !@is_tree
	end

	def on_after_build(_event)
    Arcadia.attach_listener(self, OpenBufferEvent)
    #Arcadia.attach_listener(self, BufferRaisedEvent)
    self.frame.show
    Arcadia.attach_listener(self, BufferClosedEvent)
	end
	
	def history_file
    if !defined?(@arcadia_history_file)
    		@arcadia_history_file = @arcadia.local_dir+'/'+conf('file.name')
    end
    return @arcadia_history_file
	end
		
  def on_before_open_buffer(_event)
    if _event.file && _event.row.nil? && File.exist?(_event.file)  
      if @h_stack[_event.file]
        r,c = @h_stack[_event.file].split('.')
        _event.last_row=r.to_i
        _event.last_col=c.to_i
        if _event.select_index.nil?
          _event.select_index=false
        end
      end
    end
  end


  def on_after_open_buffer(_event)
    if _event.file && File.exist?(_event.file)
      add2history(_event.file)
      add_to_tree(_event.file)
      add_to_list(_event.file)
      #build_list
    end
  end

  def on_buffer_closed(_event)
    if _event.file && File.exist?(_event.file)
      @h_stack_changed = @h_stack_changed || @h_stack[_event.file] != "#{_event.row}.0"
      @h_stack[_event.file]="#{_event.row}.0"
    end
  end

  def node2file(_node)
    if _node[0..0]=='{' && _node[-1..-1]=='}'
      return _node[1..-2]
    else
      return _node
    end
  end

  def file2node(_file)
    if _file.include?("\s") && _file[0..0]!='{'
      return "{#{_file}}"
    else
      return _file
    end
  end  


#  def selected
#    if @htree.selection_get[0]
#      if @htree.selection_get[0].length >0
#       	_selected = ""
#        if String.method_defined?(:lines)
#      	   selection_lines = @htree.selection_get[0].lines
#        else
#      	   selection_lines = @htree.selection_get[0].split("\n")
#        end
#        selection_lines.each{|_block|
#          _selected = _selected + _block.to_s + "\s" 
#        }
#        _selected = _selected.strip
#      else
#        _selected = @htree.selection_get[0]
#      end
#    end
#    return _selected
#  end

  def select_file_without_event(_file)
    _d, _f = File.split(File.expand_path(_file))
    _d = _d.downcase if Arcadia.is_windows?
    _f = _f.downcase if Arcadia.is_windows?
    _file_node_rif = _d+'@@@'+_f
    if @htree.exist?(_file_node_rif)
      _proc = @htree.cget('selectcommand')
      @htree.configure('selectcommand'=>nil)
      #_proc = @htree.selectcommand
      #@htree.selectcommand(proc{nil})
      begin
        parent = root.dir(_d)
        @htree.selection_clear
        @htree.selection_add(_file_node_rif)
        #@htree.close_tree('root')
        while !parent.nil? && parent.rif != 'root'
          @htree.open_tree(parent.rif, false)
          parent = parent.parent
        end
        @htree.see(_file_node_rif)
      ensure
        #@htree.selectcommand(_proc)
        @htree.configure('selectcommand'=>_proc)
      end
      @htree.call_after_next_show_h_scroll(proc{Tk.update;@htree.see(_file_node_rif)})
    end

    @hlist.tag_remove("file_selected",'1.0', 'end')
    @history_lines.each_with_index{|line, i|
      if line.include?(File.expand_path(_file))
        index = "#{i+1}.0"
        @hlist.tag_add("file_selected",index, "#{index} lineend")
        @hlist.see(index)
      end
    }
  end
		
  def on_buffer_raised(_event)
    return if _event.file.nil?
    @last_file = _event.file
    if @sync
      select_file_without_event(_event.file)
    end
  end
		
#	def do_editor_event(_event)
#     case _event.signature 
#     		when EditorContract::FILE_AFTER_OPEN
#     		  if _event.context.file
#    		      self.add2history(_event.context.file)
#    		      add_to_tree(_event.context.file)
#     			  end
#     		when EditorContract::FILE_AFTER_CLOSE
#     		  if _event.context.file 
#     		end
#     end
#	end

  def root
    if !defined?(@root)
      @root = TreeNode.new(nil, 'KRoot'){|_node|
        _node.rif= 'root'
        _node.label=''
      }
    end
    return @root
  end
  
  def read_history
    to_ret = []
    if File.exist?(history_file)
      f = File::open(history_file,'r')
      begin 
        to_ret = f.readlines.collect!{| line | line.chomp }
      ensure
        f.close unless f.nil?
      end
    else
      create_history_file
    end
    to_ret
  end
  
  def refresh_history_lines
    @history_lines = read_history
  end 
  
  def add_to_list(_file)
    if !@last_list_lines.include?(_file)
      build_list
    end
  end

  def build_list
    @hlist.delete('1.0','end')
    @last_list_lines.clear
    @history_lines.each_with_index{|line,i|
      file, index = line.split(';')
      if file && FileTest::exist?(file)
        append_to_list(file, i)
        @last_list_lines << file
      end
    }
  end
  
  def append_to_list(_file, _i=0)
    dir,fil =File.split(File.expand_path(_file))
    dir = dir.downcase if Arcadia.is_windows?
    fil = fil.downcase if Arcadia.is_windows?
    tag_name = "tag_#{_i}"
    @hlist.tag_remove(tag_name,'1.0', 'end')
    @hlist.tag_delete(tag_name)

    @hlist.tag_bind(tag_name,"Enter",  
      proc{
        Tk::BWidget::DynamicHelp::add(@hlist, 'text'=>_file)
        @hlist.configure('cursor'=> 'hand2')
        @hlist.tag_configure(tag_name, 'underline'=>true)
      }  
    )
    @hlist.tag_bind(tag_name,"Leave",
      proc{
        Tk::BWidget::DynamicHelp::delete(@hlist)
        @hlist.configure('cursor'=> nil)
        @hlist.tag_configure(tag_name, 'underline'=>false) 
      }
    )
    TkTextImage.new(@hlist, 'end', 'image'=> Arcadia.file_icon(_file))
    @hlist.insert("end", " ")
    @hlist.insert("end", "#{File.basename(_file)}\n", tag_name)
    @hlist.tag_bind(tag_name,"ButtonPress-1", proc{OpenBufferTransientEvent.new(self,'file'=>_file).go!})
  end
  
  def build_tree
    file_dir = Hash.new
    nodes = Array.new
    _lines = @history_lines
    _lines.sort.each{|_line|
      _file, _index = _line.split(';')
      if _file && FileTest::exist?(_file)
        @h_stack[File.expand_path(_file)]=_index
        dir,fil =File.split(File.expand_path(_file))
        dir = dir.downcase if Arcadia.is_windows?
        fil = fil.downcase if Arcadia.is_windows?
        file_dir[dir] = Array.new if file_dir[dir] == nil
        file_dir[dir] << fil if !file_dir[dir].include?(fil)
      end
    }

    file_dir.keys.sort.each{|_dir|
    				node = root.dir(_dir)
				file_dir[_dir].each{|file|
				  TreeNode.new(node, 'KFile'){|_node|
              _node.rif= _dir+'@@@'+file
              _node.label=file
				  }
				}
    }

    @image_kdir = Arcadia.image_res(ICON_FOLDER_OPEN_GIF)
    build_tree_from_node(root)
  end

  def pop_up_menu_tree
    @pop_up_tree = TkMenu.new(
      :parent=>@htree,
      :tearoff=>0,
      :title => 'Menu tree'
    )
    @pop_up_tree.extend(TkAutoPostMenu)
    @pop_up_tree.configure(Arcadia.style('menu'))
    #----- search submenu
    sub_ref_search = TkMenu.new(
      :parent=>@pop_up_tree,
      :tearoff=>0,
      :title => 'Ref'
    )
    sub_ref_search.extend(TkAutoPostMenu)
    sub_ref_search.configure(Arcadia.style('menu'))
    sub_ref_search.insert('end',
      :command,
      :label=>Arcadia.text('ext.file_history.menu.find_in_files'),
      :hidemargin => false,
      :command=> proc{
        _target = @htree.selected
        _dir, _file = _target.sub("%%%",":").split('@@@')
        if _dir
          Arcadia.process_event(SearchInFilesEvent.new(self,'dir'=>_dir))
        end
      }
    )
    
    sub_ref_search.insert('end',
      :command,
      :label=>Arcadia.text('ext.file_history.menu.act_in_files'),
      :hidemargin => false,
      :command=> proc{
        _target = @htree.selected
        _dir, _file = _target.sub("%%%",":").split('@@@')
        if _dir
          Arcadia.process_event(AckInFilesEvent.new(self,'dir'=>_dir))
        end
      }
    )
    @pop_up_tree.insert('end',
      :cascade,
      :label=>Arcadia.text('ext.file_history.menu.search_from_here'),
      :menu=>sub_ref_search,
      :hidemargin => false
    )
    
    
    @htree.areabind_append("Button-3",
      proc{|x,y|
        _x = TkWinfo.pointerx(@htree)
        _y = TkWinfo.pointery(@htree)
        @pop_up_tree.popup(_x,_y)
      },
    "%x %y")
  end


  def add_to_tree(_file)
	 _d, _f = File.split(File.expand_path(_file))
	 return if _f.nil?
	 #Arcadia.new_error_msg(self, "add_to_tree _file=#{_file}")
	 #Arcadia.new_error_msg(self, "add_to_tree _d=#{_d}")
	 #Arcadia.new_error_msg(self, "add_to_tree _f=#{_f}")
	 _d = _d.downcase if Arcadia.is_windows?
	 _f = _f.downcase if Arcadia.is_windows?
    #_foreground = conf('color.foreground')
	 node = root.dir(_d)
	 
	 node_stack = Array.new
	 node_stack << node
	 _parent = node.parent
	 while _parent.rif != 'root'
	   node_stack << _parent
	   _parent = _parent.parent
	 end
	 node_stack.reverse!
	 
	 node_stack.each{|_node|
      if !@htree.exist?(_node.rif)
        @htree.insert('end', _node.parent.rif ,_node.rif, {
            'text' =>  _node.label,
            'helptext' => _node.rif,
            'deltax'=>-1,
            'image'=> image('KDir')
          }.update(Arcadia.style('treeitem'))
        )
      end
	 }
#    if !@htree.exist?(node.rif)
#      @htree.insert('end', node.parent.rif ,node.rif, {
#          'text' =>  node.label,
#          'helptext' => node.rif,
#          'deltax'=>-1,
#          'image'=> image('KDir')
#        }.update(Arcadia.style('treeitem'))
#      )
#    end


    _file_node_rif = _d+'@@@'+_f
    if !@htree.exist?(_file_node_rif)
      @htree.insert('end', node.rif ,_file_node_rif, {
          'text' =>  _f ,
          'helptext' => _f,
          'deltax'=>-1,
          #'fill' => _foreground,
          #'font'=>@font_b,
          'image'=> image('KFile',_f)
        }.update(Arcadia.style('treeitem'))
      )
    end
    
  end
 
  def image(_kind, _label='.rb')
      if _kind == 'KDir'
        return @image_kdir
      elsif _kind == 'KFile'
        return Arcadia.file_icon(_label)
#      elsif _kind == 'KFile' && _label.include?('.rb')
#        return @image_kfile_rb
#      else
#        return @image_kfile
      end
  end

  def build_tree_from_node(_node)
    #_foreground = conf('color.foreground')
    _sorted_sons = _node.sons.sort
    for inode in 0.._sorted_sons.length - 1
      _son = _sorted_sons[inode]
      @htree.insert('end', _son.parent.rif ,_son.rif, {
        'text' =>  _son.label ,
     #   'fill' => _foreground,
        'helptext' => _son.helptext,
        'deltax'=>-1,
      #  'font'=>@font,
        'image'=> image(_son.kind, _son.label)
      }.update(Arcadia.style('treeitem'))
      )
      build_tree_from_node(_son)
    end
  end

  def on_finalize(_event)
    bookmarks = '';
    @bookmarks.each{|bm|
      if bm[:file] != nil && bm[:persistent]
        bookmarks="#{bookmarks}|" if bookmarks.strip.length > 0
        bookmarks="#{bookmarks}#{bm[:file]}@@@#{bm[:from_line]}@@@#{bm[:to_line]}"
      end
    }
    Arcadia.persistent('bookmarks', bookmarks)
    if @is_tree
      conf('view','tree') 
    else
      conf('view','list') 
    end
    return if !@h_stack_changed 
    if File.exist?(history_file)
      f = File::open(history_file,'r')
      begin
        _lines = f.readlines.collect!{| line | line.chomp}
      ensure
        f.close unless f.nil?
      end
      f = File.new(history_file, "w")
      begin
        if f
          _lines[0..-1].each{|_line|
            _lfile = _line.split(';')
            if _lfile
              if @h_stack[_lfile[0]]
                rif = "#{_lfile[0]};#{@h_stack[_lfile[0]]}"
              else
                rif = _line
              end
              f.syswrite(rif+"\n")
            end
          }
        end
      ensure
        f.close unless f.nil?
      end
    end
  end

  def load_persistent_bookmarks
    b = Arcadia.persistent('bookmarks')
    if b
      bm_list =b.split("|")
      bm_list.each do |bm| 
        file,from_line,to_line = bm.split('@@@')
        if file && from_line && to_line
          SetBookmarkEvent.new(self, 
            'file'=>file, 
            'from_row'=>from_line.to_i, 
            'to_row'=>to_line.to_i,
            'persistent'=>true).go!
        end
      end
    end
  end


  def create_history_file(_content=nil)
    dir,fil =File.split(File.expand_path(history_file))
    if !File.exist?(dir)
      Dir.mkdir(dir)
    end
    f = File.new(history_file, "w+")
    begin
      f.syswrite(_content) if f && _content
    ensure
      f.close unless f.nil?
    end
  end

  def add2history(_filename, _text_index='1.0')
    #return if !@h_stack[_filename].nil?
    if _filename && File.exist?(_filename)
      _filename = _filename.sub(Dir::pwd+'/',"")
      _filename = File.expand_path(_filename)
      _filename_index = _filename+";"+_text_index
      if File.exist?(history_file)
        f = File.new(history_file, "w")
        begin
          if f
            max= conf('length').to_i
            i = 1
            f.syswrite(_filename_index+"\n")
            @history_lines.each{|_line|
              _lfile = _line.split(';')
              if _lfile
                if (_lfile[0] != _filename) && (_line.length > 0) 
                  f.syswrite(_line+"\n")
                  i+=1 
                end
              end
              break if i >= max
            }
          end
        ensure
          f.close unless f.nil?
        end
      else
        create_history_file(_filename+"\n")
      end
      refresh_history_lines
    end
  end
end