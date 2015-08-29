#
#   a-core.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=..
#   &require_omissis=#{Dir.pwd}/conf/arcadia.init
#   &require_omissis=tk
#   &require_omissis=tk/label
#   &require_omissis=tk/toplevel

require "#{Dir.pwd}/conf/arcadia.res"
require 'tkextlib/bwidget'
require "#{Dir.pwd}/lib/a-tkcommons"
require "#{Dir.pwd}/lib/a-contracts"
require "observer"

class Arcadia < TkApplication
  include Observable
  include OS
  attr_reader :layout
  attr_reader :wf
  attr_reader :mf_root
  attr_reader :localization
  attr_reader :exts
  def initialize
    @initialized=false
    super(
      ApplicationParams.new(
        'arcadia',
        '1.1.0',
        'conf/arcadia.conf',
        'conf/arcadia.pers'
      )
    )
    load_config
    @localization = ArcadiaLocalization.new
    if self['conf']['encoding']
      Tk.encoding=self['conf']['encoding']
    end
    #    @use_splash = self['conf']['splash.show']=='yes'
    #    @splash = ArcadiaAboutSplash.new if @use_splash
    #    @splash.set_progress(50) if @splash
    #    @splash.deiconify if @splash
    #    Tk.update
    @wf = TkWidgetFactory.new
    ArcadiaProblemsShower.new(self)
    ArcadiaDialogManager.new(self)
    ArcadiaActionDispatcher.new(self)
    ArcadiaGemsWizard.new(self)
    MonitorLastUsedDir.new
    @focus_event_manager = FocusEventManager.new
    #self.load_local_config(false)
    ObjectSpace.define_finalizer($arcadia, self.class.method(:finalize).to_proc)
    #_title = "Arcadia Ruby ide :: [Platform = #{RUBY_PLATFORM}] [Ruby version = #{RUBY_VERSION}] [TclTk version = #{tcltk_info.level}]"
    _title = "Arcadia"
    @root = TkRoot.new(
      'background'=> self['conf']['background']
    ){
      title _title
      withdraw
      protocol( "WM_DELETE_WINDOW", proc{Arcadia.process_event(QuitEvent.new(self))})
      iconphoto(Arcadia.image_res(A_LOGO_STRIP_GIF)) if Arcadia.instance.tcltk_info.level >= '8.4.9'
    }
    @on_event = Hash.new

#    @main_menu_bar = TkMenubar.new(
#      'background'=> self['conf']['background']
#    ).pack('fill'=>'x')
    
    @mf_root = Tk::BWidget::MainFrame.new(@root,
    'background'=> self['conf']['background'],
    'height'=> 0
    ).pack(
      'anchor'=> 'center',
      'fill'=> 'both',
      'expand'=> 1
    )
    #.place('x'=>0,'y'=>0,'relwidth'=>1,'relheight'=>1)

    @mf_root.show_statusbar('status')
    Arcadia.new_statusbar_item("Platform").text=RUBY_PLATFORM
    self['toolbar']= ArcadiaMainToolbar.new(self, @mf_root.add_toolbar)
    @is_toolbar_show=self['conf']['user_toolbar_show']=='yes'
    @mf_root.show_toolbar(0,@is_toolbar_show)
    @use_splash = self['conf']['splash.show']=='yes'
    @splash = ArcadiaAboutSplash.new if @use_splash
    @splash.set_progress(62) if @splash
    @splash.deiconify if @splash
    Tk.update
    @screenwidth=TkWinfo.screenwidth(@root)
    @screenheight=TkWinfo.screenheight(@root)
    @need_resize=false
    @x_scale=1
    @y_scale=1
    if self['conf']['geometry']
      w0,h0,x0,y0= geometry_to_a(self['conf']['geometry'])
      g_array = []
      if @screenwidth > 0 && w0.to_i > @screenwidth
        g_array << (@screenwidth - x0.to_i).to_s
        @need_resize = true
        @x_scale = @screenwidth.to_f/w0.to_f
      else
        g_array << w0
      end
      if @screenheight > 0 && h0.to_i > @screenheight
        g_array << (@screenheight - y0.to_i).to_s
        @need_resize = true
        @y_scale = @screenheight.to_f/h0.to_f
      else
        g_array << h0
      end
      g_array << x0
      g_array << y0
      geometry = geometry_from_a(g_array)
    else
      start_width = (@screenwidth-4)
      start_height = (@screenheight-20)
      if OS.windows? # on doze don't go below the start gar
        start_height -= 50
        start_width -= 20
      end
      geometry = start_width.to_s+'x'+start_height.to_s+'+0+0'
    end
    prepare
    begin
      @root.deiconify
    rescue RuntimeError => e
      #p "RuntimeError : #{e.message}"
      Arcadia.runtime_error(e)
    end
    begin
      @root.focus(true)
    rescue RuntimeError => e
      #p "RuntimeError : #{e.message}"
      Arcadia.runtime_error(e)
    end
    begin
      @root.geometry(geometry)
    rescue RuntimeError => e
      #p "RuntimeError : #{e.message}"
      Arcadia.runtime_error(e)
    end
    begin
      @root.raise
    rescue RuntimeError => e
      #p "RuntimeError : #{e.message}"
      Arcadia.runtime_error(e)
    end
    begin
      Tk.update_idletasks
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
    if self['conf']['geometry.state'] == 'zoomed'
      if Arcadia.is_windows? || OS.mac?
        @root.state('zoomed')
      else
        @root.wm_attributes('zoomed',1)
      end
    end
    #sleep(1)
    @splash.last_step if @splash
    @splash.destroy  if @splash
    if @first_run # first ARCADIA ever
      Arcadia.process_event(OpenBufferEvent.new(self,'file'=>'README.md'))
    elsif ARGV.length > 0
      ARGV.each{|_f|
        if  $pwd != File.dirname(__FILE__) && !File.exist?(_f)
          _f = "#{$pwd}/#{_f}"
        end
        Arcadia.process_event(OpenBufferEvent.new(self,'file'=>_f)) if File.exist?(_f)
      }
    end
    Arcadia.attach_listener(self, QuitEvent)
    Arcadia.persistent("version", self['applicationParams'].version)
    @@last_input_keyboard_query_event=nil
    @initialized=true
 #   @focus_event_manager = FocusEventManager.new
  end

  def root_height
    @root.winfo_height
  end

  def initialized?
    @initialized
  end

  def on_quit(_event)
    self.do_exit
  end

  def register(_ext)
    if @@instance['exts_map'] == nil
      @@instance['exts_map'] = Hash.new
    end
    @exts_i << _ext
    @@instance['exts_map'][_ext.name]=_ext 
  end

  def unregister(_ext)
    @@instance['exts_map'][_ext.name] = nil
    @@instance['exts_map'].delete(_ext.name)
    @exts_i.delete(_ext)
  end

  def last_focused_text_widget
    @focus_event_manager.last_focus_widget
  end

  def show_hide_toolbar
    if @is_toolbar_show
      @mf_root.show_toolbar(0,false)
      @is_toolbar_show = false
    else
      @mf_root.show_toolbar(0,true)
      Tk.update
      @is_toolbar_show = true
    end

  end


  def Arcadia.finalize(id)
    puts "\nArcadia #{id} dying at #{Time.new}"
  end

  def ext_active?(_name)
    return (self['conf'][_name+'.active'] != nil && self['conf'][_name+'.active']=='yes')||
    (self['conf'][_name+'.active'] == nil)
  end

  def ext_source_must_be_loaded?(_name)
    ret = ext_active?(_name)
    if !ret
      @exts_dip.each{|key,val|
        if val == _name
          ret = ret || ext_active?(key)
        end
        break if ret
      }
    end
    ret
  end

  def load_exts_conf
    @exts = Array.new
    @exts_i = Array.new
    @exts_dip = Hash.new
    @exts_loaded = Array.new
    load_exts_conf_from('ext')
  end

  def load_exts_conf_from(_dir='',_ext_root=nil)
    dirs = Array.new
    files = Dir["#{_dir}/*"].concat(Dir[ENV["HOME"]+"/.arcadia/#{_dir}/*"]).sort
    files.each{|f|
      dirs << f if File.stat(f).directory? && FileTest.exist?(f+'/'+File.basename(f)+'.conf')
    }
    dirs.each{|ext_dir|
      conf_hash = self.properties_file2hash(ext_dir+'/'+File.basename(ext_dir)+'.conf')
      conf_hash2 = Hash.new
      name = conf_hash['name']
      conf_hash.each{|key, value|
        var_plat = key.split(':')
        if var_plat.length > 1
          new_key = var_plat[0] + ':' + name + '.' + var_plat[1]
        else
          begin
            new_key = name+'.'+key
          rescue => e
            puts 'is an extension missing a name?'
            raise e
          end
        end
        conf_hash2[new_key]= value
      }
      @exts << name
      if _ext_root
        @exts_dip[name] = _ext_root
      end
      self['conf'].update(conf_hash2)
      self['origin_conf'].update(conf_hash2)
      self['conf_without_local'].update(conf_hash2)
      load_exts_conf_from("#{ext_dir}/ext",name)
    }
  end

  def Arcadia.gem_available?(_gem)
    #TODO : Gem::Specification::find_by_name(_gem)
    if Gem::Specification.respond_to?(:find_by_name)
      begin
        !Gem::Specification::find_by_name(_gem).nil?
      rescue Exception => e
        false
      end
    elsif Gem.respond_to?(:available?)
      return Gem.available?(_gem)
    else
      return !Gem.source_index.find_name(_gem).empty?
    end
  end

  def check_gems_dependences(_ext)
    ret = true
    gems_property = self['conf']["#{_ext}.gems"]
    if gems_property
      gems = gems_property.split(',').collect{| g | g.strip }
      if gems && gems.length > 0
        gems.each{|gem|
          # consider gem only if it is not installed
          if !Arcadia.gem_available?(gem)
            repository_property =  self['conf']["#{_ext}.gems.#{gem}.repository"]
            events_property =  self['conf']["#{_ext}.gems.#{gem}.events"]
            args = Hash.new
            args['extension_name']=_ext
            args['gem_name']=gem
            args['gem_repository']=repository_property if repository_property
            args['gem_events']=events_property if events_property
            if events_property
              #EventWatcher.new
              events_str = events_property.split(',')
              events_str.each{|event_str|
                EventWatcherForGem.new(eval(event_str),args)
              }
            else
              @splash.withdraw  if @splash
              _event = Arcadia.process_event(NeedRubyGemWizardEvent.new(self, args))
              ret = ret &&  Arcadia.gem_available?(gem)
              #              if _event && _event.results
              #                ret = ret && _event.results[0].installed
              #              end
              @splash.deiconify  if @splash
            end
            break if !ret
          end
        }
      end
    end
    ret
  end

  def do_build
    # create extensions
    Array.new.concat(@exts).each{|extension|
      if extension && ext_source_must_be_loaded?(extension)
        gems_installed = check_gems_dependences(extension)
        if !gems_installed || !ext_load(extension)
          @exts.delete(extension)
        elsif !ext_active?(extension)
          @exts.delete(extension)
        elsif ext_active?(extension)
          @splash.next_step(Arcadia.text("main.splash.creating_extension", [extension])) if @splash
          #@splash.next_step('... creating '+extension)  if @splash
          @exts.delete(extension) unless
          (((@exts_dip[extension] != nil && @exts_loaded.include?(@exts_dip[extension]))||@exts_dip[extension] == nil) && ext_create(extension))
        end
      end
    }
    begin
      _build_event = Arcadia.process_event(BuildEvent.new(self))
    rescue Exception => e
      ret = false
      msg = Arcadia.text("main.e.during_build_event.msg", [ $!.class.to_s , $!.to_s , $@.to_s ] )
      ans = Arcadia.dialog(self,
      'type'=>'abort_retry_ignore',
      'title' => Arcadia.text("main.e.during_build_event.title"),
      'msg'=>msg,
      'exception'=>e,
      'level'=>'error')
      if  ans == 'abort'
        raise
        exit
      elsif ans == 'retry'
        retry
      else
        Tk.update
      end
    end
  end

  def do_initialize
    _build_event = Arcadia.process_event(InitializeEvent.new(self))
  end

  def do_make_clones
    Array.new.concat(@exts_i).each{|ext|
      if ext.kind_of?(ArcadiaExtPlus)
        a = ext.conf_array("clones")
        a.each{|clone_name|
          ext.clone(clone_name)
        }
      end
    }
  end

  def load_maximized
    lm = self['conf']['layout.maximized']
    if lm
      ext,index=lm.split(',')
      maxed = false
      if ext && index
        ext = ext.strip
        i=index.strip.to_i
        @exts_i.each{|e|
          if e.conf('name')==ext && !maxed
            e.maximize(i)
            maxed=true
            break
          end
        }
      end
    end
  end

  def ext_load(_extension)
    ret = true
    begin
      source = self['conf'][_extension+'.require']
      if source.strip.length > 0
        require "#{Dir.pwd}/#{source}"
      end
      @exts_loaded << _extension
    rescue Exception,LoadError => e
      ret = false
      msg = Arcadia.text("main.e.loading_ext.msg", [_extension, $!.class.to_s, $!.to_s, $@.to_s ] )
      ans = Arcadia.dialog(self,
      'type'=>'abort_retry_ignore',
      'title' => Arcadia.text("main.e.loading_ext.title", [_extension]),
      'msg'=>msg,
      'exception'=>e,
      'level'=>'error')
      if  ans == 'abort'
        raise
        exit
      elsif ans == 'retry'
        retry
      else
        Tk.update
      end
    end
    ret
  end

  def ext_create(_extension)
    ret = true
    begin
      class_name = self['conf'][_extension+'.class']
      if class_name.strip.length > 0
        klass = nil
        begin
          klass = eval(class_name)
        rescue => e
          puts 'does an extension class have the wrong name associated with it, in its conf file?, or is not listing the right .rb file?'
          raise e
        end
        publish(_extension, klass.new(self, _extension))
      end
    rescue Exception,LoadError => e
      ret = false
      msg = Arcadia.text("main.e.creating_ext.msg", [_extension, $!.class.to_s, $!, $@.to_s])
      ans = Arcadia.dialog(self,
      'type'=>'abort_retry_ignore',
      'title' => Arcadia.text("main.e.creating_ext.title", [_extension]),
      'msg'=>msg,
      'exception'=>e,
      'level'=>'error')
      #      ans = Tk.messageBox('icon' => 'error', 'type' => 'abortretryignore',
      #      'title' => "(Arcadia) Extensions '#{_extension}'", 'parent' => @root,
      #      'message' => msg)
      if  ans == 'abort'
        raise
        exit
      elsif ans == 'retry'
        retry
      else
        Tk.update
      end
    end
    ret
  end

  #  def ext_method(_extension, _method)
  #    begin
  #      self[_extension].send(_method)
  #    rescue Exception => e
  #      msg = _method.to_s+' "'+_extension.to_s+'"'+" ("+$!.class.to_s+") "+" : "+$! + "\n at : "+$@.to_s
  #      ans = Arcadia.dialog(self,
  #            'type'=>'abort_retry_ignore',
  #            'title' => "(Arcadia) Extensions",
  #            'msg'=>msg,
  #            'exception'=>e,
  #            'level'=>'error')
  #      if ans == 'abort'
  #        raise
  #        exit
  #      elsif ans == 'retry'
  #        retry
  #      else
  #        Tk.update
  #      end
  #    end
  #  end

  def initialize_layout
    @layout = ArcadiaLayout.new(self, @mf_root.get_frame)
    suf = "layout.split"
    elems = self['conf'][suf]
    return if elems.nil?
    if elems.strip.length > 0
      groups = elems.split(',')
      groups.each{|group|
        if group
          suf1 = suf+'.'+group
          begin
            property = self['conf'][suf1]
            #next if property.nil?
            c = property.split('c')
            if c && c.length == 2
              pt = c[0].split('.')
              perc = c[1].include?('%')
              w = c[1].sub('%','')
              if perc
                @layout.add_cols_perc(pt[0].to_i, pt[1].to_i, w.to_i)
              else
                if @need_resize
                  w_c = (w.to_i*@x_scale).to_i
                else
                  w_c = w.to_i
                end
                @layout.add_cols(pt[0].to_i, pt[1].to_i, w_c)
              end
            else
              r = property.split('r')
              if r && r.length == 2
                pt = r[0].split('.')
                perc = r[1].include?('%')
                w = r[1].sub('%','')
                if perc
                  @layout.add_rows_perc(pt[0].to_i, pt[1].to_i, w.to_i)
                else
                  if @need_resize
                    w_c = (w.to_i*@y_scale).to_i
                  else
                    w_c = w.to_i
                  end
                  @layout.add_rows(pt[0].to_i, pt[1].to_i, w_c)
                end
              end
            end
          rescue Exception
            msg = Arcadia.text('main.e.loading_layout.msg', [$!.class.to_s, $!.to_s, $@.to_s])
            if Arcadia.dialog(self,
              'type'=>'ok_cancel',
              'level'=>'error',
              'title' => Arcadia.text('main.e.loading_layout.title'),
              'exception' => $!,
              'msg'=>msg)=='cancel'
              raise
              exit
            else
              Tk.update
            end
          end
        end
      }
    else
      @layout.add_mono_panel
    end
    @layout.add_headers
  end

  def load_config
    self.load_local_config(false)
    # local config can contain loading conditions
    self.load_exts_conf
    if @first_run
      myloc = nil
      begin
        myloc = ENV["LANG"].split('.')[0].sub('_','-') if ENV["LANG"]
      rescue Exception => e
      end
      Arcadia.conf('locale', myloc) if myloc != nil
    end
    self.load_local_config
    self.load_theme(self['conf']['theme'])
    self.resolve_properties_link(self['conf'],self['conf'])
    self.resolve_properties_link(self['conf_without_local'],self['conf_without_local'])
    self.load_sysdefaultproperty
  end

  def load_sysdefaultproperty
    if !OS.mac?
      Tk.tk_call "eval","option add *background #{self['conf']['background']}"
      Tk.tk_call "eval","option add *foreground #{self['conf']['foreground']}"
      Tk.tk_call "eval","option add *activebackground #{self['conf']['activebackground']}"
      Tk.tk_call "eval","option add *activeforeground #{self['conf']['activeforeground']}"
      Tk.tk_call "eval","option add *highlightcolor  #{self['conf']['background']}"
      Tk.tk_call "eval","option add *relief #{self['conf']['relief']}"
    end
    if !Arcadia.is_windows? && File.basename(Arcadia.ruby) != 'ruby'
      begin
        if !FileTest.exist?("#{local_dir}/bin")
          Dir.mkdir("#{local_dir}/bin")
        end
        system("ln -s #{Arcadia.ruby} #{local_dir}/bin/ruby") if !File.exist?("#{local_dir}/bin/ruby")
      rescue Exception => e
        Arcadia.runtime_error(e)
      end
    end

  end

  def prepare
    super
    @splash.next_step(Arcadia.text('main.splash.initializing_layout'))  if @splash
    #load_config
    initialize_layout
    publish('buffers.code.in_memory',Hash.new)
    #provvisorio
    @keytest = KeyTest.new
    @keytest.on_close=proc{@keytest.hide}
    @keytest.hide
    @keytest.title("Keys test")
    publish('action.test.keys', proc{@keytest.show})
    publish('action.get.font', proc{Tk::BWidget::SelectFont::Dialog.new.create})
    publish('action.show_about', proc{ArcadiaAboutSplash.new.deiconify})
#    self['menubar'] = ArcadiaMainMenu.new(@main_menu_bar)
    self['menubar'] = ArcadiaMainMenu.new(@root)
    @splash.next_step(Arcadia.text('main.splash.building_extensions'))  if @splash
    self.do_build
    publish('objic.action.raise_active_obj',
    proc{
      InspectorContract.instance.raise_active_toplevel(self)
    }
    )
    @splash.next_step(Arcadia.text('main.splash.loading_common_user_controls'))  if @splash
    #Arcadia control
    load_user_control(self['toolbar'])
    load_user_control(self['menubar'])
    #Extension control
    @splash.next_step(Arcadia.text('main.splash.loading_keys_binding'))  if @splash
    load_key_binding
    @exts.each{|ext|
      @splash.next_step(Arcadia.text("main.splash.loading_ext_user_controls",[ext]))  if @splash
      load_user_control(self['toolbar'], ext)
      load_user_control(self['menubar'], ext)
      load_key_binding(ext)
    }
    load_user_control(self['toolbar'],"","e")
    load_user_control(self['menubar'],"","e")
    # Platform menus
    if OS.mac?
      apple = TkSysMenu_Apple.new(self['menubar'].menubar)
      self['menubar'].menubar.add :cascade, :menu => apple
    elsif OS.windows?
      sysmenu = TkSysMenu_System.new(self['menubar'].menubar)
      self['menubar'].menubar.add :cascade, :menu => sysmenu
    end
    @splash.next_step(Arcadia.text('main.splash.loading_runners'))  if @splash
    load_runners
    do_make_clones
    @splash.next_step(Arcadia.text('main.splash.initializing_extensions'))  if @splash
    do_initialize
    #@layout.build_invert_menu
  end

  def refresh_runners_on_menu(root_menu=nil, _file=nil, _dir=nil)
    return if root_menu.nil?
    if !root_menu.index('end').nil?
      index_end = root_menu.index('end')-1
      root_menu.delete('0',index_end)
    end
    self['runners'].each{|name, run|
      newrun = {}.update(run)
      newrun[:file] = _file if !_file.nil?
      newrun[:dir] = _dir if !_dir.nil?
      insert_runner_item(root_menu, name, newrun)
    }
  end

  def reload_runners
    mr = Arcadia.menu_root('runcurr')
    return if mr.nil?
    self['runners'].clear if self['runners']
    self['runners_by_ext'].clear if self['runners_by_ext']
    self['runners_by_lang'].clear if self['runners_by_lang']
    index_end = mr.index('end')-1
    mr.delete('0',index_end)
    load_runners
  end

  def insert_runner_item(root_menu=nil, name, run)
    return if root_menu.nil?
    if run[:file_exts]
      run[:file_exts].split(',').each{|ext|
        self['runners_by_ext'][ext.strip.sub('.','')]=run
      }
    end
    if run[:lang]
      self['runners_by_lang'][run[:lang]]=run
    end
    if run[:runner] && self['runners'][run[:runner]]
      run = Hash.new.update(self['runners'][run[:runner]]).update(run)
      #self['runners'][name]=run
    end
    if run[:image]
      image = Arcadia.image_res(run[:image])
    else
      image = Arcadia.file_icon(run[:file_exts])
    end
    _run_title = run[:title]
    #run[:title] = nil
    run[:runner_name] = name
    _command = proc{
      _event = Arcadia.process_event(
        RunCmdEvent.new(self, run)
      )
    }
    if run[:pos]
      pos = run[:pos]
    else
      pos = '0'
    end
    args = {
      :image => image,
      :label => _run_title,
      :compound => 'left',
      :command => _command
    }
    args[:font] = Arcadia.conf('menu.font') #if !OS.mac?
    
    root_menu.insert(pos, :command , args)
  end
  

  def load_runners
    self['runners'] = Hash.new if self['runners'].nil?
    self['runners_by_ext'] = Hash.new if self['runners_by_ext'].nil?
    self['runners_by_lang'] = Hash.new if self['runners_by_lang'].nil?
    mr = Arcadia.menu_root('runcurr')
    return if mr.nil?

#    insert_runner_item = proc{|name, run|
#      if run[:file_exts]
#        run[:file_exts].split(',').each{|ext|
#          self['runners_by_ext'][ext.strip.sub('.','')]=run
#        }
#      end
#      if run[:lang]
#        self['runners_by_lang'][run[:lang]]=run
#      end
#      if run[:runner] && self['runners'][run[:runner]]
#        run = Hash.new.update(self['runners'][run[:runner]]).update(run)
#        #self['runners'][name]=run
#      end
#      if run[:image]
#        image = Arcadia.image_res(run[:image])
#      else
#        image = Arcadia.file_icon(run[:file_exts])
#      end
#      _run_title = run[:title]
#      #run[:title] = nil
#      run[:runner_name] = name
#      _command = proc{
#        _event = Arcadia.process_event(
#          RunCmdEvent.new(self, run)
#        )
#      }
#      if run[:pos]
#        pos = run[:pos]
#      else
#        pos = '0'
#      end
#      args = {
#        :image => image,
#        :label => _run_title,
#        :compound => 'left',
#        :command => _command
#      }
#      args[:font] = Arcadia.conf('menu.font') #if !OS.mac?
#      
#      mr.insert(pos, :command , args)
#    }

    insert_runner_instance_item = proc{|name, run|
      if run[:runner] && self['runners'][run[:runner]]
        run = Hash.new.update(self['runners'][run[:runner]]).update(run)
        #self['runners'][name]=run
      end
      _run_title = run[:title]
      run[:title] = nil
      run[:runner_name] = name
      if run[:image]
        image = Arcadia.image_res(run[:image])
      else
        image = Arcadia.file_icon(run[:file_exts])
      end

      _command = proc{
        _event = Arcadia.process_event(
        RunCmdEvent.new(self, run)
        )
      }
      args = {
        :image => image,
        :label => _run_title,
        :compound => 'left',
        :command => _command
      }
      args[:font] = Arcadia.conf('menu.font') #if !OS.mac?
      mr.insert('0', :command , args)
    }

    #conf runner
    runs=Arcadia.conf_group('runners', true)
    mr.insert('0', :separator) if runs && !runs.empty?

    runs.each{|name, hash_string|
      self['runners'][name]=eval hash_string
    }

    self['runners'].each{|name, run|
      #insert_runner_item.call(name, run)
      insert_runner_item(mr, name, run)
    }


    #conf exts runner
    @exts.each{|ext|
      if ext_active?(ext)
        ext_runs=Arcadia.conf_group("#{ext}.runners", true)
        mr.insert(self['runners'].count, :separator) if ext_runs && !ext_runs.empty?
        ext_runs.each{|name, hash_string|
          self['runners'][name]=eval hash_string
          self['runners'][name][:pos]=self['runners'].count
          #insert_runner_item.call(name, self['runners'][name])
          insert_runner_item(mr, name, self['runners'][name])
        }
      end
    }



    # pers runner instance
    runs=Arcadia.pers_group('runners', true)
    mr.insert('0', :separator) if runs && !runs.empty?
    pers_runner = Hash.new
    runs.each{|name, hash_string|
      begin
        pers_runner[name]=eval hash_string
      rescue Exception => e
        Arcadia.unpersistent("runners.#{name}")
      end
    }

    pers_runner.each{|name, run|
      insert_runner_instance_item.call(name, run)
    }
  end

  def manage_runners
    if !@runm || @runm.nil? 
      @runm = RunnerManager.new(Arcadia.layout.root)
      @runm.on_close=proc{@runm = nil}
      @runm.clear_items
      @runm.load_tips
      @runm.load_items(:runtime)
      @runm.load_items(:config)
    end
    #@runm.show
    #@runm.load_items
  end

  def register_key_binding(_self_target, k, v)
    value = v.strip
    key_dits = k.split('[')
    return if k.length == 0
    key_event=key_dits[0]
    if key_dits[1]
      key_sym=key_dits[1][0..-2]
    end
    @root.bind_append(key_event, "%K"){|_keysym|
      if key_sym == _keysym
        Arcadia.process_event(_self_target.instance_eval(value))
      end
    }
  end

  def load_key_binding(_ext='')
    return unless _ext && ext_active?(_ext)
    if _ext.length > 0
      if self[_ext]
        _self_on_eval = self[_ext]
      else
        _self_on_eval = self
      end
      suf = "#{_ext}.keybinding"
    else
      _self_on_eval = self
      suf = "keybinding"
    end
    keybs=Arcadia.conf_group(suf)
    keybs.each{|k,v|
      register_key_binding(_self_on_eval, k, v)
    }
  end

  def load_user_control(_user_control, _ext='', _pre='')
    return unless _ext && ext_active?(_ext)

    if _ext.length > 0 && self[_ext]
      _self_on_eval = self[_ext]
      suf = "#{_ext}.#{_user_control.class::SUF}"
    else
      _self_on_eval = self
      suf = "#{_user_control.class::SUF}"
    end
    if _pre.length > 0
      suf = "#{_pre}.#{suf}"
    end
    contexts = self['conf']["#{suf}.contexts"]
    contexts_caption = make_value(_self_on_eval, self['conf']["#{suf}.contexts.caption"])
    return if contexts.nil?
    groups = contexts.split(',')
    groups_caption = contexts_caption.split(',') if contexts_caption
    groups.each_with_index{|group, gi|
      if group
        suf1 = suf+'.'+group
        begin
          context_path = self['conf']["#{suf1}.context_path"]
          rif = self['conf']["#{suf1}.rif"] == nil ? 'main': self['conf']["#{suf1}.rif"]
          context_underline = self['conf']["#{suf1}.context_underline"]
          items = self['conf'][suf1].split(',')
          items.each{|item|
            suf2 = suf1+'.'+item
            disabled = !self['conf']["#{suf2}.disabled"].nil?
            iprops=Arcadia.conf_group(suf2)
            item_args = Hash.new
            iprops.each{|k,v|
              item_args[k]=make_value(_self_on_eval, v)
            }
            item_args['name'] = item if item_args['name'].nil?
            item_args['rif'] = rif
            item_args['context'] = group
            item_args['context_path'] = context_path
            item_args['context_caption'] = groups_caption[gi] if groups_caption
            item_args['context_underline'] = context_underline.strip.to_i if context_underline
            i = _user_control.new_item(_self_on_eval, item_args)
            i.enable=false if disabled
          }
        rescue Exception
          msg = Arcadia.text("main.e.loading_user_control.msg", [groups, items, $!.class.to_s, $!.to_s, $@.to_s])
          if Arcadia.dialog(self,
            'type'=>'ok_cancel',
            'title' => Arcadia.text("main.e.loading_user_control.title", [_user_control.class::SUF]),
            'msg'=>msg,
            'exception'=>$!,
            'level'=>'error')=='cancel'
            raise
            exit
          else
            Tk.update
          end
        end
      end
    }

  end

  def do_exit
    q1 = conf('confirm-on-exit')!='yes' || (Arcadia.dialog(self,
    'type'=>'yes_no',
    'msg'=> Arcadia.text("main.d.confirm_exit.msg"),
    'title' => Arcadia.text("main.d.confirm_exit.title"),
    'level' => 'question')=='yes')
    if q1 && can_exit?
      @root.geometry('1x1-1-1')
      #ArcadiaAboutSplash.new.deiconify
      do_finalize
      @root.destroy
      #      Tk.mainloop_exist?
      #      Tk.destroy
      Tk.exit
    end
  end

  def can_exit?
    _event = Arcadia.process_event(ExitQueryEvent.new(self, 'can_exit'=>true))
    _event.can_exit
  end

  def geometry_refine(_geometry)
    begin
      a = geometry_to_a(_geometry)
      toolbar_height = @root.winfo_height-@root.winfo_screenheight
      a[3] = (a[3].to_i - toolbar_height.abs).abs.to_s
      geometry_from_a(a)
    rescue
      return _geometry
    end
  end

  def geometry_to_a(_geometry=nil)
    return if _geometry.nil?
    wh,x,y=_geometry.split('+')
    w,h=wh.split('x')
    [w,h,x,y]
  end

  def geometry_from_a(_a=nil)
    return "0x0+0+0" if _a.nil? || _a.length < 4
    "#{_a[0]}x#{_a[1]}+#{_a[2]}+#{_a[3]}"
  end

  def save_layout
    self['conf']['geometry']= geometry_refine(TkWinfo.geometry(@root))
    begin
      if Arcadia.is_windows? || OS.mac?
        self['conf']['geometry.state'] = @root.state.to_s
      else
        if @root.wm_attributes('zoomed') == '1'
          self['conf']['geometry.state']='zoomed'
        else
          self['conf']['geometry.state']='normal'
        end
      end
    rescue
      self['conf']['geometry.state']='not_supported'
    end
    Arcadia.del_conf_group(self['conf'],'layout')
    # resizing
    @exts_i.each{|e|
      found = false
      if e.conf('frames')
        frs = e.conf('frames').split(',')
      else
        frs = Array.new
      end
      frs.each_index{|i|
        if e.maximized?(i)
          self['conf']['layout.maximized']="#{e.conf('name')},#{i}"
          e.resize(i)
          found=true
          break
        end
      }
      break if found
    }
    # layouts
    splits,doms,r,c = @layout.dump_geometry
    header = ""
    splits.each_index{|i|
      header << i.to_s
      header << ',' if i < splits.length-1
    }
    self['conf']['layout.split']= header
    splits.each_with_index{|sp,i|
      self['conf']["layout.split.#{i}"]=sp
    }
    # domains
    @exts_i.each{|e|
      if e.conf('frames')
        frs = e.conf('frames').split(',')
      else
        frs = Array.new
      end
      str_frames=''
      frs.each_index{|i|
        f = e.frame(i,false)
        if f
          ff = f.hinner_frame
          frame = ff.frame if ff
          if frame && TkWinfo.parent(frame).instance_of?(Tk::BWidget::NoteBook)
            frame=TkWinfo.parent(TkWinfo.parent(frame))
          elsif frame.nil?
            if str_frames.length > 0
              str_frames << ','
            end
            str_frames << ArcadiaLayout::HIDDEN_DOMAIN
          end
          if doms[frame]
            if str_frames.length > 0
              str_frames << ','
            end
            str_frames << doms[frame]
          end
        else
        end
      }
      if str_frames.length > 0
        self['conf']["#{e.conf('name')}.frames"]=str_frames
        #     p "#{e.conf('name')}.frames=#{str_frames}"
      end
    }
    # toolbar
    if @is_toolbar_show
      self['conf']['user_toolbar_show']='yes'
    else
      self['conf']['user_toolbar_show']='no'
    end
  end

  def do_finalize
    self.save_layout
    _event = Arcadia.process_event(FinalizeEvent.new(self))
    update_local_config
    self.override_persistent(self['applicationParams'].persistent_file, self['pers'])
  end

  def Arcadia.console(_sender, _args=Hash.new)
    _event = process_event(MsgEvent.new(_sender, _args))
    _event.mark
  end

  def Arcadia.console_input(_sender, _pid=nil)
    @@input_ready = true if !defined?(@@input_ready)
    while !@@input_ready && !@@input_ready.nil?
      sleep(0.1)
    end
    begin
      @@input_ready=false
      @@last_input_keyboard_query_event = InputKeyboardQueryEvent.new(_sender, :pid => _pid)
      @@last_input_keyboard_query_event.go!
      ret = @@last_input_keyboard_query_event.results.length > 0 ? @@last_input_keyboard_query_event.results[0].input : nil
    ensure
      @@input_ready=true
      @@last_input_keyboard_query_event=nil
    end
    ret
  end

  def Arcadia.console_input_event
    @@last_input_keyboard_query_event
  end

  def Arcadia.file_extension(_filename=nil)
    if _filename
      _m = /(.*\.)(.*$)/.match(File.basename(_filename))
    end
    _ret = (_m && _m.length > 1)?_m[2]: nil
  end

  def  Arcadia.runner_for_file(_filename=nil)
    if @@instance
      return @@instance['runners_by_ext'][Arcadia.file_extension(_filename)]
    end
  end

  def  Arcadia.runner_for_lang(_lang=nil)
    if @@instance
      return @@instance['runners_by_lang'][_lang]
    end
  end

  def  Arcadia.runner(_name=nil)
    if @@instance
      return @@instance['runners'][_name]
    end
  end


  def Arcadia.dialog(_sender, _args=Hash.new)
    if @@instance && @@instance.initialized?
      Arcadia.hinner_dialog(_sender, _args)
    else
      _event = process_event(SystemDialogEvent.new(_sender, _args))
      return _event.results[0].value if _event
    end
  end

  def Arcadia.hinner_dialog(_sender, _args=Hash.new)
    _event = process_event(HinnerDialogEvent.new(_sender, _args))
    return _event.results[0].value if _event
  end

  def Arcadia.style(_class)
    Configurable.properties_group(_class, Arcadia.instance['conf'])
  end

  def Arcadia.pers_group(_path, _refresh=false)
    Configurable.properties_group(_path, Arcadia.instance['pers'], 'pers', _refresh)
  end

  def Arcadia.conf_group(_path, _refresh=false)
    Configurable.properties_group(_path, Arcadia.instance['conf'], 'conf', _refresh)
  end

  def Arcadia.conf_group_without_local(_path, _refresh=false)
    Configurable.properties_group(_path, Arcadia.instance['conf_without_local'], 'conf_without_local', _refresh)
  end

  def Arcadia.conf_group_copy(_path_source, _path_target, _suff = 'conf')
    _target = conf_group(_path_source)
    _postfix = _path_target.sub(_path_source,"")
#      p "====== copy ======="
    _target.each{|k,v|
      if ["frames.labels","frames.names","name"].include?(k)
        v_a = v.split(',')
        new_val = ''
        v_a.each{|value|
          if new_val.length > 0
            new_val = "#{new_val},"
          end
          new_val = "#{new_val}#{value}#{_postfix}"
        }
        v = new_val
      end
      @@instance['conf']["#{_path_target}.#{k}"]=v
#      p "#{k} = #{v}"
    }
#    p "====== copy ======="
  end

  def Arcadia.persistent(_property, _value=nil, _immediate=false)
    if @@instance
      if _value.nil?
        return @@instance['pers'][_property]
      else
        @@instance['pers'][_property] = _value
      end
      if _immediate
        @@instance.append_persistent_property(@@instance['applicationParams'].persistent_file,_property, _value )
      end
    end
  end

  def Arcadia.unpersistent(_property, _immediate=false)
    if @@instance
      @@instance['pers'].delete(_property)
      if _immediate
        # not yet supported
      end
    end
  end

  def Arcadia.layout
    if @@instance
      return @@instance.layout
    end
  end

  def Arcadia.wf
    if @@instance
      return @@instance.wf
    end
  end

  def Arcadia.text(_key=nil, _params=nil)
    if @@instance
      return @@instance.localization.text(_key, _params)
    end
  end

  def Arcadia.open_system_file_dialog
    Tk.getOpenFile 'initialdir' => MonitorLastUsedDir.get_last_dir
  end

  def Arcadia.select_file_dialog(_initial_dir=MonitorLastUsedDir.get_last_dir, _label=nil)
    HinnerFileDialog.new(HinnerFileDialog::SELECT_FILE_MODE, nil, _label).file(_initial_dir)
  end

  def Arcadia.select_dir_dialog(_initial_dir=MonitorLastUsedDir.get_last_dir, must_exist = nil, _label=nil)
    HinnerFileDialog.new(HinnerFileDialog::SELECT_DIR_MODE, must_exist, _label).dir(_initial_dir)
  end

  def Arcadia.save_file_dialog(_initial_dir=MonitorLastUsedDir.get_last_dir)
    file = HinnerFileDialog.new(HinnerFileDialog::SAVE_FILE_MODE).file(_initial_dir)
    if !file.nil? && File.exists?(file) 
      if (Arcadia.dialog(self, 'type'=>'yes_no',
      'msg'=>Arcadia.text('main.d.confirm_override_file.msg', [file]),
      'title' => Arcadia.text('main.d.confirm_override_file.title'),
      'level' => 'question')=='yes')
          return file
      else
        return nil
      end
    else
      return file
    end
  end

  def Arcadia.open_string_dialog(_label=nil)
    HinnerStringDialog.new(_label).string
  end

  def Arcadia.is_windows?
    OS.windows?
    #RUBY_PLATFORM =~ /mingw|mswin/
  end

  def Arcadia.ruby
    @ruby_interpreter=Gem.ruby if !defined?(@ruby_interpreter)
    @ruby_interpreter
  end

  def Arcadia.which(_command=nil)
    return nil if _command.nil?
    _ret = nil
    _file = _command
    # command check
    if FileTest.exist?(_file)
      _ret = _file
    end
    # current dir check
    if _ret.nil?
      _file = File.join(Dir.pwd, _command)
      if FileTest.exist?(_file)
        _ret = _file
      end
    end
    # $PATH check
    if _ret.nil?
      begin
        ENV['PATH'].split(File::PATH_SEPARATOR).each{|_path|
          _file = File.join(_path, _command)
          if FileTest.exist?(_file)
            _ret = _file
            break
          end
        }
      rescue RuntimeError => e
        Arcadia.runtime_error(e)
      end
    end
    # gem path check
    gem_path = Gem.path
    gem_path.each{|_path|
      _file = File.join(_path,'bin',_command)
      if FileTest.exist?(_file)
        _ret = _file
        break
      end
    } if gem_path && gem_path.kind_of?(Array)
    # gem specific bin check
    if _ret.nil?
      begin
        _ret = Gem.bin_path(_command)
      rescue
        _ret = nil
      end
    end
    _ret
  end

  def Arcadia.[](_name)
    @@instance[_name]
  end

  def Arcadia.new_statusbar_item(_help=nil)
    _other =  @@last_status_item if defined?(@@last_status_item)
    @@last_status_item=@@instance.mf_root.add_indicator()
    @@last_status_item.configure(:background=>Arcadia.conf("background"))
    @@last_status_item.configure(:foreground=>Arcadia.conf("foreground"))
    @@last_status_item.configure(:font=>Arcadia.conf("font"))
    if _other
      @@last_status_item.pack('before'=>_other)
    end
    if _help
      Tk::BWidget::DynamicHelp::add(@@last_status_item, 'text'=>_help)
    end
    @@last_status_item
  end

  def Arcadia.menu_root(_menu_root_name, _menu_root=nil)
    if @@instance['menu_roots'] == nil
      @@instance['menu_roots'] = Hash.new
    end
    if _menu_root != nil
      @@instance['menu_roots'][_menu_root_name]= _menu_root
    end
    @@instance['menu_roots'][_menu_root_name]
  end

  def Arcadia.image_res(_name)
    if @@instance['image_res'] == nil
      @@instance['image_res'] = Hash.new
    end
    if @@instance['image_res'][_name].nil?
      @@instance['image_res'][_name] = TkPhotoImage.new('data' => _name)
    end
    @@instance['image_res'][_name]
  end

  def Arcadia.lang_icon(_lang=nil)
    icon = "FILE_ICON_#{_lang.upcase if _lang}"
    if _lang && eval("defined?(#{icon})")
      image_res(eval(icon))
    else
      image_res(FILE_ICON_DEFAULT)
    end
  end

  def Arcadia.file_icon(_file_name)
    _file_name = '' if _file_name.nil?
    if @@instance['file_icons'] == nil
      @@instance['file_icons'] = Hash.new
      @@instance['file_icons']['default']= image_res(FILE_ICON_DEFAULT)
      #TkPhotoImage.new('dat' => FILE_ICON_DEFAULT)
    end
    _base_name= File.basename(_file_name)
    if _base_name.include?('.')
      file_dn = _base_name.split('.')[-1]
    else
      file_dn = "no_ext"
    end
    if @@instance['file_icons'][file_dn].nil?
      file_icon_name="FILE_ICON_#{file_dn.upcase}"
      begin
        if eval("defined?(#{file_icon_name})")
          @@instance['file_icons'][file_dn]=image_res(eval(file_icon_name))
          #TkPhotoImage.new('dat' => eval(file_icon_name))
        else
          @@instance['file_icons'][file_dn]= @@instance['file_icons']['default']
        end
      rescue Exception
        @@instance['file_icons'][file_dn]= @@instance['file_icons']['default']
      end
    end
    @@instance['file_icons'][file_dn]
  end

  #  def Arcadia.res(_res)
  #    theme = Arcadia.instance['conf']['theme']
  #    if theme
  #      ret = eval("#{theme}::#{_res}")
  #    end
  #    ret=Res::_res if ret.nil?
  #    return ret
  #  end

  def Arcadia.menubar_item(_name=nil)
    if _name && @@instance && @@instance['menubar']
      return @@instance['menubar'].items(_name)
    end
  end

  def Arcadia.toolbar_item(_name=nil)
    if _name && @@instance && @@instance['toolbar']
      #@@instance['toolbar'].items.each{|k, v | p k}
      return @@instance['toolbar'].items[_name]
    end
  end

  def Arcadia.extension(_name=nil)
    if _name && @@instance && @@instance['exts_map']
      return @@instance['exts_map'][_name]
    end
  end

  def Arcadia.extensions
    if @@instance && @@instance.exts
      return @@instance.exts
    end
  end

  def Arcadia.runtime_error(_e, _title=Arcadia.text("main.e.runtime.title"))
    ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::RUNTIME_ERROR_TYPE,"title"=>"#{_title} : [#{_e.class}] #{_e.message} at :", "detail"=>_e.backtrace).go!
  end

  def Arcadia.runtime_error_msg(_msg, _title=Arcadia.text("main.e.runtime.title"))
    ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::RUNTIME_ERROR_TYPE,"title"=>"#{_title} at :", "detail"=>_msg).go!
  end
end

class ArcadiaUserControl
  SUF='user_control'
  class UserItem
    attr_accessor :name
    attr_accessor :rif
    attr_accessor :context
    attr_accessor :context_caption
    attr_accessor :caption
    attr_accessor :hint
    attr_accessor :action
    attr_accessor :event_class
    attr_accessor :event_args
    attr_accessor :image_data
    attr_reader :item_obj
    def initialize(_sender, _args)
      @sender = _sender
      if _args
        _args.each do |key, value|
          self.send(key+'=', value) if self.respond_to?(key)
        end
      end
      if @action
        @command = proc{Arcadia.process_event(_sender.instance_eval(@action))}
      elsif @event_class
        @command = proc{Arcadia.process_event(@event_class.new(_sender, @event_args))}
      end
    end

    def method_missing(m, *args)
      if @item_obj && @item_obj.respond_to?(m)
        @item_obj.send(m, *args)
      end
    end


    def enable=(_value)
    end

    def background
    end

    def foreground
    end

  end
  #  def initialize
  #    @items = Hash.new
  #  end
  def items
    @items = Hash.new if @items.nil?
    @items
  end

  def new_item(_sender, _args)
    item = self.class::UserItem.new(_sender, _args)
    items[_args['name']]= item if _args['name']
  end

end


class ArcadiaMainToolbar < ArcadiaUserControl
  SUF='user_toolbar'
  attr_reader :frame
  class UserItem < ArcadiaUserControl::UserItem 
    attr_accessor :frame
    attr_accessor :menu_button
    def initialize(_sender, _args)
      super(_sender, _args)
      _image = Arcadia.image_res(@image_data) if @image_data
      _command = @command #proc{Arcadia.process_event(@event_class.new(_sender, @event_args))} if @event_class
      _hint = @hint
      _font = @font
      _caption = @caption
      @item_obj = Arcadia.wf.toolbutton(_args['frame']){
        image  _image if _image
        command _command if _command
#        height 23
        width 23
        padding "5 0"
        text _caption if _caption
      }
      return if @item_obj.nil?
      @item_obj.hint=_hint

#      @item_obj = Tk::BWidget::Button.new(_args['frame'], Arcadia.style('toolbarbutton')){
#        image  _image if _image
#        command _command if _command
#        width 23
#        height 23
#        helptext  _hint if _hint
#        #compound 'left'
#      }
      if _args['context_path'] && _args['last_item_for_context']
        @item_obj.pack('after'=>_args['last_item_for_context'].item_obj, 'side' =>'left', :padx=>2, :pady=>0)
      else
        @item_obj.pack('side' =>'left', :padx=>2, :pady=>0)
      end
      if _args['menu_button'] && _args['menu_button'] == 'yes'

#        item_menu = TkMenu.new(mb)
#        if !OS.mac?
#          item_menu.configure(Arcadia.style('menu'))
#        end
        item_menu = Arcadia.wf.menu(mb)
        @menu_button = Arcadia.wf.menubutton(_args['frame']){|mb|
          menu item_menu
         # image Arcadia.image_res(MENUBUTTON_ARROW_DOWN_GIF)
          pack('side'=> 'left','anchor'=> 's','pady'=>3)
        }
      
      
#        @menu_button = TkMenuButton.new(_args['frame'], Arcadia.style('toolbarbutton')){|mb|
#          indicatoron false
#          menu TkMenu.new(mb, Arcadia.style('menu'))
#          image Arcadia.image_res(MENUBUTTON_ARROW_DOWN_GIF)
#          padx 0
#          pady 0
#          pack('side'=> 'left','anchor'=> 's','pady'=>3)
#        }
        Arcadia.menu_root(_args['name'], @menu_button.cget('menu'))
      end
      #Tk::BWidget::Separator.new(@frame, :orient=>'vertical').pack('side' =>'left', :padx=>2, :pady=>2, :fill=>'y',:anchor=> 'w')
    end

    def enable=(_value)
      if _value
        @item_obj.state='normal'
      else
        @item_obj.state='disabled' if !OS.mac? # Workaround for #1100117 on mac
      end
    end
  end


  def initialize(_arcadia, _frame)
    @arcadia = _arcadia
    @frame = _frame
    @frame.borderwidth(Arcadia.conf('panel.borderwidth'))
    #@frame.highlightbackground(Arcadia.conf('panel.highlightbackground'))
    @frame.relief(Arcadia.conf('panel.relief'))

    @context_frames = Hash.new
    @last_context = nil
    @last_item_for_context = Hash.new
  end

  def new_item(_sender, _args= nil)
    _context = _args['context']
    _context_path = _args['context_path']
    if @last_context && _context != @last_context && _context_path.nil?
      new_separator
    end
    @last_context = _context
    _args['frame']=@frame
    if _context_path && @last_item_for_context[_context_path]
      _args['last_item_for_context']=@last_item_for_context[_context_path]
    end

    super(_sender, _args)
    if _context_path && items[_args['name']]
      @last_item_for_context[_context_path] = items[_args['name']]
    end
    if _context && items[_args['name']]
      @last_item_for_context[_context] = items[_args['name']]
    end
  end

  def new_separator
    Tk::BWidget::Separator.new(@frame,
    :orient=>'vertical',
    :background=>Arcadia.conf('button.highlightbackground')
    ).pack('side' =>'left', :padx=>2, :pady=>2, :fill=>'y',:anchor=> 'w')
  end

end

class ArcadiaMainMenu < ArcadiaUserControl
  SUF='user_menu'
  attr_reader :menubar
  class UserItem < UserItem
    attr_accessor :menu
    attr_accessor :underline
    attr_accessor :type
    def initialize(_sender, _args)
      super(_sender, _args)
      item_args = Hash.new
      item_args[:image]=Arcadia.image_res(@image_data) if @image_data
      item_args[:label]=@caption
      item_args[:font]=Arcadia.conf('menu.font') if !OS.mac?
      item_args[:underline]=@underline.to_i if @underline != nil
      item_args[:compound]='left'
      item_args[:command]=@command
      if @type.nil? && @commnad.nil? && @name == '-'
        @type=:separator
        item_args.clear
      elsif @type.nil?
        @type=:command
      end
      @item_obj = @menu.insert('end', @type ,item_args)
      @index = @menu.index('last')
    end

    def enable=(_value)
      if _value
        @item_obj.entryconfigure(@index,'state'=>'normal')
      else
        @item_obj.entryconfigure(@index,'state'=>'disable')
      end
    end
  end
  
  def initialize(root)
    # Creating Menubar
    @menubar = Arcadia.wf.menu(root)
#    @menubar = TkMenu.new(root)
    begin
#      if !OS.mac?
#        @menubar.configure(Arcadia.style('menu').delete_if {|key, value| key=='tearoff'}) 
#        @menubar.extend(TkAutoPostMenu)
#        @menubar.event_posting_on
#      end
      root['menu'] = @menubar
      @menu_contexts = {}
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
  end
  
  def get_menu_context(_menubar, _context, _underline=nil)
    m = @menu_contexts[_context]
    if !m.nil? 
      m
    else
      topmenu = Arcadia.wf.menu(_menubar)
#      topmenu = TkMenu.new(_menubar)
#      if !OS.mac?
#        topmenu.configure(Arcadia.style('menu'))
#        topmenu.extend(TkAutoPostMenu)
#      end
      opt = {:menu => topmenu, :label => _context}
      opt[:underline]=_underline if _underline
      _menubar.add(:cascade, opt)
      @menu_contexts[_context] = topmenu
      topmenu
    end
  end

  def ArcadiaMainMenu.sub_menu(_menu, _title=nil)
    s_i = -1
    if _title
      i_end = _menu.index('end')
      if i_end
        0.upto(i_end){|j|
          type = _menu.menutype(j)
          if type != 'separator'
            l = _menu.entrycget(j,'label')
            if l == _title && type == 'cascade'
              s_i = j
              break
            end
          end
        }
      end
    end
    if s_i > -1
      sub = _menu.entrycget(s_i, 'menu')
    else
      sub = nil
    end
    sub  
  end

  def get_sub_menu(menu_context, folder=nil)
    sub = ArcadiaMainMenu.sub_menu(menu_context, folder)
    if sub.nil?
      sub = Arcadia.wf.menu(:tearoff=>0)
#      sub = TkMenu.new(
#      :tearoff=>0
#      )
#      if !OS.mac?
#        sub.configure(Arcadia.style('menu'))
#        sub.extend(TkAutoPostMenu)
#      end
      #update_style(sub)
      menu_context.insert('end',
      :cascade,
      :label=>folder,
      :menu=>sub,
      :hidemargin => false
      )
    end
    sub
  end

  def make_menu_in_menubar(_menubar, _context, context_path, context_underline=nil)
    context_menu = get_menu_context(_menubar, _context, context_underline)
    make_menu(context_menu, context_path, context_underline)
  end

  def make_menu(_menu, context_path, context_underline=nil)
    folders = context_path.split('/')
    sub = _menu
    folders.each{|folder|
      sub = get_sub_menu(sub, folder)
    }
    sub
  end

  def new_item(_sender, _args= nil)
    return if _args.nil?

    if _args['context_caption']
      conte = _args['context_caption']
    else
      conte = _args['context']
    end
    if _args['rif'] == 'main'
      _args['menu']=make_menu_in_menubar(@menubar, conte, _args['context_path'], _args['context_underline'])
    else
      if Arcadia.menu_root(_args['rif'])
        _args['menu']=make_menu(Arcadia.menu_root(_args['rif']), _args['context_path'], _args['context_underline'])
      else
        msg = Arcadia.text("main.e.adding_new_menu_item.msg", [_args['name'], _args['rif']])
        Arcadia.dialog(self,
        'type'=>'ok',
        'title' => Arcadia.text("main.e.adding_new_menu_item.title",[self.class::SUF]),
        'msg'=>msg,
        'level'=>'error')

        _args['menu']=make_menu_in_menubar(@menubar, conte, _args['context_path'], _args['context_underline'])
      end
    end
    super(_sender, _args)
  end

end

#class RunnerManager < TkFloatTitledFrame
class RunnerManager < HinnerSplittedDialogTitled
  ROW_GAP = 25
  class RunnerMangerItem #  < TkFrame
    attr_reader :runner_hash , :readonly
    def initialize(_runner_manager, _parent=nil, _runner_hash=nil, _row=0, _state_array=nil, *args)
      #super(_parent, Arcadia.style('panel'))
      @runner_hash = _runner_hash
      @readonly = _state_array && _state_array.include?(:disabled)
      @enable_close_button = !@readonly || _runner_hash[:origin] == 'runtime'
      
      @h_hash = {}
            
      p_update_height = proc{|tktext|
        index = tktext.index('end -1 chars')
        r,c = index.split('.')
        if tktext.cget('wrap') != 'none'
          w = tktext.width
          h = ((c.to_i-1)/w.to_i).round + 1
        else
          h = r.to_i
        end
        h_to_set = h
        @h_hash.each{|k,v|  h_to_set = v if k != tktext && v > h_to_set }
        @h_hash[tktext] = h
        if tktext.height != h_to_set
          tktext.height(h_to_set)
          @h_hash.each{|k,v|
            p_update_height.call(k) if k != tktext
          }
          
        end
      }


      # ICON
      @ttklicon = Arcadia.wf.label(_parent,
        'image'=> _runner_hash[:image].nil? ? Arcadia.file_icon(_runner_hash[:file_exts]) : Arcadia.image_res(_runner_hash[:image]) ,
        'relief'=>'flat').grid(:column => 0, :row => _row, :sticky => "W", :padx=>1, :pady=>1)
      @ttklicon.state(:disabled) if @readonly

      # NAME
      @ename_old = _runner_hash[:name]  
      @ttkename = Arcadia.wf.text(_parent, 'width' => 20,
        "height" => 1).hint(_runner_hash[:file]).grid(:column => 1, :row => _row, :sticky => "WE", :padx=>1, :pady=>1)
      @ttkename.insert('end', _runner_hash[:name])
      @ttkename.state(:disabled) && @ttkename.fg('darkgray') if @readonly
      

      # TITLE
      @etitle_old = _runner_hash[:title]  
      @ttketitle = Arcadia.wf.text(_parent, 'width' => 28,
        "height" => 1).hint(_runner_hash[:file]).grid(:column => 2, :row => _row, :sticky => "WE", :padx=>1, :pady=>1)
      @ttketitle.insert('end', _runner_hash[:title])
      @ttketitle.state(:disabled) && @ttketitle.fg('darkgray') if @readonly


      # CMD
      @ecmd_old = _runner_hash[:cmd]
      @ttkecmd = Arcadia.wf.text(_parent,  'width' => 60, 'wrap'=>'word',
        "height" => 1).grid(:column => 3, :row => _row, :sticky => "WE", :padx=>1, :pady=>1)
      @ttkecmd.insert('end', _runner_hash[:cmd])
      @ttkecmd.state(:disabled) && @ttkecmd.fg('darkgray') if @readonly
      
      # FILE EXTS
      @eexts_old = _runner_hash[:file_exts]  
      @ttkeexts = Arcadia.wf.text(_parent,  'width' => 5,
        "height" => 1).grid(:column => 4, :row => _row, :sticky => "WE", :padx=>1, :pady=>1)
      @ttkeexts.insert('end', _runner_hash[:file_exts])
      @ttkeexts.state(:disabled) && @ttkeexts.fg('darkgray') if @readonly

      # COPY BUTTON
      copy_command = proc{ _runner_manager.do_add(self) }
      @ttkbcopy = Arcadia.wf.toolbutton(_parent,
        'command'=> copy_command,
        'image'=> Arcadia.image_res(COPY_GIF)
      ).grid(:column => 5, :row => _row, :sticky => "W", :padx=>1, :pady=>1)
        
      # DELETE BUTTON
      close_command = proc{
        if (Arcadia.hinner_dialog(self, 'type'=>'yes_no',
          'msg'=> Arcadia.text("main.d.confirm_delete_runner.msg", [_runner_hash[:name]]),
          'title' => Arcadia.text("main.d.confirm_delete_runner.title"),
          'level' => 'question')=='yes')

          if _runner_hash[:origin] == 'runtime'
            Arcadia.unpersistent("runners.#{_runner_hash[:name]}")
          else
            Arcadia.del_conf("runners.#{_runner_hash[:name]}")
          end
          mr = Arcadia.menu_root('runcurr')
          index_to_delete = -1
          i_end = mr.index('end')
          if i_end
            0.upto(i_end){|j|
              type = mr.menutype(j)
              if type != 'separator'
                l = mr.entrycget(j,'label')
                if l == _runner_hash[:title]
                  index_to_delete = j
                  break
                end
              end
            }
          end
          if index_to_delete > -1
            mr.delete(index_to_delete)
          end
          _runner_manager.do_delete_item(self)
          self.destroy
        end
      }
      @ttkbclose = Arcadia.wf.toolbutton(_parent,
        'command'=> close_command,
        'image'=> Arcadia.image_res(CLOSE_FRAME_GIF)
        ).grid(:column => 6, :row => _row, :sticky => "W", :padx=>1, :pady=>1)
      @ttkbclose.hint=@runner_hash[:file]
      @ttkbclose.state(:disabled) if !@enable_close_button

      [@ttkename, @ttketitle, @ttkecmd, @ttkeexts].each{|tktext|
        p_update_height.call(tktext)
        tktext.bind_append("KeyRelease"){p_update_height.call(tktext)}
      }

    end
    
    def destroy
      @ttklicon.destroy
      @ttkename.destroy
      @ttketitle.destroy
      @ttkecmd.destroy
      @ttkeexts.destroy
      @ttkbcopy.destroy
      @ttkbclose.destroy
    end
    
    def hash_value
      ret = {}
      ret[:name]=@ttkename.value
      ret[:title]=@ttketitle.value
      ret[:cmd]=@ttkecmd.value
      ret[:file_exts]=@ttkeexts.value
      ret[:image]=@runner_hash[:image] if @runner_hash[:image] 
      ret  
    end
    
    def name_change?
      @ename_old != @ttkename.value
    end

    def title_change?
      @etitle_old != @ttketitle.value
    end

    def cmd_change?
      @ecmd_old != @ttkecmd.value
    end

    def exts_change?
      @eexts_old != @ttkeexts.value
    end
    
    def change?
      title_change? || cmd_change? || exts_change? || exts_change? || name_change?
    end
    
    def reset_change
      @ename_old = @ttkename.value
      @etitle_old = @ttketitle.value
      @ecmd_old = @ttkecmd.value
      @eexts_old = @ttkeexts.value
    end
  end

  def initialize(_parent)
    super("Runners manager")
    @addb = @titled_frame.add_fixed_button('[Add Runner]',proc{do_add})
    @saveb = @titled_frame.add_fixed_button('[Save]',proc{do_save})

    @items = Hash.new
    @content = Hash.new
    @content_root = Tk::ScrollFrame.new(self.hinner_frame).place('x'=>0, 'y'=>0, 'relheight'=>1, 'relwidth'=>1)
    @content_root_frame = @content_root.baseframe

  end

  def do_close
    if something_has_changed?
      if Arcadia.dialog(self,
        'type'=>'yes_no',
        'msg'=> Arcadia.text("main.d.confirm_exit_runners_manager.msg"),
        'title' => Arcadia.text("main.d.confirm_exit_runners_manager.title"),
        'level' => 'question')!='yes'
        return
      end
    end
    super()
  end

  def do_add(_runner_from=nil)
    if _runner_from
      runner_hash = _runner_from.hash_value
      runner_hash[:name]="copy of #{runner_hash[:name]}"
    else
      runner_hash = {}
    end
    @items[:config]["item#{@items[:config].count}"]=RunnerMangerItem.new(self, @content[:config], runner_hash, @items[:config].count+1)
   # @content[:config].pack
#    root_height = Arcadia.instance.root_height
#    
#    self.height(self.height + ROW_GAP) if self.height < root_height
    add_gap
    @content_root.yview_moveto('1.0')
  end
  
  def add_gap
    #p @content_root.y_scrolled?
    root_height = Arcadia.instance.root_height
    if self.height < root_height/2
      self.height(self.height + ROW_GAP)
      @content_root.vscroll(true) if !@content_root.y_scrolled?
    end
  end
  
  def del_gap
    self.height(self.height - ROW_GAP)
  end
  
  def do_delete_item(_item, _tyme=:config)
    @items[:config].delete_if{|k,v| v == _item}
    del_gap
    #self.height(self.height - ROW_GAP)
  end

  def something_has_changed?
    ret = false
    @items.each_value{|i|
      i.each_value{|j| 
        ret = ret || (!j.readonly && j.change?)
        break if ret
      }
      break if ret
    }
    ret 
  end

  def do_save
    items_saved = []
    @items.each_value{|i| 
      i.each_value{|j| 
        if !j.readonly && j.change?
          jhash = j.hash_value 
          name = jhash[:name].gsub(" ", "_")
          Arcadia.conf("runners.#{name}", jhash.to_s)
          j.reset_change
          items_saved << name
        end
      }
    }
    Arcadia.instance.update_local_config
    Arcadia.instance.reload_runners
    if items_saved.count >0
      Arcadia.dialog(self, 
        'type'=>'ok', 
        'title' => "Save info", 
            'msg'=>"Saved #{items_saved.to_s}!",
            'level'=>'info')
    else
      Arcadia.dialog(self, 
        'type'=>'ok', 
        'title' => "Save info", 
            'msg'=>"Nothing done!",
            'level'=>'info')
    end
  end
  
  def clear_items
    @items.each_value{|i| 
      i.each_value{|j|  j.destroy }
      i.clear
    }
    #@items.clear
  end

  def load_tips
    # Runners keywords related the current file => <<FILE>>, <<DIR>>, <<FILE_BASENAME>>, <<FILE_BASENAME_WITHOUT_EXT>>, <<INPUT>>, <<INPUT_FILE>>
    # INPUT is required to user
    text = Arcadia.wf.text(@content_root_frame,
              "height" => 2 ,
              "bg"=>'teal'    
           ).pack('side' =>'top','anchor'=>'nw','fill'=>'x','padx'=>5, 'pady'=>5)
    text.insert("end", "Keywords => <<RUBY>>, <<FILE>>, <<DIR>>, <<FILE_BASENAME>>, <<FILE_BASENAME_WITHOUT_EXT>>, <<INPUT_FILE>>, <<INPUT_DIR>>, <<INPUT_STRING>>")
    add_gap
    #self.height(self.height + ROW_GAP)
  end

  def load_titles(_content)
    bg = Arcadia.conf("titlelabel.background")
    fg = Arcadia.conf("titlelabel.foreground")
#    # ICON
#    Arcadia.wf.label(_content,
#      'text'=> "" ,
#      'background'=> bg,
#      'relief'=>'flat').grid(:column => 0, :row => 0, :sticky => "WE", :padx=>1, :pady=>1)

    # NAME
    Arcadia.wf.label(_content,
      'text'=> "Name",
      'background'=> bg,
      'foreground'=> fg,
      'relief'=>'flat').grid(:column => 1, :row => 0, :sticky => "WE", :padx=>1, :pady=>1)


    # TITLE
    Arcadia.wf.label(_content,
      'text'=> "Title" ,
      'background'=> bg,
      'foreground'=> fg,
      'relief'=>'flat').grid(:column => 2, :row => 0, :sticky => "WE", :padx=>1, :pady=>1)

    # CMD
    Arcadia.wf.label(_content,
      'text'=> "CMD" ,
      'background'=> bg,
      'foreground'=> fg,
      'relief'=>'flat').grid(:column => 3, :row => 0, :sticky => "WE", :padx=>1, :pady=>1)
    
    # FILE EXTS
    Arcadia.wf.label(_content,
      'text'=> "Exts" ,
      'background'=> bg,
      'foreground'=> fg,
      'relief'=>'flat').grid(:column => 4, :row => 0, :sticky => "WE", :padx=>1, :pady=>1)
  end

  def load_items(_kind = :runtime)
    items = @items[_kind]
    if items.nil?
      items = @items[_kind] = Hash.new
    end
    if _kind == :runtime
      runs_pers=Arcadia.pers_group('runners', true)
      runs = {}
      runs_pers.each{|k, v|
        runs[k]="#{v}|||runtime"
      }
    elsif _kind == :config
      runs_with_local=Arcadia.conf_group('runners', true)
      runs_without_local = Arcadia.conf_group_without_local('runners', false)
      runs = {}

      # loading extensions runners
      Arcadia.extensions.each{|ext|
        ext_runs = Arcadia.conf_group("#{ext}.runners", true)
        if ext_runs && !ext_runs.empty?
          ext_runs_enanched = {}
          ext_runs.each{|k, v|
            ext_runs_enanched[k]="#{v}|||#{ext}"
          }
          runs.update(ext_runs_enanched)
        end
      }      
      
      # loading main runners
      runs_with_local.each{|k,v|
        if runs_without_local.include?(k)
          runs[k]="#{v}|||main"
        else
          runs[k]=v
        end
      }
      
    end
    @content[_kind] = Arcadia.wf.frame(@content_root_frame){padding "3 3 12 12"}

    @content[_kind].pack('fill'=>'both')
    #@content.extend(TkScrollableWidget).show
    # ICON
    TkGrid.columnconfigure(@content[_kind], 0, :weight => 0 , :uniform => 'a')
    # NAME
    TkGrid.columnconfigure(@content[_kind], 1, :weight => 1 )
    # TITLE
    TkGrid.columnconfigure(@content[_kind], 2, :weight => 2 )
    # CMD
    TkGrid.columnconfigure(@content[_kind], 3, :weight => 3 )
    # FILE EXTS
    TkGrid.columnconfigure(@content[_kind], 4, :weight => 1 )
    # COPY BUTTON
    TkGrid.columnconfigure(@content[_kind], 5, :weight => 0, :uniform => 'a' )
    # DELETE BUTTON
    TkGrid.columnconfigure(@content[_kind], 6, :weight => 0, :uniform => 'a' )
    TkGrid.propagate(@content[_kind], true)
    load_titles(@content[_kind])
    runs.keys.reverse.each{|name|
      hash_string = runs[name]
      hash_string, origin = hash_string.split("|||")
      item_hash = eval hash_string
      item_hash[:name]=name
      if item_hash[:runner] && Arcadia.runner(item_hash[:runner])
        item_hash = Hash.new.update(Arcadia.runner(item_hash[:runner])).update(item_hash)
      end
      if origin
        item_hash[:origin] = origin
        state_array = [] << :disabled
      end
      items[name]=RunnerMangerItem.new(self, @content[_kind], item_hash, items.count+1, state_array)
      #self.height(self.height + ROW_GAP)
      add_gap
   }
  end
end

class ArcadiaAboutSplash < TkToplevel
  attr :progress
  def initialize
    #_bgcolor = '#B83333'
    _bgcolor = '#000000'
    super()
    relief 'groove'
    #relief 'flat'
    background  _bgcolor
    highlightbackground  _bgcolor
    highlightthickness  1
    borderwidth 2
    withdraw
    overrideredirect(true)
    # dim 60x86
    @llogo = TkLabel.new(self){
      image  Arcadia.image_res(A_LOGO_GIF)
      background  _bgcolor
      #place('x'=> 20,'y' => 20)
      place('x'=> 140,'y' => 55)
    }


    #    @tkLabel1 = TkLabel.new(self){
    #      text 'Arcadia'
    #      background  _bgcolor
    #      foreground  '#ffffff'
    #      font Arcadia.conf('splash.title.font')
    #      justify  'left'
    #      place('width' => '190','x' => 110,'y' => 10,'height' => 25)
    #    }

#    @tkLabel1 = TkLabel.new(self){
#      image  Arcadia.image_res(ARCADIA_JAP_WHITE_GIF)
#      background  _bgcolor
#      justify  'left'
#      place('x' => 90,'y' => 10)
#    }

    @tkLabel1 = TkLabel.new(self){
      image  Arcadia.image_res(ARCADIA_7THE_GIF)
      background  _bgcolor
      justify  'left'
      place('x' => 26,'y' => 10)
    }

#    @tkLabelRuby = TkLabel.new(self){
#      image Arcadia.image_res(RUBY_DOCUMENT_GIF)
#      background  _bgcolor
#      place('x'=> 210,'y' => 12)
#    }

#    @tkLabel2 = TkLabel.new(self){
#      text  'Arcadia IDE'
#      background  _bgcolor
#      foreground  '#ffffff'
#      font Arcadia.instance['conf']['splash.subtitle.font']
#      justify  'left'
#      place('x' => 100,'y' => 40,'height' => 19)
#    }

    @tkLabelVersion = TkLabel.new(self){
      text Arcadia.text('main.about.version', [$arcadia['applicationParams'].version])
      background  _bgcolor
      foreground  '#009999'
      font Arcadia.instance['conf']['splash.version.font']
      justify  'left'
      #place('x' => 100,'y' => 65,'height' => 19)
      place('x' => 28,'y' => 47,'height' => 19)
    }
    @tkLabel21 = TkLabel.new(self){
      text  Arcadia.text("main.about.by", ['Antonio Galeone - 2004/2015'])
      background  _bgcolor
      foreground  '#009999'
      font Arcadia.instance['conf']['splash.credits.font']
      justify  'left'
      anchor 'w'
      place('width' => '220','x' => 28,'y' => 32,'height' => 19)
    }

#    @tkLabelCredits = TkLabel.new(self){
#      text  Arcadia.text("main.about.contributors", ['Roger D. Pack'])
#      background  _bgcolor
#      foreground  '#ffffff'
#      font Arcadia.instance['conf']['splash.credits.font']
#      justify  'left'
#      anchor 'w'
#      place('width' => '210','x' => 100,'y' => 115,'height' => 25)
#    }

    @tkLabelStep = TkLabel.new(self){
      text  ''
      background  _bgcolor
      foreground  '#009999'
      font Arcadia.instance['conf']['splash.banner.font']
      justify  'left'
      anchor  'w'
      place('width'=>-28,'relwidth' => 1,'x' => 28,'y' => 160,'height' => 45)
    }
    @progress  = TkVariable.new
    reset
    _width = 345
    _height = 210
    #_width = 0;_height = 0
    _x = TkWinfo.screenwidth(self)/2 -  _width / 2
    _y = TkWinfo.screenheight(self)/2 -  _height / 2
    geometry = _width.to_s+'x'+_height.to_s+'+'+_x.to_s+'+'+_y.to_s
    Tk.tk_call('wm', 'geometry', self, geometry )
    bind("Double-Button-1", proc{self.destroy})
    info = TkApplication.sys_info
    set_sysinfo(info)
    Arcadia.attach_listener(self, ArcadiaProblemEvent)
    Arcadia.attach_listeners_listener(self, BuildEvent)
  end
  
  def on_build(_event, _listener)
    next_step("... building #{_listener.class}")
  end

  def on_before_build(_event, _listener)
    next_step("... pre building #{_listener.class}")
  end

  def on_after_build(_event, _listener)
    next_step("... after building #{_listener.class}")
  end

  def problem_str
    @problems_nums > 1 ? "#{@problems_nums} problems found!" : "#{@problems_nums} problem found!"
  end

  def on_arcadia_problem(_event)
    if !defined?(@problems_nums)
      @problems_nums=0
      #@problem_str = proc{@problems_nums > 1 ? "#{@problems_nums} problems found!" : "#{@problem_nums} problem found!"}
      @tkAlert = TkLabel.new(self){
        image Arcadia.image_res(ALERT_GIF)
        background  'black'
        place('x'=> 28,'y' => 152)
      }

      @tkLabelProblems = TkLabel.new(self){
        text  ''
        background  'black'
        foreground  'red'
        font Arcadia.instance['conf']['splash.problems.font']
        justify  'left'
        anchor 'w'
        place('width' => '210','x' => 46,'y' => 150,'height' => 25)
      }
    end
    @problems_nums=@problems_nums+1
    @tkLabelProblems.text=problem_str if @tkLabelProblems
  end

  def set_sysinfo(_info)
    @tkLabelStep.text(_info)
  end

  def set_progress(_max=10)
    @max = _max
    Tk::BWidget::ProgressBar.new(self, :width=>340, :height=>5,
      :background=>'#000000',
      :troughcolor=>'#000000',
      :foreground=>'#990000',
      :variable=>@progress,
      :borderwidth=>0,
      :relief=>'flat',
#      :maximum=>_max).place('relwidth' => '1','y' => 145,'height' => 1)
#      :maximum=>_max).place('width' => '280','x'=>28,'y' => 33,'height' => 1)
      :maximum=>_max).place('width' => '280','x'=>28,'y' => 189,'height' => 10)
  end

  def reset
    @progress.value = -1
  end

  def next_step(_txt = nil)
    @progress.numeric += 1
    labelStep("#{perc}% #{_txt}")
  end

  def perc
    ret = @progress.numeric*100/@max
    ret > 100 ? 100:ret
  end

  def labelStep(_txt)
    @tkLabelStep.text = _txt
    Tk.update
  end

  def last_step(_txt = nil)
    @progress.numeric = @max
    labelStep(_txt) if _txt
    Arcadia.detach_listener(self, ArcadiaProblemEvent)
    Arcadia.detach_listeners_listener(self, BuildEvent)
  end
end


class ArcadiaProblemsShower
  def initialize(_arcadia)
    @arcadia = _arcadia
    @showed = false
    @initialized = false
    #@visible = false
    @problems = Array.new
    @seq = 0
    @dmc=0
    @rec=0
    Arcadia.attach_listener(self, ArcadiaProblemEvent)
    Arcadia.attach_listener(self, InitializeEvent)
  end

  def on_arcadia_problem(_event)
    @problems << _event
    if @initialized
      if !@showed
        show_problems
      else
        append_problem(_event)
        #@b_err.configure('text'=> button_text)
      end
    end
  end

  def on_after_initialize(_event)
    @initialized = true
    if @problems.count > 0
      show_problems
      Thread.new do
        num_sleep = 0
        while TkWinfo.viewable(Arcadia.layout.root) == false && num_sleep < 20
          sleep(1)
          num_sleep += 1
        end
        @ff.show
      end
#      p TkWinfo.viewable(Arcadia.layout.root)
#      Tk.after(1000, proc{@ff.show; p TkWinfo.viewable(Arcadia.layout.root)})
      
    end
  end

  def show_problems
    begin
      initialize_gui
      @problems.each{|e|
        append_problem(e)
      }
#      if @tree.exist?('dependences_missing_node')
#        @tree.open_tree('dependences_missing_node', true)
#      end
#      if @tree.exist?('runtime_error_node')
#        @tree.open_tree('runtime_error_node', true)
#      end
      @showed=true
    rescue RuntimeError => e
      Arcadia.detach_listener(self, ArcadiaProblemEvent)
      Arcadia.detach_listener(self, InitializeEvent)
    end
  end

  def button_text
    @problems.count > 1 ? Arcadia.text("main.ps.problems", [@problems.count]) : Arcadia.text("main.ps.problem", [@problems.count])
  end


  def initialize_gui
    # float_frame
#    args = {'width'=>600, 'height'=>300, 'x'=>400, 'y'=>100}
#    @ff = @arcadia.layout.add_float_frame(args).hide
#    @ff.title(Arcadia.text("main.ps.title"))
#
#    #tree
#    @tree = BWidgetTreePatched.new(@ff.frame, Arcadia.style('treepanel')){
#      showlines false
#      deltay 22
#    }
#    @tree.extend(TkScrollableWidget).show(0,0)
#
#    do_double_click = proc{
#      _selected = @tree.selected
#      _selected_text = @tree.itemcget(_selected, 'text')
#      if _selected_text
#        _file, _row, _other = _selected_text.split(':')
#        if File.exist?(_file)
#          begin
#            r = _row.strip.to_i
#            integer = true
#          rescue Exception => e
#            integer = false
#          end
#          if integer
#            OpenBufferTransientEvent.new(self,'file'=>_file, 'row'=>r).go!
#          end
#        end
#      end
#    }
#    @tree.textbind_append('Double-1',do_double_click)
#
#
#    # call button
#    command = proc{
#      if @ff.visible?
#        @ff.hide
#        #@visible = false
#      else
#        @ff.show
#        #@visible = true
#      end
#    }
#
#    b_style = Arcadia.style('toolbarbutton')
#    b_style["relief"]='groove'
#    #    b_style["borderwidth"]=2
#    b_style["highlightbackground"]='red'
#
#    b_text = button_text
#
#    @b_err = Tk::BWidget::Button.new(@arcadia['toolbar'].frame, b_style){
#      image  Arcadia.image_res(ALERT_GIF)
#      compound 'left'
#      padx  2
#      command command if command
#      #width 100
#      #height 20
#      #helptext  _hint if _hint
#      text b_text
#    }.pack('side' =>'left','before'=>@arcadia['toolbar'].items.values[0].item_obj, :padx=>2, :pady=>0)

  end


  def new_sequence_value
    @seq+=1
  end

  def append_problem(e)
#    parent_node='root'
    case e.type
    when ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE
#      parent_node='dependences_missing_node'
      text = Arcadia.text("main.ps.dependences_missing")
#      if !@tree.exist?(parent_node)
#        @tree.insert('end', 'root' ,parent_node, {
#          'text' =>  text ,
#          'helptext' => text,
#          'drawcross'=>'auto',
#          'deltax'=>-1,
#          'image'=> Arcadia.image_res(BROKEN_GIF)
#        }.update(Arcadia.style('treeitem'))
#        )
#
#      end
#      @dmc+=1
#      @tree.itemconfigure('dependences_missing_node','text'=>"#{text} (#{@dmc})" )

    when ArcadiaProblemEvent::RUNTIME_ERROR_TYPE
#      parent_node='runtime_error_node'
      text = Arcadia.text("main.ps.runtime_errors")
#      if !@tree.exist?(parent_node)
#        @tree.insert('end', 'root' ,parent_node, {
#          'text' =>  text ,
#          'helptext' => text,
#          'drawcross'=>'auto',
#          'deltax'=>-1,
#          'image'=> Arcadia.image_res(ERROR_GIF)
#        }.update(Arcadia.style('treeitem'))  #.update({'fill'=>Arcadia.conf('inactiveforeground')}))
#        )
#      end
#      @rec+=1
#      @tree.itemconfigure('runtime_error_node','text'=>"#{text} (#{@rec})" )
    end

    output_mark = Arcadia.console(self,'msg'=>"#{text} : ", 'level'=>'system_error', 'mark'=>output_mark)      

    title_node="node_#{new_sequence_value}"
    detail_node="detail_of_#{title_node}"

#    @tree.insert('end', parent_node ,title_node, {
#      'text' =>  e.title ,
#      'helptext' => e.title,
#      'drawcross'=>'auto',
#      'deltax'=>-1,
#      'image'=> Arcadia.image_res(ITEM_GIF)
#    }.update(Arcadia.style('treeitem'))  
#    )


    if e.detail.kind_of?(Array)
#      e.detail.each_with_index{|line,i|
#        @tree.insert('end', title_node , "#{detail_node}_#{i}" , {
#          'text' =>  line ,
#          'helptext' => i.to_s,
#          'drawcross'=>'auto',
#          'deltax'=>-1,
#          'image'=> Arcadia.image_res(ITEM_DETAIL_GIF)
#        }.update(Arcadia.style('treeitem'))  
#        )
#     }
    else
#      @tree.insert('end', title_node , detail_node , {
#        'text' =>  e.detail ,
#        'helptext' => e.title,
#        'drawcross'=>'auto',
#        'deltax'=>-1,
#        'image'=> Arcadia.image_res(ITEM_DETAIL_GIF)
#      }.update(Arcadia.style('treeitem'))  
#      )
    end

    output_mark = Arcadia.console(self,'msg'=>"#{e.title}\n> #{e.detail}", 'level'=>'system_error', 'mark'=>output_mark, 'append'=>true)      

  end
end


class ArcadiaActionDispatcher

  def initialize(_arcadia)
    @arcadia = _arcadia
    Arcadia.attach_listener(self, ActionEvent)
  end

  def on_action(_event)
    if _event.receiver != nil && _event.receiver.respond_to?(_event.action)
      if _event.action_args.nil?
        _event.receiver.send(_event.action)
      else
        _event.receiver.send(_event.action, _event.action_args)
      end
    end
  end

end

class ArcadiaLocalization
  include Configurable
  KEY_CACHE_VERSION = '__VERSION__'
  STANDARD_LOCALE = 'en-UK'
  PARAM_SIG = '$'
  attr_reader :lc_lang
  def initialize
    @standard_locale=Arcadia.conf("locale.standard").nil? ? STANDARD_LOCALE : Arcadia.conf("locale.standard")
    @locale=Arcadia.conf("locale").nil? ? STANDARD_LOCALE : Arcadia.conf("locale")
    lc_lang_standard_file="conf/LC/#{Arcadia.conf('locale.standard')}.LANG"
    lc_lang_locale_file="conf/LC/#{Arcadia.conf('locale')}.LANG"
    need_cache_update = false
    if @standard_locale == @locale || !File.exist?(lc_lang_locale_file)
      @lc_lang = properties_file2hash(lc_lang_standard_file) if File.exist?(lc_lang_standard_file)
    else
      lc_lang_cache_file=File.join(Arcadia.local_dir, "#{Arcadia.conf('locale')}.LC_LANG_CACHE")
      if File.exist?(lc_lang_cache_file)
        @lc_lang = properties_file2hash(lc_lang_cache_file)
        if @lc_lang[KEY_CACHE_VERSION] != Arcadia.version
          # is to update
          need_cache_update = true
        end
      else
        need_cache_update = true
      end
      if need_cache_update
        @lc_lang = properties_file2hash(lc_lang_standard_file)
        @lc_lang.each_pair{|key,value| @lc_lang[key] = "#{@locale}:#{value}"}
        if File.exist?(lc_lang_locale_file)
          lc_lang_locale = properties_file2hash(lc_lang_locale_file)
        else
          lc_lang_locale = {}
        end
        lc_lang_locale.each{|k,v| @lc_lang[k]=v}
        @lc_lang[KEY_CACHE_VERSION]=Arcadia.version
        hash2properties_file(@lc_lang, lc_lang_cache_file)
      end
    end
  end

  def text(_key, _params = nil)
    ret = @lc_lang.nil?||@lc_lang[_key].nil? ? "?" : @lc_lang[_key]
    if !_params.nil?
      _params.each_with_index{|param, i| ret = ret.gsub("#{PARAM_SIG}#{i}", param.to_s) }
    end
    ret
  end
end

class ArcadiaSh < TkToplevel
  attr_reader :wait, :result
  def initialize
    super
    title 'ArcadiaSh'
    iconphoto(Arcadia.image_res(ARCADIA_RING_GIF)) if Arcadia.instance.tcltk_info.level >= '8.4.9'
    geometry = '800x200+10+10'
    geometry(geometry)
    @text = TkText.new(self, Arcadia.style('text')){
      wrap  'none'
      undo true
      insertofftime 200
      insertontime 200
      highlightthickness 0
      insertbackground #000000
      insertwidth 6
    }
    @text.set_focus
    @text.tag_configure('error', 'foreground' => '#d93421')
    @text.tag_configure('response', 'foreground' => '#2c51d9')
    @text.extend(TkScrollableWidget).show
    #@input_buffer = ''
    @wait = true
    @result = false
    prompt
    @text.bind_append("KeyPress","%K"){|_keysym| input(_keysym)}
  end

  def exec_buffer
    @text.set_insert("end")
    input_buffer = @text.get(@index_cmd_begin,"insert")
    out("\n")
    exec(input_buffer)
  end

  def input(_char)
    case _char
    when 'Return'
      Thread.new{exec_buffer}
      Tk.callback_break
    end
  end

  def prompt
    @b_exit = TkButton.new(@text,
    'command'=>proc{@wait=false},
    'text'=>'Exit',
    'padx'=>0,
    'pady'=>0,
    'width'=>5,
    'foreground' => 'white',
    'background' => '#d92328',
    'relief'=>'flat')
    TkTextWindow.new(@text, "end", 'window'=> @b_exit)
    @b_exec = TkButton.new(@text,
    'command'=>proc{Thread.new{exec_buffer}},
    'text'=>'Exec',
    'padx'=>0,
    'pady'=>0,
    'width'=>5,
    'foreground' => 'white',
    'background' => '#1ba626',
    'relief'=>'flat')
    TkTextWindow.new(@text, "end", 'window'=> @b_exec)
    out("\n")
    out(">>> ")
    @index_cmd_begin = @text.index('insert')
  end

  def exec_prompt(_cmd)
    out("#{_cmd}\n")
    exec(_cmd)
  end

  def prepare_exec(_cmd)
    #@input_buffer=_cmd
    out("#{_cmd}")
  end

  def exec(_cmd)
    return if _cmd.nil? || _cmd.length ==0
    @b_exec.destroy if defined?(@b_exec)
    out("submitted...\n")
    case _cmd
    when 'clear'
      @text.delete('0.0','end')
    else
      begin
        if OS.windows?
          p = IO::popen("#{_cmd} 2>&1")
          out(p.read, 'response')
          @result = true
        else
          require "open3"
          Open3.popen3("#{_cmd}"){|stdin, stdout, stderr|
            stdout.each do |line|
              out(line,'response')
              @result = true
            end
            stderr.each do |line|
              out(line,'error')
              @result = false
            end

          }
        end
      rescue Exception => e
        out("#{e.message}\n",'error')
        @result = false
      end
    end
    @b_exit.destroy if defined?(@b_exit)
    prompt
    @text.see('end')
  end

  def out(_str,*tags)
    @text.insert('end',_str,*tags)
  end

end

class EventWatcherForGem
  include EventBus
  def initialize(_event, _details)
    @event=_event
    @details=_details
    enhance
    Arcadia.attach_listener(self, _event)
  end
  def enhance
    implementation=%Q{
      class << self
        def #{_method_name(@event, 'before')}(_event)
          _event.break
          new_event = Arcadia.process_event(NeedRubyGemWizardEvent.new(self, @details))
          if new_event && new_event.results
            ok=new_event.results[0].installed
            _event.break if !ok
          end
        end
      end
    }
    eval(implementation)
  end
end

class ArcadiaGemsWizard
  def initialize(_arcadia)
    @arcadia = _arcadia
    Arcadia.attach_listener(self, NeedRubyGemWizardEvent)
  end

  def on_need_ruby_gem_wizard(_event)
    msg = Arcadia.text("main.e.gem_missing.msg", [_event.gem_name, _event.extension_name])
    ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE,"title"=>Arcadia.text("main.e.gem_missing.title", [_event.gem_name]), "detail"=>msg).go!
  end

  def try_to_install_gem(name, repository=nil, version = '>0')
    ret = false
    sh=ArcadiaSh.new
    cmd = "gem install --remote --include-dependencies #{name}"
    cmd="sudo #{cmd}" if !Arcadia.is_windows?
    cmd+=" --source=#{repository}" if repository
    sh.prepare_exec(cmd)
    while sh.wait
      Tk.update
      #sleep(1)
    end
    ret=sh.result
    sh.destroy
    Gem.clear_paths
    ret
  end

end

class ArcadiaDialogManager
  DialogParams = Struct.new("DialogParams",
    :type,
    :res_array,
    :level,
    :msg,
    :title
  )

  def initialize(_arcadia)
    @arcadia = _arcadia
    Arcadia.attach_listener(self, DialogEvent)
  end

  def dialog_params(_event, check_type = true)
    ret = DialogParams.new
    if _event
      ret.type = _event.type
      if check_type && !_event.class::TYPE_PATTERNS.include?(_event.type)
        ret.type = 'ok'
      end
      ret.res_array = ret.type.split('_')
      if _event.level.nil? || _event.level.length == 0
        ret.level = 'info'
      else
        ret.level = _event.level
      end
      if _event.msg && _event.msg.length > _event.class::MSG_MAX_CHARS
        ret.msg = _event.msg[0.._event.class::MSG_MAX_CHARS]+' ...'
      else
        ret.msg = _event.msg
      end
      if _event.title && _event.title.length > _event.class::TITLE_MAX_CHARS
        ret.title = _event.title[0.._event.class::TITLE_MAX_CHARS]+' ...'
      else
        ret.title = _event.title
      end
    end
    ret
  end

  def on_dialog(_event)
    case _event
      when SystemDialogEvent
        do_system_dialog(_event)
      when HinnerDialogEvent
        do_hinner_dialog(_event)
    end
  end

  def do_system_dialog(_event)
    par = dialog_params(_event)
    tktype = par.type.gsub('_','').downcase
    tkdialog =  Tk::BWidget::MessageDlg.new(
      'icon' => par.level,
      'bg' => Arcadia.conf('background'),
      'fg' => Arcadia.conf('foreground'),
      'type' => tktype,
      'title' => _event.title,
    'message' => par.msg)
    tkdialog.configure('font'=>'courier 6')
    res = tkdialog.create
    if _event.level == 'error'
      if _event.exception != nil
        Arcadia.runtime_error(_event.exception, _event.title)
      else
        Arcadia.runtime_error_msg(_event.msg, _event.title)
      end
    end
    _event.add_result(self, 'value'=>par.res_array[res.to_i])
  end

  def do_hinner_dialog(_event)
    par = dialog_params(_event, false)
    dialog_frame = HinnerDialog.new
    max_width = 0
    par.res_array.each{|v| 
      l = v.length
      max_width = l if l > max_width
    }
    res = nil
    par.res_array.reverse_each{|value|
    #  Tk::BWidget::Button.new(dialog_frame, Arcadia.style('button')){
      Arcadia.wf.button(dialog_frame){
        command proc{res = value;dialog_frame.release}
        text value.capitalize
        #helptext  value.capitalize
        width max_width*2
        pack('side' =>'right','padx'=>5, 'pady'=>5)
      }.hint=value.capitalize
    }

    Tk::BWidget::Label.new(dialog_frame,Arcadia.style('label')){
      text  par.msg
      helptext _event.title
    }.pack('side' =>'right','padx'=>5, 'pady'=>5)

    Tk::BWidget::Label.new(dialog_frame,Arcadia.style('label')){
      compound 'left'
      Tk::Anigif.image(self, "#{Dir.pwd}/ext/ae-subprocess-inspector/process.res")
    }.pack('side' =>'right','padx'=>10)

    dialog_frame.show_modal
    _event.add_result(self, 'value'=>res)
  end

  def on_dialog_old(_event)
    type = _event.type
    if !DialogEvent::TYPE_PATTERNS.include?(_event.type)
      type = 'ok'
    end
    icon = _event.level
    tktype = type.gsub('_','').downcase

    res =  Tk.messageBox(
    'icon' => icon,
    'type' => tktype,
    'title' => _event.title,
    'message' => _event.msg)
    _event.add_result(self, 'value'=>res)
  end
end


class ArcadiaLayout

  #  include Observable
  #  ArcadiaPanelInfo = Struct.new( "ArcadiaPanelInfo",
  #    :name,
  #    :title,
  #    :frame,
  #    :ffw
  #  )
  attr_reader :parent_frame
  HIDDEN_DOMAIN = '-1.-1'
  def initialize(_arcadia, _frame, _autotab=true)
    @arcadia = _arcadia
    @frames = Array.new
    @frames[0] = Array.new
    @parent_frame = _frame
    @content_frame = TkFrame.new(_frame).pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
#    @dialog_frame = TkFrame.new(_frame)

    @frames[0][0] = @content_frame
    # @domains = Array.new
    # @domains[0] = Array.new
    # @domains[0][0] = '_domain_root_'
    
    
    @panels = Hash.new
    @panels['_domain_root_']= Hash.new
    @panels['_domain_root_']['root']= @content_frame
    @panels['_domain_root_']['sons'] = Hash.new
    @panels['_domain_root_'][:raised_stack] = []

    @panels['nil'] = Hash.new
    @panels['nil']['root'] = TkTitledFrameAdapter.new(self.root)
    @autotab = _autotab
    @headed = false
    @wrappers=Hash.new
    @splitters=Array.new
    @tabbed = Arcadia.conf('layout.tabbed')=='true'
  end
  
  def root
    @panels['_domain_root_']['root']
  end

  def raised_name(_domain)
    ret = nil
    if @panels[_domain] && @panels[_domain][:raised_stack] && @panels[_domain][:raised_stack].length > 0
      ret = @panels[_domain][:raised_stack][-1]
    end
    ret
  end

  def raise_panel(_domain, _extension)
    p = @panels[_domain]
    if p
      #p[:raised_name]=_extension
      p[:raised_stack].delete(_extension)
      p[:raised_stack] << _extension
    end
    if @tabbed
      if p && p['notebook'] != nil
        p['notebook'].raise(_extension)
        p['notebook'].see(_extension)
      end
    elsif p
      p['sons'].each{|k,v|
        if k == _extension
          v.hinner_frame.raise
          #title_titled_frame(_domain, v.title)
          p['root'].title(v.title)
          p['root'].restore_caption(k)
          p['root'].change_adapters_name(k)
          Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>k, 'frame_name'=>p['sons'][k].name))
          break
        end
      }
    end
  end

  #  def raise_panel(_domain_name, _name)
  #    @panels[_domain_name]['notebook'].raise(_name) if @panels[_domain_name] && @panels[_domain_name]['notebook']
  #  end

  def raised?(_domain, _name)
    ret = true
    p = @panels[_domain]
    if @tabbed
      if p && p['notebook'] != nil
        ret=p['notebook'].raise == _name
      end
    else
      #ret = @panels[_domain][:raised_name] == _name
      ret = raised_name(_domain) == _name
    end
    ret
  end

  def raised_fixed_frame(_domain)
    ret = nil
    p = @panels[_domain]
    if @tabbed
      if p && p['notebook'] != nil
        raised_name=p['notebook'].raise
        @panels[_domain]['sons'].each{|k,v|
          if raised_name == k
            ret = v
            break
          end
        }
      elsif @panels[_domain]['sons'].length == 1
        ret = @panels[_domain]['sons'].values[0]
      end
    else
      p['sons'].each{|k,v|
        #        if k == @panels[_domain][:raised_name]
        if k == raised_name(_domain)
          ret = v
          break
        end
      }
    end
    ret
  end

  def _prepare_rows(_row,_col, _height, _perc=false, _top_name=nil, _bottom_name=nil)
    if (@frames[_row][_col] !=  nil)
      #source_domains = all_domains(@frames[_row][_col])
      #source_domains = others_domains(@frames[_row][_col], false)
      _h = AGTkOSplittedFrames.new(self.root,@frames[_row][_col],_height, @arcadia['conf']['layout.splitter.length'].to_i,_perc)
      @splitters << _h
      if @frames[_row + 1] == nil
        @frames[_row + 1] = Array.new
        #	@domains[_row + 1] = Array.new
      end
      @frames[_row][_col] = _h.top_frame

      _top_name = _row.to_s+'.'+_col.to_s if _top_name == nil
      @panels[_top_name] = Hash.new
      @panels[_top_name]['root'] = @frames[_row][_col]
      @panels[_top_name]['sons'] = 	Hash.new
      if @panels[_top_name]['root_splitted_frames'].nil?
        @panels[_top_name]['root_splitted_frames'] = _h
      end
      @panels[_top_name]['splitted_frames'] = _h
      # @domains[_row][_col] = _top_name

      _bottom_name = (_row+1).to_s+'.'+_col.to_s if _bottom_name == nil

      if !@panels[_bottom_name].nil?
        shift_bottom(_row+1, _col)
      end

      @panels[_bottom_name] = Hash.new
      @frames[_row + 1][_col] = _h.bottom_frame
      @panels[_bottom_name]['root'] = @frames[_row + 1][_col]
      @panels[_bottom_name]['sons'] = Hash.new
      if @panels[_bottom_name]['root_splitted_frames'].nil?
        @panels[_bottom_name]['root_splitted_frames'] = _h
      end
      @panels[_bottom_name]['splitted_frames'] = _h
      #	@domains[_row + 1][_col] = _bottom_name
    end
  end
  private :_prepare_rows

  def add_mono_panel(_name=nil)
    if (@frames[0][0] !=  nil)
      _name = '0.0' if _name.nil?
      @panels[_name] = Hash.new
      @panels[_name]['root'] = @frames[0][0]
      @panels[_name]['sons'] = 	Hash.new
    end
  end

  def add_rows(_row,_col, _height, _top_name=nil, _bottom_name=nil)
    _prepare_rows(_row,_col, _height, false, _top_name, _bottom_name)
  end

  def add_rows_perc(_row,_col, _height, _top_name=nil, _bottom_name=nil)
    _prepare_rows(_row,_col, _height, true, _top_name, _bottom_name)
  end

  #  def others_domains(_frame, _vertical=true)
  #      if _vertical
  #        splitter_adapter_class = AGTkVSplittedFrames
  #      else
  #        splitter_adapter_class = AGTkOSplittedFrames
  #      end
  #      splitted_adapter = find_splitted_frame(_frame)
  #      consider_it = splitted_adapter.instance_of?(splitter_adapter_class) && splitted_adapter.frame1 == _frame
  #      if splitted_adapter && !consider_it && splitted_adapter != _frame
  #         rif_frame = splitted_adapter.frame
  #         ret = others_domains(rif_frame)
  #      elsif splitted_adapter && consider_it
  #        ret = domains_on_frame(splitted_adapter.frame2)
  #      else
  #        ret = Array.new
  #      end
  #      ret
  #  end

  def all_domains(_frame)
    splitted_adapter = find_splitted_frame(_frame)
    consider_it = splitted_adapter.kind_of?(AGTkSplittedFrames)
    if consider_it
      ret = domains_on_frame(splitted_adapter.frame2).concat(domains_on_frame(splitted_adapter.frame1))
    else
      ret = Array.new
    end
    ret
  end

  def all_domains_cols(_frame)
    ret = Array.new
    all_domains(_frame).each{|d|
      v = d.split('.')[1]
      ret << v if !ret.include?(v)
    }
    ret
  end

  def all_domains_rows(_frame)
    ret = Array.new
    all_domains(_frame).each{|d|
      v = d.split('.')[0]
      ret << v if !ret.include?(v)
    }
    ret
  end

  def _prepare_cols(_row,_col, _width, _perc=false, _left_name=nil, _right_name=nil)
    if (@frames[_row][_col] !=  nil)
      #source_domains = all_domains(@frames[_row][_col])
      #source_domains = others_domains(@frames[_row][_col])
      _w = AGTkVSplittedFrames.new(self.root,@frames[_row][_col],_width,@arcadia['conf']['layout.splitter.length'].to_i,_perc)
      @splitters << _w
      @frames[_row][_col] = _w.left_frame
      #@frames[_row][_col + 1] = _w.right_frame

      _left_name = _row.to_s+'.'+_col.to_s if _left_name == nil
      @panels[_left_name] = Hash.new
      @panels[_left_name]['root'] = @frames[_row][_col]
      @panels[_left_name]['sons'] = Hash.new
      if @panels[_left_name]['root_splitted_frames'].nil?
        @panels[_left_name]['root_splitted_frames'] = _w
      end
      @panels[_left_name]['splitted_frames'] = _w
      # @domains[_row][_col] = _left_name

      _right_name = _row.to_s+'.'+(_col+1).to_s if _right_name == nil
      if !@panels[_right_name].nil?
        shift_right(_row, _col+1)
      end

      @frames[_row][_col + 1] = _w.right_frame
      @panels[_right_name] = Hash.new
      @panels[_right_name]['root'] = @frames[_row][_col + 1]
      @panels[_right_name]['sons'] = Hash.new
      if @panels[_right_name]['root_splitted_frames'].nil?
        @panels[_right_name]['root_splitted_frames'] = _w
      end
      @panels[_right_name]['splitted_frames'] = _w
      # @domains[_row][_col + 1] = _right_name
    end
  end
  private :_prepare_cols


  def domain_name(_row,_col)
    _row.to_s+'.'+_col.to_s
  end

  def shift_right(_row,_col)
    d = domain_name(_row, _col+1)
    dj = domain_name(_row, _col)
    if @panels[d] !=nil
      shift_right(_row,_col+1)
    end
    @panels[d] = @panels[dj]
    #-------------------------------
    #@panels[d]['root'].set_domain(d)
    #-------------------------------
    @panels[d]['sons'].each{|name,ffw| ffw.domain=d}
    @frames[_row][_col+1] = @frames[_row][_col]
    # @domains[_row][_col+1] = @domains[_row][_col]

    @panels.delete(dj)
    #@panels[dj] = nil
    @frames[_row][_col] = nil
    # @domains[_row][_col] = nil
  end

  def shift_left(_row,_col)
    d = domain_name(_row, _col)
    dj = domain_name(_row, _col+1)
    if @panels[dj] !=nil
      @panels[d] = @panels[dj]
      #-------------------------------
      #@panels[d]['root'].set_domain(d)
      #-------------------------------
      @panels[d]['sons'].each{|name,ffw| ffw.domain=d}
      @frames[_row][_col] = @frames[_row][_col+1]
      # @domains[_row][_col] = @domains[_row][_col+1]

      @panels.delete(dj) # = nil
      @frames[_row][_col+1] = nil
      # @domains[_row][_col+1] = nil
      shift_left(_row,_col+1)
    end

  end

  def shift_top(_row,_col)
    d = domain_name(_row, _col)
    dj = domain_name(_row+1, _col)
    if @panels[dj] !=nil
      @panels[d] = @panels[dj]
      #-------------------------------
      #@panels[d]['root'].set_domain(d)
      #-------------------------------
      @panels[d]['sons'].each{|name,ffw| ffw.domain=d}
      @frames[_row][_col] = @frames[_row+1][_col]
      # @domains[_row][_col] = @domains[_row+1][_col]

      @panels.delete(dj) # = nil
      @frames[_row+1][_col] = nil
      # @domains[_row+1][_col] = nil

      shift_top(_row+1,_col)
    end

  end


  def shift_bottom(_row, _col)
    d = domain_name(_row+1, _col)
    dj = domain_name(_row, _col)
    if @panels[d] !=nil
      shift_bottom(_row+1,_col)
    end
    @panels[d] = @panels[dj]
    #-------------------------------
    #@panels[d]['root'].set_domain(d)
    #-------------------------------
    @panels[d]['sons'].each{|name,ffw| ffw.domain=d}
    if @frames[_row + 1] == nil
      @frames[_row + 1] = Array.new
      #	@domains[_row + 1] = Array.new
    end
    @frames[_row+1][_col] = @frames[_row][_col]
    # @domains[_row+1][_col] = @domains[_row][_col]

    @panels.delete(dj)
    #@panels[dj] = nil
    @frames[_row][_col] = nil
    # @domains[_row][_col] = nil
  end

  def add_cols(_row,_col, _width, _left_name=nil, _right_name=nil)
    _prepare_cols(_row,_col, _width, false, _left_name, _right_name)
  end

  def add_cols_perc(_row,_col, _width, _left_name=nil, _right_name=nil)
    _prepare_cols(_row,_col, _width, true, _left_name, _right_name)
  end

  def add_cols_runtime(_domain)
    saved_root_splitted_frames = @panels[_domain]['root_splitted_frames']
    _saved = Hash.new
    _saved.update(@panels[_domain]['sons'])
    _saved.each_key{|name|
      @panels['nil']['root'].change_adapters(name, @panels[_domain]['root'].transient_frame_adapter[name])
    }
    geometry = TkWinfo.geometry(@panels[_domain]['root'])
    width = geometry.split('x')[0].to_i/2
    _saved.each{|name,ffw|
      unregister_panel(ffw, false, false)
    }
    unbuild_titled_frame(_domain)
    _row,_col = _domain.split('.')
    add_cols(_row.to_i,_col.to_i, width)
    build_titled_frame(_domain)
    build_titled_frame(domain_name(_row.to_i,_col.to_i+1))
    _saved.each{|name,ffw|
      ffw.domain = _domain
      register_panel(ffw, ffw.hinner_frame)
      @panels[_domain]['root'].change_adapters(name, @panels['nil']['root'].transient_frame_adapter[name])
    }
    if saved_root_splitted_frames
      @panels[_domain]['root_splitted_frames']=saved_root_splitted_frames
    end
    build_invert_menu(true)
  end

  def add_rows_runtime(_domain)
    saved_root_splitted_frames = @panels[_domain]['root_splitted_frames']
    _saved = Hash.new
    _saved.update(@panels[_domain]['sons'])
    _saved.each_key{|name|
      @panels['nil']['root'].change_adapters(name, @panels[_domain]['root'].transient_frame_adapter[name])
    }
    geometry = TkWinfo.geometry(@panels[_domain]['root'])
    height = geometry.split('+')[0].split('x')[1].to_i/2
    _saved.each{|name,ffw|
      unregister_panel(ffw, false, false)
    }
    unbuild_titled_frame(_domain)
    _row,_col = _domain.split('.')
    add_rows(_row.to_i,_col.to_i, height)
    build_titled_frame(_domain)
    build_titled_frame(domain_name(_row.to_i+1,_col.to_i))
    _saved.each{|name,ffw|
      ffw.domain = _domain
      register_panel(ffw, ffw.hinner_frame)
      @panels[_domain]['root'].change_adapters(name, @panels['nil']['root'].transient_frame_adapter[name])
    }
    if saved_root_splitted_frames
      @panels[_domain]['root_splitted_frames']=saved_root_splitted_frames
    end
    build_invert_menu(true)
  end

  def domains_on_frame_rows(_frame)
    ret = Array.new
    domains_on_frame(_frame).each{|d|
      v = d.split('.')[0]
      ret << v if !ret.include?(v)
    }
    ret
  end

  def domains_rows(_domains)
    ret = Array.new
    if _domains
      _domains.each{|d|
        v = d.split('.')[0]
        ret << v if !ret.include?(v)
      }
    end
    ret
  end

  def max_col(_domains, _row)
    ret = 0
    if _domains
      _domains.each{|d|
        r,c = d.split('.')
        if r.to_i == _row && c.to_i > ret
          ret = c.to_i
        end
      }
    end
    ret
  end

  def max_row(_domains, _col)
    ret = 0
    if _domains
      _domains.each{|d|
        r,c = d.split('.')
        if c.to_i == _col && r.to_i > ret
          ret = r.to_i
        end
      }
    end
    ret
  end

  def domains_cols(_domains)
    ret = Array.new
    _domains.each{|d|
      v = d.split('.')[1]
      ret << v if !ret.include?(v)
    }
    ret
  end


  def domains_on_frame_cols(_frame)
    ret = Array.new
    domains_on_frame(_frame).each{|d|
      v = d.split('.')[1]
      ret << v if !ret.include?(v)
    }
    ret
  end

  def domains_on_splitter(_splitter)
    domains_on_frame(_splitter.frame1).concat(domains_on_frame(_splitter.frame2))
  end

  def domains_on_splitter_cols(_splitter)
    ret = Array.new
    domains_on_splitter(_splitter).each{|d|
      v = d.split('.')[1]
      ret << v if !ret.include?(v)
    }
    ret
  end

  def domains_on_splitter_rows(_splitter)
    ret = Array.new
    domains_on_splitter(_splitter).each{|d|
      v = d.split('.')[0]
      ret << v if !ret.include?(v)
    }
    ret
  end

  def domains_on_frame(_frame)
    ret_doms = Array.new
    frame_found = false
    @panels.keys.each{|dom|
      if dom != '_domain_root_'
        if (@panels[dom]['splitted_frames'] != nil && @panels[dom]['splitted_frames'].frame == _frame) || (@panels[dom]['root_splitted_frames'] != nil && @panels[dom]['root_splitted_frames'].frame  == _frame)
          ret_doms.concat(domains_on_frame(@panels[dom]['splitted_frames'].frame1))
          ret_doms.concat(domains_on_frame(@panels[dom]['splitted_frames'].frame2))
          frame_found = true
          break
        elsif @panels[dom]['notebook'] != nil
          cfrs = TkWinfo.children(_frame)
          if cfrs && cfrs.length == 1 && cfrs[0].instance_of?(TkTitledFrameAdapter) && TkWinfo.parent(@panels[dom]['notebook'])== cfrs[0].frame
            ret_doms << dom
            frame_found = true
          end
        elsif @panels[dom]['root'].instance_of?(TkTitledFrameAdapter) && @panels[dom]['root'].parent == _frame
          ret_doms << dom
          frame_found = true
        end
      end
    }

    if !frame_found
      cfrs = TkWinfo.children(_frame)
      if cfrs && cfrs.length == 1 && cfrs[0].instance_of?(TkTitledFrameAdapter)
        @wrappers.each{|name, ffw|
          if ffw.hinner_frame.frame == cfrs[0].frame
            ret_doms << ffw.domain
          end
        }
      end
    end
    ret_doms
  end

  def find_splitted_frame(_start_frame)
    splitted_frame = _start_frame
    while splitted_frame != nil && !splitted_frame.kind_of?(AGTkSplittedFrames)
      splitted_frame = TkWinfo.parent(splitted_frame)
    end
    splitted_frame
  end
  #--
  def close_runtime(_domain)
    splitted_adapter = find_splitted_frame(@panels[_domain]['root'])
    splitted_adapter_frame = splitted_adapter.frame
    vertical = splitted_adapter.instance_of?(AGTkVSplittedFrames)
    _row, _col = _domain.split('.')
    if @frames[_row.to_i][_col.to_i] == splitted_adapter.frame1
      other_ds = domains_on_frame(@panels[_domain]['splitted_frames'].frame2)
    elsif @frames[_row.to_i][_col.to_i] == splitted_adapter.frame2
      other_ds = domains_on_frame(@panels[_domain]['splitted_frames'].frame1)
    end

    return if other_ds.nil?


    if other_ds.length == 1
      other_domain = other_ds[0]
    elsif other_ds.length > 1
      max = other_ds.length-1
      j = 0
      while j <= max
        if other_domain.nil?
          other_domain = other_ds[j]
        else
          r,c = other_domain.split('.')
          new_r,new_c = other_ds[j].split('.')
          if new_r.to_i < r.to_i || new_r.to_i == r.to_i && new_c.to_i < c.to_i
            other_domain = other_ds[j]
          end
        end
        j = j+1
      end
    end
    _other_row, _other_col = other_domain.split('.')
    @panels[_domain]['sons'].each{|name,ffw|
      unregister_panel(ffw, false, false)
    }
    unbuild_titled_frame(_domain)

    if @panels[other_domain]['splitted_frames'] != @panels[_domain]['splitted_frames']
      if @panels[other_domain]['root_splitted_frames'].frame == @panels[_domain]['splitted_frames'].frame1 || @panels[other_domain]['root_splitted_frames'].frame == @panels[_domain]['splitted_frames'].frame2
        other_root_splitted_adapter = @panels[other_domain]['root_splitted_frames']
      elsif @panels[other_domain]['splitted_frames']
        other_root_splitted_adapter = @panels[other_domain]['splitted_frames']
      end
    end

    @panels.delete(_domain)
    @frames[_row.to_i][_col.to_i] = nil
    # @domains[_row.to_i][_col.to_i] = nil

    if other_root_splitted_adapter
      if other_root_splitted_adapter != @panels[other_domain]['splitted_frames']
        other_ds.each{|d|
          if @panels[d]['root_splitted_frames'] == splitted_adapter
            @panels[d]['root_splitted_frames']=other_root_splitted_adapter
          end
        }
      end
      other_root_splitted_adapter.detach_frame
      splitted_adapter.detach_frame
      @splitters.delete(splitted_adapter)
      splitted_adapter.destroy
      other_root_splitted_adapter.attach_frame(splitted_adapter_frame)
    else
      other_source_save = Hash.new
      other_source_save.update(@panels[other_domain]['sons']) if @panels[other_domain]
      other_source_save.each_key{|name|
        @panels['nil']['root'].change_adapters(name, @panels[other_domain]['root'].transient_frame_adapter[name])
      }
      other_source_save.each{|name,ffw|
        unregister_panel(ffw, false, false)
      }
      splitted_adapter.detach_frame
      splitted_adapter.destroy
      @panels[other_domain]['root']=splitted_adapter_frame
      @frames[_other_row.to_i][_other_col.to_i] = splitted_adapter_frame
      build_titled_frame(other_domain)
      other_source_save.each{|name,ffw|
        ffw.domain = other_domain
        register_panel(ffw, ffw.hinner_frame)
        @panels[other_domain]['root'].change_adapters(name, @panels['nil']['root'].transient_frame_adapter[name])
      }
      parent_splitted_adapter = find_splitted_frame(@panels[other_domain]['root'])
      if  parent_splitted_adapter
        @panels[other_domain]['splitted_frames']=parent_splitted_adapter
      else
        @panels[other_domain]['splitted_frames']= nil
      end
    end
    build_invert_menu(true)
  end

  #--

  def unbuild_titled_frame(domain)
    if @panels[domain]
      parent = @panels[domain]['root'].parent
      @panels[domain]['root'].destroy
      @panels[domain]['root']=parent
    end
  end

  def add_commons_menu_items(_domain, _menu)
    _menu.insert('end', :separator)
    _menu.insert('end', :command,
    :label=>"add column",
    :image=>Arcadia.image_res(ADD_GIF),
    :compound=>'left',
    :command=>proc{add_cols_runtime(_domain)},
    :hidemargin => true
    )
    _menu.insert('end', :command,
    :label=>"add row",
    :image=>Arcadia.image_res(ADD_GIF),
    :compound=>'left',
    :command=>proc{add_rows_runtime(_domain)},
    :hidemargin => true
    )
    if @panels.keys.length > 2
      _menu.insert('end', :command,
      :label=>"close",
      :image=>Arcadia.image_res(CLOSE_FRAME_GIF),
      :compound=>'left',
      :command=>proc{close_runtime(_domain)},
      :hidemargin => true
      )
    end

  end
  
#  def title_titled_frame(_domain, _text)
#    mb = @panels[_domain]['root'].menu_button('ext') if @panels[_domain]
#    if mb
#      #mb.configure('text'=>_text)
#      mb.cget('textvariable').value=_text
#      p "configuro #{_text}"
#    end 
#  end

  def build_titled_frame(domain)
    if @panels[domain]
      tframe = TkTitledFrameAdapter.new(@panels[domain]['root']).place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1)
#      mb = tframe.add_fixed_menu_button('ext')

#      mb = tframe.add_fixed_menu_button(
#        'ext',
#        nil,
#        'left',
#      {'relief'=>:flat, 
#       'borderwidth'=>1, 
#       'compound'=> 'left',
#       'anchor'=>'w',
#       'activebackground'=>Arcadia.conf('titlelabel.background'),
#       'foreground' => Arcadia.conf('titlecontext.foreground'),
#       'textvariable'=> TkVariable.new('')
#       })

      # add commons item
#      menu = mb.cget('menu')
      menu = tframe.title_menu
      add_commons_menu_items(domain, menu)
      @panels[domain]['root']= tframe
      #-----------------------------------
      #      class << tframe
      #        def set_domain(_domain)
      #          if @label_domain.nil?
      #            @label_domail = TkLabel.new(self.frame, 'text'=>_domain).pack
      #          else
      #            @label_domain.configure('text'=>_domain)
      #          end
      #        end
      #      end
      #      tframe.set_domain(domain)
      #-----------------------------------
    end
  end

  def domains
    ret = Array.new
    @panels.keys.each{|dom|
      if dom != '_domain_root_' && @panels[dom] && @panels[dom]['root']
        ret << dom
      end
    }
    ret
  end

  def add_headers
    @panels.keys.each{|dom|
      if dom != '_domain_root_' && @panels[dom] && @panels[dom]['root']
        build_titled_frame(dom)
      end
    }

    #    @domains.each{|row|
    #      row.each{|domain|
    #        build_titled_frame(domain)
    #      }
    #    }
    @headed = true
  end

  def headed?
    @headed
  end

  def autotab?
    @autotab
  end

  def registed?(_domain_name, _name)
    @panels[_domain_name]['sons'][_name] != nil
  end

  def change_domain(_target_domain, _source_name)
    source_domain = @wrappers[_source_name].domain
    source_has_domain = !source_domain.nil?
    if @arcadia.conf('layout.exchange_panel_if_no_tabbed')=='true' && source_has_domain && @panels[source_domain]['sons'].length == 1 && @panels[_target_domain]['sons'].length > 0
      # change ------
      ffw1 = raised_fixed_frame(_target_domain)
      ffw2 = @panels[source_domain]['sons'].values[0]
      unregister_panel(ffw1,false,false) if ffw1
      unregister_panel(ffw2,false,false)
      ffw1.domain = source_domain if ffw1
      ffw2.domain = _target_domain
      register_panel(ffw1, ffw1.hinner_frame) if ffw1
      register_panel(ffw2, ffw2.hinner_frame)
      @panels[_target_domain]['root'].save_caption(ffw2.name, @panels[source_domain]['root'].last_caption(ffw2.name), @panels[source_domain]['root'].last_caption_image(ffw2.name))
      @panels[source_domain]['root'].save_caption(ffw1.name, @panels[_target_domain]['root'].last_caption(ffw1.name), @panels[_target_domain]['root'].last_caption_image(ffw1.name))
      @panels[_target_domain]['root'].restore_caption(ffw2.name)
       @panels[source_domain]['root'].restore_caption(ffw1.name)
      @panels[_target_domain]['root'].change_adapters(ffw2.name, @panels[source_domain]['root'].forge_transient_adapter(ffw2.name))
      @panels[source_domain]['root'].change_adapters(ffw1.name, @panels[_target_domain]['root'].forge_transient_adapter(ffw1.name))
    elsif source_has_domain && @panels[source_domain]['sons'].length >= 1
      ffw2 = @panels[source_domain]['sons'][_source_name]
      unregister_panel(ffw2, false, false)
      ffw2.domain = _target_domain
      register_panel(ffw2, ffw2.hinner_frame)
      @panels[_target_domain]['root'].save_caption(ffw2.name, @panels[source_domain]['root'].last_caption(ffw2.name), @panels[source_domain]['root'].last_caption_image(ffw2.name))
      @panels[_target_domain]['root'].restore_caption(ffw2.name)
      @panels[_target_domain]['root'].change_adapters(ffw2.name, @panels[source_domain]['root'].forge_transient_adapter(ffw2.name))
      #Tk.event_generate(ffw2.hinner_frame, "Map")
    elsif !source_has_domain
      ffw2 = @wrappers[_source_name]
      ffw2.domain = _target_domain
      register_panel(ffw2, ffw2.hinner_frame)
      if @panels['nil']['root'].transient_frame_adapter[ffw2.name]
        @panels[ffw2.domain]['root'].change_adapters(ffw2.name, @panels['nil']['root'].transient_frame_adapter[ffw2.name])
      end
      #@panels[_target_domain]['root'].top_text('')
    end
    # refresh -----
    build_invert_menu
    Tk.update
    LayoutChangedDomainEvent.new(self, 'old_domain'=>source_domain, 'new_domain'=>_target_domain).go!
  end

  def sorted_menu_index(_menu, _label)
    index = '0'
    i_end = _menu.index('end').to_i - 4
    if i_end && i_end > 0
      0.upto(i_end){|j|
        type = _menu.menutype(j)
        if type != 'separator'
          value = _menu.entrycget(j,'label').to_s
          if value > _label
            index=j
            break
          end
        end
      }
    end
    index
  end
  
  def menu_item_exist?(_menu, _name)
    exist = false
    i_end = _menu.index('end')
    if i_end
      0.upto(i_end){|j|
        type = _menu.menutype(j)
        if type != 'separator'
          value = _menu.entrycget(j,'label').to_s
          if value == _name
            exist = true
            break
          end
        end
      }
    end
    exist
  end
  
  def menu_item_add(_menu, _dom, _ffw, _is_plus=false)
    if !menu_item_exist?(_menu, _ffw.title)
      ind = sorted_menu_index(_menu, _ffw.title)
      if _is_plus
        if Arcadia.extension(_ffw.name).main_instance? 
          submenu_title = _ffw.title
        else
          submenu_title = Arcadia.extension(_ffw.name).main_instance.frame_title
        end
        submenu = nil
        newlabel = "New ..."
        if menu_item_exist?(_menu, submenu_title)
          submenu = ArcadiaMainMenu.sub_menu(_menu, submenu_title)
        end
        if submenu.nil?
        
          #submenu = TkMenu.new(
          submenu = Arcadia.wf.menu(
            :parent=>_menu,
            :tearoff=>0,
            :title => submenu_title
          )
          #submenu.extend(TkAutoPostMenu)
          #submenu.configure(Arcadia.style('menu'))
          _menu.insert(ind,
            :cascade,
            :image=>Arcadia.image_res(ARROW_LEFT_GIF),
            :label=>submenu_title,
            :compound=>'left',
            :menu=>submenu,
            :hidemargin => false
          )
          submenu.insert('end',:command,
            :label=>newlabel,
            :image=>Arcadia.image_res(STAR_EMPTY_GIF),
            :compound=>'left',
            :command=>proc{Arcadia.extension(_ffw.name).main_instance.duplicate(nil, _dom)},
            :hidemargin => true
          )
        end
        submenu.insert(newlabel,:command,
          :label=>_ffw.title,
          :image=>Arcadia.image_res(ARROW_LEFT_GIF),
          :compound=>'left',
          :command=>proc{change_domain(_dom, _ffw.name)},
          :hidemargin => true
        )

      else
          _menu.insert(ind,:command,
          :label=>_ffw.title,
          :image=>Arcadia.image_res(ARROW_LEFT_GIF),
          :compound=>'left',
          :command=>proc{change_domain(_dom, _ffw.name)},
          :hidemargin => true
        )
      end
    end
  end

  def process_frame(_ffw)
    #p "process frame #{_ffw.title}"
    #-------
    is_plus = Arcadia.extension(_ffw.name).kind_of?(ArcadiaExtPlus)
    #-------
    @panels.keys.each{|dom|
      if  dom != '_domain_root_' && dom != _ffw.domain && @panels[dom] && @panels[dom]['root']
        titledFrame = @panels[dom]['root']
        if titledFrame.instance_of?(TkTitledFrameAdapter)
          #menu = @panels[dom]['root'].menu_button('ext').cget('menu')
          menu = titledFrame.title_menu
          menu_item_add(menu, dom, _ffw, is_plus)
        end
      end
    }
    if @panels[_ffw.domain]
      titledFrame = @panels[_ffw.domain]['root']
      if titledFrame.instance_of?(TkTitledFrameAdapter)
        #titledFrame.menu_button('ext').text("#{_ffw.title}::")
        #mymenu = titledFrame.menu_button('ext').cget('menu')
        mymenu = titledFrame.title_menu
        index = mymenu.index('end').to_i
        if @panels.keys.length > 2
          i=index-3
        else
          i=index-2
        end
        if i >= 0
          index = i.to_s
        end
        clabel = "close \"#{_ffw.title}\"" 
        if @tabbed
          if !menu_item_exist?(mymenu, clabel)
            mymenu.insert(index,:command,
            :label=> clabel,
            :image=>Arcadia.image_res(CLOSE_FRAME_GIF),
            :compound=>'left',
            :command=>proc{unregister_panel(_ffw, false, true)},
            :hidemargin => true
            )
          end
        else
           if !menu_item_exist?(mymenu, clabel)
             mymenu.insert(index,:command,
               :label=> clabel,
               :image=>Arcadia.image_res(CLOSE_FRAME_GIF),
               :compound=>'left',
               :command=>proc{unregister_panel(_ffw, false, true)},
               :hidemargin => true
             )
           end
           menu_item_add(mymenu, _ffw.domain, _ffw, is_plus)
        end
      end
    end

  end

  def build_invert_menu(refresh_commons_items=false)
    #p " ***build_invert_menu"

    @panels.keys.each{|dom|
      if dom != '_domain_root_' && @panels[dom] && @panels[dom]['root']
        titledFrame = @panels[dom]['root']
        if titledFrame.instance_of?(TkTitledFrameAdapter)
          #menu = titledFrame.menu_button('ext').cget('menu')
          menu = titledFrame.title_menu
          if refresh_commons_items
            #@panels[dom]['root'].menu_button('ext').cget('menu').delete('0','end')
            @panels[dom]['root'].title_menu.delete('0','end')
            add_commons_menu_items(dom, menu)
          else
            index = menu.index('end').to_i
            if @tabbed
              if @panels.keys.length > 2
                i=index-4
              else
                i=index-3
              end
            else
              if @panels.keys.length > 2
                i=index-4
              else
                i=index-3
              end
            end
            if i >= 0
              end_index = i.to_s
              #@panels[dom]['root'].menu_button('ext').cget('menu').delete('0',end_index)
              @panels[dom]['root'].title_menu.delete('0',end_index)
            end
          end
          #          index = menu.index('end').to_i
          #          @panels[dom]['root'].menu_button('ext').cget('menu').delete('2','end') if index > 1
        end
      end
    }

    @wrappers.each{|name,ffw|
      process_frame(ffw) #if ffw.domain
    }

  end

  def registered_panel?(_ffw)
    _ffw.domain.nil? || _ffw.domain.length == 0 ?false:registed?(_ffw.domain, _ffw.name)
  end

  def register_panel(_ffw, _adapter=nil)
    #p " > register_panel #{_ffw.title} _adapter #{_adapter}"
    _domain_name = _ffw.domain
    _name = _ffw.name
    _title = _ffw.title
    pan = @panels[_domain_name]
    @wrappers[_name]=_ffw
    if pan!=nil
      num = pan['sons'].length
      if @headed
        root_frame = pan['root'].frame
        #title_titled_frame(_domain_name, _title)
        pan['root'].title(_title)
        pan['root'].restore_caption(_name)
        pan['root'].change_adapters_name(_name)
        if !root_frame.instance_of?(TkFrameAdapter) && num==0
          if _adapter
            adapter = _adapter
          else
            adapter = TkFrameAdapter.new(self.root)
          end
          adapter.attach_frame(root_frame)
          adapter.raise
        end
      else
        root_frame = pan['root']
      end
      #@panels[_domain_name][:raised_name]=_name
      @panels[_domain_name][:raised_stack] = [] if @panels[_domain_name][:raised_stack].nil?
      @panels[_domain_name][:raised_stack] << _name
      if @tabbed
        if (num == 0 && @autotab)
          pan['sons'][_name] = _ffw
          process_frame(_ffw)
          return adapter
        else
          if num == 1 && @autotab &&  pan['notebook'] == nil
            pan['notebook'] = Tk::BWidget::NoteBook.new(root_frame, Arcadia.style('titletabpanel')){
              tabbevelsize 0
              internalborderwidth 0
              pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
            }
            api = pan['sons'].values[0]
            api_tab_frame = pan['notebook'].insert('end',
            api.name,
            'text'=>api.title,
            'raisecmd'=>proc{
              #title_titled_frame(_domain_name, api.title)
              pan['root'].title(api.title)
              pan['root'].restore_caption(api.name)
              pan['root'].change_adapters_name(api.name)
              Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>pan['sons'][api.name].extension_name, 'frame_name'=>pan['sons'][api.name].name))
            }
            )
            adapter = api.hinner_frame
            adapter.detach_frame
            adapter.attach_frame(api_tab_frame)
            api.hinner_frame.raise
          elsif (num==0 && !@autotab)
            pan['notebook'] = Tk::BWidget::NoteBook.new(root_frame, Arcadia.style('titletabpanel')){
              tabbevelsize 0
              internalborderwidth 0
              pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
            }
          end
          _panel = pan['notebook'].insert('end',_name ,
          'text'=>_title,
          'raisecmd'=>proc{
            #title_titled_frame(_domain_name, _title)
            pan['root'].title(_title)
            pan['root'].restore_caption(_name)
            pan['root'].change_adapters_name(_name)
            Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>_ffw.extension_name, 'frame_name'=>_ffw.name))
          }
          )
          if _adapter
            adapter = _adapter
          else
            adapter = TkFrameAdapter.new(self.root)
          end
          adapter.attach_frame(_panel)
          adapter.raise
          _panel=adapter
          pan['sons'][_name] = _ffw
          pan['notebook'].raise(_name)
          process_frame(_ffw)
          return _panel
        end
      else
        # not tabbed
        pan['sons'][_name] = _ffw
        process_frame(_ffw)
        if adapter.nil?
          if _adapter
            adapter = _adapter
          else
            adapter = TkFrameAdapter.new(self.root)
          end
        end
        adapter.attach_frame(root_frame)
        adapter.raise
        #        pan['sons'].each{|k,v|
        #          if k != _name
        #            unregister_panel(v,false)
        #          end
        #        }
        return adapter
      end
    else
      _ffw.domain = nil
      process_frame(_ffw)
      return TkFrameAdapter.new(self.root)
    end
  end


  def unregister_panel(_ffw, delete_wrapper=true, refresh_menu=true)
    _domain_name = _ffw.domain
    _name = _ffw.name
    @panels[_domain_name]['sons'][_name].hinner_frame.detach_frame
    if delete_wrapper
      @wrappers[_name].root.clear_transient_adapters(_name)
      @wrappers.delete(_name).hinner_frame.destroy
    else
      @wrappers[_name].domain=nil
    end
    @panels[_domain_name]['sons'].delete(_name)
    @panels[_domain_name][:raised_stack].delete(_name)
    #p "unregister #{_name} ------> 2"
    if @panels[_domain_name]['sons'].length >= 1
      n = @panels[_domain_name][:raised_stack][-1]
      w = @panels[_domain_name]['sons'][n].hinner_frame
      t = @panels[_domain_name]['sons'][n].title
      #title_titled_frame(_domain_name, t)
      @panels[_domain_name]['root'].title(t)
      @panels[_domain_name]['root'].restore_caption(n)
      @panels[_domain_name]['root'].shift_on if !@panels[_domain_name]['sons'][n].kind_of?(ArcadiaExtPlus)
      @panels[_domain_name]['root'].change_adapters_name(n)
      if !@tabbed || @panels[_domain_name]['sons'].length == 1
        w.detach_frame
        w.attach_frame(@panels[_domain_name]['root'].frame)
      end
      if @tabbed
        if @panels[_domain_name]['sons'].length == 1
          @panels[_domain_name]['notebook'].destroy
          @panels[_domain_name]['notebook']=nil
        else
          @panels[_domain_name]['notebook'].delete(_name) if @panels[_domain_name]['notebook'].index(_name) > 0
          new_raise_key = @panels[_domain_name]['sons'].keys[@panels[_domain_name]['sons'].length-1]
          @panels[_domain_name]['notebook'].raise(new_raise_key)
        end
      end
    elsif @panels[_domain_name]['sons'].length == 0
      #title_titled_frame(_domain_name, '')
      @panels[_domain_name]['root'].title('')
      @panels[_domain_name]['root'].top_text_clear
    end
    build_invert_menu if refresh_menu
  end

  def view_panel
  end

  def hide_panel(_domain, _extension)
    pan = @panels[_domain]
    if @tabbed
      if pan && pan['notebook'] != nil
        pan['notebook'].unpack
      end
    elsif pan
      pan['sons'].each{|k,v|
        if k == _extension
          v.hide
          break
        end
      }
    end
  end

  def [](_row, _col)
    @frames[_row][_col]
  end

  def frame(_domain_name, _name)
    @panels[_domain_name]['sons'][_name].hinner_frame
  end

  #  def domain_for_frame(_domain_name, _name)
  #    domain(@panels[_domain_name]['sons'][_name].domain)
  #  end

  def domain(_domain_name)
    @panels[_domain_name]
  end

  def domain_root_frame(_domain_name)
    @panels[_domain_name]['root'].frame
  end

  def add_float_frame(_args=nil)
    if _args.nil?
      _args = {'x'=>10, 'y'=>10, 'width'=>100, 'height'=>100}
    end
    _frame =  TkFloatTitledFrame.new(root)
    _frame.on_close=proc{_frame.hide}
    _frame.place(_args)
    return _frame
  end

  def add_hinner_dialog(side='top', args=nil)
    hd = HinnerDialog.new(side, args)
    return hd
  end

  def add_hinner_splitted_dialog(side='top', height=100, args=nil)
    hd = HinnerSplittedDialog.new(side, height, args)
    return hd
  end

  def add_hinner_splitted_dialog_titled(title=nil, side='top', height=100, args=nil)
    hd = HinnerSplittedDialogTitled.new(title, side, height, args)
    return hd
  end

  def dump_splitter(_splitter)
    ret = ''
    if  _splitter.instance_of?(AGTkVSplittedFrames)
      w = TkWinfo.width(_splitter.frame1)
      ret = "c#{w}"
    elsif _splitter.instance_of?(AGTkOSplittedFrames)
      h = TkWinfo.height(_splitter.frame1)
      ret = "r#{h}"
    end
    ret
  end

  def splitter_frame_on_frame(_frame)
    ret=nil
    @splitters.each{|sp|
      if sp.frame == _frame
        ret = sp
        break
      end
    }
    ret
  end

  def get_hinner_frame(_frame)
    ret = _frame
    #    child = TkWinfo.children(_frame)[0]
    TkWinfo.children(_frame).each{|child|
      if child.instance_of?(TkTitledFrameAdapter)
        ret = child.frame
        break
      end
    }
    #    if child.instance_of?(TkTitledFrame)
    #      ret = child.frame
    #    end
    ret
  end

  def shift_domain_column(_r,_c,_dom)
    Hash.new.update(_dom).each{|k,d|
      dr,dc=d.split('.')
      if dc.to_i >= _c && dr.to_i == _r
        #shift_domain_column(_r,dc.to_i+1,_dom)
        #p "== #{d} --> #{domain_name(_r,dc.to_i+1)}"
        _dom[k]= domain_name(_r,dc.to_i+1)
      end
    }
  end

  def shift_domain_row(_r,_c,_dom)
    Hash.new.update(_dom).each{|k,d|
      dr,dc=d.split('.')
      if dr.to_i >= _r && dc.to_i == _c
        #shift_domain_row(dr.to_i+1,_c,_dom)
        #p "shift_domain_row == #{d} --> #{domain_name(dr.to_i+1,_c)}"
        _dom[k]=domain_name(dr.to_i+1,_c)
      end
    }
  end

  def gap_domain_column(_r,_c,_dom)
    ret = _c
    Hash.new.update(_dom).each{|k,d|
      dr,dc=d.split('.')
      if dc.to_i == _c && dr.to_i == _r
        ret = gap_domain_column(_r,dc.to_i+1,_dom)
      end
    }
    ret
  end

  def gap_domain_row(_r,_c,_dom)
    ret = _r
    Hash.new.update(_dom).each{|k,d|
      dr,dc=d.split('.')
      if dr.to_i == _r && dc.to_i == _c
        ret = gap_domain_row(dr.to_i+1,_c,_dom)
      end
    }
    ret
  end


  def dump_geometry(_r=0,_c=0,_frame=root)
    spl = Array.new
    dom = Hash.new
    ret = [nil,nil,nil,nil]
    sp = splitter_frame_on_frame(_frame)
    if sp
      spl << "#{domain_name(_r,_c)}#{dump_splitter(sp)}"
      dom[get_hinner_frame(sp.frame1)]=domain_name(_r,_c)
      sspl,ddom,rr,cc = dump_geometry(_r, _c, sp.frame1)
      spl.concat(sspl)
      dom.update(ddom)
      if sp.instance_of?(AGTkVSplittedFrames)
        _c=cc+1
        _c=gap_domain_column(_r,_c,dom)
      else
        _r=rr+1
        _r=gap_domain_row(_r,_c,dom)
      end
      dom[get_hinner_frame(sp.frame2)]=domain_name(_r,_c)
      sspl,ddom,rr,cc = dump_geometry(_r, _c, sp.frame2)
      spl.concat(sspl)
      dom.update(ddom)
    elsif _frame==root
      dom[get_hinner_frame(root)]=domain_name(_r,_c)
    end
    ret[0]=spl
    ret[1]=dom
    ret[2]=_r
    ret[3]=_c
    ret
  end
end

#
# receives messages and tracks the
# by Roger D. Pack
class MonitorLastUsedDir

  def initialize
    for event in [SaveBufferEvent, AckInFilesEvent, SearchInFilesEvent, OpenBufferEvent] do
      Arcadia.attach_listener(self, event)
    end
  end

  def on_after_save_as_buffer(_event)
    MonitorLastUsedDir.set_last _event.new_file
  end

  def on_after_ack_in_files _event
    MonitorLastUsedDir.set_last _event.dir
  end

  # we want this one...but...not at startup time...hmm.
  def on_after_open_buffer _event
    MonitorLastUsedDir.set_last _event.file
  end

  alias :on_after_search_in_files :on_after_ack_in_files

  def self.get_last_dir
    current = $arcadia['pers']['last.used.dir']
    if current != nil && current != ''
      current
    else
      $pwd # startup dir
    end
  end

  def MonitorLastUsedDir.set_last to_this # TODO set as private...
    return if to_this.nil? or to_this == ''
    if(File.directory?(to_this))
      to_this_dir = to_this
    elsif File.directory? File.dirname(to_this)
      # filename,
      to_this_dir = File.dirname(to_this)
    end
    $arcadia['pers']['last.used.dir'] = File.expand_path(to_this_dir)
  end

end

require 'tk/clipboard'

class FocusEventManager
  attr_reader :last_focus_widget
  def initialize
    Arcadia.attach_listener(self, FocusEvent)
    Arcadia.attach_listener(self, InputEvent)
  end

  def on_input(_event)
    case _event
    when InputEnterEvent
      @last_focus_widget = _event.receiver
    when InputExitEvent
      @last_focus_widget = nil
    end
  end

  def on_focus(_event)
    if @last_focus_widget
      _event.focus_widget = @last_focus_widget
    else
      _event.focus_widget=Tk.focus
    end
    case _event
    when CutTextEvent
      do_cut(_event.focus_widget)
    when CopyTextEvent
      do_copy(_event.focus_widget)
    when PasteTextEvent
      do_paste(_event.focus_widget)
    when UndoTextEvent
      do_undo(_event.focus_widget)
    when RedoTextEvent
      do_redo(_event.focus_widget)
    when SelectAllTextEvent
      do_select_all(_event.focus_widget)
    when InvertSelectionTextEvent
      do_invert_selection(_event.focus_widget)
    when UpperCaseTextEvent
      do_upper_case(_event.focus_widget)
    when LowerCaseTextEvent
      do_lower_case(_event.focus_widget)
    end
  end

  def do_cut(_focused_widget)
    if _focused_widget.respond_to?(:text_cut)
      _focused_widget.text_cut
    elsif _focused_widget.kind_of?(Tk::Entry)
      if _focused_widget.selection_present
        i1= _focused_widget.index("sel.first")
        i2= _focused_widget.index("sel.last")
        TkClipboard::set(_focused_widget.value[i1.to_i..i2.to_i-1])
        _focused_widget.delete(i1,i2)
      end
    end
  end

  def do_copy(_focused_widget)
    if _focused_widget.respond_to?(:text_copy)
      _focused_widget.text_copy
    elsif _focused_widget.kind_of?(Tk::Entry)
      if _focused_widget.selection_present
        i1= _focused_widget.index("sel.first")
        i2= _focused_widget.index("sel.last")
        TkClipboard::set(_focused_widget.value[i1.to_i..i2.to_i-1])
      end
    end
  end

  def do_paste(_focused_widget)
    if _focused_widget.respond_to?(:text_paste)
      _focused_widget.text_paste
    elsif _focused_widget.kind_of?(Tk::Entry)
      _focused_widget.insert(_focused_widget.index("insert"), TkClipboard::get)
    end
  end

  def do_undo(_focused_widget)
    begin
      _focused_widget.edit_undo if _focused_widget.respond_to?(:edit_undo)
    rescue RuntimeError => e
      throw e unless e.to_s.include? "nothing to undo" # this is ok--we've done undo back to the beginning
    end
  end

  def do_redo(_focused_widget)
    begin
      _focused_widget.edit_redo if _focused_widget.respond_to?(:edit_redo)
    rescue RuntimeError => e
      throw e unless e.to_s.include? "nothing to redo" # this is ok--we've done redo back to the beginning
    end
  end

  def do_select_all(_focused_widget)
    if _focused_widget.respond_to?(:tag_add)
      _focused_widget.tag_add('sel','1.0','end')
    elsif _focused_widget.kind_of?(Tk::Entry)
      _focused_widget.selection_from('0')
      _focused_widget.selection_to('end')
    end
  end

  def do_invert_selection(_focused_widget)
    if _focused_widget.respond_to?(:tag_ranges)
      r = _focused_widget.tag_ranges('sel')
      _focused_widget.tag_add('sel','1.0','end') if _focused_widget.respond_to?(:tag_add)
      _focused_widget.tag_remove('sel',r[0][0],r[0][1]) if _focused_widget.respond_to?(:tag_remove) && r && r[0]
    end
  end

  def do_upper_case(_focused_widget)
    if _focused_widget.respond_to?(:do_upper_case)
      _focused_widget.do_upper_case
    else
      _replace_sel(_focused_widget, :upcase)
    end
  end

  def do_lower_case(_focused_widget)
    if _focused_widget.respond_to?(:do_lower_case)
      _focused_widget.do_lower_case
    else
      _replace_sel(_focused_widget, :downcase)
    end
  end

  def _replace_sel(_focused_widget, _method)
    if _focused_widget.respond_to?(:tag_ranges)
      r = _focused_widget.tag_ranges('sel')
      if _focused_widget.respond_to?(:get) && r && r[0]
        target_text = _focused_widget.get(r[0][0],r[0][1])
        if target_text
          _focused_widget.delete(r[0][0],r[0][1])
          _focused_widget.insert(r[0][0],target_text.send(_method))
        end
      end
    elsif _focused_widget.kind_of?(Tk::Entry)
      if _focused_widget.selection_present
        i1= _focused_widget.index("sel.first")
        i2= _focused_widget.index("sel.last")
        target_text = _focused_widget.value[i1.to_i..i2.to_i-1]
        _focused_widget.delete(i1,i2)
        _focused_widget.insert(i1,target_text.send(_method))
      end
    end
  end
end


class ArcadiaUtils
  def ArcadiaUtils.unix_child_pids(_ppid)
    ret = Array.new
    readed = ''
    open("|ps -o pid,ppid ax | grep #{_ppid}", "r"){|f|  readed = f.read  }
    apids = readed.split
    apids.each_with_index do |v,i|
      ret << v if i % 2 == 0 && v != _ppid.to_s
    end
    subpids = Array.new
    ret.each{|ccp|
      subpids.concat(unix_child_pids(ccp))
    }
    ret.concat(subpids)
  end
  
  def ArcadiaUtils.exec(_cmd_=nil)
    return nil if _cmd_.nil?
    to_ret = ''
    begin
      open("|#{_cmd_}", "r"){|f| 
        #to_ret = f.readlines
        to_ret = f.read
      }
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
    to_ret
  end
end