#
#   al-tkarcadia.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
require 'ext/ae-rad/lib/tk/al-tk'
require 'lib/a-tkcommons'

class WAGTkVSplittedFrames < AGTkFrame
  def WAGTkVSplittedFrames.class_wrapped
    AGTkVSplittedFrames
  end
  def new_object
    @obj = AGTkVSplittedFrames.new(@ag_parent.obj, @ag_parent.obj)
  end

  def properties
    super()
  end
end

class ArcadiaLibArcadiaTk < ArcadiaLib
  def register_classes
    self.add_class(WAGTkVSplittedFrames)
  end
end
