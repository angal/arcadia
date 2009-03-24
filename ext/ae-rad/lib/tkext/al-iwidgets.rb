#
#   al-iwidgets.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'ext/ae-rad/lib/tk/arcadia-tk'
require 'tkextlib/iwidgets'



class AGTkIWidgets < AGTkBase
  def newobject
    @obj = Tk::Iwidgets::Calendar.new(@ag_parent.obj)
  end
  def properties
    super()
  end
end


class ArcadiaLibTkBWidget < ArcadiaLib
  def register_classes
    self.add_class(AGTkIWidgets)
  end
end
