#
#   al-tkcustom.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'ext/ae-rad/lib/tk/al-tk'

class TkLabelWatch < TkLabel
  def show(_format="%I:%M:%S %p")
    t = Time.now
    configure('text'=>t.strftime(_format))
  end

  def start
    @active = true
    @t_clock = Thread.new {
      loop {
        show
        sleep 1
      }
    }
  end
  def stop
    @active = false
    @t_clock.exit if defined? @t_clock
  end
  def active?
    @active
  end
end

class AGTkLabelWatch < AGTkLabel
  def AGTkLabelWatch.class_wrapped
    TkLabelWatch
  end

  def new_object
    @obj = TkLabelWatch.new(@ag_parent.obj)
    @obj.show
  end
  
  def properties
    super()
    mod_publish('property','name'=>'text','default'=> nil)
    publish('property','name'=>'active',
    'get'=> proc{ @obj.active? },
    'set'=> proc{|_val|
      if _val
        @obj.start
      else
        @obj.stop
      end
    },
    'def'=> proc{|value|
      if value
        return "start"
      else
        return ""
      end
    },
    'type'=> TkType::TkagBool
    )
  end
end

class ArcadiaLibTkCustom < ArcadiaLib
  def register_classes
    self.add_class(AGTkLabelWatch)
  end
end
