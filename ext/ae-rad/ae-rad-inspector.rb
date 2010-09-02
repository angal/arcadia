#
#   ae-inspector.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'tk'
require "#{Dir.pwd}/lib/a-tkcommons"
require 'tkextlib/bwidget'
require "observer"

class TkTy
  attr_reader :agobj, :prop, :labelhost
  attr_writer :labelhost
  def free(_updatehost = false, _text = nil)
    if (defined? @propobj)&&(@propobj != nil)
      @propobj.destroy
      @propobj=nil
    end
    if _text
      @etextvalue = _text
    end
    if _updatehost and TkWinfo.exist?(@labelhost)
      @labelhost.configure('text' => @etextvalue) if defined? @labelhost
    end
  end
end

class TkReadOnly < TkTy
  def initialize(_label)
    @label = _label
    @color = @label.cget('foreground')
    @label.configure('foreground'=>'#919191')
  end

  def free(_updatehost = false, _text = nil)
    @label.configure('foreground'=>@color)
    super
  end
end


class TkStringType < TkTy

  def initialize(_host, _family, _agobj, _prop, _val = nil)
    @agobj = _agobj
    @prop = _prop
    @labelhost = _host
    @family = _family
    @etext = TkVariable.new(_host.cget('text'))
    @etextvalue = @etext.to_s
    @propobj = TkEntry.new(_host, Arcadia.style('edit').update({'textvariable'=>@etext})){
      #relief 'groove'
      #font $arcadia['conf']['inspectors.inspector.value.font']
      place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1, 'bordermode'=>'outside')
    }
    @propobj.bind("KeyRelease-F1", proc{do_update})
  end

  def setpropvalue(_value)
    @etext = _value
  end

  def do_update
    if @etextvalue != @etext.to_s
      @agobj.update_property(self, @family, @prop['name'],@etext.to_s)
      @etextvalue = @etext.to_s
    end
  end

  def free(_updatehost = true, _text = nil)
    do_update if (defined? @propobj)&&(@propobj != nil)
    super
  end

end

class TkProcType < TkStringType

  def initialize(_host,  _family, _agobj, _prop)
    super(_host, _family, _agobj, _prop, true)
    @bProp = TkButton.new(@propobj, Arcadia.style('toolbarbutton')){
      text  '...'
      #relief  'flat'
      anchor  'e'
      padx  0
      pady  0
      #activebackground background
      #activeforeground 'red'
      #borderwidth 1
      pack('side' => 'right','fill' => 'y')
    }
    do_proc_update = proc{
      _pr = @prop['type'].procReturn
      $arcadia['objic.action.raise_active_obj'].call
      if _pr && (_pr.length > 0)
        @etext = _pr if _pr != ''
        do_update
        @propobj.value = @etext
      end
    }
    @propobj.bind("Double-1", do_proc_update)
    @bProp.bind("ButtonRelease-1", do_proc_update)
  end

end

class TkEnumType < TkTy

  def initialize(_host, _family, _agobj, _prop, _editable = false)
    @agobj = _agobj
    @prop = _prop
    @labelhost = _host
    @family = _family
    @bool = _prop['type'].values[0].class.to_s == 'TrueClass'
    if @bool
      do_update = proc{
        @etextvalue = @propobj.cget('text')
        @agobj.update_property(self, @family, @prop['name'], source_to_bool(@etextvalue))
        $arcadia['objic.action.raise_active_obj'].call
      }
      _values = []
      _prop['type'].values.each{|value|
        _values << bool_to_string(value)
      }
      #Tk.messageBox('message'=>_values.to_s)
    else
      do_update = proc{ 
        #Tk.messageBox('message'=>'sasda')
        @etextvalue = @propobj.cget('text')
        @agobj.update_property(self, @family, @prop['name'], @etextvalue)
        $arcadia['objic.action.raise_active_obj'].call
      }
      _values = _prop['type'].values
      #Tk.messageBox('message'=>_values.class.to_s)
    end
    @propobj = Tk::BWidget::ComboBox.new(_host, Arcadia.style('combobox')){
      values  _values
      modifycmd do_update
      editable _editable
      place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1, 'bordermode'=>'outside')
      def e
        TkWinfo.children(self)[0]
      end
      def b
        TkWinfo.children(self)[1]
      end
    }
    setpropvalue(@prop['get'].call.to_s)
  end

  def bool_to_string(_source)
    if _source
      return 'true'
    else
      return 'false'
    end
  end

  def source_to_bool(_source)
    _source = _source.to_s
    if (_source == '1') or (_source == 'true')
      return true
    else
      return false
    end
  end

  def setpropvalue(_value)
    #Tk.messageBox('message'=>'dip')
    _index = @prop['type'].values.index(_value)
    if _index != nil
      @propobj.set_value(_index)
    else
      @propobj.e.insert( 0, _value)
    end
    @etextvalue = _value
  end
end



class TkEnumProcType < TkEnumType

  def initialize(_host,  _family, _agobj, _prop)
    super(_host, _family, _agobj, _prop, true)
    @bProp = TkButton.new(@propobj.e, Arcadia.style('toolbarbutton')){
      text  '...'
      #relief  'flat'
      anchor  'e'
      padx  0
      pady  0
      #activebackground background
      #activeforeground 'red'
      #borderwidth 1
      pack('side' => 'right','fill' => 'y')
    }
    do_proc_update = proc{
      _pr = @prop['type'].procReturn
      $arcadia['objic.action.raise_active_obj'].call
      @etextvalue = _pr if _pr != ''
      @agobj.update_property(self, _family, @prop['name'], @etextvalue)
      @propobj.configure('text'=>@etextvalue)
    }
    @propobj.e.bind("Double-1", do_proc_update)
    @bProp.bind("ButtonRelease-1", do_proc_update)
  end

  def do_update
    if @etextvalue != @propobj.cget('text')
      @etextvalue = @propobj.cget('text')
      @agobj.update_property(self, @family, @prop['name'], @etextvalue)
    end
  end

  def free(_updatehost=true, _text=nil)
    do_update if (defined? @propobj)&&(@propobj != nil)
    super
  end
end

#class PTkEntryButton
#
#  def initialize(_host, _agobj, _prop)
#    do_update = proc{
#      @etextvalue = @prop['type'].procReturn
#      @agobj.updatep(@prop['name'], @etextvalue)
#      @propobj.configure('text'=>@etextvalue, 'background'=>@etextvalue)
#    }
#    @button = TkButton.new(_host){
#      text '...'
#      font $arcadia['conf']['inspectors.inspector.value.font']
#      place('x' => 20 ,'relheight'=>1, 'relwidth'=>0.5, 'bordermode'=>'outside', 'anchor'=>'e')
#    }
#    @etext = TkVariable.new(_prop['get'].call.to_s)
#    @entry = TkEntry.new(_host, 'textvariable'=>@etext){
#      relief 'groove'
#      font $arcadia['conf']['inspectors.inspector.value.font']
#      place('relheight'=>1, 'relwidth'=>0.5, 'bordermode'=>'outside')
#    }
#  end
#
#  def setpropvalue(_value)
#    @propobj.configure('text'=>_value)
#    @etextvalue = _value
#  end
#
#  def destroy
#    @entry.destroy
#    @etext.destroy
#    @button.destroy
#  end
#
#end

class ValueRap
  attr_reader :labelvalue, :handlervalue
  attr_reader :labelkey
  def initialize(_parent, _prop, _text = nil)
    @parent = _parent;
    #@host = _parent.pwind.right_frame
    #Tk.messageBox('message'=>_prop)
    @agobj = _parent.agobj
    @family = _parent.family
    @prop = _prop
    if _text == nil
      _text = _prop['get'].call.to_s
    end
    @text = _text
    if !defined? @parent.lasthandlervalue
      @parent.lasthandlervalue = 0
    end
    @labelkey = TkLabel.new(@parent.right_text,Arcadia.style('label').update({
    'text' => _text,
    'justify' => 'right',
    'anchor' => 'w',
    #'width'=>15,
    #'font'=> $arcadia['conf']['inspectors.inspector.value.font'],
    'borderwidth'=>'1',
    'relief'=>'groove'
    }))
    
    TkTextWindow.new(@parent.right_text, 'end', 'window'=> @labelkey)

    @labelkey.pack('fill'=>'x',:padx=>0, :pady=>0)
    
    @parent.right_text.insert('end',"\n")
    
    
    @labelkey.bind("ButtonPress-1", proc{
      if @prop['set'] != nil
        do_manage(@prop['type'].class.to_s)
      else
        do_manage('ReadOnly')
      end
    })
  end
  
  def reset_last
    @parent.lasthandlervalue = 0
  end

  def free
    _reset_last = @handlervalue == @parent.lasthandlervalue
    @labelkey.destroy if defined? @labelkey
    @handlervalue.free if @handlervalue == @parent.lasthandlervalue
    @parent.lasthandlervalue = 0 if _reset_last
  end

  def recicle(_family, _agobj, _prop)
    @agobj = _agobj
    @family = _family
    @prop = _prop
    if _prop['value'] != nil
      @text = _prop['value']
    else
      @text = _prop['get'].call.to_s
    end
    @parent.lasthandlervalue = 0 if @parent.lasthandlervalue == @handlervalue
    @handlervalue.free(false,@text) if defined? @handlervalue
    @labelkey.configure('text' => @text)
  end

  def updatevalue(_text)
    @labelkey.configure('text'=>_text)
    @text = _text
  end

  def do_manage(_type)
    if @parent.lasthandlervalue != 0
      @parent.lasthandlervalue.free(defined? @labelkey)
    end
    case _type
    when 'EnumType'
      @handlervalue = TkEnumType.new(@labelkey, @family, @agobj, @prop)
    when 'ProcType'
      @handlervalue = TkProcType.new(@labelkey, @family, @agobj, @prop)
    when 'StringType'
      @handlervalue = TkStringType.new(@labelkey, @family, @agobj, @prop)
    when 'EnumProcType'
      @handlervalue = TkEnumProcType.new(@labelkey, @family, @agobj, @prop)
    when 'ReadOnly'
      @handlervalue = TkReadOnly.new(@labelkey)
    else
      @handlervalue = TkStringType.new(@labelkey, @family, @agobj, @prop)
    end
    @parent.lasthandlervalue = @handlervalue
  end

end

class PropLine
  attr_reader :valueobj
  def initialize(_parent, _name, _prop)
    @parent = _parent
    @prop = _prop
    
    @propkey = TkLabel.new(@parent.left_text, Arcadia.style('label')){
      text _name
      justify 'right'
      anchor 'w'
      borderwidth '1'
      relief 'groove'
    }
    
    TkTextWindow.new(@parent.left_text, 'end', 'window'=> @propkey)
    @propkey.pack('fill'=>'x',:padx=>0, :pady=>0)
    @parent.left_text.insert('end',"\n")
    if !defined? _prop['type']
      _prop['type'] = 'StringType'
    end
    @valueobj = ValueRap.new(@parent, @prop)
  end

  def free
    @propkey.destroy if @propkey !=nil
    @valueobj.free if @valueobj !=nil
    @valueobj = nil
    @parent.left_text.delete('end -1 lines linestart','end')
    @parent.right_text.delete('end -1 lines linestart','end')
  end

  def setvalue(_value)
    @valueobj.updatevalue(_value)
  end

  def updatekeyvalue(_agobj, _name, _prop)
    @prop = _prop
    @propkey.configure('text'=>_name) # chiave
    @valueobj.recicle(@parent.family, _agobj, @prop)
  end

end


class ValueRapReadOnly
  attr_reader :labelvalue, :handlervalue
  def initialize(_parent, _text = nil)
    @parent = _parent;
    @host = _parent.splitted_frame.right_frame
    @text = _text
    if !defined? @parent.bodyprops.lasthandlervalue
      @parent.bodyprops.lasthandlervalue = 0
    end
    @labelkey = TkLabel.new(@host, Arcadia.style('label').update({
    'text' => _text,
    'justify' => 'right',
    'anchor' => 'w'
    }))
    @labelkey.pack('fill'=>'x',:padx=>0, :pady=>0)
    @labelkey.bind("ButtonPress-1", proc{
      do_manage_read_only
    })
  end

  def reset_last
    @parent.bodyprops.lasthandlervalue = 0
  end

  def free
    _reset_last = @handlervalue == @parent.bodyprops.lasthandlervalue
    @labelkey.destroy if defined? @labelkey
    @handlervalue.free if @handlervalue == @parent.bodyprops.lasthandlervalue
    @parent.bodyprops.lasthandlervalue = 0 if _reset_last
  end

  def recicle(_text)
    @text = _text
    @parent.bodyprops.lasthandlervalue = 0 if @parent.bodyprops.lasthandlervalue == @handlervalue
    @handlervalue.free(false,@text) if defined? @handlervalue
    @labelkey.configure('text' => @text)
  end

  def updatevalue(_text)
    @labelkey.configure('text'=>_text)
    @text = _text
  end

  def do_manage_read_only
    @handlervalue = TkReadOnly.new(@labelkey)
    @parent.bodyprops.lasthandlervalue = @handlervalue
  end

end

class PropLineReadOnly
  attr_reader :valueobj
  attr_reader :splitted_frame
  attr_reader :bodyprops
  def initialize(_bodyprops, _key, _value)
    @bodyprops = _bodyprops
    @key = _key
    @splitted_frame = AGTkVSplittedFrames.new(@bodyprops.host,@bodyprops.host, 85)
    @propkey = TkLabel.new(@splitted_frame.left_frame, Arcadia.style('label')){
      text _key
      justify 'right'
      anchor 'w'
      pack('fill'=>'x',:padx=>0, :pady=>0)
    }
    @valueobj = ValueRapReadOnly.new(self, _value)
  end

  def free
    @propkey.destroy if @propkey !=nil
    @valueobj.free if @valueobj !=nil
    @valueobj = nil
  end

  def setvalue(_value)
    @valueobj.updatevalue(_value)
  end

  def updatekeyvalue(_key, _value)
    @key = _key
    @propkey.configure('text'=>_key) # chiave
    @valueobj.recicle(_value)
  end

end


class InspectListReadOnly
  attr_reader :host
  attr_writer :lasthandlervalue
  attr_reader :lasthandlervalue

  def initialize(_host, _left_width = 85)
    @lasthandlervalue = 0;
    @host = _host
    @proplines = Hash.new
  end

  def clear
    @proplines.values.each do | _value|
      _value.free
    end
    @lasthandlervalue = 0;
    @proplines.clear
  end

  def updatelines(_properties=nil)
    if _properties == nil
      clear
      return
    else
      @lasthandlervalue.free(false) if @lasthandlervalue != 0
      @lasthandlervalue = 0;
    end
    _propvalues = []
    @proplines.keys.sort.each{|key|
      _propvalues << @proplines[key]
    }
    @proplines.clear
    _inf = 0
    _sup = _propvalues.length
    @array_key = _properties.keys
    @array_key.sort.each do |key|
      if _inf < _sup  # reuse it
        _propvalues[_inf].updatekeyvalue(key, _properties[key])
        @proplines[key] = _propvalues[_inf]
        _inf = _inf.next
      else # create new
        @proplines[key] = PropLineReadOnly.new(self, key, _properties[key])
      end
    end
    if _sup > _inf
      _inf.upto(_sup -1 ) {|i|
        _propvalues[i].free
      }
    end
  end
  
  def modProp(_name, _newvalue)
    @proplines[_name].setvalue(_newvalue)
  end
  
  def delete
    @pwind.destroy
  end

end

class InspectList
  attr_reader :pwind, :agobj, :family
  attr_writer :lasthandlervalue, :family
  attr_reader :lasthandlervalue 
  attr_reader :left_text, :right_text
  def initialize(_family, _host, _left_width = 85, show_scrollbar=true)
    @lasthandlervalue = 0;
    @family = _family
    #@pwind = AGTkVSplittedFrames.new(_host,_left_width)
    if show_scrollbar
    #  @pwind.place('width' => -15)
      @bar = TkScrollbar.new(_host, Arcadia.style('scrollbar')).pack('side'=>'right', 'fill'=>'y')
    end
    @pwind = AGTkVSplittedFrames.new(_host,_host,_left_width)
    
    background = _host.cget('background')
    common_properties = {'relief'=>'flat','state'=>'disabled', 'borderwidth'=>0, 'background'=>background}
    @left_text = TkText.new(@pwind.left_frame, common_properties).pack('expand'=>'yes', 'fill'=>'both')
    @right_text = TkText.new(@pwind.right_frame, common_properties).pack('expand'=>'yes', 'fill'=>'both')
    
    @left_text.configure('selectbackground'=>@left_text.cget('background'))
		@right_text.configure('selectbackground'=>@right_text.cget('background'))

    if show_scrollbar
      @bar.command(proc { |*args|
       @left_text.yview(*args)
       @right_text.yview(*args)
      })
      @left_text.yscrollcommand(proc { |first, last|
         @bar.set(first, last)
      })
      @right_text.yscrollcommand(proc { |first, last|
         @bar.set(first, last)
      })
    end
    @right_text.bind("Configure", 
    		proc{
            new_width = new_right_width
            if new_width
              @proplines.values.each do | _value|
                _value.valueobj.labelkey.configure('width'=>(new_width))
              end
            end
    					
    					},"%w")
    @proplines = Hash.new
  end

	def new_right_width
	  new_width = 0
		font_size = TkFont.new(@right_text.cget('font')).size
    w=TkPlace.info(@pwind.right_frame)['width']
    dw = TkPlace.info(@pwind.left_frame)['width']
    p = @pwind
    while p != nil && !p.kind_of?(AGTkVSplittedFrames) || p == @pwind
      p= TkWinfo.parent(p)
    end 
    if p
      dwp = TkPlace.info(p.left_frame)['width']
      new_width = ((dwp+w)/(font_size-2)).round
		end
		return new_width
	end
 
  def clear
    @proplines.values.each do | _value|
      _value.free
    end
    @lasthandlervalue = 0;
    @proplines.clear
  end

  def updatelines(_agobj, _properties=nil)
    @left_text.configure('state'=>'normal')             
    @right_text.configure('state'=>'normal')             
    if _properties == nil
      clear
      return
    else
      @lasthandlervalue.free(false) if @lasthandlervalue != 0
      @lasthandlervalue = 0;
    end
    @agobj = _agobj
    _propvalues = []
    @proplines.keys.sort.each{|key|
      _propvalues << @proplines[key]
    }
    @proplines.clear
    _inf = 0
    _sup = _propvalues.length
    @array_key = _properties.keys
    @array_key.sort.each do |key|
      if _inf < _sup # reuse it
        _propvalues[_inf].updatekeyvalue(@agobj, key, _properties[key])
        @proplines[key] = _propvalues[_inf]
        _inf = _inf.next
      else # create new
        #Tk.messageBox('message'=>key)
        @proplines[key] = PropLine.new(self, key, _properties[key])
        @proplines[key].valueobj.labelkey.configure('width'=>(new_right_width)) 
      end
    end
    if _sup > _inf
      _inf.upto(_sup -1 ) {|i|
        _propvalues[i].free
      }
    end
    @left_text.configure('state'=>'disabled')             
    @right_text.configure('state'=>'disabled')             
  end

  def modProp(_name, _newvalue)
    @proplines[_name].setvalue(_newvalue)
  end
  def delete
    @pwind.destroy
  end
end

class  InnerFrameInspectMultiList < TkFrame
  attr_reader :lTitle
  attr_reader :tkFrameHost
  attr_reader :index
  def initialize(_parent, _index,_contr=nil)
    super(_parent, Arcadia.style('panel'))
    @index = _index
    #borderwidth  2
    #relief  'groove'
    pack('side' => 'top',
    'anchor' => 'n',
    'expand' => 0,
    'ipady' => 40,
    'fill' => 'x')
    _self = self
    bind('Enter', proc{ _contr.set_current(_index)})
    @lTitle = TkLabel.new(self, Arcadia.style('titlelabel')){
      text  '...'
      #background  '#494949'
      place('relwidth' => '1',
      'x' => 0,
      'y' => 0,
      'height' => 19)

      @tkButtonX = TkButton.new(self, Arcadia.style('button')){
        text  'X'
        pack('side' => 'top',
        'anchor' => 'e')
        bind('ButtonPress-1',proc{_contr.del_event(_self, _index)})
      }
      class << self
        attr_reader :tkButton2
      end
    }

    @tkFrameHost = TkFrame.new(self, Arcadia.style('panel')){
      borderwidth  2
      #relief  'groove'
      place('relwidth' => '1',
      'x' => 0,
      'y' => 19,
      'relheight' => '1',
      'height' => -19)
    }
  end
end


class InspectMultiList
  def initialize(_family, _host)
    _contr = self
    @family = _family
    @itemCount = 0
    @tkFrame1 = TkFrame.new(_host, Arcadia.style('panel')){
      #borderwidth  2
      #relief  'groove'
      place(
      'relwidth' => '1',
      'x' => 0,
      'y' => 0,
      'height' => 30
      )
      @tkButton1 = TkButton.new(self, Arcadia.style('button')){
        text  'New'
        padx  0
        pady  0
        #relief  'groove'
        place(
        'x' => 2,
        'y' => 2,
        'height' => 21,
        'width' => 54
        )
        bind('ButtonPress-1',proc{_contr.add_event})
      }
      class << self
        attr_reader :tkButton1
      end
    }
    @tkFrame2 = TkFrame.new(_host, Arcadia.style('panel')){
      borderwidth  2
      #relief  'groove'
      place(
      'relwidth' => '1',
      'relheight' => '1',
      'height'=>-50,
      'x' => 0,
      'y' => 50
      )
    }
    @il = Hash.new
  end

  def add_event
    set_current(@itemCount)
    fi = InnerFrameInspectMultiList.new(@tkFrame2, @itemCount, self)
    @il[fi]=InspectList.new(@family, fi.tkFrameHost,30)
    @il[fi].updatelines(@agobj, @agobj.props[@family])
    @itemCount = @itemCount + 1
  end

  def del_event(_innerFrame, _item)
    if (@agobj.persistent != nil)
      @agobj.persistent['events'].delete_at(_item)
      @agobj.persistent['procs'].delete_at(_item) if @agobj.persistent['procs'] != nil
    end
    @itemCount = @itemCount - 1
    _innerFrame.destroy
    _innerFrame.callback_break
  end

  def set_current(_index)
    @itemIndex = _index
    if (@agobj.persistent['prog'] != nil)
      @agobj.persistent['prog']=@itemIndex
    end
  end

  def update(_agobj)
    @itemCount = 0
    @agobj = _agobj
    @il.each_key{|k|
      k.destroy
    }
    @il.clear
    if _agobj.persistent['events'] != nil
      _agobj.persistent['events'].each{|item|
        add_event
      }
    end
  end

end

class InspectEvents
  attr_reader :pbottom
  def initialize(_host, _agobj, _family)
    @hash_entity = _agobj.props[_family]
    @agobj = _agobj
    @family = _family
    @pmain = Tk::BWidget::PanedWindow.new(_host, 'side' => 'left', 'weights'=> 'available', 'width'=> 3){
      pack('fill'=>'both', :padx=>0, :pady=>0)
    }
    @ptop =  @pmain.add('weight'=>1)
    @pbottom =  @pmain.add('weight'=>2)
    @list = InspectList.new('evens', @ptop)
  end

  def add(_event,_mods,_handler)
  end

  def update(_agobj, _family)
    @hash_entity = _agobj.props[_family]
    @agobj = _agobj
    @family = _family
  end

end


class InspectTkEvents

  def initialize(_host, _agobj, _family)
    @hash_entity = _agobj.props[_family]
    @agobj = _agobj
    @family = _family
    @pmain = Tk::BWidget::PanedWindow.new(_host, 'side' => 'left', 'weights'=> 'available', 'width'=> 3){
      pack('fill'=>'both', :padx=>0, :pady=>0)
    }
    @ptop =  @pmain.add('weight'=>1)

    @pbottom =  @pmain.add('weight'=>2)

    list = TkListbox.new(@ptop){
      pack
    }
  end

  def add(_event,_mods,_handler)

  end
  def update(_agobj, _family)
    @hash_entity = _agobj.props[_family]
    @agobj = _agobj
    @family = _family
  end
end

class ObjList
  attr_reader :objects
  def initialize
    @objects = Array.new
  end
  def append(_o)
    @objects << _o
  end
end



class TkScrollbox<TkListbox
  include TkComposite
  def initialize_composite(keys=nil)
    list = TkListbox.new(@frame, Arcadia.style('edit'))
    scroll = TkScrollbar.new(@frame, Arcadia.style('scrollbar'))
    @path = list.path
    list.configure 'yscroll', scroll.path+" set"
    list.pack 'side'=>'left','fill'=>'both','expand'=>'yes'
    scroll.configure 'command', list.path+" yview"
    scroll.pack 'side'=>'right','fill'=>'y'
    delegate('DEFAULT', list)
    delegate('foreground', list)
    delegate('background', list, scroll)
    delegate('borderwidth', @frame)
    delegate('relief', @frame)
    configure keys if keys
  end
end

class ObjBoard
  attr_reader :objectsList
  def initialize(_host, _obji)
    @obji = _obji
    @objectsList = Array.new
    @count = 0
    @itemindex = -1
  end

  def get_string(_agobj)
    _agobj.i_name + '  [ < '+ _agobj.obj_class.to_s+' ]'
  end

  def delete(_agobj)
    @objectsList.delete(_agobj)
    @count = @count - 1
  end

  def insert(_agobj)
    @objectsList << _agobj
    @count = @count + 1
    @itemindex = @count - 1
  end

  def select(_agobj)
  end

#  def change_name(_agobj, _newname)
#    _agobj.i_name = _newname
#  end

end


class TkScrollboxObjBoard < ObjBoard

  def initialize(_host)
    super
    @sb = TkScrollbox.new(_host, Arcadia.style('edit')){
      width  200
      height 200
      pack('fill'=>'both', :padx=>0, :pady=>0)
    }
  end

  def delete(_agobj)
    super
    @sb.delete('active')
  end

  def insert(_agobj)
    super
    @sb.insert('end', _agobj.i_name)
  end

  def select(_agobj)
    super
    @sb.selection_clear(0, @sb.size - 1)
    for i in 0..@sb.size - 1
      if @sb.get(i) == _agobj.i_name.to_s
        @sb.selection_set(i)
        break
      end
    end
  end

end

class TkBwComboBoxObjBoard < ObjBoard

  def initialize(_host, _obji)
    super
    do_select = proc {
      _itemindex = @sb.cget('values').index(@sb.cget('text'))
      @obji.select(@objectsList[_itemindex])
      @objectsList[_itemindex].activate
    }
    @sb = Tk::BWidget::ComboBox.new(_host, Arcadia.style('combobox')){
      modifycmd do_select
      editable false
      expand 'tab'
      pack('fill'=>'x', 'padx'=>0, 'pady'=>0, 'anchor'=>'n')
    }
  end

  def delete(_agobj)
    super
    @sb.delete('active')
  end

  def getString(_agobj)
    _agobj.i_name + '<--'+ _agobj.obj.class.to_s
  end

  def insert(_agobj)
    super
    _values = @sb.cget('values').to_a
    _values << getString(_agobj)
    @sb.configure('values'=>_values)
    @sb.set_value(@itemindex)
  end

  def select(_agobj)
    super
    @itemindex = @sb.cget('values').index(getString(_agobj))
    @sb.set_value(@itemindex)
  end

end

class TkMenuButtonObjBoard < ObjBoard

  def initialize(_host, _obji)
    super
    @sb = TkMenubutton.new(Arcadia.style('menu').update({
    :parent=>_host,
    :underline=>0,
    :direction=>:flush,
    #:font=>$arcadia['conf']['inspectors.inspector.tree.font'],
    :relief=>:groove,
    :borderwidth=> '1',      

    #:background=> :white,
    :justify=> :left})){|mb|
      menu TkMenu.new(Arcadia.style('menu').update({
      :parent=>mb,
      :tearoff=>0
      #:font=>$arcadia['conf']['inspectors.inspector.tree.font'],
      #:background=> :white,:relief=>'flat'
      }))
      pack('fill'=>'x', 'padx'=>0, 'pady'=>0, 'anchor'=>'n')
    }
    @menu = @sb.cget('menu')
  end

  def delete(_agobj)
    super
    @menu.delete(getobjstring(_agobj))
  end

  def getobjstring(_agobj)
    _num = 0
    _result = _agobj.i_name
    _parent = _agobj.ag_parent
    while _parent != nil
      _result = ' - '+_result
      _parent = _parent.ag_parent
      _num = _num+1
    end
    _space = ''; _num.times do 
      _space = _space + '  ' 
    end
    if _agobj.ag_parent != nil 
      _result = _space + '|'+_result 
    end
    return _result
  end

  def change_name(_agobj, _newname)
    @menu.delete(getobjstring(_agobj))
    super
    insert_menu_item(_agobj)
  end

  def insert_menu_item(_agobj)
    _do_select = proc {
      @obji.select(_agobj)
      @sb.configure('text'=>get_string(_agobj))
    }
    if (!defined? _agobj.ag_parent)|| (_agobj.ag_parent == nil)
      _index = 0
    else
      _index = @menu.index(getobjstring(_agobj.ag_parent))
    end
    @menu.insert(_index + 1,
    :command,
    :label=>getobjstring(_agobj),
    :hidemargin => true,
    :accelerator => _agobj.obj_class.to_s,
    :command=>_do_select
    )
    @sb.configure('text'=>get_string(_agobj))
  end

  def insert(_agobj)
    super
    insert_menu_item(_agobj)
  end

  def select(_agobj)
    super
    @sb.configure('text'=>get_string(_agobj))
  end

end

class ObjiRenderer

  def initialize(_obji=nil)
    if _obji
      @obji = _obji
    else
      exit
    end
  end

  def code
    return codeBegin, codeHinnerBegin, codeHinnerEnd, codeEnd
  end

  def codeBegin
    code_rb = ''
    @obji.requires.each_key do |key|
      code_rb = code_rb, "require '",key,"'\n"
    end
    return code_rb
  end

  def codeHinnerBegin
  end

  def codeHinnerEnd
  end

  def codeEnd
    code_rb = code_rb, "\n", @obji.agobj_start.renderer.classCode
  end

end


class Obji
  include Observable
  attr :lb
  attr :tlb
  attr :active_object
  attr_reader :filename
  attr_writer :filename
  attr_reader :requires
  attr_reader :inspect_core
  attr_reader :editor
  attr_reader :agobj_start
  attr_reader :renderer

  def initialize(_frame, _controller, _agobj_start, _filename = nil)
    @agobj_start = _agobj_start
    @agobj_last = nil
    @controller = _controller
    @filename = _filename
    @frame = _frame
    @pmainwind = AGTkOSplittedFrames.new(@frame,@frame,20)
    @f_top =  @pmainwind.top_frame
    @f_bottom =  @pmainwind.bottom_frame
    @lb = TkMenuButtonObjBoard.new(@f_top, self)
    @ojts = Tk::BWidget::NoteBook.new(@f_bottom, Arcadia.style('tabpanel')){
      tabbevelsize 0
      internalborderwidth 0
      side $arcadia['conf']['inspectors.inspector.tabs.side']
      #font $arcadia['conf']['inspectors.inspector.tabs.font']
      pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
    }
    #@inspect_core = _agobj_start.class.class_inspector.new(@ojts, _agobj_start)
    @inspect_core = Inspector.iclass(_agobj_start.class).new(@ojts, _agobj_start)
    #@requires = Hash.new
    @renderer = @inspect_core.class.class_inspector_renderer.new(self)
    select(_agobj_start)
  end

  def free
    #@agobj_start.delete
    @inspect_core.clear
  end

  def change_name(_agobj, _newname)
    @lb.change_name(_agobj, _newname)
  end

	def raise_toplevel
	  @agobj_start.obj.raise
	end

  def active
    @controller.active
  end

#  def add_require(_require)
#    if @requires[_require] == nil
#      @requires[_require] = 1
#    else
#      @requires[_require] += 1
#    end
#  end

#  def del_require(_require)
#    @requires[_require] -= 1
#    if @requires[_require] == 0
#      @requires[_require] = nil
#    end
#  end

  def delete(_agobj)
    _agobj.obj.destroy if defined? _agobj.obj
    if _agobj==agobj_start
      @controller.del(self)
    else
      @lb.delete(_agobj)
      select(@lb.objectsList[@lb.objectsList.length - 1]) if @lb.objectsList.length > 0
    end
  end

  def activate
    @controller.activate(self)
  end

  def register(me)
    @lb.insert(me)
    @agobj_last = me
    return self
  end

  def select_last(_activate=true)
    #Tk.messageBox('message'=>'select last')
    if @agobj_last != nil
      select(@agobj_last, _activate)
    end
  end

  def select(me, _activate_me=true)
    return if @active_object == me
    me.activate #if _activate_me
    @active_object = me
    @inspect_core.recicle_inspects(me)
    @lb.select(me)
    changed
    notify_observers('SELECT', me)
  end

#  def objects2code
#    code_rb = ''
#    @requires.each_key do |key|
#      code_rb = code_rb, "require '",key,"'\n"
#    end
#    code_rb = code_rb, "\n", @inspect_core.objects2text(@lb.objectsList)
#  end

  def code2file(_objects_file = nil)
    @filename = _objects_file
    if !@filename
      exit
    end

    File.open(_objects_file, "w") do |aFile|
      aFile.print  @renderer.code
    end
  end

#  def saveObjectsCreationtoFile(_objects_file = 'sample\objects.rb')
#    @filename = _objects_file
#    code_rb = ''
#    code_rbd = ''
#    code_form = ''
#    code_form = code_form, "class ", File.basename(_objects_file, ".rb"),"\n"
#    code_rbd = code_rbd, "require '",_objects_file,"'\n"
#    @requires.each_key do |key|
#      code_rb = code_rb, "require '",key,"'\n"
#    end
#    @lb.objectsList.each{|object|
#      code_rb = code_rb, object.get_class_code
#      code_rbd = code_rbd,"\n", object.get_implementation_code
#    }
#    File.open(_objects_file, "w") do |aFile|
#      aFile.print code_rb
#    end
#    File.open(_objects_file+'d', "w") do |aFile|
#      aFile.print code_rbd
#    end
#  end

  def dumpObjectstoFile(_objects_file = 'sample\objects.rb')
    @filename = _objects_file
    File.open(_objects_file, "w") do |aFile|
      @lb.objectsList.each{|object|
        Marshal.dump(object.obj, aFile)
      }
    end
  end

end

class ObjiControllerView
  attr_reader :nb
  attr_reader :nb_base
  attr_reader :layout
  def initialize(_frame)
    @nb_base = Tk::BWidget::NoteBook.new(_frame, Arcadia.style('tabpanel')){
      tabbevelsize 0
      internalborderwidth 0
      side $arcadia['conf']['inspectors.tabs.side']
      #font $arcadia['conf']['inspectors.tabs.font']
      pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
    }
  end
end

class ObjiController #< ArcadiaExt

  attr_reader :active 

  def initialize(_rad)
    @rad = _rad
    ArcadiaContractListener.new(self, InspectorContract, :do_inspector_event)
    ArcadiaContractListener.new(self, WrapperContract, :do_wrapper_event)
    build
  end 

#	def on_before_build(_event)
#    ArcadiaContractListener.new(self, InspectorContract, :do_inspector_event)
#	  ArcadiaContractListener.new(self, WrapperContract, :do_wrapper_event)
#	end
  def frame
    @rad.frame(0)
  end

  def build
    #@main_frame = ObjiControllerView.new(self.frame)
    @objis = Hash.new
    @wrappers_obji = Hash.new
    @frames = Array.new
  end

	def do_wrapper_event(_event)
 	   obji = @wrappers_obji[_event.context.wrapper] if _event.context
     case _event.signature 
     		when WrapperContract::WRAPPER_AFTER_CREATE
     		  self.register(_event.context.wrapper)
     		when WrapperContract::PROPERTY_AFTER_UPDATE
     		  obji.inspect_core.update_property(_event.context.wrapper, _event.context.property_family, _event.context.property_name, _event.context.property_new_value)
     		  if (_event.context.property_family=='layout_man')
		       obji.inspect_core.tabs['Layout'].family=_event.context.property_new_value
		       obji.inspect_core.tabs['Layout'].updatelines(
		       		_event.context.wrapper, 
		       		_event.context.wrapper.props[_event.context.property_new_value]
		       )
     		  end
     		  
     end		
	end
  
  def main_frame
  		if !defined?(@main_frame) || @main_frame == nil
    		@main_frame = ObjiControllerView.new(self.frame.hinner_frame)
    end
    return @main_frame
  end
  
	def do_inspector_event(_event)
 	   obji = @wrappers_obji[_event.context.wrapper] if _event.context
 	   
     case _event.signature 
     		when InspectorContract::SELECT_WRAPPER
     		  obji.select(_event.context.wrapper, false)
     		when InspectorContract::DELETE_WRAPPER
   		    obji.delete(_event.context.wrapper)
     		when InspectorContract::DELETE_INSPECTOR  
     		  self.del(obji)
     		when InspectorContract::RAISE_ACTIVE_TOPLEVEL  
     		  self.active.raise_toplevel if active
     		when InspectorContract::RAISE_LAST_WIDGET  
     		  self.active.select_last(true) if active
     end
  end

	def register(_wrapper)
	  if _wrapper.ag_parent
	  	 obji = @wrappers_obji[_wrapper.ag_parent]
	  else
	    obji = self.new_obji(_wrapper)
	  end
	  if obji
	    obji.register(_wrapper) 

	    @wrappers_obji[_wrapper]=obji
	  end
	  @last_registred = _wrapper
	end

  def new_obji(_sender, _filename = nil)
    _fname = 'f'+@frames.length.to_s
    _frame = self.main_frame.nb_base.insert('end',_fname,'text'=>_sender.i_name)
    @frames << _frame

    _newobji = Obji.new(_frame, self, _sender, _filename)

    @objis[_newobji]=_fname

    activate(_newobji)

    #@arcadia.layout.raise_panel('_mosca_','Inspect')
    
    return _newobji
  end

  def del(_obji)
    _obji.free
    self.main_frame.nb_base.delete(@objis.delete(_obji))
    if @objis.length == 0
      @active = nil
      self.frame.free
      @main_frame = nil
    else
      activate(@objis.keys[@objis.length-1])
    end
  end

  def activate(me)
    @active = me
    self.main_frame.nb_base.raise(@objis[me])
  end

end


class ObjiThread
  attr_reader :oi

  def initialize(_filename = nil)
    @oi = Obji.new(_filename)
  end

  def initialize_in_osservazione
    t_obji = Thread.new {
      print ' Thread.current = ', Thread.current,"\n"
      Thread.current[:oi]= Obji.new
    }
    @oi = t_obji[:oi]
  end

end


#----- inspector core ------

class Inspector
  def Inspector.iclass(_wrapper_class)
    class_rif = _wrapper_class
    while @@i[class_rif] == nil
      class_rif = class_rif.superclass
    end
    return @@i[class_rif]
	end
	
  def Inspector.add_wrapper_class(_class)
 		if defined?(@@i)
 		  @@i[_class]=self  
 		else
 		  @@i = Hash.new
 		end
  end
end

class AGInspector < Inspector
  attr_reader :tabs

  def initialize(_host, _agobj)
    @@instance = self
    @tabs = Hash.new
    @code = Hash.new
    @ag_signature_obj = _agobj
    @ojts_p = _host.insert('end','props','text'=>'Properties')
    _host.raise('props')
    @tabs['Properties'] = InspectList.new('property', @ojts_p)
  end
	
	def AGInspector.instance
	  @@instance
	end
	
  def AGInspector.class_inspector_renderer
    ObjiRenderer
  end

  def recicle_inspects(_agobj)
    tabs['Properties'].updatelines(_agobj, _agobj.props['property'])
  end

  def update_property(obj, _fam, _name, _value)
    if _fam == 'property' 
      tabs['Properties'].modProp(_name, _value)
    end
  end

  def activate

  end

  def clear
    @tabs['Properties'].clear
  end
  
	add_wrapper_class AG
	
end

class AGTkInspector < AGInspector

  def initialize( _host, _agobj)
    super( _host, _agobj)
    @ojts_layout = _host.insert('end','layout','text'=>'Layout')
    @top_panel = TkFrame.new(@ojts_layout, Arcadia.style('panel')){
      place('x'=>0, 'y'=>0, 'relheight'=>1, 'relwidth'=>1)
    }
    @tabs['LayoutType'] = InspectList.new('layout_man', @top_panel,85,false)
    @mid_panel = TkFrame.new(@ojts_layout, Arcadia.style('panel')){
      place('x'=>0, 'y'=>20,'relheight'=>1, 'relwidth'=>1)
    }
    @tabs['Layout'] = InspectList.new('...',@mid_panel, 85)
    
    @ojts_winfo = _host.insert('end','winfo','text'=>'Winfo')
    @tabs['Winfo'] = InspectList.new('winfo', @ojts_winfo)
    
    
    #@ojts_bind = _host.insert('end','bind','text'=>'Binding')
    #@tabs['Binding'] =  InspectMultiList.new('bind',@ojts_bind)
  end

  def clear
    super
    @tabs['LayoutType'].clear
  end

  def recicle_inspects(_agobj)
    super(_agobj)
    if _agobj.props['layout_man'] != nil
      _fam = _agobj.props['layout_man']['manager']['get'].call
      @tabs['Layout'].family=_fam
      @tabs['Layout'].updatelines(_agobj, _agobj.props[_fam])
    end
    @tabs['LayoutType'].updatelines(_agobj, _agobj.props['layout_man'])
    @tabs['Winfo'].updatelines(_agobj, _agobj.props['winfo'])
    #@tabs['Binding'].update(_agobj)
  end

  def update_property(obj, _fam, _name, _value)
    if ['place','pack','grid'].include?(_fam)
      @tabs['Layout'].modProp(_name, _value)
    elsif ['layout_man'].include?(_fam)
      @tabs['LayoutType'].modProp(_name, _value)
    else
      super(obj, _fam, _name, _value)
    end
  end
  
 	add_wrapper_class AGTk


end


