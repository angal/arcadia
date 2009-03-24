#
#   al-tktable.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'comp/agtk'
require 'comp/tktable'

class AGTktable < AGTkBase
  #il combo si compone di un entry un button e un frame
  def newobject
    @obj = Tktable.new(@ag_parent.obj)
  end

  def properties
    super()


    publish('property','name'=>'cache',
    'get'=> proc{@obj.cget('cache')},
    'set'=> proc{|cache| @obj.configure('cache'=>cache)},
    'def'=> "",
    'type'=> TkType::TkagBool
    )
    publish('property','name'=>'cols',
      'get'=> proc{@obj.cget('cols')},
      'set'=> proc{|cols| @obj.configure('cols'=>cols)},
      'def'=> ""
    )
    publish('property','name'=>'rows',
      'get'=> proc{@obj.cget('rows')},
      'set'=> proc{|rows| @obj.configure('rows'=>rows)},
      'def'=> ""
    )
    publish('property','name'=>'borderwidth',
      'get'=> proc{@obj.cget('borderwidth')},
      'set'=> proc{|borderwidth| @obj.configure('borderwidth'=>borderwidth)},
      'def'=> ""
    )
  end

end

class ArcadiaLibTkTable < ArcadiaLib
  def register_classes
    self.add_class(Aw_Tk_BWidget_MainFrameAGTktable)
  end
end
