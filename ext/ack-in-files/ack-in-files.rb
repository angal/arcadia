#
#   ae-search-in-files.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

class AckInFilesService < ArcadiaExt

  def on_before_build(_event)
    Arcadia.attach_listener(AckInFilesListener.new(self),AckInFilesEvent)
  end

end


class AckInFilesListener
  def initialize(_service)
    @service = _service
    create_find
  end

  def on_before_ack_in_files(_event)
    if _event.what.nil?
      @find.show
    end
  end
  
  #def on_search_in_files(_event)
    #Arcadia.new_msg(self, "... ti ho fregato!")
  #end

  #def on_after_search_in_files(_event)
  #end
  
  def create_find
    @find = FindFrame.new(@service.arcadia.layout.root)
    @find.on_close=proc{@find.hide}
    @find.hide
    @find.b_go.bind('1', proc{Thread.new{do_find}})
    @find.e_what_entry.bind_append('KeyRelease'){|e|
      case e.keysym
      when 'Return'
        do_find
        Tk.callback_break
      end
    }
    @find.title("Ack in files")
  end
  private :create_find

  @@ack_checked = false
  def do_find
    return if @find.e_what.text.strip.length == 0  || @find.e_filter.text.strip.length == 0  || @find.e_dir.text.strip.length == 0
    @find.hide
    if !defined?(@search_output)
      @search_output = SearchOutput.new(@service)
    else
      @service.frame.show
    end
    begin
      # unfortunately, it uses regex instead of glob. Oh well.
      # ack -i ignore case
      #   -H, --with-filename   Print the filename for each match
      #  -G REGEX              Only search files that match REGEX
      # ack -i -G .tcl Event
      # ack -i -G .rb "Ack" "c:/dev/ruby/arcadia"
      command = %!ack -i -G "#{@find.e_filter.text.gsub('*', '.*')}" "#{@find.e_what.text}" "#{@find.e_dir.text}"!

      _search_title = 'ack result for : "'+@find.e_what.text+'" in :"'+@find.e_dir.text+'"'+' ['+@find.e_filter.text+'] ' + command
      _filter = @find.e_dir.text+'/**/'+@find.e_filter.text
      _node = @search_output.new_result(_search_title, '')
      progress_stop=false
      @progress_bar = TkProgressframe.new(@service.arcadia.layout.root, 2)		  
      @progress_bar.title('Searching')
      @progress_bar.on_cancel=proc{progress_stop=true}
      #@progress_bar.on_cancel=proc{cancel}


      if !@@ack_checked
        ack_on_system = system("ack --help")
        throw 'appears you dont yet have the ack command installed--please install it and try again' unless ack_on_system
        @@ack_checked = true
      end

      answer = `#{command}`      
      @progress_bar.progress # done...could do this better
      # a now looks like
      # "C:/dev/ruby/arcadia/conf/arcadia.res.rb:184:mzWCUixPU0sEqgO/8AoIsQbpkAbCQWpVeLJUpzhXd6v9eWZV1G1DosCBogAO"
      # ...
      answer.each_line{|line|
        # we'll assume no :number: in the path...if not it will mess us right up
        line =~ /(.*):(\d+):(.*)/
        _filename = $1
        _lineno = $2
        _text = $3
        @search_output.add_result(_node, _filename, _lineno, _text)
      }
    rescue Exception => e
      Arcadia.console(self, 'msg'=>e.message + e.backtrace.inspect, 'level'=>'error')
      #Arcadia.new_error_msg(self, e.message)
    ensure
      @progress_bar.destroy
    end

  end
  
  
end
