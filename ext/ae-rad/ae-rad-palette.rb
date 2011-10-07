#
#   ae-palette.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "#{Dir.pwd}/ext/ae-rad/ae-rad-libs"
require "#{Dir.pwd}/ext/ae-rad/lib/tk/al-tk"
require 'tk'
require 'tkmenubar'
require 'tkextlib/bwidget'


class Palette #< ArcadiaExt
  attr_reader :buttons
  attr_reader :selected_wrapper  
  attr_reader :rad
  def initialize(_rad)
    @rad = _rad
    ArcadiaContractListener.new(self, InspectorContract, :do_inspector_event)
    ArcadiaContractListener.new(self, PaletteContract, :do_palette_event)
    build
  end 

#	def on_before_build(_event)
#	  ArcadiaContractListener.new(self, InspectorContract, :do_inspector_event)
#	  ArcadiaContractListener.new(self, PaletteContract, :do_palette_event)
#	end

  def build
    @buttons = Hash.new
    create_palettes
  end

  def on_after_build(_event)
  end
  
	def do_inspector_event(_event)
     case _event.signature 
     		when InspectorContract::SELECT_WRAPPER
				@selected_wrapper=_event.context.wrapper
     end  
  end  

  def do_palette_event(_event)
     case _event.signature 
     		when PaletteContract::MAKE_SELECTED_WRAPPER
     		  give_me_obj(_event.context.parent)
     end  
  end

  def eval_form_file(_filename)
    cod = '';
    IO.foreach(_filename) { |line| cod += line };
    Revparsel.new(cod, _filename)
  end


  def eval_file(_filename)
    cod = '';
    begin
      IO.foreach(_filename) { |line| cod += line }
    rescue SystemCallError
      handleException # defined elsewhere
    end
    eval(cod)
  end

  def create_palettes
    @cc = WrapperContainer.new(self){
      border 0
      borderwidth 1
    }
    @cc.pack('side' =>'left', 'fill' =>'both', 'anchor'=>'nw', :padx=>2, :pady=>2)
    @rad.libs.list.each{|lib|
      @cc.add_palette(lib)
    }
  end

  def give_me_obj(_owner)
    @cc.new_wrapper(_owner)
  end

  def give_me_code
    @cc.new_wrapper_code
  end

end

class WrapperContainer < TkFrame

  def initialize(_owner)
    
    super(_owner.rad.float_frame(0, 'x'=>10, 'y'=>10, 'width'=>200,'heigh'=>220).hinner_frame, Arcadia.style('panel'))
    @owner = _owner
    _self = self
    frame = TkFrame.new(self, Arcadia.style('panel')).pack('side' =>'left', 'anchor'=>'n', :padx=>2, :pady=>2)

    @button_u = Tk::BWidget::Button.new(frame, Arcadia.style('toolbarbutton') ){
      image  Arcadia.image_res(CURSOR_GIF)
      helptext 'Select'
      text 'C'
      #foreground 'blue'
      command proc{_self.unfill}
      #relief 'groove'
      pack('side' =>'top', 'anchor'=>'n',:padx=>2, :pady=>2)
    }
    @button_m = Tk::BWidget::Button.new(frame, Arcadia.style('toolbarbutton')){
      _command = proc{
        require 'tk/clipboard'
        _code = AG.active.renderer.class_code.to_s if AG.active
        TkClipboard::set(_code)
        eval(_code)
        _self.fill(
        self,
        _owner.selected_wrapper.class,
        nil,
        _owner.selected_wrapper.getInstanceClass
        )
        _self.new_wrapper if _owner.selected_wrapper.class.is_top

      }
      image  Arcadia.image_res(WIDGET_COPY_GIF)
      helptext 'Copy current selected'
      text 'C'
      #foreground 'blue'
      command _command
      #relief 'groove'
      pack('side' =>'left','anchor'=>'n', :padx=>2, :pady=>2)
    }
    @familyts = Tk::BWidget::NoteBook.new(self, Arcadia.style('tabpanel')){
      tabbevelsize 0
      internalborderwidth 1
      #activeforeground 'orange'
      #font $arcadia['conf']['main.font']
      pack('side' =>'left','expand'=>'yes','fill'=>'both', :padx=>2, :pady=>2)
    }
    @objCollections = Array.new
  end

  def new_wrapper_code
    _code = ''
    if @selected_button != nil && @selected_class_obj != nil
      #objiinfo = @owner.ae_inspector_talker.info
      #_code = objiinfo.active_wrapper.renderer.class_code.to_s
      _code = AG.active.renderer.class_code.to_s
      @selected_button.configure('relief'=>'groove')
      @selected_button = @selected_class = @selected_require = nil
    end
    return _code
  end


  def new_wrapper(_parent = nil, _obj = nil)
    if @selected_button == nil
      return
    end
    # copy obj
    if @selected_class_obj != nil && _obj == nil
      _obj = eval(@selected_class_obj).new(_parent == nil ?nil:_parent.obj)
    end
    
    w = @selected_class.new(_parent, _obj)
    #$arcadia['objic'].active.select_last(true) if @selected_class_obj != nil
    #$arcadia.objects('objic').active.addRequire(@selected_require) if @selected_require != nil
    
    
    w.select.activate if @selected_class_obj != nil
    w.add_require([@selected_require]) if @selected_require != nil
    
    @selected_button.configure('relief'=>'groove')
    @selected_button = @selected_class = @selected_require = nil
  end


  def fill(_b, _class, _require, _class_obj = nil)
    _b.configure('relief'=>'sunken')
    if  @selected_button != nil
      @selected_button.configure('relief'=>'groove')
    end
    @selected_button = _b
    @selected_class = _class
    @selected_require = _require
    @selected_class_obj = _class_obj
    @owner.rad.float_frame.title(_class.class_wrapped)
    #Arcadia.instance.layout.domain(Arcadia.instance['conf']['palette.frame'])['root'].top_text(_class.class_wrapped)

  end

  def unfill
    if  @selected_button != nil
      @selected_button.configure('relief'=>'groove')
    end
    @selected_button = nil
    @selected_class = nil
    @selected_require = nil
    @selected_class_obj = nil
    Arcadia.instance.layout.domain(Arcadia.instance['conf']['palette.frame'])['root'].top_text_clear
  end

  def add_palette(_lib_obj)
    _name = _lib_obj.arcadia_lib_params.name
    _file = _lib_obj.arcadia_lib_params.require
    _img = nil
    @objCollections << {
      'name'=>_name,
      'collection'=>_lib_obj,
      'file'=>_file,
      'img'=>_img
    }

    @classes_panel = @familyts.insert('end',_name,
    'text'=>_name#,
    )
    
    _background = @classes_panel.cget('background')

		@tpanel = TkText.new(@classes_panel){
		  relief 'flat'
		  background _background
		}.pack('side' =>'left', 'anchor'=>'nw', :padx=>2, :pady=>2)


    _lib_obj.classes.each{|value|
      _self = self
      _image = self.class_image(value)
      ewin = TkTextWindow.new(@tpanel, 'end',
      'window'=> Tk::BWidget::Button.new(@tpanel, Arcadia.style('toolbarbutton')){
        _command = proc{
          _self.fill(self, value, _file)
          _self.new_wrapper if value.is_top
        }
        text value.class_wrapped.to_s
        helptext  value.class_wrapped.to_s
        image Arcadia.image_res(_image)
        #foreground 'blue'
        command _command
        #font $arcadia['conf']['main.component.font']
        relief 'groove'
        height 25
        width 25
        #pack('side' =>'left', 'anchor'=>'nw', :padx=>2, :pady=>2)
      }
      )
    }

    if @objCollections.length == 1
      @familyts.raise(_name)
    end
  end

  def class_image(_class=nil)
    _current_class = _class
    _found = false
    if _class
      _dir = File.dirname(_class.library.arcadia_lib_params.source)
    end
    while _current_class != nil && !_found
      if defined?(_current_class.library)
      		_dir = File.dirname(_current_class.library.arcadia_lib_params.source)
      end
      _img = (_current_class.to_s+"_gif").upcase
      _data = eval(_img + ' if defined?('+_img+')' )
      #_file = _dir+"/res/"+_current_class.to_s+".gif"
      if _data
      #if FileTest.exist?(_file)
        _found = true
      else
        _current_class = _current_class.superclass
      end
    end
    return (_found)?_data:A_WIDGET_GIF
  end
end