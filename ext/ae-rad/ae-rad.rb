#
#   ae-rad.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "#{Dir.pwd}/ext/ae-rad/ae-rad-libs"
require "#{Dir.pwd}/ext/ae-rad/ae-rad-palette"
require "#{Dir.pwd}/ext/ae-rad/ae-rad-inspector"

class Rad < ArcadiaExt
  attr_reader :libs
  attr_reader :palette
  attr_reader :inspector
  def on_build(_event)
    load_libs
  end
  
  def show_rad
    if @palette.nil?
      @palette = Palette.new(self)
      @inspector = ObjiController.new(self)
    else
      float_frame(0).show
    end
  end
  
  def load_libs
    @libs = ArcadiaLibs.new(self)
    libs = conf('libraries').split(',')
    libs.each{|lib|
      if lib
        begin
          require conf('libraries.'+lib+'.source')
          @libs.add_lib(
          ArcadiaLibs::ArcadiaLibParams.new(
          conf('libraries.'+lib+'.name'),
          conf('libraries.'+lib+'.source'),
          conf('libraries.'+lib+'.require'),
          eval(conf('libraries.'+lib+'.collection.class')))
          )
        rescue Exception
          msg = "Loading lib "+'"'+lib+'"'+" ("+$!.class.to_s+") "+" : "+$! + " at : "+$@.to_s
          if Tk.messageBox('icon' => 'error', 'type' => 'okcancel',
            'title' => '(Rad) Libs', 
            'message' => msg) == 'cancel'
            raise
            exit
          else
            Tk.update
          end
        end
      end
    }
  end
  
end
