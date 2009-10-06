#
#   a-tkcommons.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "lib/a-commons"
require "tk/menu"

class MyBwTree < Tk::BWidget::Tree

  def open?(node)
    bool(self.itemcget(tagid(node), 'open'))
  end
    
  def areabind(context, *args)
    if TkComm._callback_entry?(args[0]) || !block_given?
      cmd = args.shift
    else
      cmd = Proc.new
    end
    _bind_for_event_class(Event_for_Items, [path, 'bindArea'], 
                          context, cmd, *args)
    self
  end

  def areabind_append(context, *args)
    if TkComm._callback_entry?(args[0]) || !block_given?
      cmd = args.shift
    else
      cmd = Proc.new
    end
    _bind_append_for_event_class(Event_for_Items, [path, 'bindArea'], 
                                 context, cmd, *args)
    self
  end

  def areabind_remove(*args)
    _bind_remove_for_event_class(Event_for_Items, [path, 'bindArea'], *args)
    self
  end

  def areabindinfo(*args)
    _bindinfo_for_event_class(Event_for_Items, [path, 'bindArea'], *args)
  end

end


class TkApplication < Application
  attr_reader :tcltk_info
  def initialize(_application_params)
    super(_application_params)
    @tcltk_info = TclTkInfo.new
  end
  
  def self.sys_info
   "#{super}\n[TclTk version = #{TclTkInfo.new.level}]"
  end
  
  def run
    Tk.appname(self['applicationParams'].name)
    Tk.mainloop
  end
end

module TkMovable
  def start_moving(_moving_obj=self, _moved_obj=self)
    @x0 = 0
    @y0 = 0
    @moving_obj = _moving_obj
    @moved_obj = _moved_obj
    @moving_obj.bind_append("B1-Motion", proc{|x, y| moving_do_move_obj(x,y)},"%x %y")
    @moving_obj.bind_append("ButtonPress-1", proc{|e| moving_do_press(e.x, e.y)})
  end

  def stop_moving
    @moving_obj.bind_remove("B1-Motion")
    @moving_obj.bind_remove("ButtonPress-1")
  end
  
  def moving_do_press(_x, _y)
  		@x0 = _x
  		@y0 = _y
  end
   
  def moving_do_move_obj(_x, _y)
    _x = TkPlace.info(@moved_obj)['x'] + _x - @x0
    _y = TkPlace.info(@moved_obj)['y'] + _y - @y0
    @moved_obj.place('x'=>_x, 'y'=>_y)
  end
  
end

module TkResizable
  MIN_WIDTH = 50
  MIN_HEIGHT = 50
  def start_resizing(_moving_obj=self, _moved_obj=self)
    @x0 = 0
    @y0 = 0
    @moving_obj = _moving_obj
    @moved_obj = _moved_obj
    @moving_obj.bind_append("B1-Motion", proc{|x, y| resizing_do_move_obj(x,y)},"%x %y")
    @moving_obj.bind_append("ButtonPress-1", proc{|e| resizing_do_press(e.x, e.y)})
  end

  def stop_resizing
    @moving_obj.bind_remove("B1-Motion")
    @moving_obj.bind_remove("ButtonPress-1")
  end
  
  def resizing_do_press(_x, _y)
  		@x0 = _x
  		@y0 = _y
  end
   
  def resizing_do_move_obj(_x, _y)
    _width0 = TkPlace.info(@moved_obj)['width']
    _height0 = TkPlace.info(@moved_obj)['height']
    _width = _width0 + _x - @x0
    _height = _height0 + _y -@y0
    _width = MIN_WIDTH if _width < MIN_WIDTH
    _height = MIN_HEIGHT if _height < MIN_HEIGHT
    @moved_obj.place('width'=>_width, 'height'=>_height)
  end
  
end


class AGTkObjPlace
  attr_reader :obj, :r, :start_x, :start_y, :motion, :x0, :y0, :w0, :h0, :width,:height,:relwidth,:relheight
  attr_writer :r, :start_x, :start_y, :motion,:width,:height,:relwidth,:relheight

  def initialize(_obj=nil , _side='both' , _cursor=nil, _bind = true )
    if !_obj
      return
    end
    @obj = _obj
    if !_cursor
      case _side
      when 'x'
        _cursor = 'sb_h_double_arrow'
      when 'y'
        _cursor = 'sb_v_double_arrow'
      when 'both'
        _cursor = 'draft_small'
      end
    end
    @motion = false
    @side = _side
    @x0 = TkPlace.info(@obj)['x']
    @y0 = TkPlace.info(@obj)['y']
    if TkWinfo.mapped?(@obj)
      @w0=TkWinfo.width(@obj)
      @h0=TkWinfo.height(@obj)
    else
      @w0=TkWinfo.reqwidth(@obj)
      @h0=TkWinfo.reqheight(@obj)
    end
    @start_x = @x0
    @start_y = @y0
    @cursor = _cursor
    if _bind
      @obj.bind_append("Enter", proc{|x, y| do_enter(x, y)}, "%x %y")
      @obj.bind_append("ButtonPress-1", proc{|e| do_press(e.x, e.y)})
      @obj.bind_append("B1-Motion", proc{|x, y| do_motion(x,y)},"%x %y")
    end
  end

  def w
    if TkWinfo.mapped?(@obj)
      @w0= TkWinfo.width(@obj)
    else
      @w0= TkWinfo.reqwidth(@obj)
    end
  end

  def h
    if TkWinfo.mapped?(@obj)
      @h0= TkWinfo.height(@obj)
    else
      @h0= TkWinfo.reqheight(@obj)
    end
  end

  def do_enter(x, y)
    @oldcursor = @obj.cget('cursor')
    @obj.configure('cursor'=> @cursor)
  end

  def do_leave
    @obj.configure('cursor'=>@oldcursor)
  end

  def do_press(x, y)
    @start_x = x
    @start_y = y
  end

  def do_motion( _x, _y)
    @motion = true
    move(_x - @start_x, _y - @start_y)
  end

  def move(_x,_y)
    case @side
    when 'both'
      @x0 = @x0 + _x  if (@x0 + _x) >= 0
      @y0 = @y0 + _y
      @obj.place('x' => @x0, 'y' => @y0, 'width' => @width, 'height'=>@height, 'relwidth'=>@relwidth, 'relheight'=>@relheight)
    when 'x'
      @x0 = @x0 + _x  if (@x0 + _x) >= 0
      @obj.place('x' => @x0, 'width' => @width, 'height'=>@height, 'relwidth'=>@relwidth, 'relheight'=>@relheight)
    when 'y'
      @y0 = @y0 + _y
      @obj.place('y' => @y0, 'width' => @width, 'height'=>@height, 'relwidth'=>@relwidth, 'relheight'=>@relheight)
    end
  end

  def amove(_x,_y)
    move(_x - @x0 , _y - @y0)
  end

  def go(_w, _h)
    case @side
    when 'x'
      @w0 = _w
      @obj.place('width' => @w0, 'height'=>@height, 'relwidth'=>@relwidth, 'relheight'=>@relheight)
    when 'y'
      @h0 = _h
      @obj.place('height' => @h0, 'width' => @width, 'relwidth'=>@relwidth, 'relheight'=>@relheight)
    end
  end

end

class TkFrameAdapter < TkFrame
  include TkMovable
  attr_reader :frame
  def initialize(scope_parent=nil, *args)
    super(scope_parent, *args)
    @scope_parent = scope_parent
    @movable = true
    #ObjectSpace.define_finalizer(self, self.method(:detach_frame).to_proc)
  end

  def add_moved_by(_obj)
    @movable = true
    start_moving(_obj, self)
  end
  
  def detach_frame
    if @frame 
      if @movable
        @frame.bind_remove("Configure") 
        @frame.bind_remove("Map") 
        @frame.bind_remove("Unmap") 
      end
      @frame = nil
      self.unplace
    end
  end
  
  def attach_frame(_frame)
    @frame = _frame
    refresh
    if @movable
      @frame.bind_append("Configure",proc{ refresh})
      @frame.bind_append("Map",proc{refresh})
      @frame.bind_append("Unmap",proc{unplace if TkWinfo.mapped?(@frame)})
    end
    self
  end

  
  def refresh(_x=0, _y=0)
    place('in'=>@frame, 'x'=>_x, 'y'=>_y, 'relheight'=> 1, 'relwidth'=>1, 'bordermode'=>'outside')
  end
  
end


class AGTkSplittedFrames < TkFrameAdapter
  attr_reader :frame1
  attr_reader :frame2
  def initialize(parent=nil, frame=nil, length=10, slen=5, keys=nil)
    if keys.nil?
      keys = Hash.new
    end
    keys.update(Arcadia.style('panel'))
    super(parent, keys)
    @parent = parent
    @slen = slen
    if frame
      self.attach_frame(frame)
    end
  end

  def maximize(_frame)
    p = TkWinfo.parent(@frame)
    if p.kind_of?(AGTkSplittedFrames)
      p.maximize(@frame)
    end
  end

  def minimize(_frame)
    p = TkWinfo.parent(@frame)
    if p.kind_of?(AGTkSplittedFrames)
      p.minimize(@frame)
    end
  end

end


class AGTkVSplittedFrames < AGTkSplittedFrames
  attr_reader :left_frame, :right_frame, :splitter_frame
  def initialize(parent=nil, frame=nil, width=10, slen=5, perc=false, keys=nil)
    super(parent, frame, width, slen, keys)
    @left_frame = TkFrame.new(self, Arcadia.style('panel'))
    @frame1 = @left_frame
    if perc
      p_width = TkWinfo.screenwidth(self)
    		x = (p_width/100*width).to_i
    else
      x = width  
    end
    
    @left_frame.place(
      'relx' => 0,
      'x' => 0,
      'y' => '0',
      'relheight' => '1',
      'rely' => 0,
      'bordermode' => 'inside',
      'width' => x
    )
    @left_frame_obj = AGTkObjPlace.new(@left_frame, 'x', nil, false)
    @left_frame_obj.width = x
    @left_frame_obj.height = 0
    @left_frame_obj.relwidth = 0
    @left_frame_obj.relheight = 1

    @splitter_frame = TkFrame.new(self, Arcadia.style('splitter'))

    @splitter_frame.place(
      'relx' => 0,
      'x' => x,
      'y' => '0',
      'relheight' => '1',
      'rely' => 0,
      'bordermode' => 'inside',
      'width' => @slen
    )
    @splitter_frame.bind_append(
      "ButtonRelease-1",
      proc{do_resize}
    )
    #-----
    #-----
#    _self = self
#    @b_left = TkButton.new(nil, Arcadia.style('button')){
#      image TkPhotoImage.new('dat'=>LEFT_SIDE_GIF)
#    }
#
#    @b_right = TkButton.new(nil, Arcadia.style('button')){
#      image TkPhotoImage.new('dat'=>RIGHT_SIDE_GIF)
#    }
#    @proc_unplace = proc{
#      @b_left.unplace
#      @b_right.unplace
#    }
#    @splitter_frame.bind_append(
#      "B1-Motion",
#      proc{@splitter_frame.raise;@proc_unplace.call}
#    )
#    @@last_b_left = nil
#    @@last_b_right = nil
#    @b_left.bind_append('ButtonPress-1',proc{_self.hide_left;@proc_unplace.call})
#    @b_right.bind_append('ButtonPress-1',proc{_self.hide_right;@proc_unplace.call})
#    @proc_place = proc{|x,y|
#      if !TkWinfo.mapped?(@b_left)
#        _x = TkWinfo.pointerx(self) - 10
#        _y = TkWinfo.pointery(self) - 20
#        if @@last_b_left != nil
#          @@last_b_left.unplace
#          @@last_b_right.unplace
#        end
#        @b_left.place('x'=>_x,'y'=>_y,'border'=>'outside')
#        @b_right.place('x'=>_x,'y'=>_y+25,'border'=>'outside')
#        @b_left.raise
#        @b_right.raise
#        @@last_b_left = @b_left
#        @@last_b_right = @b_right
#        if @thread_unplace
#          @thread_unplace.kill
#        end
#        @thread_unplace= Thread.new {
#          sleep(5)
#          @proc_unplace.call
#          kill
#        }
#      end
#    }
#
#    @splitter_frame.bind_append(
#    'ButtonPress-1',
#    proc{|x,y|
#      @thread_place= Thread.new {
#        @proc_place.call(x,y)
#      }
#    }, "%x %y")
    #-----
    #-----
    _xbutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
      background '#4966d7'
    }
    _xbutton.place(
      'x' => 0,
      'y' => 0,
      'relwidth' => 1,
      'bordermode' => 'outside',
      'height' => 20
    )
    _xbutton.bind_append(
      "ButtonPress-1",
      proc{hide_left}
    )
    _ybutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
      background '#118124'
    }
    _ybutton.place(
      'x' => 0,
      'y' => 21,
      'bordermode' => 'outside',
      'height' => 20,
      'relwidth' => 1
    )
    _ybutton.bind_append(
      "ButtonPress-1",
      proc{hide_right}
    )
    #-----
    #-----
    @splitter_frame_obj = AGTkObjPlace.new(@splitter_frame, 'x')
    @splitter_frame_obj.width = @slen
    @splitter_frame_obj.height = 0
    @splitter_frame_obj.relwidth = 0
    @splitter_frame_obj.relheight = 1
    x = x + @slen
    @right_frame = TkFrame.new(self, Arcadia.style('panel'))
    @frame2 = @right_frame
    @right_frame.place(
      'relwidth' => 1,
      'relx' => 0,
      'x' => x,
      'y' => 0,
      'width' => -x,
      'relheight' => 1,
      'rely' => 0,
      'bordermode' => 'inside'
    )
    @right_frame_obj = AGTkObjPlace.new(@right_frame, 'x', nil, false)
    @right_frame_obj.width = -x
    @right_frame_obj.height = 0
    @right_frame_obj.relwidth = 1
    @right_frame_obj.relheight = 1
    @state = 'middle'
    yield(self) if block_given?
  end

  def get_main_x
    if TkWinfo.manager(@parent)=='place'
      return TkPlace.info(@parent)['x'] / 2
    else
      return 20
    end
  end

  def do_resize
    _x = @splitter_frame_obj.x0
    _w = @splitter_frame_obj.w
    @left_frame_obj.width = _x
    @left_frame_obj.go(_x,0)
    @right_frame_obj.width = - _x - _w
    @right_frame_obj.amove(_x + _w,0)
  end

  def hide_left
    if (@state=='left')
      _w = @last
      @state = 'middle'
      @left_frame_obj.width = _w
      @left_frame_obj.go(_w,0)
    else
      _w = 0
      @state = 'right'
      @last = @left_frame_obj.w
    end
    @left_frame_obj.amove(0,0)
    @left_frame_obj.obj.place_forget if @state=='right'
    @splitter_frame_obj.amove(_w,0)
    @right_frame_obj.width = - _w - @slen
    @right_frame_obj.amove(_w + @slen,0)
  end
  
  def is_left_hide?
    @left_frame_obj.w == 0
  end

  def hide_right
    if (@state=='right')
      _w = @last
      @state = 'middle'
    else
      _w = @right_frame_obj.w + @left_frame_obj.w #+ @slen
      @state = 'left'
      @last = @left_frame_obj.w
    end
    @right_frame_obj.width = - _w - @slen
    @right_frame_obj.amove(_w + @slen,0)
    @right_frame_obj.obj.unplace if @state=='left'
    @splitter_frame_obj.amove(_w,0)
    @left_frame_obj.width = _w
    @left_frame_obj.go(_w,0)
  end

  def maximize(_frame)
    super(_frame)
    case _frame
    when left_frame
      hide_right
    when right_frame
      hide_left
    end
    Tk.update
  end

  def minimize(_frame)
    super(_frame)
    case _frame
    when left_frame
      hide_left
    when right_frame
      hide_right
    end
    Tk.update
  end

  def hide(_name)
  end

  def show(_name)
  end

end

class AGTkOSplittedFrames < AGTkSplittedFrames
  attr_reader :top_frame, :bottom_frame, :splitter_frame
  def initialize(parent=nil, frame=nil, height=10, slen=5, perc=false, keys=nil)
    super(parent, frame, height, slen, keys)
    @top_frame = TkFrame.new(self, Arcadia.style('panel')){
     # relief 'flat'
    }
    @frame1 = @top_frame
    if perc
      p_height = TkWinfo.screenheight(self)    
    		y = (p_height/100*height).to_i
    else
      y = height
    end
    @top_frame.place(
      'relwidth' => '1',
      'bordermode' => 'inside',
      'height' => y
    )
    
    @top_frame_obj = AGTkObjPlace.new(@top_frame, 'y', nil, false)
    @top_frame_obj.width = 0
    @top_frame_obj.height = y
    @top_frame_obj.relwidth = 1
    @top_frame_obj.relheight = 0
    @splitter_frame = TkFrame.new(self, Arcadia.style('splitter')){
      #relief  'groove'
      #border 1
    }
    @splitter_frame.place(
      'relx' => 0,
      'x' => 0,
      'y' => y,
      'relwidth' => '1',
      'rely' => 0,
      'bordermode' => 'inside',
      'height' => @slen
    )
    @splitter_frame.bind_append(
      "B1-Motion",
      proc{@splitter_frame.raise}
    )
    @splitter_frame.bind_append(
      "ButtonRelease-1",
      proc{do_resize}
    )
    @splitter_frame_obj = AGTkObjPlace.new(@splitter_frame, 'y')
    @splitter_frame_obj.width = 0
    @splitter_frame_obj.height = @slen
    @splitter_frame_obj.relwidth = 1
    @splitter_frame_obj.relheight = 0
    y = y + @slen
    @bottom_frame = TkFrame.new(self, Arcadia.style('panel')){
     # relief 'flat'
    }
    @frame2 = @bottom_frame
    @bottom_frame.place(
      'relwidth' => 1,
      'relx' => 0,
      'x' => 0,
      'y' => y,
      'height' => -y,
      'relheight' => 1,
      'rely' => 0,
      'bordermode' => 'inside'
    )
    @bottom_frame_obj = AGTkObjPlace.new(@bottom_frame, 'y', nil, false)
    @bottom_frame_obj.width = 0
    @bottom_frame_obj.height = -y
    @bottom_frame_obj.relwidth = 1
    @bottom_frame_obj.relheight = 1
    _xbutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
      background '#4966d7'
    }
    _xbutton.place(
      'x' => 0,
      'y' => 0,
      'relheight' => 1,
      'bordermode' => 'outside',
      'width' => 20
    )
    _xbutton.bind_append(
      "ButtonPress-1",
      proc{hide_top}
    )
    _ybutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
      background '#118124'
    }
    _ybutton.place(
      'x' => 21,
      'y' => 0,
      'bordermode' => 'outside',
      'width' => 20,
      'relheight' => 1
    )
    _ybutton.bind_append(
      "ButtonPress-1",
      proc{hide_bottom}
    )
    @state = 'middle'
    yield(self) if block_given?
  end

  def hide_top
    if (@state=='top')
      _h = @last
      @state = 'middle'
      @top_frame_obj.height = _h
      @top_frame_obj.go(0,_h)
    elsif (@state=='bottom')
      return
    else
      _h = 0
      @state = 'bottom'
      @last = @top_frame_obj.h
    end
    @top_frame_obj.amove(0,0)
    @top_frame_obj.obj.unplace if @state=='bottom'
    @splitter_frame_obj.amove(0, _h)
    @bottom_frame_obj.height = - _h - @slen
    @bottom_frame_obj.amove(0,_h + @slen)
  end

  def hide_bottom
    if (@state=='bottom')
      _h = @last
      @state = 'middle'
    elsif (@state == 'top')
      return
    else
      _h = @bottom_frame_obj.h + @top_frame_obj.h #+ @slen
      @state = 'top'
      @last = @top_frame_obj.h #+ @slen
    end
    @bottom_frame_obj.height = - _h - @slen
    @bottom_frame_obj.amove(0,_h + @slen)
    @bottom_frame_obj.obj.unplace if @state=='top'
    @splitter_frame_obj.amove(0,_h)
    @top_frame_obj.height = _h
    @top_frame_obj.go(0,_h)
  end


  def maximize(_frame)
    super(_frame)
    case _frame
    when top_frame
      hide_bottom
    when bottom_frame
      hide_top
    end
    Tk.update
  end

  def minimize(_frame)
    super(_frame)
    case _frame
    when top_frame
      hide_top
    when bottom_frame
      hide_bottom
    end
    Tk.update
  end


  def get_main_y
    return 40
  end

  def do_resize
    _y = @splitter_frame_obj.y0
    _h = @splitter_frame_obj.h
    @top_frame_obj.height = _y
    @top_frame_obj.go(0,_y)
    @bottom_frame_obj.height = -_y-_h
    @bottom_frame_obj.amove(0,_y + _h)
    #end
  end

  def hide(_name)
  end

  def show(_name)
  end

end

class TkBaseTitledFrame < TkFrame
  attr_reader :frame
  attr_reader :top

  def initialize(parent=nil, *args)
    super(parent, Arcadia.style('panel'))
    @parent = parent
    @title_height = 18
    @top = TkFrame.new(self){
      background  Arcadia.conf('titlelabel.background')
      #foreground  'white'
      #anchor 'w'
    }.place('x'=>0, 'y'=>0,'height'=>@title_height, 'relwidth'=>1)
    #.pack('fill'=> 'x','ipady'=> @title_height, 'side'=>'top')
    @frame = create_frame
    @button_frame=TkFrame.new(@top){
      #background  '#303b50'
      background  Arcadia.conf('titlelabel.background')
    }.pack('side'=> 'right','anchor'=> 'w')
    @buttons = Hash.new
    @menu_buttons = Hash.new
    self.head_buttons
  end

  def create_frame
    return TkFrame.new(self,Arcadia.style('panel')).place('x'=>0, 'y'=>@title_height,'height'=>-@title_height,'relheight'=>1, 'relwidth'=>1)
  end

  def add_button(_label,_proc=nil,_image=nil, _side= 'right')
    TkButton.new(@button_frame, Arcadia.style('toolbarbutton')){
      text  _label if _label
      image  TkPhotoImage.new('dat' => _image) if _image
      #relief 'flat'
      font 'helvetica 8 bold'
      #borderwidth 0
      #background  '#303b50'
      #background  '#8080ff'
      pack('side'=> _side,'anchor'=> 'e')
      bind('1',_proc) if _proc
    }
  end

  def add_menu_button(_name='default',_image=nil, _side= 'right')
    @menu_buttons[_name] = TkMenuButton.new(@button_frame, Arcadia.style('titlelabel')){|mb|
      indicatoron true
      menu TkMenu.new(mb, Arcadia.style('titlemenu'))
#      menu TkMenu.new(:parent=>mb, Arcadia.style('titlemenu'))
#      menu TkMenu.new(:parent=>mb,
#        :tearoff=>0,
#        :background=>Arcadia.style('titlelabel')['background'],
#        :foreground=>Arcadia.style('titlelabel')['foreground']
#      )
      if _image
        image TkPhotoImage.new('dat' => _image)
      end
      pack('side'=> _side,'anchor'=> 'e')
    }
    @menu_buttons[_name]
  end

  def menu_button(_name='default')
    @menu_buttons[_name]
  end

  def head_buttons
    @bmaxmin = add_button('[ ]',proc{resize}, W_MAX_GIF)
  end

end



class TkTitledFrame < TkBaseTitledFrame
  attr_accessor :frame
  attr_reader :top
  attr_reader :parent

  def initialize(parent=nil, title=nil, img=nil , keys=nil)
    super(parent, keys)
    @state = 'normal'
    title.nil??_text_title ='':_text_title = title+' :: ' 
    @title_label =TkLabel.new(@top, Arcadia.style('titlelabel')){
      text _text_title
      anchor  'w'
      compound 'left'
      image  TkAllPhotoImage.new('file' => img) if img
      pack('side'=> 'left','anchor'=> 'e')
    }
    @top_label =TkLabel.new(@top, Arcadia.style('titlelabel')){
      anchor  'w'
      font "#{Arcadia.conf('titlelabel.font')} italic"
      foreground  Arcadia.conf('titlecontext.foreground')
      compound 'left'
      pack('side'=> 'left','anchor'=> 'e')
    }
    
    @ap = Array.new
    @apx = Array.new
    @apy = Array.new
    @apw = Array.new
    @aph = Array.new
  end

  def title(_text=nil)
    if _text.nil?
      return @title
    else
      @title=_text
      if _text.strip.length == 0
        @title_label.text('')
      else
        @title_label.text(_text+'::')
      end
    end
  end

  def top_text(_text=nil)
    if _text.nil?
      return @top_label.text
    else
      @top_label.text(_text)
    end
  end

#  def top_text(_text)
#    @top_label.text(_text)
#  end

  def add_sep(_width=0,_background =@top.background)
    TkLabel.new(@top){||
      text  ''
      background  _background
      pack('side'=> 'right','anchor'=> 'e', 'ipadx'=>_width)
    }
  end


  def head_buttons
    @bmaxmin = add_button('[ ]',proc{resize}, W_MAX_GIF)
    #@bmaxmin = add_button('[ ]',proc{resize}, EXPAND_GIF)
  end

  def resize
    p = TkWinfo.parent(@parent)
    if @state == 'normal'
      if p.kind_of?(AGTkSplittedFrames)
        p.maximize(@parent)
        @bmaxmin.image(TkPhotoImage.new('dat' => W_NORM_GIF))
      end
      @state = 'maximize'
    else
      if p.kind_of?(AGTkSplittedFrames)
        p.minimize(@parent)
        @bmaxmin.image(TkPhotoImage.new('dat' =>W_MAX_GIF))
      end
      @state = 'normal'
    end
    self.raise
  end
  
  def maximized?
    @state == 'maximize'
  end

  def maximize
    if @state == 'normal'
      p = TkWinfo.parent(self)
      while (p != nil) && (TkWinfo.manager(p)=='place')
        Tk.messageBox('message'=>p.to_s)
        @ap << p
        @apx << TkPlace.info(p)['x']
        @apy << TkPlace.info(p)['y']
        @apw << TkPlace.info(p)['width']
        @aph << TkPlace.info(p)['height']
        p.place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1)
        p.raise
        p = TkWinfo.parent(p)
      end
      @state = 'maximize'
      self.raise
    else
      @ap.each_index{|i|
        @ap[i].place('x'=>@apx[i], 'y'=>@apy[i],'width'=>@apw[i], 'height'=>@aph[i],'relheight'=>1, 'relwidth'=>1)
        @ap[i].raise
      }
      self.raise
      @ap.clear
      @apx.clear
      @apy.clear
      @state = 'normal'
    end
  end
end



#class TkFrameAdapterOld < TkFrame
#  include TkMovable
#  attr_reader :frame
#  def initialize(god_parent=nil, *args)
#    super(god_parent, *args)
#    @god_parent = god_parent
#    #add_moved_by(self)
#  end
#  
#  def add_moved_by(_obj)
#    start_moving(_obj, self)
#  end
#
#  def detach_frame
#    if @frame 
#      @frame.bind_remove("Configure") 
#      @frame.bind_remove("Map") 
#      @frame.bind_remove("Unmap") 
#      @frame = nil
#    end
#  end
#  
#  def attach_frame(_frame)
#    @frame = _frame
#    init
#    #update
#    reset
#    @frame.bind_append("Configure",proc{|x,y,w,h| refresh(x,y,w,h)}, "%x %y %w %h")
#    @frame.bind_append("Map",proc{refresh})
#    @frame.bind_append("Unmap",proc{unplace})
#    self
#  end
#
#  def init
#    @last_x = 0
#    @last_y = 0
#    @last_w = 100
#    @last_h = 100
#    reset_offset    
#  end  
#    
#  def reset
#    w = TkPlace.info(@frame)['width']
#    h = TkPlace.info(@frame)['height']
#    x = TkPlace.info(@frame)['x']
#    y = TkPlace.info(@frame)['y']
#    refresh(x,y,w,h)
#  end
#  
#  def reset_offset
#    @x0=0
#    @y0=0
#    parent = TkWinfo.parent(@frame)
#    #parent = @frame
#    while parent != nil && parent != @god_parent
#      xc = TkPlace.info(parent)['x']
#      yc = TkPlace.info(parent)['y']
#      @x0=@x0+xc if xc
#      @y0=@y0+yc if yc
#      parent= TkWinfo.parent(parent)
#    end 
#  end
#  
#  def refresh(_x=nil, _y=nil, _w=nil, _h=nil)
#    reset_offset
#    _x=@last_x if _x.nil?
#    _y=@last_y if _y.nil?
#    _w=@last_w if _w.nil?
#    _h=@last_h if _h.nil?
#    @last_x = _x
#    @last_y = _y
#    @last_w = _w
#    @last_h = _h
#    place('x'=>_x+@x0, 'y'=>_y+@y0, 'width'=>_w, 'height'=> _h, 'bordermode'=>'outside')
#    #place('in'=>@frame, 'relheight'=> 1, 'bordermode'=>'outside', 'relwidth'=>1)
#  end
#end


#class TkTitledMovableFrame < TkTitledFrame
#  attr_reader :wrapper
#  def initialize(root_parent=nil, parent=nil, title=nil, img=nil , keys=nil)
#    @root_parent = root_parent
#    #@wrapper = TkFrameAdapter.new(@root_parent, 'background'=>'red')
#    @wrapper = TkFrameAdapter.new(@root_parent, Arcadia.style('frame'))
#    super(parent, title, img, keys)
#    #@wrapper.add_moved_by(@top)
#    @wrapper.attach_frame(@frame)
#    @frame=@wrapper
#  end
#  
#  def change_wrapper(_new_wrapper)
#    @wrapper = _new_wrapper
#    @frame = _new_wrapper
#  end  
#
#  #  def initialize(root_parent=nil, parent=nil, title=nil, img=nil , keys=nil)
#  #    @root_parent = root_parent
#  #    @wrapper = TkFrameAdapter.new(@root_parent, Arcadia.style('frame'))
#  #    super(@wrapper, title, img, keys)
#  #    @wrapped_frame=parent
#  #    #@wrapper.add_moved_by(@top)
#  #    @wrapper.attach_frame(parent)
#  #  end
#  
#end

class TkTitledScrollFrame < TkTitledFrame

  def create_frame
    return Tk::ScrollFrame.new(self,:scrollbarwidth=>10, :width=>300, :height=>200).place('x'=>0, 'y'=>@title_height,'height'=>-@title_height,'relheight'=>1, 'relwidth'=>1)
  end

end



class TkResizingTitledFrame < TkFrame
  include TkResizable
  def initialize(parent=nil, *args)
    super(parent, *args)
    @resizing_label=TkLabel.new(self, Arcadia.style('label')){
      text '-'
      image TkPhotoImage.new('dat'=>EXPAND_LIGHT_GIF)
    }.pack('side'=> 'right','anchor'=> 's')
    start_resizing(@resizing_label, self)
  end
end


class TkFloatTitledFrame < TkBaseTitledFrame
  include TkMovable
  include TkResizable
  def initialize(parent=nil, *args)
    super(parent)
    frame.place('height'=>-32)
    borderwidth  2
    relief  'groove'

    @top_label = TkLabel.new(@top, Arcadia.style('titlelabel')){
      anchor 'w'
    }.pack('fill'=>'x', 'side'=>'top')
    #.place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1 ,'width'=>-20)

    @resizing_label=TkLabel.new(self, Arcadia.style('label')){
      text '-'
      image TkPhotoImage.new('dat'=>EXPAND_LIGHT_GIF)
    }.pack('side'=> 'right','anchor'=> 's')
    start_moving(@top_label, self)
    start_moving(frame, self)
    start_resizing(@resizing_label, self)
    @grabbed = false
  end

  def title(_text)
    @top_label.text(_text)
  end

  def on_close=(_proc)
    add_button('X', _proc, TAB_CLOSE_GIF)
  end
  
  def hide
    @manager = TkWinfo.manager(self) 
    if @manager == 'place'
    		@x_place = TkPlace.info(self)['x']
    		@y_place = TkPlace.info(self)['y']
    		@width_place = TkPlace.info(self)['width']
    		@height_place = TkPlace.info(self)['height']
    		self.unplace
    end
    
    if @grabbed
      self.grab("release")
      @grabbed = false
    end
    self
  end
  
  def show
    if @manager == 'place'
      self.place('x'=>@x_place, 'y'=>@y_place, 'width'=>@width_place, 'height'=>@height_place)
    end
    self.raise
  end

  def show_grabbed
    show
    @grabbed = true
    self.grab("set")
  end
  
#  def show_modal
#    # not implemented
#  end
  
  def head_buttons
  end

end

class TkProgressframe < TkFloatTitledFrame
  attr_accessor :max
  def initialize(parent=nil, _max=100, *args)
    super(parent)
    _max=1 if _max<=0
    @max = _max
    @progress = TkVariable.new
    @progress.value = -1
    Tk::BWidget::ProgressBar.new(self, :width=>150, :height=>10,
        :background=>'red',
        :foreground=>'blue',
   		   :variable=>@progress,
     		 :borderwidth=>0,
      	 :relief=>'flat',
        :maximum=>_max).place('width' => '150','x' => 25,'y' => 30,'height' => 15)
     
    @buttons_frame = TkFrame.new(self).pack('fill'=>'x', 'side'=>'bottom')	

    @b_cancel = TkButton.new(@buttons_frame){|_b_go|
      default  'disabled'
      text  'Cancel'
      overrelief  'raised'
      justify  'center'
      pack('side'=>'top','ipadx'=>5, 'padx'=>5)
    }

    place('x'=>100,'y'=>100,'height'=> 120,'width'=> 200)
  end
  
  def quit
    #self.destroy
  end
  
  def progress(_incr=1)
    @progress.numeric += _incr
  end

  def on_cancel=(_proc)
    @b_cancel.bind_append('1', _proc)
  end
end

class TkBuffersChoiseView < TkToplevel
  
  def initialize
    super
    Tk.tk_call('wm', 'title', self, '...hello' )
    Tk.tk_call('wm', 'geometry', self, '150x217+339+198' )
    @lb = TkListbox.new(self){
      background  '#fedbd7'
      relief  'groove'
      place('relwidth' => '1','relx' => 0,'x' => '0','y' => '0','relheight' => '1','rely' => 0,'height' => '0','bordermode' => 'inside','width' => '0')
    }
  end
  
end

class TkBuffersChoise < TkBuffersChoiseView
  
  def initialize
    super
    @lb.value= $arcadia['buffers.code.in_memory'].keys
    @lb.bind("Double-ButtonPress-1",proc{
      _sel = @lb.get('active')
      Revparsel.new($arcadia['buffers.code.in_memory'][_sel])
      @lb.delete('active')
      $arcadia['buffers.code.in_memory'].delete(_sel)
      destroy
    })
    raise
  end
  
end

class TclTkInfo
  attr_reader :level
  def initialize
    @level = Tk.tk_call( "eval", "info patchlevel")
    # @level = TclTkIp.new._eval "info patchlevel"
  end
end


class TkScrollText < TkText
  def initialize(parent=nil, keys={})
    super(parent, keys)
    @scroll_width = 15
    @v_scroll_on = false
    @h_scroll_on = false
    @v_scroll = TkScrollbar.new(parent,{
      'orient'=>'vertical'}.update(Arcadia.style('scrollbar'))
    )
    @v_scroll.command(proc{|*args|
      self.yview *args
    })
    self.yscrollcommand(proc{|first,last| 
      self.do_yscrollcommand(first,last)
    })
    
    @h_scroll = TkScrollbar.new(parent,{
      'orient'=>'horizontal'}.update(Arcadia.style('scrollbar'))
    )
    @h_scroll.command(proc{|*args|
      self.xview *args
    })
    self.xscrollcommand(proc{|first,last| 
      self.do_xscrollcommand(first,last)
    })
  end
  def add_yscrollcommand(cmd=Proc.new)
    @v_scroll_command = cmd
  end   
  def do_yscrollcommand(first,last)
    #p "do_yscrollcommand first=#{first} last=#{last}"
    @v_scroll.set(first,last)
    @v_scroll_command.call(first,last) if !@v_scroll_command.nil?
  end
  def add_xscrollcommand(cmd=Proc.new)
    @h_scroll_command = cmd
  end   
  def do_xscrollcommand(first,last)
    #p "do_xscrollcommand first=#{first} last=#{last}"
    @h_scroll.set(first,last)
    @h_scroll_command.call(first,last) if !@h_scroll_command.nil?
  end
  
  def show(_x=0,_y=0,_border_mode='outside')
    @x=_x
    @y=_y
    place(
      'x'=>@x,
      'y'=>@y,
      'width' => -@x,
      'height' => -@y,
      'relheight'=>1,
      'relwidth'=>1,
      'bordermode'=>_border_mode
   )
   if @v_scroll_on
     show_v_scroll
   end
   if @h_scroll_on
     show_h_scroll
   end
  end
  
  def show_v_scroll
    self.place('width' => -@scroll_width-@x)
    @v_scroll.pack('side' => 'right', 'fill' => 'y')
    @v_scroll_on = true
  end

  def show_h_scroll
    self.place('height' => -@scroll_width-@y)
    @h_scroll.pack('side' => 'bottom', 'fill' => 'x')
    @h_scroll_on = true
  end

  def hide_v_scroll
    self.place('width' => 0)
    @v_scroll.unpack
    @v_scroll_on = false
  end

  def hide_h_scroll
    self.place('height' => 0)
    @h_scroll.unpack
    @h_scroll_on = false  
  end

end

class TkScrollWidget
  def initialize(widget)
    @widget = widget
    @parent = TkWinfo.parent(@widget)
    @scroll_width = 15
    @v_scroll_on = false
    @h_scroll_on = false
    @v_scroll = TkScrollbar.new(@parent,{
      'orient'=>'vertical'}.update(Arcadia.style('scrollbar'))
    )
    @v_scroll.command(proc{|*args|
      @widget.yview *args
    })
    @widget.yscrollcommand(proc{|first,last| 
      do_yscrollcommand(first,last)
    })
    
    @h_scroll = TkScrollbar.new(@parent,{
      'orient'=>'horizontal'}.update(Arcadia.style('scrollbar'))
    )
    @h_scroll.command(proc{|*args|
      @widget.xview *args
    })
    @widget.xscrollcommand(proc{|first,last| 
      do_xscrollcommand(first,last)
    })
  end
  
  def add_yscrollcommand(cmd=Proc.new)
    @v_scroll_command = cmd
  end   
  
  def do_yscrollcommand(first,last)
    @v_scroll.set(first,last)
    @v_scroll_command.call(first,last) if !@v_scroll_command.nil?
  end
  
  def add_xscrollcommand(cmd=Proc.new)
    @h_scroll_command = cmd
  end   
  
  def do_xscrollcommand(first,last)
    @h_scroll.set(first,last)
    @h_scroll_command.call(first,last) if !@h_scroll_command.nil?
  end
  
  def show(_x=0,_y=0,_border_mode='outside')
    @x=_x
    @y=_y
    @widget.place(
      'x'=>@x,
      'y'=>@y,
      'width' => -@x,
      'height' => -@y,
      'relheight'=>1,
      'relwidth'=>1,
      'bordermode'=>_border_mode
   )
   if @v_scroll_on
     show_v_scroll
   end
   if @h_scroll_on
     show_h_scroll
   end
  end

  def hide
    @widget.unplace
    @v_scroll.unpack
    @h_scroll.unpack
  end
  
  def show_v_scroll
    @widget.place('width' => -@scroll_width-@x)
    @v_scroll.pack('side' => 'right', 'fill' => 'y')
    @v_scroll_on = true
  end

  def show_h_scroll
    @widget.place('height' => -@scroll_width-@y)
    @h_scroll.pack('side' => 'bottom', 'fill' => 'x')
    @h_scroll_on = true
  end

  def hide_v_scroll
    @widget.place('width' => 0)
    @v_scroll.unpack
    @v_scroll_on = false
  end

  def hide_h_scroll
    @widget.place('height' => 0)
    @h_scroll.unpack
    @h_scroll_on = false  
  end

end

class KeyTest < TkFloatTitledFrame
  attr_reader :ttest
  def initialize(_parent=nil)
    _parent = Arcadia.instance.layout.root if _parent.nil?
    super(_parent)

    #Tk.tk_call('wm', 'title', self, '...hello' )
    #Tk.tk_call('wm', 'geometry', self, '638x117+200+257' )

    @ttest = TkText.new(self.frame){
      background  '#FFF454'
      #place('relwidth' => '1','relx' => 0,'x' => '0','y' => '0','relheight' => '1','rely' => 0,'height' => '0','bordermode' => 'inside','width' => '0')
    }.bind("KeyPress"){|e|
      @ttest.insert('end'," "+e.keysym+" ")
      break
    }
    _wrapper = TkScrollWidget.new(@ttest)
    _wrapper.show
    _wrapper.show_v_scroll
    _wrapper.show_h_scroll
    place('x'=>100,'y'=>100,'height'=> 220,'width'=> 500)
  end
end


