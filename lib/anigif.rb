TkPackage.require("anigif")

module Tk
  module Anigif
    def self.image(_widget, _file)
      Tk.tk_call("eval","::anigif::anigif", _file, _widget.path)
    end
  end
end