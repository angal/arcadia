#
#   a-tkcommons.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "#{Dir.pwd}/lib/a-commons"
require "tk/menu"

class BWidgetTreePatched < Tk::BWidget::Tree

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

#  def selectcommand(_proc=nil)
#    self.configure('selectcommand'=>_proc)
#  end

  def selected
    if self.selection_get[0]
      if self.selection_get[0].respond_to?(:length) && self.selection_get[0].length >0
       	_selected = ""
        if self.selection_get[0].instance_of?(Array)
          selection_lines = self.selection_get[0]
        else
          if String.method_defined?(:lines)
        	   selection_lines = self.selection_get[0].lines
          else
        	   selection_lines = self.selection_get[0].split("\n")
          end
        end
        selection_lines.each{|_block|
          _selected = _selected + _block.to_s + "\s" 
        }
        _selected = _selected.strip
      else
        _selected = self.selection_get[0]
      end
    end
    return _selected
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
    @x0_m = 0
    @y0_m = 0
    @moving_obj_m = _moving_obj
    @moved_obj_m = _moved_obj
    @moving_obj_m.bind_append("B1-Motion", proc{|x, y| moving_do_move_obj(x,y)},"%x %y")
    @moving_obj_m.bind_append("ButtonPress-1", proc{|e| moving_do_press(e.x, e.y)})
  end

  def stop_moving
    @moving_obj_m.bind_remove("B1-Motion")
    @moving_obj_m.bind_remove("ButtonPress-1")
  end

  def moving_do_press(_x, _y)
    @x0_m = _x
    @y0_m = _y
  end

  def moving_do_move_obj(_x, _y)
    _x = TkPlace.info(@moved_obj_m)['x'] + _x - @x0_m
    _y = TkPlace.info(@moved_obj_m)['y'] + _y - @y0_m
    @moved_obj_m.place('x'=>_x, 'y'=>_y)
  end

end

module TkResizable
  MIN_WIDTH = 50
  MIN_HEIGHT = 50
  def start_resizing(_moving_obj=self, _moved_obj=self)
    @x0_r = 0
    @y0_r = 0
    @moving_obj_r = _moving_obj
    @moved_obj_r = _moved_obj
    @moving_obj_r.bind_append("B1-Motion", proc{|x, y| resizing_do_move_obj(x,y)},"%x %y")
    @moving_obj_r.bind_append("ButtonPress-1", proc{|e| resizing_do_press(e.x, e.y)})
  end

  def stop_resizing
    @moving_obj_r.bind_remove("B1-Motion")
    @moving_obj_r.bind_remove("ButtonPress-1")
  end

  def resizing_do_press(_x, _y)
    @x0_r = _x
    @y0_r = _y
  end

  def resizing_do_move_obj(_x, _y)
    _width0 = TkPlace.info(@moved_obj_r)['width']
    _height0 = TkPlace.info(@moved_obj_r)['height']
    _width = _width0 + _x - @x0_r
    _height = _height0 + _y -@y0_r
    _width = MIN_WIDTH if _width < MIN_WIDTH
    _height = MIN_HEIGHT if _height < MIN_HEIGHT
    @moved_obj_r.place('width'=>_width, 'height'=>_height)
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
  #include TkMovable
  attr_reader :frame
  def initialize(scope_parent=nil, args=nil)
    newargs =  Arcadia.style('panel')
    if !args.nil?
      newargs.update(args) 
    end
    super(scope_parent, newargs)
    @scope_parent = scope_parent
    #@movable = false
  end

#  def add_moved_by(_obj)
#    @movable = true
#    start_moving(_obj, self)
#  end

  def detach_frame
    if @frame
      self.bind_remove("Map")
      self.unmap(@manager_forced_to_frame)
      @frame = nil
    end
  end

  def attach_frame(_frame, _extension = nil, _frame_index=0)
    @frame = _frame
    refresh_layout_manager
    self.map
    if _extension
      @frame.bind("Map", proc{
        if _extension.frame_raised?(_frame_index)
          @frame.raise
        else
          @frame.lower
        end
      })

      
#      ffw = Arcadia.instance.layout.frame(_extension.frame_domain(_frame_index),_extension.name)
#      if ffw
#        ffw.bind("Map", proc{
#          if _extension.frame_raised?(_frame_index)
#            p "pack"
#            @frame.pack
#            @frame.raise
#          else
#            p "unpack"
#            @frame.lower
#            @frame.unpack
#          end
#        })
#      end
    else
      self.bind("Map", proc{@frame.raise})
    end
    self
  end
  
  def layout_manager
    @frame_manager
  end
  
  def refresh_layout_manager
    @frame_manager = TkWinfo.manager(@frame)
  end

  def is_undefined?
    @frame_manager.nil? || @frame_manager == ''
  end

  def is_place?
    @frame_manager == 'place' || is_undefined?
  end

  def is_pack?
    @frame_manager == 'pack'
  end

  def map(_layout_manager=nil)
    if _layout_manager == "place" || (_layout_manager.nil? && is_place?) 
      if is_undefined? && _layout_manager
        @frame.place('x'=>0, 'y'=>0, 'relheight'=> 1, 'relwidth'=>1, 'bordermode'=>'outside')
        @manager_forced_to_frame = "place" 
      end
      place('in'=>@frame, 'x'=>0, 'y'=>0, 'relheight'=> 1, 'relwidth'=>1, 'bordermode'=>'outside')
    elsif _layout_manager == "pack" || (_layout_manager.nil? && is_pack?)
      if is_undefined? && _layout_manager
        @frame.pack('fill'=>'both', :padx=>0, :pady=>0,  'expand'=>'yes')
        @manager_forced_to_frame = "pack" 
      end
      pack('in'=>@frame, 'fill'=>'both', :padx=>0, :pady=>0,  'expand'=>'yes')
    end
  end

  def unmap(_layout_manager=nil)
    if _layout_manager == "place" || (_layout_manager.nil? && is_place?)
      self.unplace
      @frame.unplace if @frame && @manager_forced_to_frame == "place"
    elsif _layout_manager == "pack" || (_layout_manager.nil? && is_pack?)
      self.unpack
      @frame.unpack if @frame  && @manager_forced_to_frame == "pack"
    end
  end

end

class AGTkSplittedFrames < TkFrameAdapter
  attr_reader :frame1
  attr_reader :frame2
  def initialize(parent=nil, frame=nil, length=10, slen=5, user_control=true, keys=nil)
#    if keys.nil?
#      keys = Hash.new
#    end
#    keys.update(Arcadia.style('panel'))
    super(parent, keys)
    @parent = parent
    @slen = slen
    @user_control = user_control
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
  def initialize(parent=nil, frame=nil, width=10, slen=5, perc=false, user_control=true, keys=nil)
    super(parent, frame, width, slen, user_control, keys)
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

    if @user_control
      @splitter_frame.bind_append(
      "ButtonRelease-1",
      proc{do_resize}
      )
      _xbutton = Arcadia.wf.toolbutton(@splitter_frame){
        image Arcadia.image_res(VERTICAL_SPLITTER_HIDE_LEFT_GIF)
      }
#      _xbutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
#        background '#4966d7'
#      }
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
      _ybutton = Arcadia.wf.toolbutton(@splitter_frame){
        image Arcadia.image_res(VERTICAL_SPLITTER_HIDE_RIGHT_GIF)
      }
#      _ybutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
#        background '#118124'
#      }
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
    end
    #-----
    #-----
    @splitter_frame_obj = AGTkObjPlace.new(@splitter_frame, 'x', nil, @user_control)
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

  def move_splitter(_gapx=0,_gapy=0)
    @splitter_frame_obj.amove(_gapx,_gapy)
    do_resize
  end

  def resize_left(_new_width)
    @left_frame_obj.width = _new_width
    @left_frame_obj.go(_new_width,0)
    @left_frame_obj.amove(0,0)
    @splitter_frame_obj.amove(_new_width,0)
    @right_frame_obj.width = - _new_width - @slen
    @right_frame_obj.amove(_new_width + @slen,0)
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

  def show_left
    if @state=='right'
      _w = @last
      @state = 'middle'
      @right_frame_obj.width = - _w - @slen
      @right_frame_obj.amove(_w + @slen,0)
      @splitter_frame_obj.amove(_w,0)
      @left_frame_obj.width = _w
      @left_frame_obj.go(_w,0)
    end
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
    @right_frame_obj.obj.place_forget if @state=='left'
    #.unplace if @state=='left'
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
  def initialize(parent=nil, frame=nil, height=10, slen=5, perc=false, user_control=true, keys=nil)
    super(parent, frame, height, slen, user_control, keys)
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
    @splitter_frame_obj = AGTkObjPlace.new(@splitter_frame, 'y', nil, user_control)
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
    if @user_control
      @splitter_frame.bind_append(
      "B1-Motion",
      proc{@splitter_frame.raise}
      )
      @splitter_frame.bind_append(
      "ButtonRelease-1",
      proc{do_resize}
      )
      _xbutton = Arcadia.wf.toolbutton(@splitter_frame){
        image Arcadia.image_res(HORIZONTAL_SPLITTER_HIDE_TOP_GIF)
      }
#      _xbutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
#        background '#4966d7'
#      }
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

      _ybutton = Arcadia.wf.toolbutton(@splitter_frame){
        image Arcadia.image_res(HORIZONTAL_SPLITTER_HIDE_BOTTOM_GIF)
      }
#      _ybutton = TkButton.new(@splitter_frame, Arcadia.style('toolbarbutton')){
#        background '#118124'
#      }
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
    end
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
    }.place('x'=>0, 'y'=>0,'height'=>@title_height, 'relwidth'=>1)
    #.pack('fill'=> 'x','ipady'=> @title_height, 'side'=>'top')
    @frame = create_frame

    @state_frame=TkFrame.new(@top){
      #background  '#303b50'
      background  Arcadia.conf('titlelabel.background')
    }.pack('side'=> 'left','anchor'=> 'e')

    @button_frame=TkFrame.new(@top){
      #background  '#303b50'
      background  Arcadia.conf('titlelabel.background')
    }.pack('side'=> 'right','anchor'=> 'w', 'fill'=>'both', 'expand'=>'true')

    @buttons = Hash.new
    @menu_buttons = Hash.new
    @panels = Hash.new
    @last_for_frame = Hash.new
    @last_for_state_frame = Hash.new
    self.head_buttons
  end

  def create_frame
    return TkFrame.new(self,Arcadia.style('panel')).place('x'=>0, 'y'=>@title_height,'height'=>-@title_height,'relheight'=>1, 'relwidth'=>1)
  end

  def add_fixed_button(_label,_proc=nil,_image=nil, _side= 'right')
    __add_button(_label,_proc,_image, _side,@button_frame)
  end

  def add_fixed_menu_button(_name='default',_image=nil, _side= 'right', _args=nil)
    __add_menu_button(_name, _image, _side, _args, @button_frame)
  end

  def add_fixed_panel(_name='default',_side= 'right', _args=nil)
    __add_panel(_name, _side, _args, @button_frame)
  end

  def add_fixed_sep(_width=0)
    __add_sep(_width, @button_frame)
  end

  def add_fixed_progress(_max=100, _canc_proc=nil, _hint=nil)
    __add_progress(_max, _canc_proc, @button_frame, _hint)
  end

  def __add_button(_label,_proc=nil,_image=nil, _side= 'right', _frame=nil)
    return if _frame.nil?
    begin
      last = @last_for_frame[_frame]
#      @last_for_frame[_frame] = TkButton.new(_frame, Arcadia.style('titletoolbarbutton')){
      @last_for_frame[_frame] = Arcadia.wf.titletoolbutton(_frame){
        text  _label if _label
        image  Arcadia.image_res(_image) if _image
#        padx 0
#        pady 0
        if last
          pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
        else
          pack('side'=> _side,'anchor'=> 'e')
        end
        bind('1',_proc) if _proc
      }
      Tk::BWidget::DynamicHelp::add(@last_for_frame[_frame], 'text'=>_label) if _label
      @last_for_frame[_frame]
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
  end
  private :__add_button

  def __add_menu_button(_name='default',_image=nil, _side= 'right', _args=nil, _frame=nil)
    return if _frame.nil?
    args = Arcadia.style('titlelabel')
    args.update(_args) if _args
    last = @last_for_frame[_frame]
    @last_for_frame[_frame] =  @menu_buttons[_name] = Arcadia.wf.titlecontextmenubutton(_frame, _args){|mb|
      menu Arcadia.wf.titlemenu(mb)
#      menu TkMenu.new(mb, Arcadia.style('titlemenu'))
      if _image
#        indicatoron false
        image Arcadia.image_res(_image)
      else
#        indicatoron true
      end
#      padx 0
      if last
        pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
      else
        pack('side'=> _side,'anchor'=> 'e')
      end
    }
    
#    @last_for_frame[_frame] =  @menu_buttons[_name] = TkMenuButton.new(_frame, args){|mb|
#      menu TkMenu.new(mb, Arcadia.style('titlemenu'))
#      if _image
#        indicatoron false
#        image Arcadia.image_res(_image)
#      else
#        indicatoron true
#      end
#      padx 0
#      if last
#        pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
#      else
#        pack('side'=> _side,'anchor'=> 'e')
#      end
#    }
    @menu_buttons[_name]
  end
  private :__add_menu_button

  def __add_check_button(_label,_proc=nil,_image=nil, _side= 'right', _frame=nil)
    return if _frame.nil?
    begin
      last = @last_for_frame[_frame]
#      @last_for_frame[_frame] = TkCheckButton.new(_frame, Arcadia.style('checkbox').update('background'=>_frame.background)){
#        text  _label if _label
#        image  Arcadia.image_res(_image) if _image
#        padx 0
#        pady 0
#        if last
#          pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
#        else
#          pack('side'=> _side,'anchor'=> 'e')
#        end
#        command(_proc) if _proc
#      }
#      Tk::BWidget::DynamicHelp::add(@last_for_frame[_frame], 'text'=>_label) if _label

      @last_for_frame[_frame] = Arcadia.wf.titlecontextcheckbutton(@panel){
        text  _label if _label
        variable TkVariable.new
        image Arcadia.image_res(_image) if _image
        if last
          pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
        else
          pack('side'=> _side,'anchor'=> 'e')
        end
        command(_proc) if _proc
      }
      @last_for_frame[_frame].hint=_label if _label 
      @last_for_frame[_frame]
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
  end
  private :__add_check_button

  def __add_panel(_name='default', _side= 'right', _args=nil, _frame=nil)
    return if _frame.nil?
    args = Arcadia.style('panel').update('background'=>_frame.background, 'highlightbackground'=>_frame.background)
    args.update(_args) if _args
    begin
      last = @last_for_frame[_frame]
      @last_for_frame[_frame] = @panels[_name]= TkFrame.new(_frame, args){
        padx 0
        pady 0
        if last
          pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
        else
          pack('side'=> _side,'anchor'=> 'e')
        end
      }
      @panels[_name]
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
  end
  private :__add_panel

  def __add_sep(_width=0, _frame=nil)
    return if _width <= 0 || _frame.nil?
    _background=_frame.background
    last = @last_for_frame[_frame]
    @last_for_frame[_frame] =  TkLabel.new(_frame){||
      text  ''
      background  _background
      if last
        pack('side'=> 'right','anchor'=> 'e', 'ipadx'=>_width, 'after'=>last)
      else
        pack('side'=> 'right','anchor'=> 'e', 'ipadx'=>_width)
      end
    }
  end
  private :__add_sep

  def __add_state_button(_label,_proc=nil,_image=nil, _side= 'left', _frame=nil)
    return if _frame.nil?
    begin
      last = @last_for_state_frame[_frame]
      #@last_for_state_frame[_frame] = TkButton.new(_frame, Arcadia.style('titletoolbarbutton')){
      @last_for_state_frame[_frame] = Arcadia.wf.titletoolbutton(_frame){
        text  _label if _label
        image  Arcadia.image_res(_image) if _image
       # font 'helvetica 8 bold'
       # padx 0
       # pady 0
        if last
          pack('side'=> _side,'anchor'=> 'w', 'after'=>last)
        else
          pack('side'=> _side,'anchor'=> 'w')
        end
        bind('1',_proc) if _proc
      }
      @last_for_state_frame[_frame].hint=_label
      #Tk::BWidget::DynamicHelp::add(@last_for_state_frame[_frame], 'text'=>_label) if _label
      @last_for_state_frame[_frame]
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
  end
  private :__add_state_button

  def __add_progress(_max, _canc_proc=nil, _frame=nil, _hint=nil, _side= 'left')
    
    return if _frame.nil?
    begin
      last = @last_for_frame[_frame]
      @last_for_frame[_frame] = TkFrameProgress.new(_frame, _max)
      if last
        @last_for_frame[_frame].pack('side'=> _side,'anchor'=> 'e', 'after'=>last)
      else
        @last_for_frame[_frame].pack('side'=> _side,'anchor'=> 'e')
      end
      
      @last_for_frame[_frame].on_cancel=_canc_proc if _canc_proc

      Tk::BWidget::DynamicHelp::add(@last_for_frame[_frame], 'text'=>_hint) if _hint
      @last_for_frame[_frame]
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
  end
  private :__add_progress

  def __destroy_progress(_progress, _frame)
    @last_for_frame[_frame] = nil if @last_for_frame[_frame] == _progress
    _progress.destroy
  end
  private :__destroy_progress

  def menu_button(_name='default')
    @menu_buttons[_name]
  end

  def head_buttons
    @bmaxmin = add_fixed_button('[ ]',proc{resize}, W_MAX_GIF)
  end

  def visible?
    ret = false
    begin
      ret = TkWinfo.mapped?(self)
    rescue Exception => e
    end
  end
end

class TkTitledFrame < TkBaseTitledFrame
  attr_accessor :frame
  attr_reader :top
  attr_reader :parent
  def initialize(parent=nil, title=nil, img=nil , keys=nil)
    super(parent, keys)
    @state = 'normal'
    @title = title
    @img = img
#    @left_label = create_left_label
    @left_label = create_left_title
    @right_label = create_right_label
    @right_labels_text = Hash.new
    @right_labels_image = Hash.new
    @ap = Array.new
    @apx = Array.new
    @apy = Array.new
    @apw = Array.new
    @aph = Array.new
    @top.bind_append("Double-Button-1", proc{resize})
    #@left_label.bind_append("Double-Button-1", proc{resize})
    @right_label.bind_append("Double-Button-1", proc{resize})
  end

#  def create_left_label
#    __create_left_label(@top)
#  end

  def create_right_label
    __create_right_label(@top)
  end

#  def __create_left_label(_frame)
#    @title.nil??_text_title ='':_text_title = @title+' :: '
#    _img=@img
#    TkLabel.new(_frame, Arcadia.style('titlelabel')){
#      text _text_title
#      anchor  'w'
#      compound 'left'
#      image  TkAllPhotoImage.new('file' => _img) if _img
#      pack('side'=> 'left','anchor'=> 'e')
#    }
#  end

  def __create_right_label(_frame)
    TkLabel.new(_frame, Arcadia.style('titlelabel')){
      anchor  'w'
      font "#{Arcadia.conf('titlelabel.font')} italic"
      foreground  Arcadia.conf('titlecontext.foreground')
      compound 'left'
      pack('side'=> 'left','anchor'=> 'e')
    }
  end
  
#  def shift_on
#    @left_label.foreground(Arcadia.conf('titlelabel.foreground'))
#  end
#  
#  def shift_off
#    @left_label.foreground(Arcadia.conf('titlelabel.disabledforeground'))
#  end
  
#  def title(_text=nil)
#    if _text.nil?
#      return @title
#    else
#      @title=_text
#      if _text.strip.length == 0
#        @left_label.text('')
#      else
#        @left_label.text(_text+'::')
#      end
#    end
#  end

  def top_text_clear
    @right_label.configure('text'=>'', 'image'=>nil)
  end

  def top_text_hide
    @right_label.unpack
  end

  def top_text(_text=nil, _image=nil)
    if _text.nil? && _image.nil?
      return @right_label.text
    elsif !_text.nil? && _image.nil?
      @right_label.text(_text)
    else
      @right_label.configure('text'=>_text, 'image'=>_image)
    end
  end

  def top_text_bind_append(_tkevent, _proc=nil)
    @right_label.bind_append(_tkevent, _proc)
  end

  def top_text_bind_remove(_tkevent)
    @right_label.bind_remove(_tkevent)
  end

  def top_text_hint(_text=nil)
    if _text.nil?
      res = ''
      res = @right_label_hint_variable.value if defined?(@right_label_hint_variable)
      res
    else
      if !defined?(@right_label_hint_variable)
        @right_label_hint_variable = TkVariable.new
        Tk::BWidget::DynamicHelp::add(@right_label, 'variable'=>@right_label_hint_variable)
      end      
      @right_label_hint_variable.value=_text
    end
  end

  def save_caption(_name, _caption, _image=nil)
    @right_labels_text[_name] = _caption
    @right_labels_image[_name] = _image
  end

  def last_caption(_name)
    @right_labels_text[_name]
  end

  def last_caption_image(_name)
    @right_labels_image[_name]
  end

  def restore_caption(_name)
    if @right_labels_text[_name]
      top_text(@right_labels_text[_name], @right_labels_image[_name])
    else
      top_text_clear
    end
  end

  #  def top_text(_text)
  #    @right_label.text(_text)
  #  end

  def head_buttons
    @bmaxmin = add_fixed_button('[ ]',proc{resize}, W_MAX_GIF)
    #@bmaxmin = add_button('[ ]',proc{resize}, EXPAND_GIF)
  end

  def resize
    p = TkWinfo.parent(@parent)
    if @state == 'normal'
      if p.kind_of?(AGTkSplittedFrames)
        p.maximize(@parent)
        @bmaxmin.image(Arcadia.image_res(W_NORM_GIF))
      end
      @state = 'maximize'
    else
      if p.kind_of?(AGTkSplittedFrames)
        p.minimize(@parent)
        @bmaxmin.image(Arcadia.image_res(W_MAX_GIF))
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
        Arcadia.dialog(self, 'msg'=>p.to_s)
        #Tk.messageBox('message'=>p.to_s)
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


class TkLabelTitledFrame < TkTitledFrame

  def create_left_title
    @left_label = __create_left_label(@top)
    @left_label.bind_append("Double-Button-1", proc{resize})
  end

  def __create_left_label(_frame)
    @title.nil??_text_title ='':_text_title = @title+' :: '
    _img=@img
    TkLabel.new(_frame, Arcadia.style('titlelabel')){
      text _text_title
      anchor  'w'
      compound 'left'
      image  TkAllPhotoImage.new('file' => _img) if _img
      pack('side'=> 'left','anchor'=> 'e')
    }
  end

  def shift_on
    @left_label.state='normal'
    #@left_label.foreground(Arcadia.conf('titlelabel.foreground'))
  end
  
  def shift_off
    @left_label.state='disable'
    #@left_label.foreground(Arcadia.conf('titlelabel.disabledforeground'))
  end
  
  def title(_text=nil)
    if _text.nil?
      return @title
    else
      @title=_text
      if _text.strip.length == 0
        @left_label.text('')
      else
        @left_label.text(_text+'::')
      end
    end
  end
end

class TkLabelTitledFrameClosable < TkLabelTitledFrame
    def head_buttons
      @bclose = add_fixed_button('[ ]',proc{}, CLOSE_FRAME_GIF)
    end
    
    def add_close_action(_proc)
      @bclose.bind_append("1", _proc)
    end
end


class TkMenuTitledFrame < TkTitledFrame
  def create_left_title
    @left_menu_button = __create_left_menu_button(@top)
    @left_menu_button.bind_append("Double-Button-1", proc{resize})
  end

  def title_menu
    @left_menu_button.cget('menu') if @left_menu_button
  end

  def __create_left_menu_button(_frame)
    img=@img
    #@left_menu_button = TkMenuButton.new(_frame, Arcadia.style('titlebutton')){|mb|
    @left_menu_button = Arcadia.wf.titlemenubutton(_frame){|mb|
      menu Arcadia.wf.titlemenu(mb)
      #menu TkMenu.new(mb, Arcadia.style('titlemenu'))
      if img
        #indicatoron false
        image Arcadia.image_res(img)
      else
        #indicatoron true
      end
      #padx 0
      textvariable TkVariable.new('')
      pack('side'=> 'left','anchor'=> 'e')
    }

  end

  def shift_on
    @left_menu_button.state='normal'
    #@left_menu_button.foreground(Arcadia.conf('titlelabel.foreground'))
  end
  
  def shift_off
    @left_menu_button.state='disable'
    #@left_menu_button.foreground(Arcadia.conf('titlelabel.disabledforeground'))
  end
  
  def title(_text=nil)
    if _text.nil?
      return @title
    else
      @title=_text
      if _text.strip.length == 0
        @left_menu_button.textvariable.value=''
      else
        @left_menu_button.textvariable.value=_text+'::'
      end
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

class TkTitledFrameAdapter < TkMenuTitledFrame
  attr_reader :transient_frame_adapter

  def initialize(parent=nil, title=nil, img=nil , keys=nil)
    super(parent, title, img, keys)
    @transient_action_frame = TkFrame.new(@button_frame){
      background  Arcadia.conf('titlelabel.background')
      padx 0
      pady 0
      pack('side'=> "right",'anchor'=> 'e','fill'=>'both', 'expand'=>true)
    }
    @transient_state_frame = TkFrame.new(@state_frame){
      background  Arcadia.conf('titlelabel.background')
      padx 0
      pady 0
      pack('side'=> "left",'anchor'=> 'w','fill'=>'both', 'expand'=>true)
    }
    @transient_frame_adapter = Hash.new
    @@instances = [] if !defined?(@@instances)
    @@instances << self 
  end

  def forge_transient_adapter(_name)
    if @transient_frame_adapter[_name].nil?
      @transient_frame_adapter[_name] = Hash.new
      @transient_frame_adapter[_name][:action] = TkFrameAdapter.new(Arcadia.layout.root, {'background'=>  Arcadia.conf('titlelabel.background')})
      @transient_frame_adapter[_name][:state] = TkFrameAdapter.new(Arcadia.layout.root, {'background'=>  Arcadia.conf('titlelabel.background')})
      __attach_action_adapter(@transient_frame_adapter[_name][:action])
      __attach_action_adapter(@transient_frame_adapter[_name][:state])
      @transient_frame_adapter[_name][:action].raise
      @transient_frame_adapter[_name][:state].raise
    end
    @transient_frame_adapter[_name]
  end

#  def __attach_adapter(_adapter)
#    @last_attached_adapter.detach_frame if @last_attached_adapter
#    _adapter.attach_frame(@transient_action_frame)
#    @last_attached_adapter = _adapter
#  end

  def __attach_action_adapter(_adapter)
    @last_attached_action_adapter.detach_frame if @last_attached_action_adapter
    _adapter.attach_frame(@transient_action_frame)
    @last_attached_action_adapter = _adapter
  end

  def __attach_state_adapter(_adapter)
    @last_attached_state_adapter.detach_frame if @last_attached_state_adapter
    _adapter.attach_frame(@transient_state_frame)
    @last_attached_state_adapter = _adapter
  end

#  def change_adapter(_name, _adapter)
#    @transient_frame_adapter[_name] = _adapter
#    @transient_frame_adapter[_name].detach_frame
#    __attach_adapter(@transient_frame_adapter[_name])
#    @transient_frame_adapter[_name].raise
#  end
#
#  def change_adapter_name(_name)
#    __attach_adapter(forge_transient_adapter(_name))
#    @transient_frame_adapter[_name].raise
#  end

  def change_adapters(_name, _adapters)
    forge_transient_adapter(_name)
    @transient_frame_adapter[_name][:action] = _adapters[:action]
    @transient_frame_adapter[_name][:state] = _adapters[:state]
    @transient_frame_adapter[_name][:action].detach_frame
    @transient_frame_adapter[_name][:state].detach_frame
    __attach_action_adapter(@transient_frame_adapter[_name][:action])
    __attach_state_adapter(@transient_frame_adapter[_name][:state])
    @transient_frame_adapter[_name][:action].raise
    @transient_frame_adapter[_name][:state].raise
  end

  def change_adapters_name(_name)
    __attach_action_adapter(forge_transient_adapter(_name)[:action])
    __attach_state_adapter(forge_transient_adapter(_name)[:state])
    @transient_frame_adapter[_name][:action].raise
    @transient_frame_adapter[_name][:state].raise
  end

  def clear_transient_adapters(_name)
    @@instances.each{|i| 
      if i.transient_frame_adapter[_name] 
        if i.transient_frame_adapter[_name][:action]
          i.transient_frame_adapter[_name][:action].detach_frame
        end
        if i.transient_frame_adapter[_name][:state]
          i.transient_frame_adapter[_name][:state].detach_frame
        end
        i.transient_frame_adapter.delete(_name).clear
      end 
    }
  end

  def add_button(_sender_name, _label,_proc=nil,_image=nil, _side= 'right')
    forge_transient_adapter(_sender_name)
    __add_button(_label,_proc,_image, _side, @transient_frame_adapter[_sender_name][:action])
  end

  def add_menu_button(_sender_name, _name='default',_image=nil, _side= 'right', _args=nil)
    forge_transient_adapter(_sender_name)
    __add_menu_button(_name, _image, _side, _args, @transient_frame_adapter[_sender_name][:action])
  end

  def add_check_button(_sender_name, _label,_proc=nil,_image=nil, _side= 'right')
    forge_transient_adapter(_sender_name)
    __add_check_button(_label,_proc,_image, _side, @transient_frame_adapter[_sender_name][:action])
  end

  def add_panel(_sender_name, _name='default',_side= 'right', _args=nil)
    forge_transient_adapter(_sender_name)
    __add_panel(_name, _side, _args, @transient_frame_adapter[_sender_name][:action])
  end

  def add_sep(_sender_name, _width=0)
    forge_transient_adapter(_sender_name)
    __add_sep(_width, @transient_frame_adapter[_sender_name][:action])
  end

  def add_state_button(_sender_name, _label,_proc=nil,_image=nil, _side= 'left')
    forge_transient_adapter(_sender_name)
    __add_state_button(_label,_proc,_image, _side, @transient_frame_adapter[_sender_name][:state])
  end

  def add_progress(_sender_name, _max=100, _canc_proc=nil, _hint=nil)
    forge_transient_adapter(_sender_name)
    __add_progress(_max, _canc_proc, @transient_frame_adapter[_sender_name][:action], _hint)
  end

  def destroy_progress(_sender_name, _progress)
    __destroy_progress(_progress, @transient_frame_adapter[_sender_name][:action])
  end

end


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
      image Arcadia.image_res(EXPAND_LIGHT_GIF)
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
    @left_label = TkLabel.new(@top, Arcadia.style('titlelabel')){
      anchor 'w'
    }.place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1 ,'width'=>-20)
    #.pack('fill'=>'x', 'side'=>'top')
    @resizing_label=TkLabel.new(self, Arcadia.style('label')){
      text '-'
      image Arcadia.image_res(EXPAND_LIGHT_GIF)
    }.pack('side'=> 'right','anchor'=> 's')
    start_moving(@left_label, self)
    start_moving(frame, self)
    start_resizing(@resizing_label, self)
    @grabbed = false
    @event_loop = false
    #    frame.bind_append('KeyPress'){|e|
    #      p e.keysym
    #      case e.keysym
    #        when 'Escape'
    #          p "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
    #          hide
    #      end
    #    }
    Arcadia.instance.register_key_binding(self,"KeyPress[Escape]","ActionEvent.new(self, 'action'=>hide_if_visible)")
  end
  
  def title(_text)
    @left_label.text(_text)
  end

  def on_close=(_proc)
    add_fixed_button('X', _proc, TAB_CLOSE_GIF)
  end

  def hide_if_visible
    hide if visible?
  end

  def hide
    if @event_loop
      Arcadia.detach_listener(self, ArcadiaEvent)
      @event_loop = false
    end
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

  def on_arcadia(_e)
    self.raise
  end

  def show
    if @manager == 'place'
      self.place('x'=>@x_place, 'y'=>@y_place, 'width'=>@width_place, 'height'=>@height_place)
    end
    if @event_loop == false
      Arcadia.attach_listener(self, ArcadiaEvent)
      @event_loop = true
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

    @buttons_frame = TkFrame.new(self, Arcadia.style('panel')).pack('fill'=>'x', 'side'=>'bottom')

    #@b_cancel = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
    @b_cancel = Arcadia.wf.titletoolbutton(@buttons_frame){|_b_go|
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

class TkFrameProgress < TkFrame
  attr_accessor :max
  def initialize(parent=nil, _max=100,  *args)
    super(parent, Arcadia.style('panel').update({:background => Arcadia.conf('titlelabel.background')}), *args)
    _max=1 if _max<=0
    @max = _max
    @progress = TkVariable.new
    @progress.value = -1
    Tk::BWidget::ProgressBar.new(self, :width=>50, :height=>16,
      :background=>Arcadia.conf('titlelabel.background'),
      :troughcolor=>Arcadia.conf('titlelabel.background'),
      :foreground=>Arcadia.conf('progress.foreground'),
      :variable=>@progress,
      :borderwidth=>0,
      :relief=>'flat',
      :maximum=>_max).pack('side'=>'left','padx'=>0, 'pady'=>0)
    #@b_cancel = TkButton.new(self, Arcadia.style('toolbarbutton')){|b|
    @b_cancel = Arcadia.wf.titletoolbutton(self){|b|
     # background  Arcadia.conf('titlelabel.background')
     # foreground  Arcadia.conf('titlelabel.background')
     # highlightbackground Arcadia.conf('titlelabel.background')
     # highlightcolor Arcadia.conf('titlelabel.background')
      image Arcadia.image_res(CLOSE_FRAME_GIF)
     # borderwidth 0
     # relief 'flat'
     # padx 0
     # pady 0
     # anchor 'n'
      pack('side'=>'left','padx'=>0, 'pady'=>0)
    }
  end

  def destroy
    @on_destroy.call if defined?(@on_destroy)
    super
  end

  def progress(_incr=1)
    @progress.numeric += _incr
  end

  def on_cancel=(_proc)
    @b_cancel.bind_append('1', _proc)
  end

  def on_destroy=(_proc)
    @on_destroy=_proc
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

#    info args procname 
#    info body procname 
#    info cmdcount 
#    info commands ?pattern? 
#    info complete command 
#    info default procname arg varname 
#    info exists varName 
#    info globals ?pattern? 
#    info hostname 
#    info level ?number? 
#    info library 
#    info loaded ?interp? 
#    info locals ?pattern? 
#    info nameofexecutable 
#    info patchlevel 
#    info procs ?pattern? 
#    info script 
#    info sharedlibextension 
#    info tclversion 
#    info vars ?pattern?     
  end
end

#require 'tkextlib/tile'
#Tk.tk_call "eval","ttk::setTheme clam"
#Tk::Tile::Style.theme_use('clam')


class TkWidgetFactory

  module WidgetEnhancer

    def hint=(_hint=nil)
      hint(_hint)
    end

    def hint(_hint=nil)
      Tk::BWidget::DynamicHelp::add(self, 'text'=>_hint) if _hint
      self
    end

  end

  def initialize
    if Arcadia.conf('tile.theme')
      @use_tile = true
      begin
        require 'tkextlib/tile'
        if Tk::Tile::Style.theme_names.include?(Arcadia.conf('tile.theme'))
          Tk::Tile::Style.theme_use(Arcadia.conf('tile.theme'))
        end
      rescue
        @use_tile = false
      end
      initialize_tile_widgets if @use_tile
    end
  end

  def initialize_tile_widgets
  
    #Widget state flags include:
    #active,disabled,focus,pressed,selected,background,readonly,alternate,invalid,hover
  
  	 # Workaround for #1100117:
    # Actually, on Aqua we probably shouldn't stipple images in
    # disabled buttons even if it did work...
    # don't work with Cocoa
    Tk.tk_call("eval","ttk::style configure . -stipple {}") if OS.mac?
  
    #TScrollbar
    Tk::Tile::Style.configure("Arcadia.TScrollbar", Arcadia.style('scrollbar'))
    Tk::Tile::Style.map("Arcadia.TScrollbar",
    :background=>[:pressed, Arcadia.style('scrollbar')['activebackground'], :disabled, Arcadia.style('scrollbar')['background'], :active, Arcadia.style('scrollbar')['activebackground']],
    :arrowcolor=>[:pressed, Arcadia.style('scrollbar')['background'], :disabled, Arcadia.style('scrollbar')['highlightbackground'], :active, Arcadia.style('scrollbar')['background']],
    :relief=>[:pressed, :sunken])

    Tk::Tile::Style.layout(Tk::Tile.style('Vertical', "Arcadia.TScrollbar"),
    ["Scrollbar.trough",{:sticky=>"nsew", :children=>[
      "Scrollbar.uparrow",{:side=>:top, :sticky=>"we"},
      "Scrollbar.downarrow", {:side=>:bottom, :sticky=>"we"},
    "Scrollbar.thumb", {:sticky=>"nswe",:side=>:top, :border =>1, :expand=>true}]}])

    Tk::Tile::Style.layout(Tk::Tile.style('Horizontal', "Arcadia.TScrollbar"),
    ['Scrollbar.trough', {:children=>[
      'Scrollbar.leftarrow',   {:side=>:left},
      'Scrollbar.rightarrow', {:side=>:right},
    'Scrollbar.thumb',  {:side=>:left, :expand=>true}]}])

    #TFrame
    #Tk::Tile::Style.configure(Tk::Tile::TFrame, Arcadia.style('panel'))

    #TPaned
    #Tk::Tile::Style.configure(Tk::Tile::TPaned, Arcadia.style('panel'))

    #TEntry
    #Tk::Tile::Style.configure(Tk::Tile::TEntry, Arcadia.style('edit'))

    #TCombobox
    #Tk::Tile::Style.configure(Tk::Tile::TCombobox, Arcadia.style('combobox'))

    #TLabel
    #Tk::Tile::Style.configure(Tk::Tile::TLabel, Arcadia.style('label'))


    #Treeview
    #Tk::Tile::Style.configure(Tk::Tile::Treeview, Arcadia.style('treepanel'))

    #TMenubutton
    Tk::Tile::Style.element_create('Arcadia.Menubutton.indicator', 
                                   :image, Arcadia.image_res(DROP_DOWN_ARROW_GIF),
                                   :sticky=>:w)    

    Tk::Tile::Style.configure("Arcadia.TMenubutton", Arcadia.style('menubutton').update(
      'padding'=>"0 0 0 0", 
      'width'=>0
      )
    )

    Tk::Tile::Style.map("Arcadia.TMenubutton",
    :background=>[:pressed, Arcadia.style('menubutton')['activebackground'], :disabled, Arcadia.style('menubutton')['background'], :active, Arcadia.style('menubutton')['activebackground']],
    :arrowcolor=>[:pressed, Arcadia.style('menubutton')['background'], :disabled, Arcadia.style('menubutton')['highlightbackground'], :active, Arcadia.style('menubutton')['background']],
    :relief=>[:pressed, :flat])
    Tk::Tile::Style.layout('Arcadia.TMenubutton', [
        'Menubutton.border', {:children=>[
             'Menubutton.padding', {:children=>[
                  'Arcadia.Menubutton.indicator', {:side=>:right}, 
                  'Menubutton.focus', {:side=>:left, :children=>['Menubutton.label']}
             ]}
        ]}
    ])

    #Title.TMenubutton
    # 
    Tk::Tile::Style.configure("Arcadia.Title.TMenubutton", Arcadia.style('titlelabel').update(
      'padding'=>"0 0 0 0", 
      'font'=>Arcadia.conf('titlelabel.font'), 
      'width'=>0,
      'foreground' => Arcadia.conf('titlelabel.foreground'),
      )
    )
    Tk::Tile::Style.map("Arcadia.Title.TMenubutton",
    :background=>[:pressed, Arcadia.style('titlelabel')['activebackground'], :disabled, Arcadia.style('titlelabel')['background'], :active, Arcadia.style('titlelabel')['activebackground']],
    :arrowcolor=>[:pressed, Arcadia.style('titlelabel')['background'], :disabled, Arcadia.style('titlelabel')['highlightbackground'], :active, Arcadia.style('titlelabel')['background']],
    :relief=>[:pressed, :flat])
    Tk::Tile::Style.layout('Arcadia.Title.TMenubutton', [
        'Menubutton.border', {:children=>[
             'Menubutton.padding', {:children=>[
                  'Arcadia.Menubutton.indicator', {:side=>:right}, 
                  'Menubutton.focus', {:side=>:left, :children=>['Menubutton.label']}
             ]}
        ]}
    ])

    #Title.Context.TMenubutton
    # 
    Tk::Tile::Style.configure("Arcadia.Title.Context.TMenubutton", Arcadia.style('titlelabel').update(
      'padding'=>"0 0 0 0", 
      'font'=>"#{Arcadia.conf('titlelabel.font')} italic", 
      'width'=>0,
      'foreground' => Arcadia.conf('titlecontext.foreground'),
      )
    )
    Tk::Tile::Style.map("Arcadia.Title.Context.TMenubutton",
    :background=>[:pressed, Arcadia.style('titlelabel')['activebackground'], :disabled, Arcadia.style('titlelabel')['background'], :active, Arcadia.style('titlelabel')['activebackground']],
    :arrowcolor=>[:pressed, Arcadia.style('titlelabel')['background'], :disabled, Arcadia.style('titlelabel')['highlightbackground'], :active, Arcadia.style('titlelabel')['background']],
    :relief=>[:pressed, :flat])
    Tk::Tile::Style.layout('Arcadia.Title.Context.TMenubutton', [
        'Menubutton.border', {:children=>[
             'Menubutton.padding', {:children=>[
                  'Arcadia.Menubutton.indicator', {:side=>:right}, 
                  'Menubutton.focus', {:side=>:left, :children=>['Menubutton.label']}
             ]}
        ]}
    ])
    
    
    #TCheckbutton, 

    Tk::Tile::Style.element_create('Arcadia.Checkbutton.indicator', 
                                   :image, Arcadia.image_res(CHECKBOX_0_DARK_GIF),
                                   :map=>[
                                     [:pressed, :selected],Arcadia.image_res(CHECKBOX_1_DARK_GIF),
                                     :pressed,             Arcadia.image_res(CHECKBOX_0_DARK_GIF),
                                     [:active, :selected], Arcadia.image_res(CHECKBOX_2_DARK_GIF),
                                     :active,              Arcadia.image_res(CHECKBOX_0_DARK_GIF),
                                     :selected,            Arcadia.image_res(CHECKBOX_1_DARK_GIF),
                                   ], :sticky=>:w)  

    Tk::Tile::Style.configure("Arcadia.TCheckbutton", Arcadia.style('checkbox').update(
        'padding'=>"0 0 0 0", 
        'width'=>0
        )
      )
    
    Tk::Tile::Style.layout('Arcadia.TCheckbutton', [
        'Checkbutton.background', # this is not needed in tile 0.5 or later
        'Checkbutton.border', {:children=>[
             'Checkbutton.padding', {:children=>[
                  'Arcadia.Checkbutton.indicator', {:side=>:left}, 
                  'Checkbutton.focus', {:side=>:left, :children=>[
                      'Checkbutton.label'
                  ]}
             ]}
        ]}
    ])    

                                   
    Tk::Tile::Style.configure("Arcadia.Title.TCheckbutton", Arcadia.style('titlelabel').update(
        'padding'=>"0 0 0 0", 
        'width'=>0
        )
      )
    
    Tk::Tile::Style.layout('Arcadia.Title.TCheckbutton', [
        'Checkbutton.background', # this is not needed in tile 0.5 or later
        'Checkbutton.border', {:children=>[
             'Checkbutton.padding', {:children=>[
                  'Arcadia.Checkbutton.indicator', {:side=>:left}, 
                  'Checkbutton.focus', {:side=>:left, :children=>[
                      'Checkbutton.label'
                  ]}
             ]}
        ]}
    ])    
    
    #Combobox
    

    Tk::Tile::Style.element_create('Arcadia.Combobox.indicator', 
                                   :image, Arcadia.image_res(DROP_DOWN_ARROW_GIF),
                                   :sticky=>:w)    

    Tk::Tile::Style.configure("Arcadia.TCombobox", Arcadia.style('combobox').update(
      'padding'=>"0 0 0 0", 
      'width'=>0
     # 'borderwidth'=>1,
     # 'relief'=>'groove'      
      )
    )

#    Tk::Tile::Style.map("Arcadia.TCombobox",
#    :relief=>[:pressed, :flat])
    
    Tk::Tile::Style.layout('Arcadia.TCombobox', [
        'Combobox.border', {:children=>[
             'Combobox.padding', {:children=>[
                  'Arcadia.Combobox.indicator', {:side=>:right}, 
                  'Combobox.focus', {:side=>:left, :children=>['Combobox.label']}
             ]}
        ]}
    ])


    #TFrame
    Tk::Tile::Style.configure("Arcadia.TFrame", Arcadia.style('panel'))



    #Tk::Tile::Style.configure(Tk::Tile::TLabel, Arcadia.style('label'))
    #TLabel
    Tk::Tile::Style.configure("Arcadia.TLabel", Arcadia.style('label'))


    #TEntry
    Tk::Tile::Style.layout("Arcadia.TEntry", [
        'Entry.border', { :sticky => 'nswe', :border => 1, 
              :children =>  ['Entry.padding',  { :sticky => 'nswe', 
                      :children => [ 'Entry.textarea',  { :sticky => 'nswe' } ] }] } ])
    
    
    Tk::Tile::Style.configure("Arcadia.TEntry", Arcadia.style('edit').update(
         'fieldbackground' => Arcadia.style('edit')['background'],
         'selectbackground' => 'red',
         'selectforeground' => 'yellow'
       )
    )
  
    #TText
    Tk::Tile::Style.configure("Arcadia.TText", Arcadia.style('text'))


    #TButton
    Tk::Tile::Style.configure("Arcadia.TButton", Arcadia.style('button').update(
      'padding'=>"0 0 0 0"
#      ,
#      'borderwidth'=>1,
#      'relief'=>'groove' 
      )
    )
    Tk::Tile::Style.map("Arcadia.TButton",
    :background=>[:pressed, Arcadia.style('button')['activebackground'], :disabled, Arcadia.style('button')['background'], :active, Arcadia.style('button')['activebackground']],
    :foreground=>[:pressed, Arcadia.style('button')['activeforeground'], :disabled, Arcadia.style('button')['foreground'], :active, Arcadia.style('button')['activeforeground']],
    :relief=>[:pressed, :sunken])

    #Tool.TButton
    Tk::Tile::Style.configure("Arcadia.Tool.TButton", Arcadia.style('toolbarbutton').update(
      'padding'=>"0 0 0 0",
      'anchor'=>'w' 
      )
    )
    Tk::Tile::Style.map("Arcadia.Tool.TButton",
    :background=>[:pressed, Arcadia.style('button')['activebackground'], :disabled, Arcadia.style('toolbarbutton')['background'], :active, Arcadia.style('toolbarbutton')['activebackground']],
    :arrowcolor=>[:pressed, Arcadia.style('button')['background'], :disabled, Arcadia.style('toolbarbutton')['highlightbackground'], :active, Arcadia.style('toolbarbutton')['background']],
    :relief=>[:pressed, :sunken])

    #Title.Tool.TButton
    Tk::Tile::Style.configure("Arcadia.Title.Tool.TButton", Arcadia.style('titletoolbarbutton').update(
      'padding'=>"0 0 0 0" 
      )
    )
    Tk::Tile::Style.map("Arcadia.Title.Tool.TButton",
    :background=>[:pressed, Arcadia.style('button')['activebackground'], :disabled, Arcadia.style('titletoolbarbutton')['background'], :active, Arcadia.style('toolbarbutton')['activebackground']],
    :arrowcolor=>[:pressed, Arcadia.style('button')['background'], :disabled, Arcadia.style('titletoolbarbutton')['highlightbackground'], :active, Arcadia.style('toolbarbutton')['background']],
    :relief=>[:pressed, :sunken])
    
  end



  def scrollbar(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Scrollbar.new(_parent,{:style=>"Arcadia.TScrollbar"}.update(_args), &b)
      else
        obj = TkScrollbar.new(_parent,Arcadia.style('scrollbar').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
    end
  end

  def frame(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::TFrame.new(_parent,{:style=>"Arcadia.TFrame"}.update(_args), &b)
      else
        obj = TkFrame.new(_parent,Arcadia.style('panel').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end


  def label(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::TLabel.new(_parent,{:style=>"Arcadia.TLabel"}.update(_args), &b)
      else
        obj = TkLabel.new(_parent,Arcadia.style('label').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def entry(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::TEntry.new(_parent,{:style=>"Arcadia.TEntry"}.update(_args), &b)
      else
        obj = TkEntry.new(_parent,Arcadia.style('edit').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def text(_parent,_args={}, &b)
    begin
#      if @use_tile
#        obj = Tk::Tile::Text.new(_parent,{:style=>"Arcadia.TText"}.update(_args), &b)
#      else
        obj = TkText.new(_parent,Arcadia.style('text').update(_args), &b)
#      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def button(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Button.new(_parent,{:style=>"Arcadia.TButton"}.update(_args), &b)
      else
        obj = TkButton.new(_parent,Arcadia.style('button').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def toolbutton(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Button.new(_parent,{:style=>"Arcadia.Tool.TButton"}.update(_args), &b)
      else
        obj = TkButton.new(_parent,Arcadia.style('toolbarbutton').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def titletoolbutton(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Button.new(_parent,{:style=>"Arcadia.Title.Tool.TButton"}.update(_args), &b)
      else
        obj = TkButton.new(_parent,Arcadia.style('toolbarbutton').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def menubutton(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Menubutton.new(_parent,{:style=>"Arcadia.TMenubutton"}.update(_args), &b)
      else
        obj = TkMenuButton.new(_parent,Arcadia.style('menubutton').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end
  
  def combobox(_parent,_args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Combobox.new(_parent,{:style=>"Arcadia.TCombobox"}.update(_args), &b)
      else
        obj = Tk::BWidget::ComboBox.new(_parent, Arcadia.style('combobox').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def titlemenubutton(_parent, _args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Menubutton.new(_parent,{:style=>"Arcadia.Title.TMenubutton"}.update(_args), &b)
      else
        obj = TkMenuButton.new(_parent,Arcadia.style('menubutton').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def titlecontextmenubutton(_parent, _args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Menubutton.new(_parent,{:style=>"Arcadia.Title.Context.TMenubutton"}.update(_args), &b)
      else
        obj = TkMenuButton.new(_parent,Arcadia.style('menubutton').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def checkbutton(_parent, _args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Checkbutton.new(_parent,{:style=>"Arcadia.TCheckbutton"}.update(_args), &b)
      else
        obj = TkCheckbutton.new(_parent,Arcadia.style('checkbox').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def titlecontextcheckbutton(_parent, _args={}, &b)
    begin
      if @use_tile
        obj = Tk::Tile::Checkbutton.new(_parent,{:style=>"Arcadia.Title.TCheckbutton"}.update(_args), &b)
      else
        obj = TkCheckbutton.new(_parent,Arcadia.style('checkbox').update(_args), &b)
      end
      class << obj
        include WidgetEnhancer
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def menu(_parent,_args={}, &b)
    begin
      obj = TkMenu.new(_parent, &b)
      if !OS.mac?
        obj.configure(Arcadia.style('menu').update(_args))
        obj.extend(TkAutoPostMenu)
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end

  def titlemenu(_parent,_args={}, &b)
    begin
      obj = TkMenu.new(_parent, &b)
      if !OS.mac?
        obj.configure(Arcadia.style('titlemenu').update(_args))
        obj.extend(TkAutoPostMenu)
      end
      return obj
    rescue RuntimeError => e
      Arcadia.runtime_error(e) 
      return nil
    end
  end


end



class TkArcadiaText < TkText
  def initialize(parent=nil, keys={})
    super(parent, keys)
#    self.bind_append("<Copy>"){Arcadia.process_event(CopyTextEvent.new(self));break}
#    self.bind_append("<Cut>"){Arcadia.process_event(CutTextEvent.new(self));break}
#    self.bind_append("<Paste>"){Arcadia.process_event(PasteTextEvent.new(self));break}
#    self.bind_append("<Undo>"){Arcadia.process_event(UndoTextEvent.new(self));break}
#    self.bind_append("<Redo>"){Arcadia.process_event(RedoTextEvent.new(self));break}
  end
end

module TkInputThrow
  def self.extended(_widget)
    _widget.__initialize_throw(_widget)
  end

  def self.included(_widget)
    _widget.__initialize_throw(_widget)
  end

  def __initialize_throw(_widget)
    #_widget.bind_append("Enter", proc{p "Enter on #{_widget}";Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>_widget))})
    _widget.bind_append("<Copy>"){Arcadia.process_event(CopyTextEvent.new(_widget));break}
    _widget.bind_append("<Cut>"){Arcadia.process_event(CutTextEvent.new(_widget));break}
    _widget.bind_append("<Paste>"){Arcadia.process_event(PasteTextEvent.new(_widget));break}
    _widget.bind_append("<Undo>"){Arcadia.process_event(UndoTextEvent.new(_widget));break}
    _widget.bind_append("<Redo>"){Arcadia.process_event(RedoTextEvent.new(_widget));break}
    _widget.bind_append("1", proc{Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>_widget))})
  end
  
  def select_throw
    InputEnterEvent.new(self,'receiver'=>self).go!
  end
end

module TkAutoPostMenu

  def self.extended(_widget)
    _widget.__initialize_posting(_widget)
  end

  def self.included(_widget)
    _widget.__initialize_posting(_widget)
  end

  def event_posting_on
    @event_posting_on = true
    @posting_on = false
  end

  def event_posting_off
    @event_posting_on = false
    @posting_on = true
  end


  def __initialize_posting(_widget=self)
    #    parent = TkWinfo.parent(_widget)
    #    parent.bind_append("Enter", proc{p "Enter parent"})
    #    parent.bind_append("Leave", proc{p "Leave parent"})

    chs = TkWinfo.children(_widget)
    hh = 22
    @last_post = nil
    @posting_on = true
    @event_posting_on = false
    @m_show = Hash.new
    chs.each{|ch|
      next if ch.kind_of?(String)
      ch.menu.bind_append("Map", proc{ @m_show[ch.menu] = true })
      ch.menu.bind_append("Unmap", proc{ @m_show[ch.menu] = false })
      ch.bind_append("Enter", proc{|x,y,rx,ry|
        if @posting_on
          if @last_post && @last_post != ch.menu
            @last_post.unpost
            @last_post=nil
          end
          if @last_clicked && @last_clicked != ch.menu
            @last_clicked.unpost
            @last_clicked = nil
          end
          
          ch.menu.post(x-rx,y-ry+hh)
          #just_posted = TkWinfo.containing(x, y+hh)

          chmenus = TkWinfo.children(ch)
          @last_menu_posted = chmenus[0]
          @last_menu_posted.set_focus

          @last_menu_posted.bind("Enter", proc{
            @last_menu_posted.bind("Leave", proc{
              if @posting_on
                @last_post.unpost if @last_post
                @last_post = nil
                @last_menu_posted.bind("Enter", proc{})
                @last_menu_posted.bind("Leave", proc{})
              end
            })
          })
          #@last_post = just_posted
        end

        #@last_post=ch.menu
      }, "%X %Y %x %y")
      ch.bind_append("Leave", proc{
        ch.configure("state"=>:normal, "relief"=>:flat)
        if @posting_on
          if @last_post
            _x = TkWinfo.x(@last_post)
            _y = TkWinfo.y(@last_post)
            ch.event_generate("KeyPress", :keysym=>"Escape")  if Tk.focus.kind_of?(TkMenu) &&  Tk.focus != ch.menu
            @last_post.post(_x,_y) if @last_clicked && @last_clicked == ch.menu
          end
          if @last_post!=ch.menu
            @last_post=ch.menu
          else
            @last_post=nil
          end
          if !Tk.focus.kind_of?(TkMenu)
            @last_post.unpost if @last_post
            @last_post=nil
          end
        end
      })
      ch.bind_append("1", proc{|x,y,rx,ry|
        @posting_on=true if @event_posting_on
        if @last_post && @last_post != ch.menu
          @last_post.unpost
       #   @last_post.bind_remove("1")
          @last_post = nil
        end
        @last_post=ch.menu #if ch.state == 'active'
        ch.configure('state'=>'normal')
        @last_clicked = ch.menu
        
#        ch.menu.bind_append("1", proc{|mx,my,mrx,mry|
#          if ch.menu.index("active").nil?
#            ch.menu.activate(ch.menu.index("@#{mry}")) 
#          end
#        }, "%X %Y %x %y")
        
        #@last_post.unpost
        #@last_post.post(0,0)
        #@last_post.set_focus
        @posting_on=true  if @event_posting_on

      }, "%X %Y %x %y")

    }
    _widget.bind_append("Leave", proc{
      if @posting_on  && Tk.focus != @last_menu_posted
        @last_post.unpost if @last_post
        @last_post=nil
        @posting_on = false if @event_posting_on
      end
      TkAfter.new(1000,1, proc{
        one_post = false
        @m_show.each{|m,v|
          one_post = v
          break if v
        }
        @posting_on = one_post if @event_posting_on
      }).start
    })

  end
end

#
module TkScrollableWidget

  def self.extended(_widget)
    _widget.__initialize_scrolling(_widget)
  end

  def self.included(_widget)
    _widget.__initialize_scrolling(_widget)
  end

  def __initialize_scrolling(_widget=self)
    @widget = _widget
    @parent = TkWinfo.parent(@widget)
    @scroll_width = Arcadia.style('scrollbar')['width'].to_i
    @x=0
    @y=0
    @v_scroll_on = false
    @h_scroll_on = false
    @v_scroll = Arcadia.wf.scrollbar(@parent,{'orient'=>'vertical'})
    @h_scroll = Arcadia.wf.scrollbar(@parent,{'orient'=>'horizontal'})
  end

  def destroy
    @h_scroll.destroy
    @v_scroll.destroy
  end

  def call_after_next_show_h_scroll(_proc_to_call=nil)
    @h_proc = _proc_to_call
  end

  def call_after_next_show_v_scroll(_proc_to_call=nil)
    @v_proc = _proc_to_call    
  end

  def add_yscrollcommand(cmd=Proc.new)
    @v_scroll_command = cmd
  end

  def do_yscrollcommand(first,last)
    if first != nil && last != nil
      delta = last.to_f - first.to_f
      if delta < 1 && delta > 0 && last != @last_y_last
        show_v_scroll
        begin
          @v_scroll.set(first,last) #if TkWinfo.mapped?(@v_scroll)
        rescue Exception => e
          Arcadia.runtime_error(e)
          #p "#{e.message}"
        end
      elsif delta == 1 || delta == 0
        hide_v_scroll
      end
      @v_scroll_command.call(first,last) if !@v_scroll_command.nil?
      @last_y_last = last if last.to_f < 1
    end    
  end

  def add_xscrollcommand(cmd=Proc.new)
    @h_scroll_command = cmd
  end

  def do_xscrollcommand(first,last)
    if first != nil && last != nil
      delta = last.to_f - first.to_f
      if delta < 1 && delta > 0  && last != @last_x_last
        show_h_scroll
        begin
          @h_scroll.set(first,last) #if TkWinfo.mapped?(@h_scroll)
        rescue Exception => e
          Arcadia.runtime_error(e)
          #p "#{e.message}"
        end
      elsif  delta == 1 || delta == 0
        hide_h_scroll
      end
      @h_scroll_command.call(first,last) if !@h_scroll_command.nil?
      @last_x_last = last if last.to_f < 1
    end
    if @x_proc
      begin
        @x_proc.call
      ensure
        @x_proc=nil
      end
    end
  end

  def show(_x=0,_y=0,_w=nil,_h=nil,_border_mode='inside')
    @x=_x
    @y=_y
    _w != nil ? @w=_w : @w=-@x
    _h != nil ? @h=_h : @h=-@y
    @widget.place(
    'x'=>@x,
    'y'=>@y,
    'width' => @w,
    'height' => @h,
    'relheight'=>1,
    'relwidth'=>1,
    'bordermode'=>_border_mode
    )
    @widget.raise
    if @v_scroll_on
      show_v_scroll(true)
    end
    if @h_scroll_on
      show_h_scroll(true)
    end
    begin
      arm_scroll_binding
    rescue  Exception => e
      Arcadia.runtime_error(e)
      #p "#{e.message}"
    end
  end

  def hide
    disarm_scroll_binding
    @widget.unplace
    @v_scroll.unpack
    @h_scroll.unpack
  end

  def arm_scroll_binding
    @widget.yscrollcommand(proc{|first,last|
      do_yscrollcommand(first,last)
    })
    @v_scroll.command(proc{|*args|
      @widget.yview *args
    })
    @widget.xscrollcommand(proc{|first,last|
      do_xscrollcommand(first,last)
    })
    @h_scroll.command(proc{|*args|
      @widget.xview *args
    })
  end

  def disarm_scroll_binding
    @widget.yscrollcommand(proc{})
    @widget.xscrollcommand(proc{})
    @v_scroll.command(proc{}) if @v_scroll
    @h_scroll.command(proc{}) if @h_scroll
  end

  def show_v_scroll(_force=false)
    if _force || !@v_scroll_on
      begin
        @widget.place('width' => -@scroll_width-@x)
        @v_scroll.pack('side' => 'right', 'fill' => 'y')
        @v_scroll_on = true
        @v_scroll.raise
        if @v_proc
          begin
            @v_proc.call
          ensure
            @v_proc=nil
          end
        end
      rescue RuntimeError => e
        #p "RuntimeError : #{e.message}"
        Arcadia.runtime_error(e)
      end
    end
  end

  def show_h_scroll(_force=false)
    if _force || !@h_scroll_on
      begin
        @widget.place('height' => -@scroll_width-@y)
        @h_scroll.pack('side' => 'bottom', 'fill' => 'x')
        @h_scroll_on = true
        @h_scroll.raise
        if @h_proc
          begin
            @h_proc.call
          ensure
            @h_proc=nil
          end
        end
      rescue RuntimeError => e
        #p "RuntimeError : #{e.message}"
        Arcadia.runtime_error(e)
      end
    end
  end

  def hide_v_scroll
    if @v_scroll_on
      begin
        @widget.place('width' => 0)
        @v_scroll.unpack
        @v_scroll_on = false
      rescue RuntimeError => e
        Arcadia.runtime_error(e)
        #p "RuntimeError : #{e.message}"
      end

    end
  end

  def hide_h_scroll
    if @h_scroll_on
      begin
        @widget.place('height' => 0)
        @h_scroll.unpack
        @h_scroll_on = false
      rescue RuntimeError => e
        Arcadia.runtime_error(e)
        #p "RuntimeError : #{e.message}"
      end
    end
  end

end


class KeyTest < TkFloatTitledFrame
  attr_reader :ttest
  def initialize(_parent=nil)
    _parent = Arcadia.instance.layout.root if _parent.nil?
    super(_parent)

    @ttest = TkText.new(self.frame){
      background  Arcadia.conf("background")
      foreground  Arcadia.conf("foreground")
      #place('relwidth' => '1','relx' => 0,'x' => '0','y' => '0','relheight' => '1','rely' => 0,'height' => '0','bordermode' => 'inside','width' => '0')
    }.bind("KeyPress"){|e|
      @ttest.insert('end'," "+e.keysym+" ")
      break
    }
    @ttest.extend(TkScrollableWidget).show
    place('x'=>100,'y'=>100,'height'=> 220,'width'=> 500)
  end
end

class HinnerDialog < TkFrame
  def initialize(side='top',args=nil)
    newargs =  Arcadia.style('panel').update({
      "highlightbackground" => Arcadia.conf('hightlight.link.foreground'),
      "highlightthickness" => 1
    })
    if !args.nil?
      newargs.update(args) 
    end
    super(Arcadia.layout.parent_frame, newargs)
    case side
      when 'top'
#        self.pack('side' =>side,'before'=>Arcadia.layout.root, 'anchor'=>'nw','fill'=>'both', 'padx'=>0, 'pady'=>0, 'expand'=>'yes')
        self.pack('side' =>side,'before'=>Arcadia.layout.root, 'anchor'=>'nw','fill'=>'x', 'padx'=>0, 'pady'=>0)
      when 'bottom'
        self.pack('side' =>side,'after'=>Arcadia.layout.root, 'anchor'=>'nw','fill'=>'x', 'padx'=>0, 'pady'=>0)
    end
    @modal = false
  end
  
  def is_modal?
    @modal
  end
  
  def release
    @modal=false
  end
  
  def show_modal(_destroy=true)
    @modal=true
    Tk.update
    self.grab("set")
    begin
      while is_modal? do 
        Tk.update
        sleep(0.1) 
      end
    ensure
      self.grab("release")
    end
    Tk.update
    self.destroy if _destroy
  end
end


class HinnerSplittedDialog < HinnerDialog
  attr_reader :frame, :splitter_frame
  def initialize(side='top', height=100, args=nil)
    super(side, args)
    @y0= height
    fr = TkFrame.new(self){
      height height 
      pack('side' =>side,'padx'=>0, 'pady'=>0, 'fill'=>'x', 'expand'=>'1')
    }
    splitter_frame = TkFrame.new(self, Arcadia.style('splitter')){
      height 5
      pack('side' =>side,'padx'=>0, 'pady'=>0, 'fill'=>'x', 'expand'=>'1')
    }
    oldcursor = splitter_frame.cget('cursor')
    tmpcursor = 'sb_v_double_arrow'
    yx=0
    
    splitter_frame.bind_append("Enter", proc{|x, y| 
      splitter_frame.configure('cursor'=> tmpcursor)
    } , "%x %y")

    splitter_frame.bind_append("B1-Motion", proc{|x, y| 
      yx=y
      splitter_frame.raise
    } ,"%x %y")
     
    splitter_frame.bind_append("ButtonRelease-1", proc{|e|
      splitter_frame.configure('cursor'=> oldcursor)
      if side == 'top'
        h = (@y0+yx).abs
      elsif side == 'bottom'
        h = (@y0-yx).abs
      end
      @y0 = h
      fr.configure('height'=>h)
    })    
    @frame = fr
    @splitter_frame = splitter_frame
  end
  
  def height(_h=nil)
    if _h.nil?
      @frame.height
    else
      @frame.configure('height'=>_h)
      @y0 = _h
    end
  end
end

class HinnerSplittedDialogTitled < HinnerSplittedDialog
  attr_accessor :hinner_frame, :titled_frame
  def initialize(title=nil, side='top', height=100, args=nil)
    super(side, height, args)
    @titled_frame = TkLabelTitledFrameClosable.new(self.frame, title).place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1)
    @ext_proc = nil
    close = proc{
      do_close
      #self.destroy
      #Tk.callback_break
    }
    @titled_frame.add_close_action(close)
    @hinner_frame = @titled_frame.frame
  end

  def do_close
    @ext_proc.call if !@ext_proc.nil?
    self.destroy
    Tk.callback_break
  end

  def on_close=(_proc)
    @ext_proc = _proc
  end
 
end

class HinnerFileDialog < HinnerDialog
  SELECT_FILE_MODE=0
  SAVE_FILE_MODE=1
  SELECT_DIR_MODE=2
  def initialize(mode=SELECT_FILE_MODE , must_exist = nil, side='top',args=nil)
    super(side, args)
    @mode = mode
    if must_exist.nil?
      must_exist = mode != SAVE_FILE_MODE
    end
    @must_exist = must_exist
    build_gui
    @closed = false
  end
  
  def build_gui
    @font = Arcadia.conf('edit.font')
    @font_bold = "#{Arcadia.conf('edit.font')} bold"
    @font_metrics = TkFont.new(@font).metrics
    @font_metrics_bold = TkFont.new(@font_bold).metrics
    @dir_text = TkText.new(self, Arcadia.style('text').update({"height"=>'1',"highlightcolor"=>Arcadia.conf('panel.background'), "bg"=>Arcadia.conf('panel.background')})).pack('side' =>'left','padx'=>5, 'pady'=>5, 'fill'=>'x', 'expand'=>'1')
    #{"bg"=>'white', "height"=>'1', "borderwidth"=>0, 'font'=>@font}
    @dir_text.bind_append("Enter", proc{ @dir_text.set_insert("end")})
    #@dir_text.tag_configure("entry",'foreground'=> "red",'borderwidth'=>0, 'relief'=>'flat',  'underline'=>true)

    @tag_file_exist = "file_exist"
    @dir_text.tag_configure(@tag_file_exist,'background'=> Arcadia.conf("hightlight.selected.background"), 'borderwidth'=>0, 'relief'=>'flat', 'underline'=>true)
    
    @tag_selected = "link_selected"
    @dir_text.tag_configure(@tag_selected,'borderwidth'=>0, 'relief'=>'flat', 'underline'=>true)
    @dir_text.tag_bind(@tag_selected,"ButtonRelease-1",  proc{ 
       self.release
       Tk.callback_break
    } )
    @dir_text.tag_bind(@tag_selected,"Enter", proc{@dir_text.configure('cursor'=> 'hand2')})
    @dir_text.tag_bind(@tag_selected,"Leave", proc{@dir_text.configure('cursor'=> @cursor)})
    _self=self
    @dir_text.bind_append('KeyPress'){|e|
      case e.keysym
      when 'Escape','Tab'
        i1 = @dir_text.index("insert")
        raise_candidates(i1, @dir_text.get("#{i1} linestart", i1))
      when "Return"
        if (@mode == SELECT_FILE_MODE || @mode == SAVE_FILE_MODE) && @must_exist
          str_file = @dir_text.get('1.0','end')
          if str_file && str_file.length > 0 && File.exists?(str_file.strip) && File.ftype(str_file.strip) == 'file'
            _self.release
          end
          Tk.callback_break
        elsif @mode == SELECT_DIR_MODE && @must_exist
          str_file = @dir_text.get('1.0','end')
          if str_file && str_file.length > 0 && File.exists?(str_file.strip) && File.ftype(str_file.strip) == 'directory'
            _self.release
          end
          Tk.callback_break
        else
          _self.release
        end
      end
    }   
    @dir_text.bind_append('KeyRelease'){|e|
      case e.keysym
      when 'Escape','Tab', "Return"
      else
        @dir_text.tag_remove(@tag_selected,'1.0','end')
        i1 = @dir_text.index("insert - 1 chars wordstart")
        while @dir_text.get("#{i1} -1 chars",i1) != File::SEPARATOR && @dir_text.get("#{i1} - 1 chars",i1) != ""
          i1 = @dir_text.index("#{i1} - 1 chars")
        end
        i2 = @dir_text.index("insert")
        
        @dir_text.tag_add(@tag_selected ,i1,i2) if @mode == SAVE_FILE_MODE
        
        if File.exists?(@dir_text.get('1.0',i2))
          @dir_text.tag_add(@tag_file_exist ,i1,i2)
          @dir_text.tag_add(@tag_selected ,i1,i2) if @mode == SELECT_FILE_MODE && File.ftype(@dir_text.get('1.0',i2)) == 'file'
          @dir_text.tag_add(@tag_selected ,i1,i2) if @mode == SELECT_DIR_MODE && File.ftype(@dir_text.get('1.0',i2)) == 'directory'
        else
          @dir_text.tag_remove(@tag_file_exist,'1.0','end')
        end
      end
    }   
    
    @dir_text.bind_append("Control-KeyPress"){|e|
      case e.keysym
      when 'd'
        _self.close
        Tk.callback_break
      end
    }    

    #@select_button = Tk::BWidget::Button.new(self, Arcadia.style('toolbarbutton')){
    @select_button = Arcadia.wf.toolbutton(self){
      command proc{_self.close}
      image Arcadia.image_res(CLOSE_FRAME_GIF)
    }.pack('side' =>'right','padx'=>5, 'pady'=>0)
  end
  
  def file(_dir)
    set_dir(_dir)
    show_modal(false)
    if @closed == false
      file_selected = @dir_text.get("0.1","end").strip
      destroy  
      file_selected
    end
  end

  def dir(_dir)
    file(_dir)
  end
  
  def close
    @closed=true
    self.release
    destroy  
  end
  
  def set_dir(_dir)
    _dir=Dir.pwd if !File.exists?(_dir)
    #load_from_dir(_dir)
    @dir_text.state("normal")
    @dir_text.delete("0.1","end")
    @cursor =  @dir_text.cget('cursor')
    dir_seg = _dir.split(File::SEPARATOR)
    incr_dir = ""
    get_dir = proc{|i| 
      res = ""
      0.upto(i){|j|
         if res == File::SEPARATOR
          res=res+dir_seg[j]
         elsif res.length == 0 && dir_seg[j].length == 0
          res=File::SEPARATOR+dir_seg[j]
         elsif res.length == 0 && dir_seg[j].length > 0
          res=dir_seg[j]
         else
          res=res+File::SEPARATOR+dir_seg[j]
         end
      }
      is_dir = File.ftype(res) == "directory"
      res=res+File::SEPARATOR if is_dir && res[-1..-1]!=File::SEPARATOR
      res
    }
    
    dir_seg.each_with_index{|seg,i|
      tag_name = "link#{i}"
      @dir_text.tag_configure(tag_name,'foreground'=> Arcadia.conf('hightlight.link.foreground'),'borderwidth'=>0, 'relief'=>'flat', 'underline'=>true)

      dir = get_dir.call(i)
      if File.ftype(dir) == "directory"
        @dir_text.insert("end", seg, tag_name)
        @dir_text.insert("end", "#{File::SEPARATOR}")
        @dir_text.tag_bind(tag_name,"ButtonRelease-1",  proc{ 
          inx = @dir_text.index("insert wordend +1 chars")
          @dir_text.set_insert("end")
          raise_candidates(inx, dir)
        } )
        @dir_text.tag_bind(tag_name,"Enter", proc{@dir_text.configure('cursor'=> 'hand2')})
        @dir_text.tag_bind(tag_name,"Leave", proc{@dir_text.configure('cursor'=> @cursor)})
      else
        @dir_text.insert("end", seg, @tag_selected)
      end
    }
    
    @dir_text.focus
    @dir_text.set_insert("end")
    @dir_text.see("end")
  end

  def raise_candidates(_inx, _dir)
    if _dir[-1..-1] != File::SEPARATOR && _dir !=nil && _dir.length > 0
      len = _dir.split(File::SEPARATOR)[-1].length+1
      _dir = _dir[0..-len]
      _inx = "#{_inx} - #{len-1} chars"
    end 
    _dir=Dir.pwd if !File.exists?(_dir)  
    @dir_text.set_insert("end")
    dirs_and_files=load_from_dir(_dir)
    if dirs_and_files[0].length + dirs_and_files[1].length == 1
      if dirs_and_files[0].length == 1
        one = "#{_dir}#{dirs_and_files[0][0]}"
      else
        one = "#{_dir}#{dirs_and_files[1][0]}"
      end
      set_dir(one)
    elsif dirs_and_files[0].length + dirs_and_files[1].length == 0
      # do not raise
    else 
      if @mode == SELECT_DIR_MODE
        raise_dir(_inx, _dir, dirs_and_files[0], [])
      else
        raise_dir(_inx, _dir, dirs_and_files[0], dirs_and_files[1])
      end
    end
    Tk.callback_break
  end
  
  def last_candidate_is_file?(_name)
    @last_candidates_file && @last_candidates_file.include?(_name)
  end

  def last_candidate_is_dir?(_name)
    @last_candidates_dir && @last_candidates_dir.include?(_name)
  end
  
  def raise_dir(_index, _dir, _candidates_dir, _candidates_file=nil) 
    @raised_listbox_frame.destroy if @raised_listbox_frame != nil
    @last_candidates_dir = _candidates_dir
    @last_candidates_file = _candidates_file
    _index_now = @dir_text.index('insert')
    _index_for_raise =  @dir_text.index("#{_index} wordstart")
    _candidates = [] 
    _candidates.concat(_candidates_dir) if _candidates_dir 
    _candidates.concat(_candidates_file) if _candidates_file 
        
    if _candidates.length >= 1 
        _rx, _ry, _width, heigth = @dir_text.bbox(_index_for_raise);
        _x = _rx + TkWinfo.rootx(@dir_text)  
        _y = _ry + TkWinfo.rooty(@dir_text)  + @font_metrics[2][1]
        _xroot = _x
        _yroot = _y

        max_width = TkWinfo.screenwidth(Arcadia.layout.root) - _x
        
        @raised_listbox_frame = TkFrame.new(Arcadia.layout.root, {
          :padx=>"1",
          :pady=>"1",
          :background=> "yellow"
        })
        
        @raised_listbox = TkTextListBox.new(@raised_listbox_frame, {
          :takefocus=>true}.update(Arcadia.style('listbox')))
        @raised_listbox.tag_configure('file','foreground'=> Arcadia.conf('hightlight.link.foreground'),'borderwidth'=>0, 'relief'=>'flat')

        
        _char_height = @font_metrics[2][1]
        _width = 0
        _docs_entries = Hash.new
        _item_num = 0

        _select_value = proc{
          if @raised_listbox.selected_line && @raised_listbox.selected_line.strip.length>0
            #_value = @raised_listbox.selected_line.split('-')[0].strip
            seldir = File.join(_dir,@raised_listbox.selected_line)

            set_dir(seldir)
            @raised_listbox_frame.grab("release")
            @raised_listbox_frame.destroy
          end
        }    

        _update_list = proc{|_in|
            _in.strip!
            @raised_listbox.clear
            _length = 0
            _candidates.each{|value|
              _doc = value.strip
              _class, _key, _arity = _doc.split('#')
              if _key && _arity
                args = arity_to_str(_arity.to_i)
                if args.length > 0
                  _key = "#{_key}(#{args})"
                end
              end
              
              if _key && _class && _key.strip.length > 0 && _class.strip.length > 0 
                _item = "#{_key.strip} #{TkTextListBox::SEP} #{_class.strip}"
              elsif _key && _key.strip.length > 0
                _item = "#{_key.strip}"
              else
                _key = "#{_doc.strip}"
                _item = "#{_doc.strip}"
              end
              array_include = proc{|_a, _str, _asterisk_first_char|
                ret = true
                str = _str
                _a.each_with_index{|x, j|
                  next if x.length == 0
                  if j == 0 && !_asterisk_first_char
                    ret = ret && str[0..x.length-1] == x
                  else
                    ret = ret && str.include?(x)
                  end
                  if ret 
                    i = str.index(x)
                    str = str[i+x.length..-1]
                  else
                    break
                  end
                }
                ret
              }
              if _in.nil? || _in.strip.length == 0 || _item[0.._in.length-1] == _in || 
                 (_in.include?('*') &&  array_include.call(_in.split("*"), _item, _in[0..1]=='*'))
#                 (_in[0..0] == '*' && _item.include?(_in[1..-1]))

                _docs_entries[_item]= _doc
       #         @raised_listbox.insert('end', _item)
                if last_candidate_is_dir?(_item)
                  @raised_listbox.add(_item, 'file')
                else
                  @raised_listbox.add(_item)
                end
                _temp_length = _item.length
                _length = _temp_length if _temp_length > _length 
                _item_num = _item_num+1 
                _last_valid_key = _key
              end
            }
            _width = _length*8
            if @raised_listbox.length == 0
              @raised_listbox.grab("release")
              @raised_listbox_frame.destroy
              @dir_text.focus
              Tk.callback_break
              #Tk.event_generate(@raised_listbox, "KeyPress" , :keysym=>"Escape") if TkWinfo.mapped?(@raised_listbox)
            else
              @raised_listbox.select(1)
              Tk.event_generate(@raised_listbox, "1") if TkWinfo.mapped?(@raised_listbox)
            end
        }

        get_filter = proc{
          filter = ""
          if @dir_text.get("insert -1 chars", "insert") != File::SEPARATOR  
            file_str = @dir_text.get("insert linestart", "insert")
            parts = file_str.split(File::SEPARATOR)
            if _dir == File::SEPARATOR
              original_parts = [""] 
            else
              original_parts = _dir.split(File::SEPARATOR)
            end
            if parts && parts.length == original_parts.length + 1
              filter = parts[-1]
            end
          end
          filter = "" if filter.nil?
          filter
        }
        #filter = @dir_text.get("insert -1 chars wordstart", "insert")


        @raised_listbox.bind_append('KeyPress'){|e|
          is_list_for_update = false
          case e.keysym
            when 'a'..'z','A'..'Z','0'..'9'
              @dir_text.insert('end', e.keysym)
              @dir_text.see("end")
              is_list_for_update = true
            when 'minus'
              @dir_text.insert('end', e.char)
              @dir_text.see("end")
              is_list_for_update = true
            when 'period'
              @dir_text.insert('end', '.')
              @dir_text.see("end")
              is_list_for_update = true
            when 'BackSpace'
              if @dir_text.get("insert -1 chars", "insert") != File::SEPARATOR 
                @dir_text.delete('end -2 chars','end')
              end
              is_list_for_update = true
            when 'Escape'
              @raised_listbox.grab("release")
              @raised_listbox_frame.destroy
              @dir_text.focus
              Tk.callback_break
            when "Next","Prior"
            when "Down","Up"
              Tk.callback_break
            else
              Tk.callback_break
          end
          _update_list.call(get_filter.call) if is_list_for_update
          @raised_listbox.focus 
          Tk.callback_break if  !["Next","Prior"].include?(e.keysym)
        }

        @raised_listbox.bind_append('Shift-KeyPress'){|e|
          is_list_for_update = false
          case e.keysym
            when 'asterisk','underscore'
              @dir_text.insert('end', e.char)
              @dir_text.see("end")
              is_list_for_update = true
            when 'a'..'z','A'..'Z'
              @dir_text.insert('end', e.keysym)
              @dir_text.see("end")
              is_list_for_update = true
            
          end
          _update_list.call(get_filter.call) if is_list_for_update
          @raised_listbox.focus 
          Tk.callback_break
        }

        @raised_listbox.bind_append('KeyRelease'){|e|
          case e.keysym
            when 'Return'
              _select_value.call
          end
        }
        
        _update_list.call(get_filter.call)

        if @raised_listbox.length == 1
          _select_value.call
        else
          _width = _width + 30
          _width = max_width if _width > max_width
          _height = 15*_char_height
          
          @raised_listbox_frame.place('x'=>_x,'y'=>_ry, 'width'=>_width, 'height'=>_height)
          @raised_listbox.extend(TkScrollableWidget).show(0,0) 
          @raised_listbox.place('x'=>0,'y'=>0, 'relwidth'=>1, 'relheight'=>1) 
          @raised_listbox.focus
          @raised_listbox.select(1)

          Tk.update
          @raised_listbox_frame.grab("set")
  
       
       
          @raised_listbox.bind_append("Double-ButtonPress-1", 
            proc{|x,y| 
              _select_value.call
              Tk.callback_break
                }, "%x %y")
  
        end  
      elsif _candidates.length == 1 && _candidates[0].length>0
        @dir_text.set_dir(_candidates[0])
      end
  end
  
  
  def load_from_dir(_dir)
    childrens = Dir.entries(_dir)
    childrens_dir = Array.new
    childrens_file = Array.new
    childrens.sort.each{|c|
      if c != '.' && c != '..'
        child = File.join(_dir,c)
        fty = File.ftype(child)
        if fty == "file"
          childrens_file << c
          #childrens_file << child
        elsif fty == "directory"
          #childrens_dir << child
          childrens_dir << c
        end
      end
    }
    return childrens_dir,childrens_file
  end 

end


class HinnerStringDialog < HinnerDialog
  def initialize(side='top',args=nil)
    super(side, args)
    build_gui
    @closed = false
  end
  
  def build_gui
    @font = Arcadia.conf('edit.font')
    @font_bold = "#{Arcadia.conf('edit.font')} bold"
    @font_metrics = TkFont.new(@font).metrics
    @font_metrics_bold = TkFont.new(@font_bold).metrics
    @string_text = TkText.new(self, Arcadia.style('text').update({"height"=>'1',"highlightcolor"=>Arcadia.conf('panel.background'), "bg"=>Arcadia.conf('panel.background')})).pack('side' =>'left','padx'=>5, 'pady'=>5, 'fill'=>'x', 'expand'=>'1')
    #{"bg"=>'white', "height"=>'1', "borderwidth"=>0, 'font'=>@font}
    @string_text.bind_append("Enter", proc{ @string_text.set_insert("end")})

    
    @tag_selected = "link_selected"
    @string_text.tag_configure(@tag_selected,'borderwidth'=>0, 'relief'=>'flat', 'underline'=>true)
    @string_text.tag_bind(@tag_selected,"ButtonRelease-1",  proc{ 
       self.release
    } )
    @string_text.tag_bind(@tag_selected,"Enter", proc{@string_text.configure('cursor'=> 'hand2')})
    @string_text.tag_bind(@tag_selected,"Leave", proc{@string_text.configure('cursor'=> @cursor)})
    _self=self
    @string_text.bind_append('KeyPress'){|e|
      case e.keysym
      when "Return"
        _self.release
      end
    }   
    @string_text.bind_append('KeyRelease'){|e|
      case e.keysym
      when 'Escape','Tab', "Return"
      else
        @string_text.tag_remove(@tag_selected,'1.0','end')
        @string_text.tag_add(@tag_selected ,'1.0','end')
      end
    }   
    
    @string_text.bind_append("Control-KeyPress"){|e|
      case e.keysym
      when 'd'
        _self.close
        Tk.callback_break
      end
    }    

    @close_button = Arcadia.wf.toolbutton(self){
      command proc{_self.close}
      image Arcadia.image_res(CLOSE_FRAME_GIF)
    }.pack('side' =>'right','padx'=>5, 'pady'=>0)
  end
  
  def string
    @string_text.focus
    @string_text.set_insert("end")
    @string_text.see("end")

    show_modal(false)
    if @closed == false
      string_selected = @string_text.get("0.1","end").strip
      destroy  
      string_selected
    end
  end

  
  def close
    @closed=true
    self.release
    destroy  
  end
  

  
end