#
#   ae-file-history.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   §require_dir_ref=../..
#   §require_omissis=conf/arcadia.init
#   §require_omissis=lib/a-commons
#   §require_omissis=lib/a-tkcommons
#   §require_omissis=lib/a-core


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
	
#	def path
#	  _path = @label
#	  if @parent != nil
#	    _path = @parent.path+_path
#	  end
#	  return _path
#	end

	def dir_old(_path)
	  node = nil
	  parent = self
	  sons.each{|_tree|
	     if _path[0.._tree.label.length-1] == _tree.label 
				 res = _path[_tree.label.length.._path.length-1]
				 if ["\\","/"].include?(res[0,1])
              parent = _tree
              node= _tree.dir(res)
				 end
			 end
			 break if node != nil
	  }
	  if node == nil
	    node = TreeNode.new(parent,'KDir') do |_node|
      		_node.label=_path
      		_node.rif= parent.path+_path
	    end
	  end
	  return node
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
	    if _path.length > 0 && (_path.include?("/")||_path.include?("\\"))
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
  include Autils
  attr_reader :htree

  def sync_on
    @sync = true
    select_file_without_event(@last_file) if @last_file

    #Arcadia.attach_listener(self, BufferRaisedEvent)
  end

  def sync_off
    @sync = false
    #Arcadia.detach_listener(self, BufferRaisedEvent)
  end

  def on_before_build(_event)
    Arcadia.attach_listener(self, BufferRaisedEvent)
  end

  def on_build(_event)
    @h_stack = Array.new
    @cb_sync = TkCheckButton.new(self.frame.hinner_frame, Arcadia.style('checkbox')){
      text  'Sync'
      justify  'left'
      variable 1
      #command do_check
      place('x' => 0,'y' => 0,'height' => 22)
    }

    do_check = proc {
      if @cb_sync.cget('onvalue')==@cb_sync.cget('variable').value.to_i
        sync_on
      else
        sync_off
      end
    }
    @sync = false
    @cb_sync.command(do_check)
    
    do_select_item = proc{|_self|
      if _self.selection_get[0].length >0
      	_selected = ""
      	_self.selection_get[0].each{|_block|
       	 _selected = _selected + _block.to_s + "\s" 
      	}
      	_selected = _selected.strip
      else
        _selected = _self.selection_get[0]
      end
      _dir, _file = _selected.sub("%%%",":").split('@@@')
      if _file
        _file = File.expand_path( _file  , _dir ) 
	    else
	      _file = Tk.getOpenFile('initialdir'=>_dir)
	    end
	    if _file && _file.strip.length > 0 
	      Arcadia.process_event(OpenBufferEvent.new(self,'file'=>_file))
        #EditorContract.instance.open_file(self,'file'=>_file)
      end
    }
#    _background = conf('color.background')
#    _foreground = conf('color.foreground')
    @font =  Arcadia.conf('treeitem.font')
    @font_b = "#{Arcadia.conf('treeitem.font')} bold"

	  @htree = Tk::BWidget::Tree.new(self.frame.hinner_frame, Arcadia.style('treepanel')){
      showlines false
      deltay 18
      selectcommand proc{ do_select_item.call(self) } 
#      place('relwidth' => 1,'relheight' => '1', 'x' => '0','y' => '22', 'height' => -22)
    }
    _wrapper = TkScrollWidget.new(@htree)  
    _wrapper.show(0,22)
    _wrapper.show_v_scroll
    _wrapper.show_h_scroll
#    _scrollcommand = proc{|*args| @htree.yview(*args)}
#    _scrollbar = TkScrollbar.new(self.frame.hinner_frame, Arcadia.style('scrollbar')){|s|
#      width 8
#      command _scrollcommand
#    }.pack('side'=>'right', 'fill'=>'y')
#    @htree.yscrollcommand proc{|first,last| _scrollbar.set(first,last)}
    
	  self.build_tree
	end

	def on_after_build(_event)
    Arcadia.attach_listener(self, OpenBufferEvent)
    #Arcadia.attach_listener(self, BufferRaisedEvent)
    self.frame.show
    #Arcadia.attach_listener(self, CloseBufferEvent)
	end
	
	def history_file
    if !defined?(@arcadia_history_file)
    		@arcadia_history_file = @arcadia.local_dir+'/'+conf('file.name')
    end
    return @arcadia_history_file
	end
		
  def on_after_open_buffer(_event)
    if _event.file && File.exist?(_event.file)
      self.add2history(_event.file)
      add_to_tree(_event.file)
    end
  end

#  def on_after_close_buffer(_event)
#    if _event.file
#      self.add2history(_event.file)
#      add_to_tree(_event.file)
#    end
#  end

  def select_file_without_event(_file)
    _d, _f = File.split(File.expand_path(_file))
    _d = _d.downcase if is_windows?
    _f = _f.downcase if is_windows?
    _file_node_rif = _d+'@@@'+_f
    if @htree.exist?(_file_node_rif)
      _proc = @htree.selectcommand
      @htree.selectcommand(proc{nil})
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
        @htree.selectcommand(_proc)
      end
    end
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
  
  def build_tree
    file_dir = Hash.new
    nodes = Array.new
    if File.exist?(history_file)
      f = File::open(history_file,'r')
      f_open = $arcadia['pers']['editor.files.open'].split("|") if $arcadia['pers']['editor.files.open']
      begin
        _lines = f.readlines.collect!{| line | line.chomp+"\n" }.to_s
        _lines.sort.each{|_line|
          _file = _line.split(';')[0]
          if FileTest::exist?(_file)
						dir,fil =File.split(File.expand_path(_file))
						dir = dir.downcase if is_windows?
						fil = fil.downcase if is_windows?
						file_dir[dir] = Array.new if file_dir[dir] == nil
						file_dir[dir] << fil if !file_dir[dir].include?(fil)
          end
        }
      ensure
        f.close unless f.nil?
      end
    end

    file_dir.keys.sort.each{|_dir|
    				node = root.dir(_dir)
				file_dir[_dir].each{|file|
				  TreeNode.new(node, 'KFile'){|_node|
              _node.rif= _dir+'@@@'+file
              _node.label=file
				  }
				}
    }

    #@image_kdir = TkPhotoImage.new('dat' => BOOK_GIF)
    @image_kdir = TkPhotoImage.new('dat' => ICON_FOLDER_OPEN_GIF)
    @image_kfile_rb = TkPhotoImage.new('dat' => RUBY_DOCUMENT_GIF)
    @image_kfile = TkPhotoImage.new('dat' => DOCUMENT_GIF)

	  build_tree_from_node(root)
  end

  def add_to_tree(_file)
	 _d, _f = File.split(File.expand_path(_file))
	 return if _f.nil?
	 #Arcadia.new_error_msg(self, "add_to_tree _file=#{_file}")
	 #Arcadia.new_error_msg(self, "add_to_tree _d=#{_d}")
	 #Arcadia.new_error_msg(self, "add_to_tree _f=#{_f}")
	 _d = _d.downcase if is_windows?
	 _f = _f.downcase if is_windows?
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
      elsif _kind == 'KFile' && _label.include?('.rb')
        return @image_kfile_rb
      else
        return @image_kfile
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


  def add2history(_filename, _text_index='1.0')
    if _filename && File.exist?(_filename)
      _filename = _filename.sub(Dir::pwd+'/',"")
      _filename = File.expand_path(_filename)
      _filename_index = _filename+";"+_text_index
     	 #Arcadia.new_error_msg(self, "add2history _filename=#{_filename}")
     	 #Arcadia.new_error_msg(self, "add2history history_file=#{history_file}")

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
            _l= conf('length').to_i
            f.syswrite(_filename_index+"\n")
            _lines[0.._l-2].each{|_line|
              _lfile = _line.split(';')
              if _lfile
                f.syswrite(_line+"\n") if (_lfile[0] != _filename)&&(_line.length > 0)
              end
            }
          end
        ensure
          f.close unless f.nil?
        end
      else
     			dir,fil =File.split(File.expand_path(history_file))
     			if !File.exist?(dir)
     			  Dir.mkdir(dir)
     			end
        f = File.new(history_file, "w+")
        begin
          f.syswrite(_filename+"\n") if f
        ensure
          f.close unless f.nil?
        end
      end
    end
  end
end
