#
#   a-core.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=..
#   &require_omissis=conf/arcadia.init
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
  attr_reader :layout
  attr_reader :wf
  def initialize
    super(
      ApplicationParams.new(
        'arcadia',
        '0.9.3',
        'conf/arcadia.conf',
        'conf/arcadia.pers'
      )
    ) 
    load_config
    if self['conf']['encoding']
      Tk.encoding=self['conf']['encoding']
    end
#    @use_splash = self['conf']['splash.show']=='yes'
#    @splash = ArcadiaAboutSplash.new if @use_splash
#    @splash.set_progress(50) if @splash
#    @splash.deiconify if @splash
#    Tk.update
    @wf = TkWidgetFactory.new
    ArcadiaDialogManager.new(self)
    ArcadiaActionDispatcher.new(self)
    ArcadiaGemsWizard.new(self)
    MonitorLastUsedDir.new
    FocusEventManager.new
    #self.load_local_config(false)
    ObjectSpace.define_finalizer($arcadia, self.class.method(:finalize).to_proc)
    publish('action.on_exit', proc{do_exit})
    #_title = "Arcadia Ruby ide :: [Platform = #{RUBY_PLATFORM}] [Ruby version = #{RUBY_VERSION}] [TclTk version = #{tcltk_info.level}]"
    _title = "Arcadia ide "
    @root = TkRoot.new(
      'background'=> self['conf']['background']
      ){
      title _title
      withdraw
      protocol( "WM_DELETE_WINDOW", $arcadia['action.on_exit'])
      iconphoto(TkPhotoImage.new('dat'=>ARCADIA_RING_GIF))
    }
    @on_event = Hash.new

    @main_menu_bar = TkMenubar.new(
      'background'=> self['conf']['background']
    ).pack('fill'=>'x')
    @mf_root = Tk::BWidget::MainFrame.new(@root,
     'background'=> self['conf']['background'],
     'height'=> 0
      ){
      menu @main_menu_bar
    }.pack(
      'anchor'=> 'center',
      'fill'=> 'both',
      'expand'=> 1
    )
    #.place('x'=>0,'y'=>0,'relwidth'=>1,'relheight'=>1)
    @mf_root.show_statusbar('none')
    #@toolbar = @mf_root.add_toolbar
    @main_toolbar = ArcadiaMainToolbar.new(self, @mf_root.add_toolbar)
    @is_toolbar_show=self['conf']['user_toolbar_show']=='yes'
    @mf_root.show_toolbar(0,@is_toolbar_show)
    @use_splash = self['conf']['splash.show']=='yes'
    @splash = ArcadiaAboutSplash.new if @use_splash
    @splash.set_progress(50) if @splash
    @splash.deiconify if @splash
    Tk.update
    @splash.next_step('..prepare')  if @splash
    prepare
    @splash.last_step('..load finish')  if @splash
    if self['conf']['geometry']
      geometry = self['conf']['geometry']
    else
      start_width = (TkWinfo.screenwidth(@root)-4)
      start_height = (TkWinfo.screenheight(@root)-20)
      if RUBY_PLATFORM =~ /mswin|mingw/ # on doze don't go below the start gar
        start_height -= 50
        start_width -= 20
      end
      geometry = start_width.to_s+'x'+start_height.to_s+'+0+0'
    end
    @root.deiconify
    @root.focus(true)
    @root.geometry(geometry)
    @root.raise
    Tk.update_idletasks
    if self['conf']['geometry.state'] == 'zoomed'
      if Arcadia.is_windows?
        @root.state('zoomed')
      else
        @root.wm_attributes('zoomed',1)
      end
    end
    #sleep(1)
    @splash.destroy  if @splash
    if @first_run # first ARCADIA ever
      Arcadia.process_event(OpenBufferEvent.new(self,'file'=>'README'))
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
  end

  def on_quit(_event)
    self.do_exit
  end
  
  def register(_ext)
    @exts_i << _ext
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
      if Gem.respond_to?(:available?)
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
          @splash.next_step('... creating '+extension)  if @splash
          @exts.delete(extension) unless 
            (((@exts_dip[extension] != nil && @exts_loaded.include?(@exts_dip[extension]))||@exts_dip[extension] == nil) && ext_create(extension)) 
        end
      end
    }
    begin
      _build_event = Arcadia.process_event(BuildEvent.new(self))
    rescue Exception
      ret = false
      msg = "During build event processing(#{$!.class.to_s}) : #{$!} at : #{$@.to_s}"
      ans = Tk.messageBox('icon' => 'error', 'type' => 'abortretryignore',
      'title' => "(Arcadia) Build face", 'parent' => @root,
      'message' => msg)
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
    rescue Exception,LoadError
      ret = false
      msg = "Loading \"#{_extension}\" (#{$!.class.to_s}) : #{$!} at : #{$@.to_s}"
      ans = Tk.messageBox('icon' => 'error', 'type' => 'abortretryignore',
      'title' => "(Arcadia) Extensions '#{_extension}'", 'parent' => @root,
      'message' => msg)
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
    rescue Exception,LoadError
      ret = false
      msg = "Loading \"#{_extension}\" (#{$!.class.to_s}) : #{$!} at : #{$@.to_s}"
      ans = Tk.messageBox('icon' => 'error', 'type' => 'abortretryignore',
      'title' => "(Arcadia) Extensions '#{_extension}'", 'parent' => @root,
      'message' => msg)
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

  def ext_method(_extension, _method)
    begin
      self[_extension].send(_method)
    rescue Exception
      msg = _method.to_s+' "'+_extension.to_s+'"'+" ("+$!.class.to_s+") "+" : "+$! + "\n at : "+$@.to_s
      ans = Tk.messageBox('icon' => 'warning', 'type' => 'abortretryignore',
      'title' => '(Arcadia) Extensions', 'parent' => @root,
      'message' => msg)
      if ans == 'abort'
        raise
        exit
      elsif ans == 'retry'
        retry
      else
        Tk.update
      end
    end
  end

  def init_layout
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
                @layout.add_cols(pt[0].to_i, pt[1].to_i, w.to_i)
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
                  @layout.add_rows(pt[0].to_i, pt[1].to_i, w.to_i)
                end
              end
            end
            
          rescue Exception
            msg = "Loading layout: (#{$!.class.to_s} : #{$!.to_s} at : #{$@.to_s})"
            if Arcadia.dialog(self, 'type'=>'ok_cancel', 'level'=>'error','title' => '(Arcadia) Layout', 'msg'=>msg)=='cancel'
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
    self.load_local_config
    self.load_theme(self['conf']['theme'])
    self.resolve_properties_link(self['conf'],self['conf'])
    self.resolve_properties_link(self['conf_without_local'],self['conf_without_local'])
    self.load_sysdefaultproperty
  end

  def load_sysdefaultproperty
#    colors = Hash.new
#    colors['background']=self['conf']['background']
#    colors['foreground']=self['conf']['foreground']
#    
#    TkPalette.set(colors)
  
    Tk.tk_call "eval","option add *background #{self['conf']['background']}"
    Tk.tk_call "eval","option add *foreground #{self['conf']['foreground']}"
    #Tk.tk_call "eval","option add *font #{self['conf']['font']}"
    Tk.tk_call "eval","option add *activebackground #{self['conf']['activebackground']}"
    Tk.tk_call "eval","option add *activeforeground #{self['conf']['activeforeground']}"
  end

  def prepare
    super
    @splash.next_step('...initialize')  if @splash
    @splash.next_step  if @splash
    #self.load_libs
    @splash.next_step  if @splash
    @splash.next_step('... load extensions')  if @splash
    #load_config
    init_layout
    publish('buffers.code.in_memory',Hash.new)
    publish('action.load_code_from_buffers', proc{TkBuffersChoise.new})
    publish('output.action.run_last', proc{$arcadia['output'].run_last})
    publish('main.action.open_file', proc{self['editor'].open_file(Arcadia.open_file_dialog)})
    @splash.next_step('... load obj controller')  if @splash
    @splash.next_step('... load editor')  if @splash
    publish('main.action.new_file',proc{$arcadia['editor'].open_buffer()})
    @splash.next_step('... load actions')  if @splash
    #provvisorio 
    @keytest = KeyTest.new
    @keytest.on_close=proc{@keytest.hide}
    @keytest.hide
    @keytest.title("Keys test")
    publish('action.test.keys', proc{@keytest.show})
    publish('action.get.font', proc{Tk::BWidget::SelectFont::Dialog.new.create})
    @splash.next_step  if @splash
    publish('action.show_about', proc{ArcadiaAboutSplash.new.deiconify})
#    publish('main.menu', @main_menu)
    @main_menu = ArcadiaMainMenu.new(@main_menu_bar)
    self.do_build
    #publish('main.menu', ArcadiaMainMenu.new(@main_menu))
    @splash.next_step  if @splash
    publish('objic.action.raise_active_obj',
    proc{
    		InspectorContract.instance.raise_active_toplevel(self)
    }
    )
    @splash.next_step('... toolbar buttons ')  if @splash
    #@main_toolbar.load_toolbar_buttons
    
    #load user controls
    #Arcadia control
    load_user_control(@main_toolbar)
    load_user_control(@main_menu)
    #Extension control
    load_key_binding
    @exts.each{|ext|
      @splash.next_step("... load #{ext} user controls ")  if @splash
      load_user_control(@main_menu, ext)
      load_user_control(@main_toolbar, ext)
      load_key_binding(ext)
    }
    load_user_control(@main_menu,"","e")
    load_user_control(@main_toolbar,"","e")
    load_runners
    #@layout.build_invert_menu
  end
  
  def load_runners
    self['runners'] = Hash.new
    self['runners_by_ext'] = Hash.new
    mr = Arcadia.menu_root('runcurr')
    return if mr.nil?

    insert_runner_item = proc{|name, run|
      if run[:file_exts]
        run[:file_exts].split(',').each{|ext|
          self['runners_by_ext'][ext.strip.sub('.','')]=run
        }
      end
      if run[:runner] && self['runners'][run[:runner]]
        run = Hash.new.update(self['runners'][run[:runner]]).update(run)
        #self['runners'][name]=run
      end
      _run_title = run[:title]
      run[:title] = nil
      run[:runner_name] = name
      _command = proc{
          _event = Arcadia.process_event(
            RunCmdEvent.new(self, run)
          )
      }
      mr.insert('0', 
        :command ,{
          :image => Arcadia.file_icon(run[:file_exts]),
          :label => _run_title,
          :compound => 'left',
          :command => _command
        }
      )
    }

    insert_runner_instance_item = proc{|name, run|
      if run[:runner] && self['runners'][run[:runner]]
        run = Hash.new.update(self['runners'][run[:runner]]).update(run)
        #self['runners'][name]=run
      end
      _run_title = run[:title]
      run[:title] = nil
      run[:runner_name] = name
      _command = proc{
          _event = Arcadia.process_event(
            RunCmdEvent.new(self, run)
          )
      }
      mr.insert('0', 
        :command ,{
          :image => Arcadia.file_icon(run[:file_exts]),
          :label => _run_title,
          :compound => 'left',
          :command => _command
        }
      )
    }

    # conf runner
    runs=Arcadia.conf_group('runners')
    mr.insert('0', :separator) if runs && !runs.empty?

    runs.each{|name, hash_string|
      self['runners'][name]=eval hash_string
    }
    
    self['runners'].each{|name, run|
      insert_runner_item.call(name, run)
    }

    # pers runner instance
    runs=Arcadia.pers_group('runners')
    mr.insert('0', :separator) if runs && !runs.empty?
    pers_runner = Hash.new
    runs.each{|name, hash_string|
      begin
        pers_runner[name]=eval hash_string
      rescue Exception => e
        p  "Loading runners : probably bud runner conf '#{hash_string}' : #{e.message}"
        Arcadia.unpersistent("runners.#{name}")
      end
    }
    
    pers_runner.each{|name, run|
      insert_runner_instance_item.call(name, run)
    }
  end

  def manage_runners
    if !@runm
      @runm = RunnerManager.new(Arcadia.layout.root)
      @runm.on_close=proc{@runm.hide}
    end
    @runm.show
    @runm.load_items 

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
      value = v.strip
      key_dits = k.split('[')
      next if k.length == 0
      key_event=key_dits[0]
      if key_dits[1]
        key_sym=key_dits[1][0..-2]
      end
      @root.bind_append(key_event){|e|
        if key_sym == e.keysym
          Arcadia.process_event(_self_on_eval.instance_eval(value))
        end
      }
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
    contexts_caption = self['conf']["#{suf}.contexts.caption"]
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
              item_args[k]= make_value(_self_on_eval, v)
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
          msg = "Loading #{groups} ->#{items} (#{$!.class.to_s} : #{$!.to_s} at : #{$@.to_s})"
          if Arcadia.dialog(self, 
            'type'=>'ok_cancel', 
            'title' => "(Arcadia) #{_user_control.class::SUF}", 
            'msg'=>msg,
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
                        'msg'=>"Do you want exit?",
                        'title' => '(Arcadia) Exit',
                        'level' => 'question')=='yes')
    if q1 && can_exit?
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
      a[3] = (a[3].to_i - toolbar_height).to_s
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
      if Arcadia.is_windows?
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
            str_frames << '-1.-1'
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

  def  Arcadia.runner(_name=nil)
    if @@instance
      return @@instance['runners'][_name]  
    end
  end

  
  def Arcadia.dialog(_sender, _args=Hash.new)
    _event = process_event(DialogEvent.new(_sender, _args))  
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
  
  def Arcadia.runner(_name)
	  @@instance['runners'][_name] if @@instance
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
  
  def Arcadia.open_file_dialog
     Tk.getOpenFile 'initialdir' => MonitorLastUsedDir.get_last_dir
  end

  def Arcadia.is_windows?
    RUBY_PLATFORM =~ /mingw|mswin/
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

  
  def Arcadia.file_icon(_file_name)
    _file_name = '' if _file_name.nil?
    if @@instance['file_icons'] == nil
      @@instance['file_icons'] = Hash.new 
      @@instance['file_icons']['default']= TkPhotoImage.new('dat' => FILE_ICON_DEFAULT)
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
          @@instance['file_icons'][file_dn]= TkPhotoImage.new('dat' => eval(file_icon_name))
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
  class UserItem < UserItem
    attr_accessor :frame
    attr_accessor :menu_button
    def initialize(_sender, _args)
      super(_sender, _args)
      _image = TkPhotoImage.new('data' => @image_data) if @image_data
      _command = @command #proc{Arcadia.process_event(@event_class.new(_sender, @event_args))} if @event_class
      _hint = @hint
      _font = @font
      _caption = @caption
      @item_obj = Tk::BWidget::Button.new(_args['frame'], Arcadia.style('toolbarbutton')){
        image  _image if _image
        command _command if _command
        width 20
        height 20
        helptext  _hint if _hint
        text _caption if _caption
      }
      if _args['context_path'] && _args['last_item_for_context']
        @item_obj.pack('after'=>_args['last_item_for_context'].item_obj, 'side' =>'left', :padx=>2, :pady=>0)
      else
        @item_obj.pack('side' =>'left', :padx=>2, :pady=>0)
      end
      if _args['menu_button'] && _args['menu_button'] == 'yes'
        @menu_button = TkMenuButton.new(_args['frame'], Arcadia.style('toolbarbutton')){|mb|
          indicatoron false
          menu TkMenu.new(mb, Arcadia.style('titlemenu'))
          image TkPhotoImage.new('dat' => MENUBUTTON_ARROW_DOWN_GIF)
          padx 0
          pady 0
          pack('side'=> 'left','anchor'=> 's','pady'=>3)
        }     
        Arcadia.menu_root(_args['name'], @menu_button.cget('menu'))  
      end
      #Tk::BWidget::Separator.new(@frame, :orient=>'vertical').pack('side' =>'left', :padx=>2, :pady=>2, :fill=>'y',:anchor=> 'w')
    end

    def enabled=(_value)
      if _value
        @item_obj.state='enable'
      else
        @item_obj.state='disable'
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

#  def load_toolbar_buttons
#    suf = 'toolbar_buttons'
#    return if @arcadia['conf'][suf].nil?
#    @buttons = Hash.new
#    toolbar_buttons = @arcadia['conf'][suf].split(',')
#    toolbar_buttons.each{|groups|
#      if groups
#        suf1 = suf+'.'+groups
#        begin
#          buttons = @arcadia['conf'][suf1].split(',')
#          buttons.each{|button|
#            suf2 = suf1+'.'+button
#            name = @arcadia['conf'][suf2+'.name']
#            text = @arcadia['conf'][suf2+'.text']
#            image = @arcadia['conf'][suf2+'.image']
#            font = @arcadia['conf'][suf2+'.font']
#            background = @arcadia['conf'][suf2+'.background']
#            foreground = @arcadia['conf'][suf2+'.foreground']
#            hint = @arcadia['conf'][suf2+'.hint']
#            action = @arcadia['conf'][suf2+'.action']
#            actions = action.split('->')  if action
#            if actions && actions.length>1
#              _command = proc{
#                action_obj = $arcadia[actions[0]]
#                1.upto(actions.length-2) do |x|
#                  action_obj = action_obj.send(actions[x])
#                end
#                action_obj.send(actions[actions.length-1])
#              }
#            elsif action
#              _command = proc{$arcadia[action].call}
#            end
#            @buttons[name] = Tk::BWidget::Button.new(@frame){
#              image  TkPhotoImage.new('data' => eval(image)) if image
#              borderwidth 1
#              font font if font
#              background background if background
#              foreground foreground if foreground
#              command _command if action
#              relief 'flat'
#              helptext  hint if hint
#              text text if text
#              pack('side' =>'left', :padx=>2, :pady=>0)
#            }
#          }
#        rescue Exception
#          msg = 'Loading '+groups+'" -> '+buttons.to_s+ '" (' + $!.class.to_s + ") : " + $!.to_s + " at : "+$@.to_s
#          if Tk.messageBox('icon' => 'error', 'type' => 'okcancel',
#            'title' => '(Arcadia) Toolbar', 'parent' => @frame,
#            'message' => msg) == 'cancel'
#            raise
#            exit
#          else
#            Tk.update
#          end
#        end
#      end
#      Tk::BWidget::Separator.new(@frame, :orient=>'vertical').pack('side' =>'left', :padx=>2, :pady=>2, :fill=>'y',:anchor=> 'w')
#    }
#  end

  
end

class ArcadiaMainMenu < ArcadiaUserControl
  SUF='user_menu'
  class UserItem < UserItem
    attr_accessor :menu
    attr_accessor :underline
    attr_accessor :type
    def initialize(_sender, _args)
      super(_sender, _args)
      _command = @command #proc{ Arcadia.process_event(@event_class.new(_sender, @event_args)) } if @event_class
      #_menu = @menu[@parent]
      item_args = Hash.new
      item_args['image']=TkPhotoImage.new('data' => @image_data) if @image_data
      item_args['label']=@caption
      item_args['underline']=@underline.to_i if @underline != nil
      item_args['compound']='left'
      item_args['command']=_command
      if @type.nil? && _commnad.nil? && @name == '-'
        @type=:separator
        item_args.clear
      elsif @type.nil?
        @type=:command
      end
      @item_obj = @menu.insert('end', @type ,item_args)  
      @index = @menu.index('last')
    end

    def enabled=(_value)
      if _value
        @item_obj.entryconfigure(@index, 'state'=>'enable')
      else
        @item_obj.entryconfigure(@index,'state'=>'disable')
      end
    end
  end
  
  def initialize(menu)
    # create main menu
    @menu = menu
    build
    @menu.configure(Arcadia.style('menu'))
  end

  def get_menu_context(_menubar, _context, _underline=nil)
    menubuttons =  _menubar[0..-1]
    # cerchiamo il context
    m_i = -1
    menubuttons.each_with_index{|mb, i|
      _t = mb[0].cget('text')
      if _t==_context
        m_i = i 
        break
      end
    }
    if m_i > -1
      _menubar[m_i][1]
    else
      _menubar.add_menu([[_context,_underline],[]])[1].delete(0)
    end
  end
  
  def get_sub_menu(menu_context, folder=nil)
    if folder
      s_i = -1 
      i_end = menu_context.index('end')
      if i_end
        0.upto(i_end){|j|
          type = menu_context.menutype(j)
          if type != 'separator'
            l = menu_context.entrycget(j,'label')
            if l == folder && type == 'cascade'
             s_i = j
             break
            end
          end
        }
      end
    end
    if s_i > -1 #&& menu_context.menutype(s_i) == 'cascade'
      sub = menu_context.entrycget(s_i, 'menu')
    else
      sub = TkMenu.new(
        :parent=>@pop_up,
        :tearoff=>0
      )
      sub.configure(Arcadia.style('menu'))
      sub.extend(TkAutoPostMenu)
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
      _args['menu']=make_menu_in_menubar(@menu, conte, _args['context_path'], _args['context_underline'])
    else
      if Arcadia.menu_root(_args['rif'])
        _args['menu']=make_menu(Arcadia.menu_root(_args['rif']), _args['context_path'], _args['context_underline'])
      else
        msg = "During building of menu item \"#{_args['name']}\" rif \"#{_args['rif']}\" not found!"
        Arcadia.dialog(self, 
            'type'=>'ok', 
            'title' => "(Arcadia) #{self.class::SUF}", 
            'msg'=>msg,
            'level'=>'error')

        _args['menu']=make_menu_in_menubar(@menu, conte, _args['context_path'], _args['context_underline'])
      end
    end
    super(_sender, _args)
  end


  def build
    menu_spec_file = [
      ['File', 0],
      ['Open', proc{Arcadia.process_event(OpenBufferEvent.new(self,'file'=>Arcadia.open_file_dialog))}, 0],
      ['New', $arcadia['main.action.new_file'], 0],
      #['Save', proc{EditorContract.instance.save_file_raised(self)},0],
      ['Save', proc{Arcadia.process_event(SaveBufferEvent.new(self))},0],
      ['Save as ...', proc{Arcadia.process_event(SaveAsBufferEvent.new(self))},0],
      '---',
      ['Quit', $arcadia['action.on_exit'], 0]]
      menu_spec_edit = [['Edit', 0],
      ['Cut', proc{Arcadia.process_event(CutTextEvent.new(self))}, 2],
      ['Copy', proc{Arcadia.process_event(CopyTextEvent.new(self))}, 0],
      ['Paste', proc{Arcadia.process_event(PasteTextEvent.new(self))}, 0],
      ['Undo', proc{Arcadia.process_event(UndoTextEvent.new(self))}, 0],
      ['Redo', proc{Arcadia.process_event(RedoTextEvent.new(self))}, 0],
      ['Select all', proc{Arcadia.process_event(SelectAllTextEvent.new(self))}, 0],
      ['Invert selection', proc{Arcadia.process_event(InvertSelectionTextEvent.new(self))}, 0],
      ['Uppercase', proc{Arcadia.process_event(UpperCaseTextEvent.new(self))}, 0],
      ['Lowercase', proc{Arcadia.process_event(LowerCaseTextEvent.new(self))}, 0],
      ['Prettify Current', proc{Arcadia.process_event(PrettifyTextEvent.new(self))}, 0]]
      
      menu_spec_search = [['Search', 0],
      ['Find/Replace ...', proc{Arcadia.process_event(SearchBufferEvent.new(self))}, 2],
      ['Find in files...', proc{Arcadia.process_event(SearchInFilesEvent.new(self))}, 2],
      ['Ack in files...', proc{Arcadia.process_event(AckInFilesEvent.new(self))}, 2],
      ['Go to line ...', proc{Arcadia.process_event(GoToLineBufferEvent.new(self))}, 2]]
      menu_spec_view = [['View', 0],['Show/Hide Toolbar', proc{$arcadia.show_hide_toolbar}, 2],
      ['Close current tab', proc{Arcadia.process_event(CloseCurrentTabEvent.new(self))}, 0],
      ]
      menu_spec_tools = [['Tools', 0],
      ['Keys-test', $arcadia['action.test.keys'], 2],
      ['Edit prefs', proc{Arcadia.process_event(OpenBufferEvent.new(self,'file'=>$arcadia.local_file_config))}, 0],
      ['Load from edited prefs', proc{$arcadia.load_local_config}, 0]
    ]
    menu_spec_help = [['Help', 0],
    ['About', $arcadia['action.show_about'], 2],]
    @menu.add_menu(menu_spec_file)
    @menu.add_menu(menu_spec_edit)
    @menu.add_menu(menu_spec_search)
    @menu.add_menu(menu_spec_view)
    @menu.add_menu(menu_spec_tools)
    @menu.add_menu(menu_spec_help)
  
#    #@menu.bind_append("1", proc{
#      chs = TkWinfo.children(@menu)
#      hh = 25
#      @last_post = nil
#      chs.each{|ch|
#        ch.bind_append("Enter", proc{|x,y,rx,ry|
#          @last_post.unpost if @last_post && @last_post != ch.menu
#          ch.menu.post(x-rx,y-ry+hh)
#          @last_post=ch.menu}, "%X %Y %x %y")
#        ch.bind_append("Leave", proc{
#          @last_post.unpost if @last_post
#          @last_post=nil
#        })
#      }
#
#    #})

#      @menu.bind_append("Leave", proc{
#        if Tk.focus != @last_menu_posted 
#          @last_post.unpost if @last_post
#          @last_post=nil
#        end
#      })
#      


#      chs = TkWinfo.children(@menu)
#      hh = 25
#      @last_post = nil
#      chs.each{|ch|
#        ch.bind_append("Enter", proc{|x,y,rx,ry|
#          @last_post.unpost if @last_post && @last_post != ch.menu
#          ch.menu.post(x-rx,y-ry+hh)
#          chmenus = TkWinfo.children(ch)
#          @last_menu_posted = chmenus[0]
#          @last_menu_posted.set_focus
#          #@last_post=ch.menu
#          }, "%X %Y %x %y")
#        ch.bind_append("Leave", proc{
#          @last_post.unpost if @last_post
#          #@last_post=nil
#          @last_post=ch.menu
#        })
#      }
#      @menu.bind_append("Leave", proc{
#        if Tk.focus != @last_menu_posted 
#          @last_post.unpost if @last_post
#          @last_post=nil
#        end
#      })
     @menu.extend(TkAutoPostMenu)      
     @menu.event_posting_on
  end
  
end

class RunnerManager < TkFloatTitledFrame
  class RunnerMangerItem  < TkFrame
    def initialize(_parent=nil, _runner_hash=nil, *args)
      super(_parent, Arcadia.style('panel'))
      @runner_hash = _runner_hash
      Tk::BWidget::Label.new(self, 
         'image'=> Arcadia.file_icon(_runner_hash[:file_exts]),
         'relief'=>'flat').pack('side' =>'left')
      Tk::BWidget::Label.new(self, 
         'text'=>_runner_hash[:title],
         'helptext'=>_runner_hash[:file],
         'compound'=>:left, 
         'relief'=>'flat').pack('fill'=>'x','side' =>'left')
      _close_command = proc{
        if (Arcadia.dialog(self, 'type'=>'yes_no',
                        'msg'=>"Do you want delete runner item '#{_runner_hash[:name]}'?",
                        'title' => '(Arcadia) Manage runners',
                        'level' => 'question')=='yes')
        
          Arcadia.unpersistent("runners.#{_runner_hash[:name]}")
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
          self.destroy
        end
      }   
      Tk::BWidget::Button.new(self, 
         'command'=>_close_command,
         'helptext'=>@runner_hash[:file],
         'background'=>'white',
         'image'=> TkPhotoImage.new('data' => TRASH_GIF),
         'relief'=>'flat').pack('side' =>'right','padx'=>0)
      pack('side' =>'top','anchor'=>'nw','fill'=>'x','padx'=>5, 'pady'=>5)
    end
      
  end

  def initialize(_parent)
    super(_parent)
    title("Runners manager")
    @items = Hash.new
    place('x'=>100,'y'=>100,'height'=> 220,'width'=> 300)
  end
  
  def clear_items
    @items.each_value{|i| i.destroy }
    @items.clear
  end
  
  def load_items
    clear_items
    runs=Arcadia.pers_group('runners', true)
    runs.each{|name, hash_string|
      item_hash = eval hash_string
      item_hash[:name]=name
      if item_hash[:runner] && Arcadia.runner(item_hash[:runner])
        item_hash = Hash.new.update(Arcadia.runner(item_hash[:runner])).update(item_hash)
      end
      @items[name]=RunnerMangerItem.new(self.frame, item_hash)
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
    
    @tkLabel3 = TkLabel.new(self){
      image  TkPhotoImage.new('format'=>'GIF','data' =>A_LOGO_GIF)
      background  _bgcolor
      place('x'=> 20,'y' => 20)
    }
    
    
#    @tkLabel1 = TkLabel.new(self){
#      text 'Arcadia'  
#      background  _bgcolor
#      foreground  '#ffffff'
#      font Arcadia.conf('splash.title.font')
#      justify  'left'
#      place('width' => '190','x' => 110,'y' => 10,'height' => 25)
#    }

    @tkLabel1 = TkLabel.new(self){
      image  TkPhotoImage.new('format'=>'GIF','data' =>ARCADIA_JAP_GIF)
      background  _bgcolor
      justify  'left'
      place('x' => 90,'y' => 10)
    }

    @tkLabelRuby = TkLabel.new(self){
      image TkPhotoImage.new('data' =>RUBY_DOCUMENT_GIF)
      background  _bgcolor
      place('x'=> 210,'y' => 12)
    }
    
    @tkLabel2 = TkLabel.new(self){
      text  'Arcadia Ide'
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.subtitle.font']
      justify  'left'
      place('x' => 100,'y' => 40,'height' => 19)
    }
    @tkLabelVersion = TkLabel.new(self){
      text  'version: '+$arcadia['applicationParams'].version
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.version.font']
      justify  'left'
      place('x' => 100,'y' => 65,'height' => 19)
    }
    @tkLabel21 = TkLabel.new(self){
      text  'by Antonio Galeone - 2004/2011'
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.credits.font']
      justify  'left'
      anchor 'w'
      place('width' => '220','x' => 100,'y' => 95,'height' => 25)
    }

    @tkLabelCredits = TkLabel.new(self){
      text  'Contributors: Roger D. Pack'
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.credits.font']
      justify  'left'
      anchor 'w'
      place('width' => '210','x' => 100,'y' => 115,'height' => 25)
    }

    @tkLabelStep = TkLabel.new(self){
      text  ''
      background  _bgcolor
      foreground  'yellow'
      font Arcadia.instance['conf']['splash.banner.font']
      justify  'left'
      anchor  'w'
      place('width'=>-5,'relwidth' => 1,'x' => 5,'y' => 160,'height' => 45)
    }
    @progress  = TkVariable.new
    reset
    _width = 380
    _height = 210
    #_width = 0;_height = 0
    _x = TkWinfo.screenwidth(self)/2 -  _width / 2
    _y = TkWinfo.screenheight(self)/2 -  _height / 2
    geometry = _width.to_s+'x'+_height.to_s+'+'+_x.to_s+'+'+_y.to_s
    Tk.tk_call('wm', 'geometry', self, geometry )
    #bind("ButtonPress-1", proc{self.destroy})
    bind("Double-Button-1", proc{self.destroy})
    info = TkApplication.sys_info
    set_sysinfo(info)
  end

  def set_sysinfo(_info)
    @tkLabelStep.text(_info)
  end

  def set_progress(_max=10)
    @max = _max
    Tk::BWidget::ProgressBar.new(self, :width=>150, :height=>10,
      :background=>'#000000',
      :troughcolor=>'#000000',
      :foreground=>'#a11934',
      :variable=>@progress,
      :borderwidth=>0,
      :relief=>'flat',
      :maximum=>_max).place('relwidth' => '1','y' => 146,'height' => 2)
  end

  def reset
    @progress.value = -1
  end

  def next_step(_txt = nil)
    @progress.numeric += 1
    labelStep(_txt) if _txt
  end

  def labelStep(_txt)
    @tkLabelStep.text = _txt
    Tk.update
  end

  def last_step(_txt = nil)
    @progress.numeric = @max
    labelStep(_txt) if _txt
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

class ArcadiaSh < TkToplevel
  attr_reader :wait, :result
  def initialize
    super
    title 'ArcadiaSh'
    iconphoto(TkPhotoImage.new('dat'=>ARCADIA_RING_GIF))
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
    @text.bind_append("KeyPress"){|e| input(e.keysym)}
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
        if RUBY_PLATFORM =~ /mingw|mswin/
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
  include Autils
  def initialize(_arcadia)
    @arcadia = _arcadia
    Arcadia.attach_listener(self, NeedRubyGemWizardEvent)
  end
  
  def on_need_ruby_gem_wizard(_event)
    # ... todo implamentation
    msg = "Appears that gem : '#{_event.gem_name}' required by : '#{_event.extension_name}' is not installed!\n Do you want to try install it now?" 
    ans = Tk.messageBox('icon' => 'error', 'type' => 'yesno',
      'title' => "(Arcadia) Extensions '#{_event.extension_name}'",
      'message' => msg)
      if  ans == 'yes'
        _event.add_result(self, 'installed'=>try_to_install_gem(_event.gem_name,_event.gem_repository))
      else
        _event.add_result(self, 'installed'=>false)
      end
  end
  
#  def try_to_install_gem(name, repository=nil, version = '>0')
#    ret = false
#    require 'rubygems/command.rb'
#    require 'rubygems/dependency_installer.rb'
#    
#    inst.install name, version
#    # TODO WIZARD
#    # TODO accept repository, too
#  end

  def try_to_install_gem(name, repository=nil, version = '>0')
    ret = false
    
    sh=ArcadiaSh.new
    cmd = "gem install --remote --include-dependencies #{name}"
    cmd="sudo #{cmd}" if !is_windows?
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
  def initialize(_arcadia)
    @arcadia = _arcadia
    Arcadia.attach_listener(self, DialogEvent)
  end

  def on_dialog(_event)
    type = _event.type
    if !DialogEvent::TYPE_PATTERNS.include?(_event.type)
      type = 'ok'
    end
    res_array = type.split('_')
    if _event.level.nil? || _event.level.length == 0
      icon = 'info'
    else
      icon = _event.level
    end
    tktype = type.gsub('_','').downcase
    
    tkdialog =  Tk::BWidget::MessageDlg.new(
            'icon' => icon,
            'bg' => Arcadia.conf('background'),
            'fg' => Arcadia.conf('foreground'),
            'type' => tktype,
            'title' => _event.title, 
            'message' => _event.msg)
            
    tkdialog.configure('font'=>'courier 6')        
    res = tkdialog.create
    _event.add_result(self, 'value'=>res_array[res.to_i])
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

  def initialize(_arcadia, _frame, _autotab=true)
    @arcadia = _arcadia
    @frames = Array.new
    @frames[0] = Array.new
    @frames[0][0] = _frame
   # @domains = Array.new
   # @domains[0] = Array.new
   # @domains[0][0] = '_domain_root_'
    @panels = Hash.new
    @panels['_domain_root_']= Hash.new
    @panels['_domain_root_']['root']= _frame
    @panels['_domain_root_']['sons'] = 	Hash.new
    @autotab = _autotab
    @headed = false
    @wrappers=Hash.new
    @splitters=Array.new
    #ArcadiaContractListener.new(self, MainContract, :do_main_event)
  end
	
	def root
		@panels['_domain_root_']['root']
	end
	
	def raise_panel(_domain, _extension)
    p = @panels[_domain]
    if p && p['notebook'] != nil
      p['notebook'].raise(_extension)
      p['notebook'].see(_extension)
    end
	end

#  def raise_panel(_domain_name, _name)
#    @panels[_domain_name]['notebook'].raise(_name) if @panels[_domain_name] && @panels[_domain_name]['notebook']
#  end

	def raised?(_domain, _name)
    ret = true
    p = @panels[_domain]
    if p && p['notebook'] != nil
      ret=p['notebook'].raise == _name
    end
    ret
	end
	
	def raised_fixed_frame(_domain)
	  ret = nil
	  p = @panels[_domain]
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
      _menu.insert('end',:command,
          :label=>"add column",
          :image=>TkPhotoImage.new('dat'=>ADD_GIF),
          :compound=>'left',
          :command=>proc{add_cols_runtime(_domain)},
          :hidemargin => true
      )
      _menu.insert('end',:command,
          :label=>"add row",
          :image=>TkPhotoImage.new('dat'=>ADD_GIF),
          :compound=>'left',
          :command=>proc{add_rows_runtime(_domain)},
          :hidemargin => true
      )
      if @panels.keys.length > 2
        _menu.insert('end',:command,
            :label=>"close",
            :image=>TkPhotoImage.new('dat'=>CLOSE_FRAME_GIF),
            :compound=>'left',
            :command=>proc{close_runtime(_domain)},
            :hidemargin => true
        )
      end

  end
  
  def build_titled_frame(domain)
    if @panels[domain]
      tframe = TkTitledFrameAdapter.new(@panels[domain]['root']).place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1)
      mb = tframe.add_fixed_menu_button('ext')
      # add commons item
      menu = mb.cget('menu')
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
    #tt1= @panels[_target_domain]['root'].top_text
    source_domain = @wrappers[_source_name].domain
    source_has_domain = !source_domain.nil?
    #tt2= @panels[source_domain]['root'].top_text if source_has_domain
    if @arcadia.conf('layout.exchange_panel_if_no_tabbed')=='true' && source_has_domain && @panels[source_domain]['sons'].length ==1 && @panels[_target_domain]['sons'].length > 0
      # change ------
      ffw1 = raised_fixed_frame(_target_domain)
      ffw2 = @panels[source_domain]['sons'].values[0]
      unregister_panel(ffw1,false,false) if ffw1
      unregister_panel(ffw2,false,false)
      ffw1.domain = source_domain if ffw1
      ffw2.domain = _target_domain
      register_panel(ffw1, ffw1.hinner_frame) if ffw1
      register_panel(ffw2, ffw2.hinner_frame)
      #@panels[_target_domain]['root'].top_text(tt2)
      #@panels[source_domain]['root'].top_text(tt1)
      @panels[_target_domain]['root'].save_caption(ffw2.name, @panels[source_domain]['root'].last_caption(ffw2.name))
      @panels[source_domain]['root'].save_caption(ffw1.name, @panels[_target_domain]['root'].last_caption(ffw1.name))
      @panels[_target_domain]['root'].restore_caption(ffw2.name)
      @panels[source_domain]['root'].restore_caption(ffw1.name)
      @panels[_target_domain]['root'].change_adapter(ffw2.name, @panels[source_domain]['root'].forge_transient_adapter(ffw2.name))
      @panels[source_domain]['root'].change_adapter(ffw1.name, @panels[_target_domain]['root'].forge_transient_adapter(ffw1.name))
    elsif source_has_domain && @panels[source_domain]['sons'].length >= 1
      ffw2 = @panels[source_domain]['sons'][_source_name]
      unregister_panel(ffw2, false, false)
      ffw2.domain = _target_domain
      register_panel(ffw2, ffw2.hinner_frame)
      #@panels[_target_domain]['root'].top_text(tt2)
      #@panels[source_domain]['root'].top_text('')
      @panels[_target_domain]['root'].save_caption(ffw2.name, @panels[source_domain]['root'].last_caption(ffw2.name))
      @panels[_target_domain]['root'].restore_caption(ffw2.name)
      @panels[_target_domain]['root'].change_adapter(ffw2.name, @panels[source_domain]['root'].forge_transient_adapter(ffw2.name))
    elsif !source_has_domain
      ffw2 = @wrappers[_source_name]
      ffw2.domain = _target_domain
      register_panel(ffw2, ffw2.hinner_frame)
      #@panels[_target_domain]['root'].top_text('')
    end
    # refresh -----
    build_invert_menu
  end


#  def change_domain_old(_dom1, _dom2, _name2)
#    tt1= @panels[_dom1]['root'].top_text
#    tt2= @panels[_dom2]['root'].top_text
#    if  @panels[_dom2]['sons'].length ==1 && @panels[_dom1]['sons'].length > 0
#      # change ------
#      ffw1 = raised_fixed_frame(_dom1)
#      ffw2 = @panels[_dom2]['sons'].values[0]
#      unregister_panel(ffw1,false,false) if ffw1
#      unregister_panel(ffw2,false,false)
#      ffw1.domain = _dom2 if ffw1
#      ffw2.domain = _dom1
#      register_panel(ffw1, ffw1.hinner_frame) if ffw1
#      register_panel(ffw2, ffw2.hinner_frame)
#      @panels[_dom1]['root'].top_text(tt2)
#      @panels[_dom2]['root'].top_text(tt1)
#    elsif @panels[_dom2]['sons'].length > 1
#      ffw2 = @panels[_dom2]['sons'][_name2]
#      unregister_panel(ffw2, false, false)
#      ffw2.domain = _dom1
#      register_panel(ffw2, ffw2.hinner_frame)
#      @panels[_dom1]['root'].top_text(tt2)
#      @panels[_dom2]['root'].top_text('')
#    end
#    # refresh -----
#    build_invert_menu
#  end

  def process_frame(_ffw)
  #def process_frame(_domain_name, _frame_name)
    #domain_root = @panels[_domain_name]['sons'][_frame_name]
    @panels.keys.each{|dom|
      if  dom != '_domain_root_' && dom != _ffw.domain && @panels[dom] && @panels[dom]['root']
        titledFrame = @panels[dom]['root']
        if titledFrame.instance_of?(TkTitledFrameAdapter)
          menu = @panels[dom]['root'].menu_button('ext').cget('menu')
          menu.insert('0',:command,
                :label=>_ffw.title,
                :image=>TkPhotoImage.new('dat'=>ARROW_LEFT_GIF),
                :compound=>'left',
                :command=>proc{change_domain(dom, _ffw.name)},
                :hidemargin => true
          )
        end
      end
    }
    if @panels[_ffw.domain]
      titledFrame = @panels[_ffw.domain]['root']
      if titledFrame.instance_of?(TkTitledFrameAdapter)
        mymenu = titledFrame.menu_button('ext').cget('menu')
        index = mymenu.index('end').to_i
        if @panels.keys.length > 2
          i=index-3
        else
          i=index-2
        end
        if i >= 0
          index = i.to_s
        end
        mymenu.insert(index,:command,
           :label=>"close \"#{_ffw.title}\"",
           :image=>TkPhotoImage.new('dat'=>CLOSE_FRAME_GIF),
           :compound=>'left',
           :command=>proc{unregister_panel(_ffw, false, true)},
           :hidemargin => true
        )
      end
    end
    
  end

  
  def build_invert_menu(refresh_commons_items=false)
    @panels.keys.each{|dom|
      if dom != '_domain_root_' && @panels[dom] && @panels[dom]['root']
        titledFrame = @panels[dom]['root']
        if titledFrame.instance_of?(TkTitledFrameAdapter)
          menu = titledFrame.menu_button('ext').cget('menu')
          if refresh_commons_items
            @panels[dom]['root'].menu_button('ext').cget('menu').delete('0','end')
            add_commons_menu_items(dom, menu)
          else
            index = menu.index('end').to_i
            if @panels.keys.length > 2
              i=index-4
            else
              i=index-3
            end
            if i >= 0
              end_index = i.to_s
              @panels[dom]['root'].menu_button('ext').cget('menu').delete('0',end_index)
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
    _domain_name = _ffw.domain
    _name = _ffw.name
    _title = _ffw.title
    pan = @panels[_domain_name]
    @wrappers[_name]=_ffw
    if pan!=nil
      num = pan['sons'].length
      if @headed
        root_frame = pan['root'].frame
        pan['root'].title(_title)
        pan['root'].restore_caption(_name)
   	    pan['root'].change_adapter_name(_name)
        if !root_frame.instance_of?(TkFrameAdapter) && num==0
          if _adapter
            adapter = _adapter
          else
            adapter = TkFrameAdapter.new(self.root, Arcadia.style('frame'))
          end
          adapter.attach_frame(root_frame)
          adapter.raise
        end
      else
        root_frame = pan['root']
      end
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
  					    pan['root'].title(api.title)
  					    pan['root'].restore_caption(api.name) 
  					    pan['root'].change_adapter_name(api.name)
         	         Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>pan['sons'][api.name].extension_name, 'frame_name'=>pan['sons'][api.name].name))
#               changed
#               notify_observers('RAISE', api.name)
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
            pan['root'].title(_title)            
            pan['root'].restore_caption(_name) 
            pan['root'].change_adapter_name(_name)
      	     Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>_ffw.extension_name, 'frame_name'=>_ffw.name))
#            changed
#            notify_observers('RAISE', _name)
          }
        		)
        if _adapter
          adapter = _adapter
        else
          adapter = TkFrameAdapter.new(self.root, Arcadia.style('frame'))
        end
        adapter.attach_frame(_panel)
        adapter.raise
        _panel=adapter
        #@wrappers[_name]=wrapper
        #p['sons'][_name] = ArcadiaPanelInfo.new(_name,_title,_panel,_ffw)
        pan['sons'][_name] = _ffw
        pan['notebook'].raise(_name)
        process_frame(_ffw)
        return _panel
      end
    else
      _ffw.domain = nil
      process_frame(_ffw)
      return TkFrameAdapter.new(self.root, Arcadia.style('frame'))
#
#      Arcadia.dialog(self, 
#        'type'=>'ok',
#        'msg'=>"domain #{_domain_name} do not exist\nfor '#{_title}'!",
#        'level'=>'warning' 
#      )
#      float_frame = new_float_frame
#      float_frame.title(_title)
#      return float_frame.frame
    end
  end


  def unregister_panel(_ffw, delete_wrapper=true, refresh_menu=true)
    #p "unregister #{_name} ------> 1"
    _domain_name = _ffw.domain
    _name = _ffw.name
    @panels[_domain_name]['sons'][_name].hinner_frame.detach_frame
    if delete_wrapper
      @wrappers.delete(_name).hinner_frame.destroy 
    else
      @wrappers[_name].domain=nil
    end
    @panels[_domain_name]['sons'].delete(_name)
    #p "unregister #{_name} ------> 2"
    if @panels[_domain_name]['sons'].length == 1
      w = @panels[_domain_name]['sons'].values[0].hinner_frame
      t = @panels[_domain_name]['sons'].values[0].title
      n = @panels[_domain_name]['sons'].values[0].name
      w.detach_frame
      w.attach_frame(@panels[_domain_name]['root'].frame)
      @panels[_domain_name]['root'].title(t)
      @panels[_domain_name]['root'].restore_caption(n)
      @panels[_domain_name]['root'].change_adapter_name(n)

      @panels[_domain_name]['notebook'].destroy
      @panels[_domain_name]['notebook']=nil
    elsif @panels[_domain_name]['sons'].length > 1
      @panels[_domain_name]['notebook'].delete(_name) if @panels[_domain_name]['notebook'].index(_name) > 0
      #p "unregister #{_name} ------> 3"
      new_raise_key = @panels[_domain_name]['sons'].keys[@panels[_domain_name]['sons'].length-1]
      #p "unregister #{_name} ------> 4"
      @panels[_domain_name]['notebook'].raise(new_raise_key)
      #p "unregister #{_name} ------> 5"
    elsif @panels[_domain_name]['sons'].length == 0
      @panels[_domain_name]['root'].title('')
      @panels[_domain_name]['root'].top_text('')
    end
    build_invert_menu if refresh_menu
  end

  def view_panel
  end

  def hide_panel
  end

  def [](_row, _col)
    @frames[_row][_col]
  end
  
  def frame(_domain_name, _name)
    @panels[_domain_name]['sons'][_name].frame
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
  
  def new_float_frame(_args=nil)
    if _args.nil?
     _args = {'x'=>10, 'y'=>10, 'width'=>100, 'height'=>100}
    end
    _frame =  TkFloatTitledFrame.new(root)
    _frame.on_close=proc{_frame.hide}
    _frame.place(_args)
    return _frame
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
        p "== #{d} --> #{domain_name(_r,dc.to_i+1)}"
        _dom[k]= domain_name(_r,dc.to_i+1)
      end
    }
  end

  def shift_domain_row(_r,_c,_dom)
    Hash.new.update(_dom).each{|k,d|
      dr,dc=d.split('.')
      if dr.to_i >= _r && dc.to_i == _c 
         #shift_domain_row(dr.to_i+1,_c,_dom)
        p "shift_domain_row == #{d} --> #{domain_name(dr.to_i+1,_c)}"
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

class FocusEventManager
  def initialize
    Arcadia.attach_listener(self, FocusEvent)
  end
  
  def on_focus(_event)
    _event.focus_widget=Tk.focus
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
    _focused_widget.text_cut if _focused_widget.respond_to?(:text_cut)
  end
  
  def do_copy(_focused_widget)
    _focused_widget.text_copy if _focused_widget.respond_to?(:text_copy)
  end

  def do_paste(_focused_widget)
    _focused_widget.text_paste if _focused_widget.respond_to?(:text_paste)
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
    _focused_widget.tag_add('sel','1.0','end') if _focused_widget.respond_to?(:tag_add)
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
end