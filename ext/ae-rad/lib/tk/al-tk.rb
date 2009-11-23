#
#   al-tk.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'tk'
require 'ext/ae-rad/ae-rad-libs'
require "lib/a-tkcommons"
require "ext/ae-rad/lib/tk/al-tk.res"

TkAllPhotoImage = TkPhotoImage

class AGTkObjRect
  attr_reader :r, :start_x, :start_y, :motion, :x0, :y0, :w0, :h0
  attr_writer :r, :start_x, :start_y, :motion
  def initialize(_parent, _x0, _y0, _w0 , _h0, _side , _cursor, _bind = true )
    if _bind
      _bc = 'white'
    else
      _bc = 'red'
    end
    @r = TkLabel.new(_parent){
      background _bc
      highlightbackground 'black'
      relief 'groove'
      place('x' => _x0 , 'y' => _y0, 'width' => _w0, 'height' => _h0)
    }
    @motion = false
    @side = _side
    @x0 = _x0
    @y0 = _y0
    @w0 = _w0
    @h0 = _h0
    @start_x = _x0
    @start_y = _y0
    @cursor = _cursor
    if _bind
      @r.bind("Enter", proc{|x, y| do_enter(x, y)}, "%x %y")
      @r.bind("ButtonPress-1", proc{|e| do_press(e.x, e.y)})
      @r.bind("B1-Motion", proc{|x, y| do_motion(x,y)},"%x %y")
    end
  end

  def do_enter(x, y)
    @oldcursor = @r.cget('cursor')
    @r.configure('cursor'=> @cursor)
    
  end
  
  def do_leave
    @r.configure('cursor'=>@oldcursor)
  end

  def do_press(x, y)
    @start_x = x
    @start_y = y
  end
  
  def do_motion( x, y)
    @motion = true
    move(x - @start_x, y - @start_y)
  end

  def move(_x,_y)
    case @side
    when 'both'
      @x0 = @x0 + _x
      @y0 = @y0 + _y
      @r.place('x' => @x0, 'y' => @y0)
    when 'x'
      @x0 = @x0 + _x
      @r.place('x' => @x0)
    when 'y'
      @y0 = @y0 + _y
      @r.place('y' => @y0)
    end
  end

end

class AGTkSimpleManager
  
  def initialize(_agobj, _active)
    @agobj = _agobj
    @active = _active
    add_bind
#    @byb = true
  end
  
  def add_bind
    @agobj.obj.bind_append("ButtonPress-1", proc{object_inspector_select})
  end
  
#  def bypass_bind
#    @byb = true
#  end
  
  def object_inspector_select
    @agobj.select
    #@agobj.object_inspector.select(@agobj, false) if !defined? @agobj.object_inspector.active_object or @agobj.object_inspector.active_object != @agobj
    AGTkLManager.deactivate_all
  end

end

class AGTkPlaceManager

  def initialize(_agobj, _active=false)
    #Tk.messageBox('message'=>_active.to_s)
    unless defined? _agobj.ag_parent
      return
    end
    @agobj = _agobj
    if !defined? @@place_managers
      @@place_managers = Array.new
    end
    if @agobj.ag_parent != nil
      @top = @agobj.ag_parent
      while @top.l_manager.simple_manager == nil
        @top = @top.ag_parent
      end
    end
    initx0x3
    flash
    obj_bind
    activate if _active
    object_inspector_select if _active
    @active = _active
    @last_layout = @agobj.props['layout_man']['manager']['get'].call
    @@place_managers << self
    @cursor = 'fleur'
  end

  def obj_bind
    if (@agobj.ag_parent != nil)
      @agobj.obj.bind_append("ButtonPress-1", proc{|e| do_press_obj(e.x, e.y);@agobj.obj.callback_break})
      @agobj.obj.bind_append("ButtonRelease-1", proc{|e| do_release_obj(e.x, e.y)})
      @agobj.obj.bind("B1-Motion", proc{|x, y| do_mov_obj(x,y)},"%x %y")
      @agobj.obj.bind("Control-ButtonPress-1", proc{
        if active?
          deactivate
        else
          activate(false)
        end
        #do_bypass_parent_bind
      })
      @agobj.obj.bind("Control-ButtonRelease-1", proc{})
      if @agobj.obj.configure('cursor') != nil
        @agobj.obj.bind_append("Enter", proc{|x, y| do_enter_obj(x, y)}, "%x %y" )
        @agobj.obj.bind_append("Leave", proc{do_leave_obj})
      end
    end
  end

	def do_release_obj(x,y)
    @agobj.update_property(@agobj, 'place', 'x', @x0)
    @agobj.update_property(@agobj, 'place', 'y', @y0)
	end

  def do_enter_obj(x, y)
    @oldcursor = @agobj.obj.cget('cursor')
    @agobj.obj.configure('cursor'=> @cursor)
  end

  def do_leave_obj
    @agobj.obj.configure('cursor'=>@oldcursor)
  end

  def do_mov_obj(x,y)
    x00 = @x0
    y00 = @y0
    @x0 = @x0 + x - @start_x
    @y0 = @y0 + y - @start_y
    @agobj.obj.place('x'=>@x0, 'y'=>@y0)
    @x3 = @x3 + @x0 - x00
    @y3 = @y3 + @y0 - y00
    move_other_obj(@x0 - x00,@y0 - y00)
  end

  def do_mov_obj_delta(_delta_x=1, _delta_y=1)
    x00 = @x0
    y00 = @y0
    @x0 = @x0 + _delta_x
    #@agobj.update_property('place', 'x', @x0)
    @y0 = @y0 + _delta_y
    #@agobj.update_property('place', 'y', @y0)
    @agobj.obj.place('x'=>@x0, 'y'=>@y0)
    @x3 = @x3 + @x0 - x00
    @y3 = @y3 + @y0 - y00
  end

  def do_mov_obj_delta_dim(_delta_width=1, _delta_height=1)
    _width = @x3 - @x0 + _delta_width
    _height = @y3 - @y0 + _delta_height
    #@agobj.update_property('place', 'width', _width)
    #@agobj.update_property('place', 'height', _height)
    @agobj.obj.place('width'=>_width, 'height'=>_height)
    @x3 = @x0 + _width
    @y3 = @y0 + _height
  end

  def object_inspector_select
    @agobj.select
    #@agobj.object_inspector.select(@agobj, false) if !defined? @agobj.object_inspector.active_object or @agobj.object_inspector.active_object != @agobj
  end

  def do_press_obj(x, y)
    @start_x = x
    @start_y = y
    object_inspector_select
  end

  def getx0x3
    @agobj.props['place']['x']['value'] = @agobj.props['place']['x']['get'].call.to_i
    @agobj.props['place']['y']['value'] = @agobj.props['place']['y']['get'].call.to_i
    @agobj.props['place']['width']['value'] = @agobj.props['place']['width']['get'].call.to_i
    @agobj.props['place']['height']['value'] = @agobj.props['place']['height']['get'].call.to_i
    @x0 = @agobj.props['place']['x']['value']
    @y0 = @agobj.props['place']['y']['value']
    @x3 = @x0 + @agobj.props['place']['width']['value']
    @y3 = @y0 + @agobj.props['place']['height']['value']
  end

  def initx0x3(_prop = nil, _value = nil)
    case _prop
    when 'x'
      _x = @x0
      @x0 = _value.to_i
      @x3 = @x3 + @x0 - _x
    when 'y'
      _y = @y0
      @y0 = _value.to_i
      @y3 = @y3 + @y0 - _y
    when 'width'
      @x3 = @x0 + _value.to_i
    when 'height'
      @y3 = @y0 + _value.to_i
    when nil, 'text'
      getx0x3
    end
    @start_x = @x0 if defined? @x0
    @start_y = @y0 if defined? @y0
  end

  def move_other_obj(x,y)
    @@place_managers.each do |value|
      if (value != self)&&(value.active?)
        value.do_mov_obj_delta(x,y)
      end
    end
  end

  def deactivate
    self.free_rect
    @active = false
  end

  def refresh_active
    @@place_managers.each do |value|
      if  value.active?
        value.refresh
      end
    end
  end

	def refresh
	  Tk.update
	  getx0x3
    activate(false)
	end


  def activate(free=true)
    if free
      @@place_managers.each do |value|
        value.deactivate
      end
    else
      self.free_rect
    end
    _layout = @agobj.props['layout_man']['manager']['get'].call
    _bind = _layout == 'place'
    if	_bind && @last_layout != 'place'
      @agobj.obj.place('x'=> @ox0,'y'=> @oy0)
    end
    create_rect(_bind)
    @last_layout = _layout
    @active = true
  end

  def active?
    return @active
  end

  def create_rect(_bind = true)
    _L = 6
    _mx = 0
    _my = 0

    # r1         r14       r4
    # r12                  r34
    # r2         r23       r3

    _x0_RectLeft = @x0 - _L - _mx
    _x3_RectLeft = @x3  + _mx
    _x14_RectLeft = (@x3 + @x0)/2 - _L/2
    _y0_RectLeft = @y0 - _L - _my
    _y3_RectLeft = @y3  + _my
    _y12_RectLeft = (@y3 + @y0 - _L)/2

    @r1 = AGTkObjRect.new(@agobj.ag_parent.obj, _x0_RectLeft,  _y0_RectLeft, _L,  _L,'both',
    'top_left_corner',_bind)
    @r12 = AGTkObjRect.new(@agobj.ag_parent.obj, _x0_RectLeft,  _y12_RectLeft, _L,  _L,
    'x', 'sb_h_double_arrow',_bind)
    @r2 = AGTkObjRect.new(@agobj.ag_parent.obj, _x0_RectLeft, _y3_RectLeft, _L,  _L,'both', 'bottom_left_corner',_bind)
    @r3 = AGTkObjRect.new(@agobj.ag_parent.obj,_x3_RectLeft,  _y3_RectLeft, _L,  _L,'both','bottom_right_corner',_bind)
    @r34 = AGTkObjRect.new(@agobj.ag_parent.obj, _x3_RectLeft,  _y12_RectLeft, _L,   _L, 'x', 'sb_h_double_arrow',_bind)
    @r4 = AGTkObjRect.new(@agobj.ag_parent.obj,_x3_RectLeft, _y0_RectLeft, _L,  _L,'both', 'top_right_corner',_bind)
    @r14 = AGTkObjRect.new(@agobj.ag_parent.obj, _x14_RectLeft, _y0_RectLeft, _L, _L,'y', 'sb_v_double_arrow',_bind)
    @r23 = AGTkObjRect.new(@agobj.ag_parent.obj, _x14_RectLeft, _y3_RectLeft, _L,  _L,'y', 'sb_v_double_arrow',_bind)
    if _bind
      @r1.r.bind("ButtonRelease-1", proc{do_Release(@r1)})
      @r1.r.bind_append("B1-Motion",proc{geomvar(@r1)})
      @r12.r.bind("ButtonRelease-1", proc{do_Release(@r12)})
      @r12.r.bind_append("B1-Motion",proc{geomvar(@r12)})
      @r2.r.bind("ButtonRelease-1", proc{do_Release(@r2)})
      @r2.r.bind_append("B1-Motion",proc{geomvar(@r2)})
      @r3.r.bind("ButtonRelease-1", proc{do_Release(@r3)})
      @r3.r.bind_append("B1-Motion",proc{geomvar(@r3)})
      @r34.r.bind("ButtonRelease-1", proc{do_Release(@r34)})
      @r34.r.bind_append("B1-Motion",proc{geomvar(@r34)})
      @r4.r.bind("ButtonRelease-1", proc{do_Release(@r4)})
      @r4.r.bind_append("B1-Motion",proc{geomvar(@r4)})
      @r14.r.bind("ButtonRelease-1", proc{do_Release(@r14)})
      @r14.r.bind_append("B1-Motion",proc{geomvar(@r14)})
      @r23.r.bind("ButtonRelease-1", proc{do_Release(@r23)})
      @r23.r.bind_append("B1-Motion",proc{geomvar(@r23)})

      @r1.r.bind_append("ButtonPress-1", proc{@r1.r.callback_break})
      @r12.r.bind_append("ButtonPress-1", proc{@r12.r.callback_break})
      @r2.r.bind_append("ButtonPress-1", proc{@r2.r..callback_break})
      @r3.r.bind_append("ButtonPress-1", proc{@r3.r.callback_break})
      @r34.r.bind_append("ButtonPress-1", proc{@r34.r.callback_break})
      @r4.r.bind_append("ButtonPress-1", proc{@r4.r.callback_break})
      @r14.r.bind_append("ButtonPress-1", proc{@r14.r.callback_break})
      @r23.r.bind_append("ButtonPress-1", proc{@r23.r.callback_break})
    end
    flash
  end

  def flash
    @ox0 = @x0
    @ox3 = @x3
    @oy0 = @y0
    @oy3 = @y3
  end

  def free_rect
    if defined? @r1
      @r1.r.destroy
    end
    if defined? @r2
      @r2.r.destroy
    end
    if defined? @r3
      @r3.r.destroy
    end
    if defined? @r4
      @r4.r.destroy
    end
    if defined? @r14
      @r14.r.destroy
    end
    if defined? @r23
      @r23.r.destroy
    end
    if defined? @r12
      @r12.r.destroy
    end
    if defined? @r34
      @r34.r.destroy
    end
  end

  def do_start(_r)
    case _r
    when @r3
      @r4.start_x = _r.start_x
      @r2.start_y = _r.start_y
    end
  end

  def resize_rect(_x0,_y0, _x3,_y3, _r)
    # r1         r14       r4
    # r12                  r34
    # r2         r23       r3
    if defined? _r
      if _r != @r1
        @r1.r.place('x' =>_x0 - @r1.w0 , 'y' => _y0 - @r1.h0)
      end
      if _r != @r2
        @r2.r.place('x' =>_x0 - @r2.w0, 'y' => _y3)
      end
      if _r != @r3
        @r3.r.place('x' =>_x3, 'y' => _y3)
      end
      if _r != @r4
        @r4.r.place('x' =>_x3, 'y' => _y0  - @r4.h0)
      end
      if _r != @r14
        @r14.r.place('x' => (_x3 +_x0 - @r14.w0)/2, 'y' => _y0  - @r14.h0)
      end
      if _r != @r23
        @r23.r.place('x' => (_x3 +_x0 - @r23.w0)/2, 'y' => _y3)
      end
      if _r != @r12
        @r12.r.place('x' => _x0 - @r12.w0, 'y' => (_y3  + _y0 - @r12.w0)/2)
      end
      if _r != @r34
        @r34.r.place('x' => _x3 , 'y' => (_y3  + _y0 - @r34.w0)/2)
      end
    end
  end

  def border
    @l1.delete if defined? @l1
    @l1 = TkcLine.new(@agobj.ag_parent.canvas, @ox0, @oy0, @ox3,@oy0, @ox3,@oy3, @ox0 , @oy3, @ox0, @oy0){
      fill 'red'
      width 0.2
    }
  end

  def geomvar(_r)
    # r1         r14       r4
    # r12                  r34
    # r2         r23       r3
    case _r
    when @r1
      w = @ox3 - @r1.x0 - @r1.w0
      h = @oy3 - @r1.y0 - @r1.h0
      @ox0 = @ox3 - w
      @oy0 = @oy3 - h
    when @r12
      w = @ox3 - @r12.x0 - @r12.w0
      @ox0 = @ox3 - w
    when @r2
      w = @ox3 - @r2.x0 - @r2.w0
      h = @r2.y0 - @oy0
      @ox0 = @ox3 - w
      @oy3 = @oy0 + h
    when @r23
      h = @r23.y0 - @oy0
      @oy3 = @oy0 + h
    when @r3
      w = @r3.x0  - @ox0
      h = @r3.y0  - @oy0
      @ox3 = @ox0 + w
      @oy3 = @oy0 + h
    when @r34
      w = @r34.x0  - @ox0
      @ox3 = @ox0 + w
    when @r4
      w = @r4.x0  - @ox0
      h = @oy3 - @r4.y0 - @r4.h0
      @oy0 = @oy3 - h
      @ox3 = @ox0 + w
    when @r14
      h = @oy3 - @r14.y0 - @r14.h0
      @oy0 = @oy3 - h
    end
    resize_rect(@ox0, @oy0 , @ox3, @oy3, _r)
  end

  def do_Release(_r)
    # r1         r14       r4
    # r12                  r34
    # r2         r23       r3
    if _r.motion
      case _r
      when @r1
        w = @ox3 - @ox0
        h = @oy3 - @oy0
        @agobj.update_property(@agobj, 'place', 'x', @ox0) if @ox0 != @x0
        @agobj.update_property(@agobj, 'place', 'y', @oy0) if @oy0 != @y0
        @agobj.update_property(@agobj, 'place', 'width', w) if w != @x3 - @x0
        @agobj.update_property(@agobj, 'place', 'height', h) if h != @y3 - @y0
      when @r12
        w = @ox3 - @ox0
        @agobj.update_property(@agobj, 'place', 'x', @ox0) if @ox0 != @x0
        @agobj.update_property(@agobj, 'place', 'width', w) if w != @x3 - @x0
      when @r2
        w = @ox3 - @ox0
        h = @oy3 - @oy0
        @agobj.update_property(@agobj, 'place', 'x', @ox0) if @ox0 != @x0
        @agobj.update_property(@agobj, 'place', 'width', w) if w != @x3 - @x0
        @agobj.update_property(@agobj, 'place', 'height', h) if h != @y3 - @y0
      when @r23
        h = @oy3 - @oy0
        @agobj.update_property(@agobj, 'place', 'height', h) if h != @y3 - @y0
      when @r3
        w = @ox3 - @ox0
        h = @oy3 - @oy0
        @agobj.update_property(@agobj, 'place', 'width', w) if w != @x3 - @x0
        @agobj.update_property(@agobj, 'place', 'height', h) if h != @y3 - @y0
      when @r34
        w = @ox3 - @ox0
        @agobj.update_property(@agobj, 'place', 'width', w) if w != @x3 - @x0
      when @r4
        w = @ox3 - @ox0
        h = @oy3 - @oy0

        @agobj.update_property(@agobj, 'place', 'y', @oy0) if @oy0 != @y0
        @agobj.update_property(@agobj, 'place', 'width', w) if w != @x3 - @x0
        @agobj.update_property(@agobj, 'place', 'height', h) if h != @y3 - @y0
      when @r14
        h = @oy3 - @oy0
        @agobj.update_property(@agobj, 'place', 'y', @oy0) if @oy0 != @y0
        @agobj.update_property(@agobj, 'place', 'height', h) if h != @y3 - @y0

      end
      @x0 = @ox0
      @y0 = @oy0
      @x3 = @ox3
      @y3 = @oy3
      @l1.delete if defined? @l1
      _r.motion = false
    end
  end

  def move_rect(x,y)
    @r1.move(x,y) if defined? @r1
    @r2.move(x,y) if defined? @r2
    @r3.move(x,y) if defined? @r3
    @r4.move(x,y) if defined? @r4
    @r14.move(x,y) if defined? @r14
    @ox0 = @agobj.x0
    @ox3 = @agobj.x3
    @oy0 = @agobj.y0
    @oy3 = @agobj.y3
  end

end

class AGTkObjPackRect
  attr :r

  def initialize(_parent,_w0 , _h0, _anchor)
    @r = TkLabel.new(_parent){
      text 'p'
      font 'courier 8'
      highlightbackground 'black'
      background 'yellow'
      relief 'groove'
      pack('ipadx'=>0,'ipady'=>0, 'anchor' => _anchor)
    }
  end

end

class AGTkPackManager

  def initialize(_agobj, _active)
    unless defined? _agobj.ag_parent
      return
    end
    @agobj = _agobj
    if !defined? @@packs_managers
      @@packs_managers = Array.new
    end
    activate if _active
    @@packs_managers << self
  end

  def deactivate
    self.free_rect
  end

  def activate
    @@packs_managers.each do |value|
      value.free_rect
    end
    create_rect
  end
  
  def create_rect
    # r1         r14       r4
    # r12                  r34
    # r2         r23       r3
    TkPack::propagate(@agobj.obj, false)
    @r1 = AGTkObjPackRect.new(@agobj.obj, 3,  3, 'nw')
  end

  def free_rect
    if defined? @r1
      @r1.r.destroy
    end
  end

end

class AGTkGridManager
  
  def initialize(_agobj, _active)
    unless defined? _agobj.ag_parent
      return
    end
    @agobj = _agobj
    if !defined? @@grids_managers
      @@grids_managers = Array.new
    end
    activate if _active
    @@grids_managers << self
  end

  def deactivate
  end

  def activate
  end

end


class AGTkLManager
  attr_reader :place_manager
  attr_reader :simple_manager
  
  def initialize(_agobj, _activate)
    unless defined? _agobj.ag_parent
      return
    end
    @@place_managers = Array.new if !defined? @@place_managers
    @@pack_managers = Array.new if !defined? @@pack_managers
    @@grid_managers = Array.new if !defined? @@grid_managers
    @agobj = _agobj
    @agobj.obj.bind_append("ButtonPress-1", proc{switch_manager(_activate)})
    set_manager(_agobj.props['layout_man']['manager']['get'].call, _activate)
    @active = _activate
  end

  def active?
    return @active||@place_manager.active?
  end

  def switch_manager(_activate=true)
    _req_manager = @agobj.props['layout_man']['manager']['get'].call
    if @manager != _req_manager
      set_manager(_req_manager, _activate)
    end
  end

  def set_manager(_name, _activate)
    case _name
    when 'place'
      if !defined? @place_manager
        @place_manager = AGTkPlaceManager.new(@agobj,_activate)
        @@last = @place_manager
        @@place_managers << @place_manager
      end
      if defined? @pack_manager
        @pack_manager.free_rect
      end
    when 'pack'
      if !defined? @pack_manager
        @pack_manager = AGTkPackManager.new(@agobj,_activate) if !defined? @pack_manager
        @@last = @pack_manager
        @@pack_managers << @pack_manager
      end
      if defined? @place_manager
        @place_manager.free_rect
      end
    when 'grid'
      if !defined? @grid_manager
        @grid_manager = AGTkGridManager.new(@agobj,_activate) if !defined? @grid_manager
        @@last = @grid_manager
        @@grid_managers << @grid_manager
      end
    else
      @simple_manager = AGTkSimpleManager.new(@agobj,_activate)
    end
    @manager = _name
    @active = _activate
  end

  def activate(free=true)
    #Tk.messageBox('message'=>'activate')
    if !defined?(@manager)
      set_manager(@agobj.props['layout_man']['manager']['get'].call, true)
    end
    case @manager
    when 'place'
      @place_manager.activate(free) if defined? @place_manager
      @@last = @place_manager if defined? @place_manager
    when 'pack'
      @pack_manager.activate if defined? @pack_manager
      @@last = @place_manager if defined? @pack_manager
    else
      AGTkLManager.deactivate_all
      @@last = nil
    end
    @active = true
    #@agobj.obj.callback_break
  end
  
  def refresh
    case @manager
      when 'place'
        @place_manager.refresh
    end
  end

  def deactivate_last
    @@last.deactivate if @@last
  end

  def AGTkLManager.deactivate_all
    @@place_managers.each{|value| value.deactivate}
    @@pack_managers.each{|value| value.deactivate}
    @@grid_managers.each{|value| value.deactivate}
    @active = false
  end

  def deactivate
    case @manager
    when 'place'
      @place_manager.deactivate if defined? @place_manager
    when 'pack'
      @pack_manager.deactivate if defined? @pack_manager
    end
    @active = false
  end

  def util_bind
    @agobj.obj.bind_append("Control-KeyPress"){|e|
      _deltax = 0
      _deltay = 0
      case e.keysym
      when 'Left'
        _deltax = -1
        _deltay = 0
      when 'Right'
        _deltax = 1
        _deltay = 0
      when 'Up'
        _deltax = 0
        _deltay = -1
      when 'Down'
        _deltax = 0
        _deltay = 1
      end
      if (_deltax != 0) || (_deltay != 0)
        active_object = AG.active
        active_object.l_manager.place_manager.do_mov_obj_delta(_deltax,_deltay)
        active_object.l_manager.place_manager.move_other_obj(_deltax, _deltay)
        active_object.l_manager.place_manager.refresh_active
      end
    }
    @agobj.obj.bind_append("Shift-KeyPress"){|e|
      active_object = AG.active
      case e.keysym
      when 'Left'
        active_object.l_manager.place_manager.do_mov_obj_delta_dim(-1,0)
        active_object.l_manager.activate
      when 'Right'
        active_object.l_manager.place_manager.do_mov_obj_delta_dim(1,0)
        active_object.l_manager.activate
      when 'Up'
        active_object.l_manager.place_manager.do_mov_obj_delta_dim(0,-1)
        active_object.l_manager.activate
      when 'Down'
        active_object.l_manager.place_manager.do_mov_obj_delta_dim(0,1)
        active_object.l_manager.activate
      end
    }
  end

end

class AGTkRenderer < AGRenderer

  def class_hinner_begin(_ind=0)
    return super(_ind), render_family(_ind+1,TkWinfo.manager(@agobj.obj)), "\n"
  end

  def class_end(_ind=0)
    result = super(_ind)
    if @agobj.contains_events
      result = result,"\n", class_controller(_ind)
    end
    return result
  end

  def class_controller(_ind=0)
    return class_controller_begin(_ind), class_controller_hinner_begin(_ind), class_controller_hinner_end(_ind), class_controller_end(_ind)
  end

  def class_controller_begin(_ind=0)
    code = "\n","\t"*_ind,'class ', @agobj.getInstanceClass,  'C', "\n"
    code = code, "\t"*(_ind+1),"attr_reader :",@agobj.i_name," :md\n"
    code = code, "\t"*(_ind+1),"def initialize(_md)\n"
    code = code, "\t"*(_ind+2),"@",@agobj.i_name,"=",@agobj.getInstanceClass,".new\n"
    code = code, "\t"*(_ind+2),"@md=_md\n"
    code = code, "\t"*(_ind+2),"self.binding\n"
    code = code, "\t"*(_ind+1),"end\n"
  end

  def class_controller_hinner_begin(_ind=0)
    code = code, "\t"*(_ind+1),"def binding\n"
    code = code, "\t"*(_ind+2),recursive_binding(@agobj,2),"\n"
  end

  def recursive_binding(_agobj,_ind=0)
    _code = ''
    _agobj.props_def['bind']['path'] = '@',_agobj.get_path_i_name,'.'
    if _agobj.has_events
      for i in 0.._agobj.persistent['events'].length - 1
        _agobj.persistent['prog']=i
        if _agobj.persistent['procs'] == nil || (_agobj.persistent['procs'][i] == nil || _agobj.persistent['procs'][i].length == 0)
          _agobj.persistent['procs'] = Array.new if _agobj.persistent['procs'] == nil
          _agobj.persistent['procs'][i]= "@md.on_",_agobj.i_name,'_',_agobj.persistent['events'][i]
        end
        _code = _code, _agobj.renderer.render_family(_ind,'bind')
      end
      _code = _code,"\n"
    end
    _agobj.sons.each{|son|
      _code = _code, recursive_binding(son,_ind),"\n"
    }
    return _code
  end

  def class_controller_hinner_end(_ind=0)
    code = code, "  end\n"
  end

  def class_controller_end(_ind=0)
    code = code, "end\n"
  end

end

class AGTkSniffer < AGSniffer
end

class AGTkCompositeSniffer < AGTkSniffer

  def find_sons
    super
    @sons.concat(TkWinfo.children(@obj))
  end

end

class AGINTk < AG
  attr_reader :graphic_obj

  def initialize(_ag_parent = nil, _object = nil)
    super(_ag_parent, _object)
    object_inspector_select
  end

  def new_object
    super
    new_graphic_rappresentation
  end

  def update(_event, _agobj)
    case _event
    when 'SELECT'
      if _agobj == self
        @graphic_obj.configure('relief'=>	'ridge')
      else
        @graphic_obj.configure('relief'=>	'flat')
      end
    end
  end

  def new_graphic_rappresentation
    @graphic_obj = TkLabel.new(@ag_parent.obj){
      background	'#fab4b9'
      background	'#fab4b9'
      foreground	'#a30c17'
      text	'obj'
    }
    if (defined? @ag_parent.where_x)&&(defined? @ag_parent.where_y)
      @graphic_obj.place('x'=>@ag_parent.where_x,'y'=>@ag_parent.where_y)
    end
    AGTkObjPlace.new(@graphic_obj)
    @graphic_obj.bind_append("ButtonPress-1", proc{object_inspector_select; @graphic_obj.callback_break })
  end

  def object_inspector_select
    AGTkLManager.deactivate_all
    self.select
    self.activate
    #@object_inspector.select(self, true) if !defined? @object_inspector.active_object or @object_inspector.active_object != self
  end

end

class AGTk < AG
  attr_reader :canvas, :x0, :y0, :x3, :y3, :l_manager
  attr_writer :x0, :y0, :x3, :y3

  def initialize(_ag_parent = nil, _object = nil)
    #Tk.update if _object != nil && _ag_parent == nil
    super(_ag_parent, _object)
    if (defined? @obj)
      if @ag_parent != nil
        ppress = proc{
          @l_manager.deactivate_last
        }
        prelease = proc{
          @l_manager.activate
        }
        @obj.bind_append("ButtonPress-1", ppress)
        @obj.bind_append("ButtonRelease-1", prelease)
        @parent = TkWinfo.parent(@obj)
      end
      @l_manager = AGTkLManager.new(self, _object == nil)
    end
    popup
    build_sons if _object != nil
  end
  
  def properties
    super
    publish('winfo','name'=>'path','get'=> proc{@obj.path}, 'def'=> 'nodef')
    publish('winfo','name'=>'id','get'=> proc{TkWinfo.id(@obj)}, 'def'=> 'nodef')
    publish('winfo','name'=>'parent','get'=> proc{TkWinfo.parent(@obj)}, 'def'=> 'nodef')

  end
  
  def update_property(_sender, _family,_name,_value)
	  super
	  if _sender != self && ['x','y','width','height','text'].include?(_name)
	    @l_manager.refresh
	  end
	
	end
  
  
  def popup_items(_popup_menu)
    _popup_menu.insert('end',
      :command,
      :label=>self.class.class_wrapped.to_s,
      :background => 'white',
      :hidemargin => false
    )

    _popup_menu.insert('end',
      :command,
      :label=>'Delete',
      :hidemargin => false,
      :command=> proc{self.delete}
    )
  end

  def popup
    if @obj
      _parent = nil
      if @ag_parent != nil
        _parent = @ag_parent.obj
      end
      @obj.bind("Button-3", proc{|x,y|
        popup_menu = TkMenu.new(
        :parent=>_parent,
        :tearoff=>0,
        :relief=>'groove',
        :title => @obj.class.to_s
        )
        popup_items(popup_menu)
        _x = TkWinfo.pointerx(@obj)
        _y = TkWinfo.pointery(@obj)
        popup_menu.popup(_x,_y)
        @obj.callback_break
      },
      "%x %y")
    end
  end

  def active_move_tab
    @obj.bind("Enter",
      proc{@canvas_of_move = TkCanvas.new(@obj)
        _lx = 30
        _ly = 43
        _x = (@x3 - @x0)/2 - _lx/2
        _y = (@y3 - @y0)/2 - _ly/2
        TkcImage.new(@canvas_of_move, _lx/2, _ly/2){
          image  TkAllPhotoImage.new('file' => 'skull.bmp')
        }
        @canvas_of_move.configure('cursor'=>'draft_small')
        @canvas_of_move.place('x' => _x ,
          'y' => _y,
          'width' => _lx,
          'height' => _ly
        )
        @canvas_of_move.bind("1", proc{|e| do_press(e.x, e.y)})
        @canvas_of_move.bind("B1-Motion", proc{|x, y| do_movobj(x,y)},"%x %y")
        @canvas_of_move.bind_append("ButtonPress-1", proc{@l_manager.deactivate_last})
        @canvas_of_move.bind_append("ButtonPress-1", proc{|e| do_press(e.x, e.y)})
        @canvas_of_move.bind("ButtonRelease-1", proc{ @l_manager.activate })
      }
    )
    @obj.bind("Leave", proc{@canvas_of_move.destroy})
    @obj.bind("Motion", proc{|x, y| @canvas_of_move.place('x' =>x - 5, 'y' => y - 5)},"%x %y")
  end

  def new_object
    if self.class.class_wrapped
      if @ag_parent
        @obj = self.class.class_wrapped.new(@ag_parent.obj)
      else
        @obj = self.class.class_wrapped.new
      end
    end
  end

  def AGTk.class_wrapped
    nil
  end

  def AGTk.class_renderer
    AGTkRenderer
  end

  def AGTk.class_sniffer
    AGTkSniffer
  end

  def has_events
    result =  defined?(@persistent) && @persistent['events'] != nil
  end

  def contains_events
    result =  has_events
    self.sons.each{|son|
      result = result || son.contains_events
    }
    return result
  end

#  def retrive_values
#    @props['layout_man']['manager']['value'] = @props['layout_man']['manager']['get'].call
#  end

  def delete
    @l_manager.deactivate if defined? @l_manager
    super()
  end

  def getFileName
    __FILE__
  end

#  def updatep(_family, prop, value, _call_from_inspector=false)
#    if _call_from_inspector && ['place','pack','grid','layout_man'].include?(_family)
#      @l_manager.deactivate
#    end
#    super(_family, prop,value, _call_from_inspector)
#    if _call_from_inspector && _family == 'place'
#      @l_manager.place_manager.initx0x3
#    end
#    if _call_from_inspector && ['place','pack','grid','layout_man'].include?(_family)
#      @l_manager.activate
#    end
#    Tk.update
#  end

  def activate
    super
    @l_manager.activate if defined? @l_manager
    self
  end

end

class QTkScrollbar < TkScrollbar

  def initialize(parent=nil, keys=nil,&b)
    @strin = ''
    if keys
      @strin = keys.to_s
    end
    if block_given?
      @strin = @strin + b.to_s
    end
    super
    ArcadiaLibs.copy_wrapper_of_class_to_class(TkScrollbar, QTkScrollbar)
  end

  def class
    TkScrollbar
  end

  def wrapline(_str)
    if _str
      m = /@\(eval\)\:([0123456789]*)/.match(_str)
      if m && m[1]
        return m[1].to_i
      else
        -1
      end
    else
      -1
    end
  end

  def block(_i, _str)
    _nline = 0
    _strwrk = ''
    _str.each{|line|
      _nline = _nline + 1
      if _nline >= _i
        _strwrk = _strwrk + line
      end
    }

    m = /\{(.*)\}/m.match(_strwrk)
    if m && m[1]
      return m[1]
    else
      ' ma! '
    end

  end

  def command_script
    block(wrapline(@strin), $arcadia['code'])
  end

end


module WrapBind

  def wbind_mini()
    p self
  end

  def wbind_append(context, cmd=Proc.new, args=nil)
    self.bind_append(context, cmd)
  end

  def wbind(context, cmd=Proc.new, args=nil)
    self.bind(context, cmd)
  end

  def procstr(path)
    parts = path.split('@')
    file,srow = parts[1].split(':')
    srow.sub!('>','')
    row = srow.to_i
    lines = IO.readlines(file)
    line = lines[row - 1]
    i1 = line.index('proc{') + 5
    result = line[i1..line.length - 1]
    i2 = nil
    while i2 == nil
      i2 = result.index('}')
      if i2
        i2 = i2 + i1 - 1
        result = line[i1..i2]
      else
        row = row + 1
        result = result + lines[row - 1]
      end
    end
    return result
  end

end

include WrapBind

class Revparsel

  def initialize(_code, _filename=nil)
    #p "-------- revparsel ------------"
    _code.gsub!('TkScrollbar','QTkScrollbar')
    _code.gsub!('bind(','wbind(')
    if $arcadia.objects('code')
      $arcadia['code']=_code
    else
      $arcadia.publish('code',_code)
    end
    @filename = _filename
    _re_string = ''
    ['TkToplevel','Tk::Toplevel','TkRoot','TkToplevelLayer'].each{|top|
      if _re_string.length > 0
        _re_string = _re_string+'|'
      end
      _re_string = _re_string+'class\s*[A-Za-z0-9_]*\s*<\s*'+top
    }
    m = Regexp::new(_re_string).match(_code)
    if m
      _c,_class_name,_c,_class = m[0].split
      _obj_name = _class_name.sub(/^./) { $&.downcase}
      cod = _code + "\n@"+ _obj_name + "="+ _class_name+".new('class'=>"+_class+")\n"
      cod = cod +"Tk.update\n"
      #p cod
      eval(cod)
      cod = ''
      cod = cod + '@ag'+ _obj_name + "="+'AG'+ _class.sub('::','')+".new(nil,@"+_obj_name+"){\n"
      cod = cod + "|_self|\n"
      cod = cod + "  _self.i_name='"+_obj_name+"' \n"
      cod = cod + "  _self.i_ag='"+'ag'+_obj_name+"' \n"
      cod = cod + '}'+"\n"
      #p "-------------------"
      #p cod
      eval(cod)
    end
  end

  def eval_obj(_obj_name, _ag_obj_name)
    _obj_name_base = _obj_name.delete('@')
    cod = " @istancev = "+ _obj_name +".instance_variables\n"
    eval(cod)
    cod = " @tkv = TkWinfo.children("+_obj_name+")\n"
    eval(cod)
    if @tkv.length > 0
      array_eval = "["
      l=0
      @istancev.each{|i|
        array_eval = array_eval + "," if l>0
        array_eval = array_eval +i+'.object_id'
        l=l+1
      }
      array_eval = array_eval +"]"
      @tkv.each{|k|
        $k=k
        _name = '@j'+$k.object_id.abs.to_s
        cod = "if !"+ array_eval
        cod = cod+".include?("+$k.object_id.to_s+")"+"\n"
        cod = cod + _name +'=$k'
        cod = cod + "\nelse\n" + '$k=nil'
        cod = cod+"\nend\n"
        eval(_obj_name+'.instance_eval{|k| '+cod+'}')
        if $k
          @istancev << _name
        end
      }
    end
    if @istancev.length > 0
      cod = " class << "+_obj_name+"\n"
      @istancev.each{|i|
        i.delete!('@')
        cod = cod + "  attr_reader  :"+i+"\n"
      }
      cod = cod +"end\n"
      eval(cod)
      cod = ''
      @istancev.each{|v|
        v.delete!('@')
        path_obj =  _obj_name+'.'+ v
        eval('@gong = '+ path_obj)
        _agclass=ArcadiaLibs.wrapper_class(@gong.class)
        if _agclass
          cod = "@ag"+v+"="+_agclass+".new("+ _ag_obj_name +","+path_obj+"){|_self|\n"
          cod = cod + " _self.i_name = '"+v+"'\n"
          cod = cod + " _self.i_ag = 'ag"+v+"'\n"
          cod = cod + "}\n"
          eval(cod)
          eval_obj(path_obj, "@ag"+v)
        end
      }
    end
  end
end

module Visible
  def hide object = self
    object.withdraw
  end
  def show object = self
    object.takefocus(1)
    object.deiconify
  end
end

class TkToplevelLayer < TkToplevel
  include Visible
  def initialize()
    super
    takefocus 1
    withdraw
    protocol( "WM_DELETE_WINDOW", proc{self.hide})
  end
end

class TkFrameLayer < TkFrame
  include Visible
  def initialize()
    super
    takefocus 1
    withdraw
  end
end

class TkToplevelRoot < TkToplevel

  def initialize(parent=nil, screen=nil, classname=nil, keys=nil)
    super
    ArcadiaLibs.copy_wrapper_of_class_to_class(TkToplevel, TkToplevelRoot)
  end

end

class ParsifalTk
  include TkComm

  def initialize(_code=nil, _filename=nil, _language='ruby')
    @filename = _filename;
    @code = _code
    if (@filename)&&(File.exist?(@filename))
      @code =''
      IO.foreach(@filename) { |line| @code += line };
    end
    @root =  TkWinfo.widget(Tk.tk_call('winfo', 'id', '.'))
    @top_level_banned = Array.new
    TkWinfo.children(@root).each{|_c|
      if _c.kind_of?(TkToplevel)
        @top_level_banned << _c
        print "\n"+Tk.tk_call('wm', 'title', _c)
      end
    }

    case _language
    when 'ruby'
      if !@code.gsub!('TkRoot','TkToplevelRoot')
        eval('@preudo_root=TkToplevelRoot.new')
        @code.gsub!('.new(nil','.new(@preudo_root')
      end
      @code.gsub!('Tk.mainloop','')
      eval(@code)
    when 'tcl'
      Tk.tk_call( "eval", @code)
    end
    tk_tree
  end

  def tk_tree
    if defined?(@sons_of)
      return @sons_of
    else
      begin
        @sons_of = dynasty_of(@root)
      end
      ag_wrap_dynasty_of(@root)
    end
  end

  def names_dynasty_of(_root, _names=Hash.new)
    if _root == @root
      iv = self.instance_variables
    else
      iv = _root.instance_variables
    end
    if @sons_of[_root]
      @sons_of[_root].each{|tkobj|
        iv.each{|i|
          eval("@bingo = "+i+"==tkobj")
          if @bingo
            _names[tkobj]=i.delete!('@')
            break
          end
        }
        names_dynasty_of(tkobj, _names)
      }
    end
    return _names
  end

  def name(_obj)
    if !defined?(@names)
      @names = names_dynasty_of(@root)
    end
    _name = @names[_obj]
    if !_name&&(_obj!=@root)
      _name = 'j'+_obj.id.to_s
    end
    return _name
  end

  def ag_wrap_dynasty_of(_root, _rootname=name(_root))
    if _rootname
      _rootname = '@ag'+_rootname
    end
    if @sons_of[_root]
      @sons_of[_root].each{|_son|
        print "\nwrappo -->"+_son.to_s
        ag_create(_son, name(_son), _rootname, @filename)
        ag_wrap_dynasty_of(_son)
      }
    end
  end

  def ag_create(_obj, _obj_name=nil, _ag_parent_name=nil, _filename=nil)
    if !_ag_parent_name
      _ag_parent_name='nil'
    end
    @filename = _filename
    if !_obj_name
      _obj_name = 'j'+_obj.id.to_s
    end
    _agclass=ArcadiaLibs.wrapper_class(_obj.class)
    if _agclass
      cod = '@'+_obj_name+"=_obj\n"
      if @filename && _obj.kind_of?(TkToplevel)
        cod = cod + '@ag'+ _obj_name + "="+ _agclass+".new("+_ag_parent_name+", _obj"+",nil,'"+_filename+"'){\n"
      else
        cod = cod +  '@ag'+ _obj_name + "="+ _agclass+".new("+_ag_parent_name+", _obj"+",nil){\n"
      end
      cod = cod + "|_self|\n"
      cod = cod + "  _self.i_name='"+_obj_name+"'\n"
      cod = cod + "  _self.i_ag='"+'ag'+_obj_name+"'\n"
      cod = cod + '}'
      eval(cod)
    end
  end

  def dynasty_of(_root, sons_of = Hash.new)
    _childrens = TkWinfo.children(_root)
    if (_childrens != nil)&&(_childrens.length > 0)
      sons_of[_root] = _childrens
      sons_of[_root].delete_if {
        |_s|
        @top_level_banned.include?(_s)||
        ((_root.kind_of?(TkRoot))&&(!_s.kind_of?(TkToplevel)))
      }
      sons_of[_root].each{|son|
        dynasty_of(son, sons_of)
      }
    end
    return sons_of
  end

end


class AGTkFramePlaceManager
  attr_reader :main_frame

  def initialize(_main_frame = nil)
    @main_frame = _main_frame
    @frames = Hash.new
    @frames_seq = Array.new

    @frames_left = Hash.new
    @frames_right = Hash.new
    @frames_top = Hash.new
    @frames_bottom = Hash.new

    @Info = Struct.new("Info", :obj, :splitter, :side, :objp, :visible)
    @motion = false
    @nx= 0
    yield(self) if block_given?
  end

  def add(_name, _frame=TkFrame.new(@main_frame), _ndim=-1, _splitter=false, _side='x' )
    if _frame == nil
      _frame=TkFrame.new(@main_frame)
    end
    case _side
    when 'x'
      @frames_right.each_value{|value|
        value << _name
      }
      if @frames_right[_name]==nil
        @frames_right[_name] = Array.new
      end
    when 'y'
      @frames_bottom.each_value{|value|
        value << _name
      }
    end
    case _side
    when 'x'
      @frames_left[_name]= Array.new
      @frames_seq.each{|item|
        @frames_left[_name] << item
      }
      (_ndim>0)?(_rw=0):_rw=1
      _frame.place(
      'relwidth' => _rw,
      'relx' => 0,
      'x' => @nx,
      'y' => '0',
      'relheight' => '1',
      'rely' => 0,
      'height' => 1,
      'bordermode' => 'inside',
      'width' => _ndim
      )
      if _splitter
        _xbutton = TkButton.new(@main_frame){
          text  '<'
          overrelief  'ridge'
          relief  'groove'
        }
        _xbutton.place(
        'x' => @nx - 20,
        'y' => 0,
        'height' => 20,
        'bordermode' => 'outside',
        'width' => 20
        )
        _xbutton.bind_append(
        "ButtonPress-1",
        proc{
          @frames[@frames_left[_name][0]].objp.obj.unplace
          @frames[_name].objp.amove(1,0)
          do_resize(_name)
          _xbutton.place('x'=>0)
          _xbutton.raise
          if _xbutton.cget('text') == '<'
            _xbutton.configure('text'=>'>')
          else
            _xbutton.configure('text'=>'<')
          end
        }
        )
        if @motion
          _frame.bind_append(
          "B1-Motion",
          proc{do_resize(_name)}
          )
        else
          _frame.bind_append(
          "B1-Motion",
          proc{_frame.raise}
          )
        end
        _frame.bind_append(
        "ButtonRelease-1",
        proc{do_resize(_name)}
        )
      end

      @nx = @nx + _ndim if _ndim > 0

    when 'y'
      @frames_top[_name]= Array.new
      @frames_bottom[_name]= Array.new
      @frames_seq.each{|item|
        @frames_top[_name] << item
      }
    end
    @frames[_name] = @Info.new(
      _frame,
      _splitter,
      _side,
      AGTkObjPlace.new(_frame, _side),
      true
    )
    @frames_seq << _name
    return _frame
  end

  def do_resize (_name_splitter)
    case @frames[_name_splitter].side
    when 'x'
      _x = @frames[_name_splitter].objp.x0
      if (_x > 0)&&(@frames_left.length > 0)
        _w = @frames[_name_splitter].objp.w
        _index = @frames_left[_name_splitter].length - 1
        if (@frames_left.length == 1)||(_x > @frames[@frames_left[_name_splitter][_index]].objp.x0)
          @frames[@frames_left[_name_splitter][_index]].objp.go(_x,0)
        end
        _gap = _w
        @frames_right[_name_splitter].each{|i|
          @frames[i].objp.amove(_x + _gap,0)
          _gap = _gap + @frames[i].objp.w
        }
      end
    when 'y'
    end
  end

  def [](_name)
    @frames[_name].obj
  end

  def frame(_name)
    @frames[_name].obj
  end

  def hide(_name)
    _w = @frames[_name].objp.w
    @frames[_name].obj.unplace
    @frames[_name].visible = false
    @frames_right[_name].each{|i|
      @frames[i].objp.move(-_w,0) if @frames[i].visible
    }
  end
  def show(_name)
    _x = @frames[_name].objp.x0
    _w = @frames[_name].objp.w0
    @frames[_name].obj.place(
    'x' => _x,
    'relheight' => '1',
    'width' => _w
    )
    @frames[_name].visible = true
    _x = _x + _w
    @frames_right[_name].each{|i|
      if @frames[i].visible
        @frames[i].obj.place('x' =>_x)
        _x = _x + @frames[i].objp.w
      end
    }
  end

end

module TkType
  TkagRelief = EnumType.new('flat','groove','raised','ridge','sunken')
  TkagJustify = EnumType.new('left','center','right')
  TkagOrient = EnumType.new('vertical','horizontal')
  TkagAnchor = EnumType.new('n', 'ne', 'e','se', 's', 'sw', 'w', 'nw','center')
  TkagBool = EnumType.new(true,false)
  TkagState = EnumType.new('normal', 'active', 'disabled')
  TkagFile = ProcType.new(proc{value = Tk.getOpenFile})
  TkagCompound = EnumType.new('none' ,'bottom', 'center', 'left', 'none', 'right', 'top')
  if RUBY_PLATFORM.include?('win32')
    TkagColor = EnumProcType.new(proc{value = Tk.chooseColor},
    'SystemActiveBorder',
    'SystemActiveCaption',
    'SystemAppWorkspace',
    'SystemBackground',
    'SystemButtonFace',
    'SystemButtonHighlight',
    'SystemButtonShadow',
    'SystemButtonText',
    'SystemCaptionText',
    'SystemDisabledText',
    'SystemHighlight',
    'SystemHighlightText',
    'SystemInactiveBorder',
    'SystemInactiveCaption',
    'SystemInactiveCaptionText',
    'SystemMenu',
    'SystemMenuText',
    'SystemScrollbar',
    'SystemWindow',
    'SystemWindowFrame',
    'SystemWindowText'
    )
	else
	  TkagColor = ProcType.new(proc{value = Tk.chooseColor})
	end
  TkagFont = ProcType.new(proc{value = $arcadia['action.get.font'].call})
  TkagCursor = EnumType.new('X_cursor', 'hand2','left_ptr')

end

module TkProperties

  def TkProperties.property(_name, _obj)
    {'name'=>_name,
      'get'=> proc{_obj.cget(_name)},
      'set'=> proc{|value| _obj.configure(_name=>value)}
    }
  end

  def TkProperties.generic_color(_name, _obj)
    {'name'=>_name,
      'get'=> proc{_obj.cget(_name)},
      'set'=> proc{|value| _obj.configure(_name=>value)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end


  def TkProperties.background(_obj)
    {'name'=>'background',
      'get'=> proc{_obj.cget('background')},
      'set'=> proc{|background| _obj.configure('background'=>background)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.highlightbackground(_obj)
    {'name'=>'highlightbackground',
      'get'=> proc{_obj.cget('highlightbackground')},
      'set'=> proc{|background| _obj.configure('highlightbackground'=>background)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.width(_obj)
    {'name'=>'width',
      'get'=> proc{_obj.cget('width')},
      'set'=> proc{|t| _obj.configure('width'=>t)},
      'def'=> ""
    }
  end

  def TkProperties.height(_obj)
    {'name'=>'height',
      'get'=> proc{_obj.cget('height')},
      'set'=> proc{|t| _obj.configure('height'=>t)},
      'def'=> ""
    }
  end

  
  def TkProperties.highlightcolor(_obj)
    {'name'=>'highlightcolor',
      'get'=> proc{_obj.cget('highlightcolor')},
      'set'=> proc{|background| _obj.configure('highlightcolor'=>background)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.highlightthickness(_obj)
    {'name'=>'highlightthickness',
      'get'=> proc{_obj.cget('highlightthickness')},
      'set'=> proc{|x| _obj.configure('highlightthickness'=>x)},
      'def'=> ''
    }
  end

  def TkProperties.foreground(_obj)
    {'name'=>'foreground',
      'get'=> proc{_obj.cget('foreground')},
      'set'=> proc{|foreground| _obj.configure('foreground'=>foreground)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.disabledforeground(_obj)
    {'name'=>'disabledforeground',
      'get'=> proc{_obj.cget('disabledforeground')},
      'set'=> proc{|foreground| _obj.configure('disabledforeground'=>foreground)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.activebackground(_obj)
    {'name'=>'activebackground',
      'get'=> proc{_obj.cget('activebackground')},
      'set'=> proc{|activebackground| _obj.configure('activebackground'=>activebackground)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.activeforeground(_obj)
    {'name'=>'activeforeground',
      'get'=> proc{_obj.cget('activeforeground')},
      'set'=> proc{|activeforeground| _obj.configure('activeforeground'=>activeforeground)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.disabledforeground(_obj)
    {'name'=>'disabledforeground',
      'get'=> proc{_obj.cget('disabledforeground')},
      'set'=> proc{|disabledforeground| _obj.configure('disabledforeground'=>disabledforeground)},
      'def'=> '',
      'type'=> TkType::TkagColor
    }
  end

  def TkProperties.relief(_obj)
    {'name'=>'relief',
      'get'=> proc{_obj.cget('relief')},
      'set'=> proc{|r| _obj.configure('relief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    }
  end


  def TkProperties.overrelief(_obj)
    {'name'=>'overrelief',
      #'default'=> 'ridge',
      'get'=> proc{_obj.cget('overrelief')},
      'set'=> proc{|r| _obj.configure('overrelief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    }
  end

  def TkProperties.command(_obj)
    {'name'=>'command',
      'get'=> proc{eval('@c = _obj.command_script'); @c},
      'set'=> proc{|r| _obj.configure('command'=>r)},
      'def'=> ""
    }
  end

  def TkProperties.xscrollcommand(_obj)
    {'name'=>'xscrollcommand',
      'get'=> proc{_obj.cget('xscrollcommand')},
      'set'=> proc{|r| _obj.configure('xscrollcommand'=>r)},
      'def'=> ""
    }
  end

  def TkProperties.yscrollcommand(_obj)
    {'name'=>'yscrollcommand',
      'get'=> proc{_obj.cget('yscrollcommand')},
      'set'=> proc{|r| _obj.configure('yscrollcommand'=>r)},
      'def'=> ""
    }
  end



  def TkProperties.compound(_obj)
    {'name'=>'compound',
      'get'=> proc{_obj.cget('compound')},
      'set'=> proc{|compound| _obj.configure('compound'=>compound)},
      'def'=> '',
      'type'=> TkType::TkagCompound
    }
  end

  def TkProperties.font(_obj)
    {'name'=>'font',
      'get'=> proc{font = _obj.cget('font')
        if font.kind_of?(TkFont)
          keys = Hash.new
          font.configinfo.each{|key,value| keys[key]=value }
          keys['family']+"\s"+keys['size'].to_s+"\s"+keys['weight'].to_s
        else
          nil
        end
      },
      'set'=> proc{|f| _obj.configure('font'=>f)},
      'def'=> "",
      'type'=> TkType::TkagFont
    }
  end

  def TkProperties.state(_obj)
    {'name'=>'state',
      'get'=> proc{_obj.cget('state')},
      'set'=> proc{|s| _obj.configure('state'=>s)},
      'def'=> "",
      'type'=> TkType::TkagState
    }
  end

  def TkProperties.wraplength(_obj)
    {'name'=>'wraplength',
      'get'=> proc{_obj.cget('wraplength')},
      'set'=> proc{|w| _obj.configure('wraplength'=>w)},
      'def'=> ""
    }
  end

  def TkProperties.image(_obj)
    {'name'=>'image',
      'get'=> proc{_ret = _obj.cget('image') 
      							 if ! _ret.kind_of?(String)		
      									_ret = _ret.cget('file')
      							 end
      							 _ret
      						},
      'set'=> proc{|j| _obj.configure('image'=>TkAllPhotoImage.new('file' => j))},
      'def'=> proc{|x|
        if x.to_s.length > 2
          "image TkPhotoImage.new('file' => #{x})"
        else
          ""
        end
      },
      'type'=> TkType::TkagFile
    }
  end

  def TkProperties.bitmap(_obj)
    {'name'=>'bitmap',
      'get'=> proc{_obj.cget('bitmap')},
      'set'=> proc{|j| _obj.configure('bitmap'=>TkAllPhotoImage.new('file' => j))},
      'def'=> proc{|x|
        if x.to_s.length > 2
          "bitmap TkAllPhotoImage.new('file' => #{x})"
        else
          ""
        end
      },
      'type'=> TkType::TkagFile
    }
  end


  def TkProperties.borderwidth(_obj)
    {'name'=>'borderwidth',
      #'default'=> 2,
      'get'=> proc{_obj.cget('borderwidth')},
      'set'=> proc{|b| _obj.configure('borderwidth'=>b)},
      'def'=> ""
    }
  end

  def TkProperties.border(_obj)
    {'name'=>'border',
      'default'=> 0,
      'get'=> proc{_obj.cget('border')},
      'set'=> proc{|b| _obj.configure('border'=>b)},
      'def'=> ""
    }
  end


  def TkProperties.padx(_obj)
    {'name'=>'padx',
      #'default'=> 0,
      'get'=> proc{_obj.cget('padx')},
      'set'=> proc{|b| _obj.configure('padx'=>b)},
      'def'=> ""
    }
  end

  def TkProperties.pady(_obj)
    {'name'=>'pady',
      #'default'=> 0,
      'get'=> proc{_obj.cget('pady')},
      'set'=> proc{|b| _obj.configure('pady'=>b)},
      'def'=> ""
    }
  end


  def TkProperties.orient(_obj)
    {'name'=>'orient',
      'get'=> proc{_obj.cget('orient')},
      'set'=> proc{|o| _obj.configure('orient'=>o)},
      'def'=> "",
      'type'=> TkType::TkagOrient
    }
  end

  def TkProperties.anchor(_obj)
    {'name'=>'anchor',
      'get'=> proc{_obj.cget('anchor')},
      'set'=> proc{|a| _obj.configure('anchor'=>a)},
      'def'=> "",
      'type'=> TkType::TkagAnchor
    }
  end

  def TkProperties.labelanchor(_obj)
    {'name'=>'labelanchor',
      'get'=> proc{_obj.cget('labelanchor')},
      'set'=> proc{|a| _obj.configure('labelanchor'=>a)},
      'def'=> "",
      'type'=> TkType::TkagAnchor
    }
  end

  def TkProperties.cursor(_obj)
    {'name'=>'cursor',
      'get'=> proc{_obj.cget('cursor')},
      'set'=> proc{|o| _obj.configure('cursor'=>o)},
      'def'=> "",
      'type'=> TkType::TkagCursor
    }
  end

  def TkProperties.justify(_obj)
    {'name'=>'justify',
      'get'=> proc{_obj.cget('justify')},
      'set'=> proc{|j| _obj.configure('justify'=>j)},
      'def'=> "",
      'type'=> TkType::TkagJustify
    }
  end

  def TkProperties.takefocus(_obj)
    {'name'=>'takefocus',
      'get'=> proc{_obj.cget('takefocus')},
      'set'=> proc{|j| _obj.configure('takefocus'=>j)},
      'def'=> "",
      'type'=> EnumType.new(0,1)
    }
  end

  def TkProperties.class(_obj)
    {'name'=>'class',
      'default'=> AG.near_class_wrapped(_obj).to_s,
      'get'=> proc{_obj.cget('class')},
      'set'=> proc{|r| _obj.configure('class'=>r)},
      'def'=> "",
      'kind'=>'on-create'
    }
  end

  def TkProperties.colormap(_obj)
    {'name'=>'colormap',
      'get'=> proc{_obj.cget('colormap')},
      'set'=> proc{|r| _obj.configure('colormap'=>r)},
      'def'=> "",
      'type'=> EnumType.new('new','')
    }
  end

  def TkProperties.container(_obj)
    {'name'=>'container',
      'get'=> proc{_obj.cget('container')},
      'set'=> proc{|r| _obj.configure('container'=>r)},
      'def'=> "",
      'type'=> TkType::TkagBool
    }
  end

  def TkProperties.text(_obj)
    {'name'=>'text',
      'start'=> '<...>',
      'get'=> proc{_obj.cget('text')},
      'set'=> proc{|t| _obj.configure('text'=>t)},
      'def'=> ""
    }
  end
  def TkProperties.labelwidget(_obj)
    {'name'=>'labelwidget',
      'get'=> proc{_obj.cget('labelwidget')},
      'set'=> proc{|t| _obj.configure('labelwidget'=>t)},
      'def'=> ""
    }
  end

#  def TkProperties.path(_obj)
#    {'name'=>'path',
#      'get'=> proc{_obj.path},
#      'def'=> 'nodef'
#    }
#  end

end



class AGTkLayoutManaged < AGTk
  def start_properties
    if (defined? @ag_parent.where_x)&&(defined? @ag_parent.where_y)
      @props['place']['x']['start'] = @ag_parent.where_x
      @props['place']['y']['start'] = @ag_parent.where_y
    end
    super()
  end


  def properties
    super
    #  +-----------------------------------+
    #  |					common properties     								|
    #  +-----------------------------------+
    _self = self

    publish('layout_man','name'=>'manager',
      'default'=> 'place',
      'get'=> proc{TkWinfo.manager(@obj)},
      'set'=> proc{|l|
        _old_manager = @props['layout_man']['manager']['value']
        @props['layout_man']['manager']['value'] = l
        if ['pack','place','grid'].include?(l)
          if _old_manager != l
            eval('@obj.'+@renderer.render_family(0,l,nil,true).to_s.strip)
          		WrapperContract.instance.property_updated(self, 
          					'wrapper'=>self,
          					'property_name'=> 'manager',
          					'property_family'=>'layout_man',
          					'property_old_value'=>_old_manager,
          					'property_new_value'=>l
          		)

          end
        end
        if _old_manager != @props['layout_man']['manager']['value']
          self.l_manager.switch_manager if self.l_manager != nil
        end

      },
      'def'=> proc{""},
      'type'=> EnumType.new('place','pack','grid')
    )
    #  +-----------------------------------+
    #  |							        place               |
    #  +-----------------------------------+
    publish_def('place',
      'before'=>'place(',
      'sep'=>',',
      'after'=>')'
    )
    publish('place','name'=>'x',
      'get'=> proc{TkPlace.info(@obj)['x'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|x| @obj.place('x'=>x); @props['place']['x']['value'] = x },
      'def'=> proc{|x| "'x'=>#{x}"},
      'default'=> 10
    )
    publish('place','name'=>'y',
      'get'=> proc{TkPlace.info(@obj)['y'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|y| @obj.place('y'=>y);@props['place']['y']['value'] = y},
      'def'=> proc{|x| "'y'=>#{x}"},
      'default'=> 10
    )
    publish('place','name'=>'width',
      'get'=> proc{if TkWinfo.mapped?(@obj)
          TkWinfo.width(@obj) if TkWinfo.manager(@obj)=='place'
        else
          TkWinfo.reqwidth(@obj) if TkWinfo.manager(@obj)=='place'
        end
       },
      'set'=> proc{|w| @obj.place('width'=>w)},
      'def'=> proc{|x| "'width'=>#{x}"}
    )

    publish('place','name'=>'height',
      'get'=> proc{if TkWinfo.mapped?(@obj)
          TkWinfo.height(@obj)  if TkWinfo.manager(@obj)=='place'
        else
          TkWinfo.reqheight(@obj)  if TkWinfo.manager(@obj)=='place'
        end
      },
      'set'=> proc{|h| @obj.place('height'=>h);@props['place']['height']['value'] = h},
      'def'=> proc{|x| "'height'=> #{x}"}
    )

    publish('place','name'=>'relx',
      'get'=> proc{TkPlace.info(@obj)['relx'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|x| @obj.place('relx'=>x);@props['place']['relx']['value'] = x},
      'def'=> proc{|x| "'relx'=> #{x}"},
      'value'=> 0,
      'default'=> 0
    )
    
    publish('place','name'=>'rely',
      'get'=> proc{TkPlace.info(@obj)['rely'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|x| @obj.place('rely'=>x);@props['place']['rely']['value'] = x},
      'def'=> proc{|x| "'rely'=> #{x}"},
      'value'=> 0,
      'default'=> 0
    )

    publish('place','name'=>'relheight',
      'get'=> proc{TkPlace.info(@obj)['relheight'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|x| @obj.place('relheight'=>x);@props['place']['relheight']['value'] = x},
      'def'=> proc{|x| "'relheight'=> #{x}"},
      'value'=> 0,
      'default'=> ''
    )

    publish('place','name'=>'relwidth',
      'get'=> proc{TkPlace.info(@obj)['relwidth'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|x| @obj.place('relwidth'=>x);@props['place']['relwidth']['value'] = x},
      'def'=> proc{|x| "'relwidth'=> #{x}"},
      'value'=> 0,
      'default'=> ''
    )
    
    publish('place','name'=>'bordermode',
      'get'=> proc{TkPlace.info(@obj)['bordermode'] if TkWinfo.manager(@obj)=='place'},
      'set'=> proc{|x| @obj.place('bordermode'=>x);@props['place']['bordermode']['value'] = x},
      'def'=> proc{|x| "'bordermode'=> #{x}"},
      'default'=> 'inside',
      'type'=> EnumType.new('inside','outside','ignore')
    )
#  +-----------------------------------+
#  |						       pack               |
#  +-----------------------------------+

    publish_def('pack',
      'before'=>'pack(',
      'sep'=>',',
      'after'=>')',
      'default'=>proc{|name,x| "'#{name}'=> #{x}"}
    )
    
    publish('pack','name'=>'anchor',
      'get'=> proc{TkPack.info(@obj)['anchor'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|a| @obj.pack('anchor'=>a)},
      'def'=> proc{|x| "'anchor'=> #{x}"},
      'type'=> TkType::TkagAnchor
    )

    publish('pack','name'=>'fill',
      'get'=> proc{TkPack.info(@obj)['fill'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|a| @obj.pack('fill'=>a)},
      'def'=> proc{|x| "'fill'=> #{x}"},
      'type'=> EnumType.new('none','x','y','both')
    )

    publish('pack','name'=>'ipadx',
      'get'=> proc{TkPack.info(@obj)['ipadx'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|x| @obj.pack('ipadx'=>x)},
      'def'=> proc{|x| "'ipadx'=> #{x}"}
    )

    publish('pack','name'=>'ipady',
      'get'=> proc{TkPack.info(@obj)['ipady'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|x| @obj.pack('ipady'=>x)},
      'def'=> proc{|x| "'ipady'=> #{x}"}
    )

    publish('pack','name'=>'expand',
      'get'=> proc{TkPack.info(@obj)['expand'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|x| @obj.pack('expand'=>x)},
      'def'=> '',
      'type'=> EnumType.new('yes','no')
    )

    publish('pack','name'=>'side',
      'get'=> proc{TkPack.info(@obj)['side'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|x| @obj.pack('side'=>x)},
      'def'=> '',
      'type'=> EnumType.new('left', 'right', 'top','bottom')
    )
    
    publish('pack','name'=>'padx',
      'get'=> proc{TkPack.info(@obj)['padx'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|x| @obj.pack('padx'=>x)},
      'def'=> ''
    )
    
    publish('pack','name'=>'pady',
      'get'=> proc{TkPack.info(@obj)['pady'] if TkWinfo.manager(@obj)=='pack'},
      'set'=> proc{|y| @obj.pack('padx'=>y)},
      'def'=> ''
    )
#  +-----------------------------------+
#  |						      grid                |
#  +-----------------------------------+

    publish_def('grid',
      'before'=>'grid(',
      'sep'=>',',
      'after'=>')'
    )

    publish('grid','name'=>'column',
      'get'=> proc{TkGrid.info(@obj)['column'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('column'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'row',
      'get'=> proc{TkGrid.info(@obj)['row'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('row'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'columnspan',
      'get'=> proc{TkGrid.info(@obj)['columnspan'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('columnspan'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'rowspan',
      'get'=> proc{TkGrid.info(@obj)['rowspan'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('rowspan'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'padx',
      'get'=> proc{TkGrid.info(@obj)['padx'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('padx'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'pady',
      'get'=> proc{TkGrid.info(@obj)['pady'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('pady'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'ipadx',
      'get'=> proc{TkGrid.info(@obj)['ipadx'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('ipadx'=>y)},
      'def'=> ''
    )

    publish('grid','name'=>'ipady',
      'get'=> proc{TkGrid.info(@obj)['ipady'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('ipady'=>y)},
      'def'=> ''
    )
    
    publish('grid','name'=>'in',
      'get'=> proc{TkGrid.info(@obj)['in'] if TkWinfo.manager(@obj)=='grid'},
      'set'=> proc{|y| @obj.grid('in'=>y)},
      'def'=> ''
    )

#  +-----------------------------------+
#  |							 binding                |
#  +-----------------------------------+

    @persistent_proc = proc{|url,value|
      if @persistent['prog'] == nil
        @persistent['prog'] = 0
      end
      if @persistent[url] == nil
        @persistent[url] = Array.new
      end
      @persistent[url][@persistent['prog']]=value
    }
    
    publish('bind','name'=>'event',
      'get'=>proc{@persistent['events'][@persistent['prog']] if @persistent['events'] != nil},
      'set'=>proc{|v| @persistent_proc.call('events',v)},
      'def'=>proc{|x| "#{x}"}
    )
    
    publish('bind','name'=>'handler',
      'get'=>proc{@persistent['procs'][@persistent['prog']] if @persistent['procs'] != nil},
      'set'=>proc{|v| @persistent_proc.call('procs',v)},
      'def'=>proc{|x| "proc{#{x}}"},
      'def_string'=>false
    )
    
    publish_def('bind',
      'path'=>'',
      'before'=>'bind(',
      'after'=>')',
      'sep'=>',',
      'default'=>proc{|name,x| "#{x}"}
    )
  end

end
#-----------------------------------------------------------------

class AGTkBase < AGTkLayoutManaged
  def properties
    super
    publish('property',TkProperties::background(@obj))
  end
end

class AGTkBaseContainer < AGTkLayoutManaged
  attr_reader :where_x, :where_y
  def initialize(_ag_parent, _object = nil)
    super(_ag_parent, _object)
    p1 = proc{|e|
      @where_x = e.x
      @where_y = e.y
      #$arcadia.objects('objic').activate(@object_inspector) if @object_inspector != $arcadia.objects('objic').active
      PaletteContract.instance.make_selected(self, 'parent'=>self)
    }
    @obj.bind_append("ButtonRelease-1", p1)

  end
  def properties
    super
    publish('property',TkProperties::background(@obj))
  end
end

class AGTkContainer < AGTkBaseContainer
  def AGTkContainer.class_sniffer
    AGTkCompositeSniffer
  end
end


class AGTkToplevel < AGTkContainer

  def initialize(_ag_parent=nil, _object = nil)
    super(_ag_parent, _object)

    @l_manager.util_bind
  end
  
  def AGTkToplevel.class_wrapped
    TkToplevel
  end
  
  def form2code
    _title = @i_name+'.rb'
    _text = @renderer.class_code.flatten.join
    
    Arcadia.process_event(OpenBufferEvent.new(self,'title'=>_title, 'text'=>_text))
    meditor = $arcadia['editor']
    if meditor
      _editor = meditor.raised
      code2form = proc{
        Revparsel.new(_editor.text_value)
        meditor.close_editor(_editor, true)
        InspectorContract.instance.raise_last_widget(meditor)
      }
      _editor.insert_popup_menu_item('end',
        :command,
        :label=>'View as form',
        :hidemargin => false,
        :command=> code2form
      )
    end
    
    #EditorContract.instance.open_text(self, 'title'=>_title, 'text'=>_text)
    self.delete
  end

  def keep_me
    $arcadia['buffers.code.in_memory'][@i_name]=@renderer.class_code.to_s
    self.delete
  end

  def popup_items(_popup_menu)
    super(_popup_menu)
    _popup_menu.insert('end',
      :command,
      :label=>'View as code',
      :hidemargin => false,
      :command=> proc{form2code}
    )
  end



  def on_close_query
    ans = Tk.messageBox('icon' => 'question', 'type' => 'yesnocancel',
      'title' => 'Exit', 'parent' => @obj,
      'message' => "Do you want shift to code view?")
      
    if ans =='yes'
      form2code
    elsif ans =='no'
        keep_me
    end
  end
  
  def set_obj_exit_protocol
    @obj.protocol( "WM_DELETE_WINDOW", proc{on_close_query})
  end
  
  def new_object
    super
    set_obj_exit_protocol
  end


  def passed_object(_obj)
    super(_obj)
    set_obj_exit_protocol
  end
  
  def rewind_by_property(_name, _val)
    msg = "To modify "+_name+" must create new Toplevel: do you want to procede ?"
    if Tk.messageBox('icon' => 'warning', 'type' => 'okcancel',
      'title' => '(Arcadia) '+_name, 'message' => msg) == 'cancel'
      return
    end
    _rewind_code = @renderer.class_code(2,_name=> _val).to_s
    begin
      Revparsel.new(_rewind_code)
      #$arcadia.objects('objic').del(@object_inspector)
    rescue => exc
      _editor = $arcadia.objects('editor').open_tab(@i_name)
      _editor.text_insert('end', _rewind_code)
      raise
    end 
  end

  def properties
    super
    publish_mod('layout_man','name'=>'manager',
      'default'=> 'none',
      'get'=> proc{'none'},
      'set'=> proc{},
      'def'=> proc{""},
      'type'=> ''
    )
    publish_del('place')
    publish_del('pack')
    publish_del('property','state')
    publish('property','name'=>'geometry',
      'get'=> proc{ TkWinfo.geometry(@obj)},
      'set'=> proc{|g|  Tk.tk_call('wm', 'geometry', @obj, g )},
      'def'=> proc{|x| "Tk.tk_call('wm', 'geometry', self, #{x} )"},
      'start'=> '245x180+300+230'
    )
    publish('property','name'=>'icon',
      'get'=> proc{Tk.tk_call('wm', 'iconbitmap', @obj, nil)},
      'set'=> proc{|i|  Tk.tk_call('wm', 'iconbitmap', @obj, i )},
      'def'=> proc{|x| "Tk.tk_call('wm', 'iconbitmap', self, #{x} )"},
      'type'=> TkType::TkagFile
    )
    publish('property','name'=>'title',
      'get'=> proc{ Tk.tk_call('wm', 'title', @obj)},
      'set'=> proc{|t|  Tk.tk_call('wm', 'title', @obj, t )},
      'def'=> proc{|x| "Tk.tk_call('wm', 'title', self, #{x} )"},
      'start'=>'...hello'
    )
    publish('property',TkProperties::container(@obj))
    publish('property',TkProperties::borderwidth(@obj))
    publish('property',TkProperties::cursor(@obj))
    publish('property',TkProperties::highlightbackground(@obj))
    publish('property',TkProperties::highlightcolor(@obj))
    publish('property',TkProperties::highlightthickness(@obj))
    publish('property',TkProperties::relief(@obj))
    publish('property',TkProperties::takefocus(@obj))
    publish('property',TkProperties::padx(@obj))
    publish('property',TkProperties::pady(@obj))
    publish('property',TkProperties::height(@obj))
    publish('property',TkProperties::width(@obj))
    publish('property','name'=>'class',
      'get'=> proc{@obj.cget('class')},
      'set'=> proc{ |r| rewind_by_property('class',r) },
      'kind'=>'on-create'
    )
    publish('property','name'=>'colormap',
      'get'=> proc{@obj.cget('colormap')},
      'set'=> proc{|t| @obj.configure('colormap'=>t)},
      'def'=> ""
    )

    publish('property','name'=>'menu',
      'get'=> proc{@obj.cget('menu')},
      'set'=> proc{|t| @obj.configure('menu'=>t)},
      'def'=> ""
    )
    
    publish('property','name'=>'screen',
      'get'=> proc{@obj.cget('screen')},
      'set'=> proc{|t| rewind_by_property('screen',t) },
      'def'=> "",
      'kind'=>'on-create'
    )

    publish('property','name'=>'use',
      'get'=> proc{@obj.cget('use')},
      'set'=> proc{ |r| rewind_by_property('use',r) },
      'kind'=>'on-create'
    )

    publish('property','name'=>'visual',
      'get'=> proc{@obj.cget('visual')},
      'set'=> proc{|r| rewind_by_property('visual',r) },
      'def'=> "",
      'kind'=>'on-create',
      'type'=> EnumType.new('','best', 'directcolor', 'grayscale','greyscale', 
        'pseudocolor', 'staticcolor', 'staticgray', 'staticgrey', 'truecolor', 'default')
    )

    publish('winfo','name'=>'server','get'=> proc{TkWinfo.server(@obj)}, 'def'=> 'nodef')
    publish('winfo','name'=>'screen','get'=> proc{TkWinfo.screen(@obj)}, 'def'=> 'nodef')

  end

  def get_implementation_new #overloaded
    result = '@',@i_name,' = ', getInstanceClass ,".new\n"
    result = result,'@', @i_ag," = ",self.class, '.new(nil,','@',@i_name,", $arcadia.objects('objic').create(",
    "self,'", $arcadia.objects('objic').active.filename,"'))"
  end
end

class AGTkRoot < AGTkToplevel

  def AGTkRoot.class_wrapped
    TkRoot
  end
  
  def new_object
    AGTkToplevel.new_object
  end
  
end
  
class AGTkFrame < AGTkContainer
  
  def AGTkFrame.class_wrapped
    TkFrame
  end
  
  def properties
    super
    publish('property',TkProperties::borderwidth(@obj))
    publish('property',TkProperties::cursor(@obj))
    publish('property',TkProperties::highlightbackground(@obj))
    publish('property',TkProperties::highlightcolor(@obj))
    publish('property',TkProperties::highlightthickness(@obj))
    publish('property',TkProperties::relief(@obj))
    publish('property',TkProperties::takefocus(@obj))
    publish('property',TkProperties::class(@obj))
    publish('property',TkProperties::colormap(@obj))
    publish('property',TkProperties::padx(@obj))
    publish('property',TkProperties::pady(@obj))
    publish('property',TkProperties::container(@obj))
    publish('property',TkProperties::border(@obj))
    publish('property',TkProperties::height(@obj))
    publish('property',TkProperties::width(@obj))
    publish_mod('place','name'=>'width', 'default'=> 200)
    publish('property','name'=>'visual',
      'get'=> proc{@obj.cget('visual')},
      'set'=> proc{|r| rewind_by_property('visual',r) },
      'def'=> "",
      'kind'=>'on-create',
      'type'=> EnumType.new('','best', 'directcolor', 'grayscale','greyscale', 
        'pseudocolor', 'staticcolor', 'staticgray', 'staticgrey', 'truecolor', 'default')
    )
  end

  def rewind_by_property(_name, _val)
    msg = "To modify "+_name+" must create new Toplevel: do you want to procede ?"
    if Tk.messageBox('icon' => 'warning', 'type' => 'okcancel',
      'title' => '(Arcadia) '+_name, 'message' => msg) == 'cancel'
      return
    end
    _rewind_code = @renderer.class_code(2,_name=> _val).to_s
    begin
      Tk.messageBox('message'=>_rewind_code)
      #@object_inspector.delete(self)
      #Revparsel.new(_rewind_code)
      
    rescue => exc
      _editor = $arcadia.objects('editor').open_tab(@i_name)
      _editor.text_insert('end', _rewind_code)
      raise
    end 
 end
  
end

class AGTkLabelFrame < AGTkFrame
  def AGTkLabelFrame.class_wrapped
    TkLabelFrame
  end
  
  def properties
    super
    publish('property',TkProperties::text(@obj))
    publish('property',TkProperties::labelanchor(@obj))
    publish('property',TkProperties::labelwidget(@obj))
  end
end


class AGTkLabel < AGTkContainer
  def AGTkLabel.class_wrapped
  TkLabel
  end
  
  def properties
    super
    publish('property',TkProperties::relief(@obj))
    publish('property',TkProperties::wraplength(@obj))
    publish('property',TkProperties::borderwidth(@obj))
    publish('property',TkProperties::activebackground(@obj))
    publish('property',TkProperties::activeforeground(@obj))
    publish('property',TkProperties::anchor(@obj))
    publish('property',TkProperties::background(@obj))
    publish('property',TkProperties::bitmap(@obj))
    publish('property',TkProperties::compound(@obj))
    publish('property',TkProperties::borderwidth(@obj))
    publish('property',TkProperties::cursor(@obj))
    publish('property',TkProperties::disabledforeground(@obj))
    publish('property',TkProperties::font(@obj))
    publish('property',TkProperties::foreground(@obj))
    publish('property',TkProperties::highlightbackground(@obj))
    publish('property',TkProperties::highlightcolor(@obj))
    publish('property',TkProperties::highlightthickness(@obj))
    publish('property',TkProperties::image(@obj))
    publish('property',TkProperties::justify(@obj))
    publish('property',TkProperties::padx(@obj))
    publish('property',TkProperties::pady(@obj))
    publish('property',TkProperties::takefocus(@obj))
    publish('property',TkProperties::text(@obj))
		publish('property',TkProperties::property('textvariable', @obj))
		publish('property',TkProperties::property('underline', @obj))
		publish('property',TkProperties::property('wraplength', @obj))
		publish('property',TkProperties::height(@obj))
		publish('property',TkProperties::state(@obj))
		publish('property',TkProperties::width(@obj))
      
  end

end

class AGTkButton < AGTkBase

  def AGTkButton.class_wrapped
    TkButton
  end
  
  def properties
    super()
    publish('property',TkProperties::relief(@obj))
    publish('property',TkProperties::overrelief(@obj))
    publish('property',TkProperties::foreground(@obj))
    publish('property',TkProperties::compound(@obj))
    publish('property',TkProperties::image(@obj))
    publish('property',TkProperties::font(@obj))
    publish('property',TkProperties::anchor(@obj))
    publish('property',TkProperties::padx(@obj))
    publish('property',TkProperties::pady(@obj))
    publish('property',TkProperties::activebackground(@obj))
    publish('property',TkProperties::text(@obj))
    publish('property',TkProperties::activeforeground(@obj))
    publish('property',TkProperties::borderwidth(@obj))
    publish('property','name'=>'justify',
      'get'=> proc{@obj.cget('justify')},
      'set'=> proc{|j| @obj.configure('justify'=>j)},
      'def'=> "",
      'type'=> TkType::TkagJustify
    )
    publish('property','name'=>'default',
      'get'=> proc{@obj.cget('default')},
      'set'=> proc{|j| @obj.configure('default'=>j)},
      'def'=> "",
      'type'=> TkType::TkagState
    )
  end
end

class AGTkCheckButton < AGTkBase
  def AGTkCheckButton.class_wrapped
    TkCheckButton
  end
  
  def properties
    super()
    publish('property','name'=>'relief',
      'get'=> proc{@obj.cget('relief')},
      'set'=> proc{|r| @obj.configure('relief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    )
    
    publish('property','name'=>'text',
      'default'=> @i_name,
      'get'=> proc{@obj.cget('text')},
      'set'=> proc{|t| @obj.configure('text'=>t)},
      'def'=> ""
    )
    publish('property','name'=>'justify',
      'get'=> proc{@obj.cget('justify')},
      'set'=> proc{|j| @obj.configure('justify'=>j)},
      'def'=> "",
      'type'=> TkType::TkagJustify
    )
  end
end


class AGTkListbox < AGTkBase
  def AGTkListbox.class_wrapped
    TkListbox
  end
  
  def properties
    super()
    publish('property','name'=>'relief',
      'get'=> proc{@obj.cget('relief')},
      'set'=> proc{|r| @obj.configure('relief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    )
  end
end


class AGTkEntry < AGTkBase

  def AGTkEntry.class_wrapped
    TkEntry
  end
  
  def properties
    super()
    publish('property','name'=>'relief',
      'get'=> proc{@obj.cget('relief')},
      'set'=> proc{|r| @obj.configure('relief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    )
    publish('property','name'=>'text',
      'default'=> @i_name,
      'get'=> proc{@obj.cget('text')},
      'set'=> proc{|t| @obj.configure('text'=>t)},
      'def'=> ""
    )
    publish('property','name'=>'justify',
      'get'=> proc{@obj.cget('justify')},
      'set'=> proc{|j| @obj.configure('justify'=>j)},
      'def'=> "",
      'type'=> TkType::TkagJustify
    )
    publish('property','name'=>'value',
      'default'=> '',
      'get'=> proc{@obj.value},
      'set'=> proc{|t| @obj.value=t},
      'def'=> proc{|x| "self.value=#{x}"}
    )
  end
end

class AGTkText < AGTkContainer

  def AGTkText.class_wrapped
    TkText
  end
  
  def properties
    super()
    publish('property','name'=>'relief',
      'get'=> proc{@obj.cget('relief')},
      'set'=> proc{|r| @obj.configure('relief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    )

    publish('property','name'=>'exportselection',
      'get'=> proc{@obj.cget('exportselection')},
      'set'=> proc{|r| @obj.configure('exportselection'=>r)},
      'def'=> "",
      'type'=> TkType::TkagBool
    )

    publish('property','name'=>'setgrid',
    'get'=> proc{@obj.cget('setgrid')},
    'set'=> proc{|r| @obj.configure('setgrid'=>r)},
    'def'=> "",
    'type'=> TkType::TkagBool
    )

    publish('property','name'=>'autoseparators',
    'get'=> proc{@obj.cget('autoseparators')},
    'set'=> proc{|r| @obj.configure('autoseparators'=>r)},
    'def'=> "",
    'type'=> TkType::TkagBool
    )

    publish('property','name'=>'undo',
    'get'=> proc{@obj.cget('undo')},
    'set'=> proc{|r| @obj.configure('undo'=>r)},
    'def'=> "",
    'type'=> TkType::TkagBool
    )


    publish_mod('place','name'=>'width','default'=> 100)
    publish('property',TkProperties::yscrollcommand(@obj))
    publish('property',TkProperties::xscrollcommand(@obj))

#    publish('property',TkProperties::container(@obj))
    publish('property',TkProperties::borderwidth(@obj))
    publish('property',TkProperties::cursor(@obj))
    publish('property',TkProperties::font(@obj))
    publish('property',TkProperties::foreground(@obj))
    publish('property',TkProperties::highlightbackground(@obj))
    publish('property',TkProperties::highlightcolor(@obj))
    publish('property',TkProperties::highlightthickness(@obj))

		publish('property',TkProperties::generic_color('insertbackground', @obj))
		publish('property',TkProperties::generic_color('selectbackground', @obj))
		publish('property',TkProperties::generic_color('selectforeground', @obj))

		publish('property',TkProperties::property('insertborderwidth', @obj))
		publish('property',TkProperties::property('insertofftime', @obj))
		publish('property',TkProperties::property('insertontime', @obj))
		publish('property',TkProperties::property('insertwidth', @obj))
		publish('property',TkProperties::property('selectborderwidth', @obj))
		publish('property',TkProperties::property('maxundo', @obj))
		publish('property',TkProperties::property('spacing1', @obj))
		publish('property',TkProperties::property('spacing2', @obj))
		publish('property',TkProperties::property('spacing3', @obj))
		publish('property',TkProperties::property('tabs', @obj))

    publish('property',TkProperties::relief(@obj))
    publish('property',TkProperties::takefocus(@obj))
    publish('property',TkProperties::padx(@obj))
    publish('property',TkProperties::pady(@obj))
    publish('property',TkProperties::height(@obj))
    publish('property',TkProperties::width(@obj))
    publish('property',TkProperties::state(@obj))

    publish('property','name'=>'wrap',
      'get'=> proc{@obj.cget('wrap')},
      'set'=> proc{|r| @obj.configure('wrap'=>r)},
      'def'=> "",
      'type'=> EnumType.new('none', 'char', 'word')
    )
    
    
  end
end

class AGTkScrollbar < AGTkBase

  def AGTkScrollbar.class_wrapped
    TkScrollbar
  end
  
  def properties
    super()
    publish('property','name'=>'relief',
      'get'=> proc{@obj.cget('relief')},
      'set'=> proc{|r| @obj.configure('relief'=>r)},
      'def'=> "",
      'type'=> TkType::TkagRelief
    )
    publish('property','name'=>'orient',
      'get'=> proc{@obj.cget('orient')},
      'set'=> proc{|o| @obj.configure('orient'=>o)},
      'def'=> "",
      'type'=> TkType::TkagOrient
    )
  end
end

class AGTkMenuButton < AGTkButton
  
  def new_object
    @obj = TkMenuButton.new(@ag_parent.obj)
  end
  
  def AGTkMenuButton.class_wrapped
    TkMenuButton
  end
  
  def properties
    super()
  end
  
end


class AGTkMenu < AG

  def new_object
    if @ag_parent.obj.class == TkMenubar
      @obj=@ag_parent.obj.add_menu(['asdasd',0])
      $arcadia.outln(@obj.to_s)
    end
  end

  def AGTkMenu.class_wrapped
    TkMenu
  end
  
  def properties
    super()
  end

end

class AGTkMenubar < AGTkContainer
  
  def new_object
    @obj = TkMenubar.new(@ag_parent.obj)
  end
  
  def AGTkMenubar.class_wrapped
    TkMenubar
  end
  
  def properties
    super()
  end
  
end

class AGTkScale < AGTkBase
  def AGTkScale.class_wrapped
    TkScale
  end
  
  def properties
    super
    publish('property',TkProperties::activebackground(@obj))
    publish('property',TkProperties::borderwidth(@obj))
    publish('property',TkProperties::relief(@obj))
    publish('property',TkProperties::orient(@obj))
  end
end

class ArcadiaLibTk < ArcadiaLib
  def register_classes
    self.add_class(AGTkToplevel,true)
    self.add_class(AGTkFrame)
    self.add_class(AGTkLabelFrame)
    self.add_class(AGTkText)
    self.add_class(AGTkLabel)
    self.add_class(AGTkButton)
    self.add_class(AGTkCheckButton)
    self.add_class(AGTkListbox)
    self.add_class(AGTkEntry)
    self.add_class(AGTkScrollbar)
    self.add_class(AGTkScale)
    self.add_class(AGTkMenubar)
    self.add_class(AGTkMenu)
    self.add_class(AGTkMenuButton)
  end
end