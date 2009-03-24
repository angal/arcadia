#
#   al-bwidget.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'ext/ae-rad/lib/tk/al-tk'
require 'tkextlib/bwidget'
require "ext/ae-rad/ae-rad-libs"

class AGBWidgetMainFrame < AGTkContainer

  def AGBWidgetMainFrame.class_wrapped
    Tk::BWidget::MainFrame
  end
  
  def properties
    super()
#    publish_del('property','visual')
#    publish_del('property','container')
#    publish_del('property','class')
    publish_del('property','cursor')
  end
  
end

class AGBWidgetComboBox < AGTkBase

  def initialize(_ag_parent = nil, _object = nil)
    super(_ag_parent, _object)
    ppress = proc{@l_manager.deactivate;@obj.callback_break}
    prelease = proc{@l_manager.activate;@obj.callback_break}
    @obj.e.bind("ButtonPress-1", proc{|e| 
        @l_manager.place_manager.do_press_obj(e.x, e.y)
        @obj.callback_break
      }
    )
    @obj.e.bind_append("ButtonPress-1", ppress)
    @obj.e.bind("ButtonRelease-1", prelease)
    @obj.e.bind("B1-Motion", proc{|x, y| @l_manager.place_manager.do_mov_obj(x,y); @obj.callback_break},"%x %y")
  end
  
  def AGBWidgetComboBox.class_wrapped
    Tk::BWidget::ComboBox
  end

  def new_object
    super
    initobj
  end
  
  def  initobj
    def @obj.e
      TkWinfo.children(self)[0]
    end

    def @obj.b
      TkWinfo.children(self)[1]
    end
  
  end
  
  def passedobject(_obj)
    super
    initobj
  end

  def properties
    super()

    publish_mod('place','name'=>'width',
      'get'=> proc{if TkWinfo.mapped?(@obj)
          TkWinfo.width(@obj.e)+ TkWinfo.width(@obj.b)
        else
          TkWinfo.reqwidth(@obj.e)+ TkWinfo.reqwidth(@obj.b)
        end
      }
    )

    publish_mod('place','name'=>'height',
        'get'=> proc{ if TkWinfo.mapped?(@obj)
          TkWinfo.height(@obj)
        else
          TkWinfo.reqheight(@obj.b)
        end
      }
    )
  
    publish('property','name'=>'entry-background',
      'get'=> proc{@obj.e.cget('background')},
      'set'=> proc{|background| @obj.e.configure('background'=>background)},
      'def'=> proc{|x| "TkWinfo.children(self)[0].configure('background'=>#{x})"},
      'type'=> TkType::TkagColor
    )
    publish('property','name'=>'button-background',
      'get'=> proc{@obj.b.cget('background')},
      'set'=> proc{|background| @obj.b.configure('background'=>background)},
      'def'=> proc{|x| "TkWinfo.children(self)[1].configure('background'=>#{x})"},
      'type'=> TkType::TkagColor
    )
    publish('property','name'=>'values',
      'get'=> proc{@obj.cget('values')},
      'set'=> proc{|v| @obj.configure('values'=>v)},
      'def'=> ""
    )
  end
end

class AGTkBwProgressBar < AGTkBase
  def AGTkBwProgressBar.class_wrapped
    Tk::BWidget::ProgressBar
  end
  
  def properties
    super()
    publish('property','name'=>'variable',
      'get'=> proc{@obj.cget('variable')},
      'set'=> proc{|variable| @obj.configure('variable'=>variable)},
      'def'=> ''
    )
  end
end

class AGTkBwButton < AGTkButton
  def AGTkBwButton.class_wrapped
   Tk::BWidget::Button
  end
  def properties
    super()
    publish('property','name'=>'helptype',
    'get'=> proc{@obj.cget('helptype')},
    'set'=> proc{|v| @obj.configure('helptype'=>v)},
    'def'=> "",
    'type'=> EnumType.new('balloon','variable')
    )
    publish('property','name'=>'helptext',
    'get'=> proc{@obj.cget('helptext')},
    'set'=> proc{|v| @obj.configure('helptext'=>v)},
    'def'=> ""
    )
  end
end

class AGTkBwSeparator < AGTkBase
  def new_object
    @obj = Tk::BWidget::Separator.new(@ag_parent.obj)
  end
end

class AGTkBwPanedWindow < AGTkFrame
  def new_object
    @obj = Tk::BWidget::PanedWindow.new(@ag_parent.obj)
  end
end

class AGTkBwNoteBook < AGTkBwPanedWindow
  def new_object
    @obj = Tk::BWidget::NoteBook.new(@ag_parent.obj)
  end

  def AGTkBwNoteBook.class_wrapped
    Tk::BWidget::NoteBook
  end

  
  def properties
    super
    publish('property','name'=>'background',
    'get'=> proc{@obj.cget('background')},
    'set'=> proc{|background| @obj.configure('background'=>background)},
    'def'=> '',
    'type'=> TkType::TkagColor
    )
  end
end

class AGTkBwTree < AGTkBase
  def new_object
    @obj = Tk::BWidget::Tree.new(@ag_parent.obj)
  end
end


class ArcadiaLibBWidget < ArcadiaLib
  def register_classes
    self.add_class(AGBWidgetMainFrame)
    self.add_class(AGBWidgetComboBox)
    self.add_class(AGTkBwProgressBar)
    self.add_class(AGTkBwSeparator)
    self.add_class(AGTkBwPanedWindow)
    self.add_class(AGTkBwNoteBook)
    self.add_class(AGTkBwTree)
    self.add_class(AGTkBwButton)
  end
end
