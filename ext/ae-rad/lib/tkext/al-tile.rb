#
#   al-tile.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require 'lib/wrappers/tk/w-arcadia-tk'
require 'tkextlib/tile'
require "lib/arcadia/arcadia-ext"

class AGTkCommonTile < AGTkLayoutManaged
  def properties
    super
    publish('property','name'=>'style',
    'get'=> proc{@obj.cget('style')},
    'set'=> proc{|j| @obj.configure('style'=>j)},
    'def'=> ""
    )
    publish('property','name'=>'theme_use',
    'get'=> proc{},
    'set'=> proc{|j| Tk::Tile::Style.theme_use(j)},
    'def'=> ""
    )

  end

end

class ATKTileLabel < AGTkCommonTile
  def ATKTileLabel.class_wrapped
    Tk::Tile::TLabel
  end
  def properties
    super
    publish('property','name'=>'text',
    'default'=> @i_name,
    'get'=> proc{@obj.cget('text')},
    'set'=> proc{|t| @obj.configure('text'=>t)},
    'def'=> ""
    )
    publish('property','name'=>'state',
    'get'=> proc{@obj.cget('state')},
    'set'=> proc{|j| @obj.configure('state'=>j)},
    'def'=> "",
    'type'=>TkType::TkagState
    )
  end
end



class ATKTileButton < AGTkCommonTile
  def ATKTileButton.class_wrapped
    Tk::Tile::TButton
  end
  def properties
    super
    publish('property','name'=>'text',
    'default'=> @i_name,
    'get'=> proc{@obj.cget('text')},
    'set'=> proc{|t| @obj.configure('text'=>t)},
    'def'=> ""
    )
    publish('property','name'=>'state',
    'get'=> proc{@obj.cget('state')},
    'set'=> proc{|j| @obj.configure('state'=>j)},
    'def'=> "",
    'type'=>TkType::TkagState
    )
  end
end


class ATKTileScrollbar < AGTkCommonTile
  def ATKTileScrollbar.class_wrapped
    Tk::Tile::TScrollbar
  end
  def properties
    super
  end
end

class ATKTileCombobox < AGTkCommonTile
  def ATKTileCombobox.class_wrapped
    Tk::Tile::TCombobox
  end
  def properties
    super
    publish('property','name'=>'values',
    'get'=> proc{@obj.cget('values')},
    'set'=> proc{|t| @obj.configure('values'=>t)},
    'def'=> ""
    )
  end
end

class ATKTileSeparator < AGTkCommonTile
  def ATKTileSeparator.class_wrapped
    Tk::Tile::TSeparator
  end
  def properties
    super
  end
end


class ATKTileFrame < AGTkLayoutManagedContainer
  include Tk::Tile
  def ATKTileFrame.class_wrapped
    TFrame
  end
end

class ATKTileLabelframe < ATKTileFrame
  def ATKTileLabelframe.class_wrapped
    Tk::Tile::TLabelframe
  end
  def properties
    super
    publish('property','name'=>'text',
    'default'=> @i_name,
    'get'=> proc{@obj.cget('text')},
    'set'=> proc{|t| @obj.configure('text'=>t)},
    'def'=> ""
    )
  end
end


class ATkTileStyle < AGINTk
  class TkTileStyle
    include Tk::Tile::Style
    def style
      Tk::Tile::Style
    end
  end
  def ATkTileStyle.class_wrapped
    TkTileStyle
  end
  def properties
    super
    publish('property','name'=>'theme',
    'get'=> proc{},
    'set'=> proc{|j| @obj.style.theme_use(j)},
    'def'=> "",
    'type'=> EnumType.new(@obj.style.theme_names)
    )

    publish('property','name'=>'foreground',
    'get'=> proc{},
    'set'=> proc{|foreground| @obj.style.configure('foreground'=>foreground)},
    'def'=> '',
    'type'=> TkType::TkagColor
    )


  end
end

class ArcadiaLibTkTile < ArcadiaLib
  def register_classes
    self.add_class(ATkTileStyle)
    self.add_class(ATKTileLabel)
    self.add_class(ATKTileLabelframe)
    self.add_class(ATKTileButton)
    self.add_class(ATKTileFrame)
    self.add_class(ATKTileScrollbar)
    self.add_class(ATKTileCombobox)
    self.add_class(ATKTileSeparator)
  end
end



