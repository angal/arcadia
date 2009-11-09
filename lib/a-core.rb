#
#   a-core.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=..
#   &require_omissis=conf/arcadia.init
#   &require_omissis=tk
#   &require_omissis=tk/label
#   &require_omissis=tk/toplevel

require "conf/arcadia.res"
require 'tkextlib/bwidget'
require "lib/a-tkcommons"
require "lib/a-contracts"
require "observer"

class Arcadia < TkApplication
  include Observable
  attr_reader :layout
  def initialize
    super(
      ApplicationParams.new(
        'arcadia',
        '0.8.0',
        'conf/arcadia.conf',
        'conf/arcadia.pers'
      )
    )
    load_config
    set_sysdefaultproperty
    ArcadiaDialogManager.new(self)
    ArcadiaActionDispatcher.new(self)
    ArcadiaGemsWizard.new(self)
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
    start_width = (TkWinfo.screenwidth(@root)-4)
    start_height = (TkWinfo.screenheight(@root)-20)
    if RUBY_PLATFORM =~ /mswin|mingw/ # on doze don't go below the start gar
      start_height -= 50
      start_width -= 20
    end
    geometry = start_width.to_s+'x'+start_height.to_s+'+0+0'
    @root.deiconify
    @root.raise
    @root.focus(true)
    @root.geometry(geometry)
    Tk.update_idletasks
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
	
  def load_exts_conf
  		@exts = Array.new
  		@exts_i = Array.new
  		dirs = Array.new
  		files = Dir['ext/*'].concat(Dir[ENV["HOME"]+'/.arcadia/ext/*']).sort
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
    		 self['conf'].update(conf_hash2)	
    		 self['origin_conf'].update(conf_hash2)	
  		}
  end

  def gem_available?(_gem)
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
          if !gem_available?(gem)
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
              _event = Arcadia.process_event(NeedRubyGemWizardEvent.new(self, args))
              if _event && _event.results
                ret = ret && _event.results[0].installed
              end
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
      if extension && ext_active?(extension)
        @splash.next_step('... creating '+extension)  if @splash
        # before creating extension check gems dependences
        gems_installed = check_gems_dependences(extension)
        if !gems_installed || !ext_create(extension)
          @exts.delete(extension)
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
  
  def load_maximised
    lm = self['conf']['layout.maximized']
    if lm    
      ext,index=lm.split(',')
      maxed = false
      if ext && index
        ext = ext.strip
        i=index.strip.to_i
        @exts_i.each{|e|
          if e.conf('name')==ext && !maxed
            p "maximizzo #{ext}"
            e.maximize(i)
            maxed=true
            break
          end
        }    
      end
    end
  end

  def ext_create(_extension)
    ret = true
    begin
      source = self['conf'][_extension+'.require']
      class_name = self['conf'][_extension+'.class']
      if source.strip.length > 0
	      require source 
      end
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
    self.resolve_properties_link(self['origin_conf'],self['origin_conf'])
  end

  def set_sysdefaultproperty
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
    publish('main.action.edit_cut',proc{$arcadia['editor'].raised.text.text_cut()})
    publish('main.action.edit_copy',proc{$arcadia['editor'].raised.text.text_copy()})
    publish('main.action.edit_paste',proc{$arcadia['editor'].raised.text.text_paste()})
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
    load_user_control(@main_menu)
    load_user_control(@main_toolbar)
    #Extension control
    @exts.each{|ext|
      @splash.next_step("... load #{ext} user controls ")  if @splash
      load_user_control(@main_menu, ext)
      load_user_control(@main_toolbar, ext)
    }
    load_user_control(@main_menu,"","e")
    load_user_control(@main_toolbar,"","e")
    #@layout.build_invert_menu
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
          property = proc{|_str, _suf| self['conf']["#{_suf}.#{_str}"]} 
          property_to_eval = proc{|_str, _suf| 
            p = self['conf']["#{_suf}.#{_str}"]
            _self_on_eval.instance_eval(p) if p 
          } 
          items = self['conf'][suf1].split(',')
          items.each{|item|
            suf2 = suf1+'.'+item
            disabled = !self['conf']["#{suf2}.disabled"].nil?
#            property = proc{|_str| self['conf']["#{suf2}.#{_str}"]} 
#            property_to_eval = proc{|_str| 
#              p = self['conf']["#{suf2}.#{_str}"]
#              _self_on_eval.instance_eval(p) if p 
#            } 
            name = property.call('name',suf2)
            caption = property.call('caption',suf2)
            hint = property.call('hint',suf2)
            event_class = property_to_eval.call('event_class',suf2)
            
            event_args = property_to_eval.call('event_args',suf2)
            image_data = property_to_eval.call('image_data',suf2)
            item_args = {
              'name'=>name,
              'caption'=>caption,
              'hint'=>hint,
              'event_class' =>event_class,
              'event_args' =>event_args,
              'image_data' =>image_data,
              'context'=>group,
              'context_path'=>context_path
            }
            item_args['context_caption'] = groups_caption[gi] if groups_caption
            i = _user_control.new_item(self, item_args)
            i.enable=false if disabled

          }
        rescue Exception
          msg = "Loading #{groups} ->#{items} (#{$!.class.to_s} : #{$!.to_s} at : #{$@.to_s})"
          if Arcadia.dialog(self, 'type'=>'ok_cancel', 'title' => '(Arcadia) Toolbar', 'msg'=>msg)=='cancel'
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
    end
  end

  def can_exit?
    _event = Arcadia.process_event(ExitQueryEvent.new(self, 'can_exit'=>true))
    _event.can_exit
  end

  def save_layout
    Arcadia.del_conf_group('layout')
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
  end
  
  def do_finalize
    self.save_layout
    _event = Arcadia.process_event(FinalizeEvent.new(self))
    update_local_config
    self.override_persistent(self['applicationParams'].persistent_file, self['pers'])
  end

  def Arcadia.console(_sender, _args=Hash.new)
    process_event(MsgEvent.new(_sender, _args))
  end
  
  def Arcadia.dialog(_sender, _args=Hash.new)
    _event = process_event(DialogEvent.new(_sender, _args))  
    return _event.results[0].value if _event
  end

  def Arcadia.style(_class)
    Configurable.properties_group(_class, Arcadia.instance['conf'])
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

  def Arcadia.layout
    if @@instance
        return @@instance.layout
	  end
  end
  
  def Arcadia.open_file_dialog
     Tk.getOpenFile 'initialdir' => MonitorLastUsedDir.get_last_dir
  end

  
  def Arcadia.file_icon(_file_name)
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
    attr_accessor :context
    attr_accessor :context_caption
    attr_accessor :caption
    attr_accessor :hint
    attr_accessor :event_class
    attr_accessor :event_args
    attr_accessor :image_data
    def initialize(_sender, _args)
      @sender = _sender
      if _args 
        _args.each do |key, value|
          self.send(key+'=', value)
        end
      end
      #@item_obj = ?
    end

    def method_missing(m, *args)  
      if @item_obj && m.respond_to?(m)
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
    def initialize(_sender, _args)
      super(_sender, _args)
      _image = TkPhotoImage.new('data' => @image_data) if @image_data
      _command = proc{Arcadia.process_event(@event_class.new(_sender, @event_args))} if @event_class
      _hint = @hint
      _font = @font
      _caption = @caption
      @item_obj = Tk::BWidget::Button.new(_args['frame'], Arcadia.style('toolbarbutton')){
        image  _image if _image
        #borderwidth 1
        #font _font if _font
        #activebackground Arcadia.conf('button.activebackground')
        #activeforeground Arcadia.conf('button.activeforeground')
        #background Arcadia.conf('button.background')
        #foreground Arcadia.conf('button.foreground')
        #highlightbackground Arcadia.conf('button.highlightbackground')
        #relief Arcadia.conf('button.relief')
        command _command if _command
        #relief 'groove'
        width 20
        height 20
        helptext  _hint if _hint
        text _caption if _caption
        pack('side' =>'left', :padx=>2, :pady=>0)
      }
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
  end

  def new_item(_sender, _args= nil)
     _context = _args['context']
#    if _context
#      if @context_frames[_context]
#      else
#        @context_frames[_context] = TkLabelFrame.new(@frame){
#          text  ""
#          relief 'groove'
#          pack('side' =>'left', :padx=>0, :pady=>0)
#        } 
#      end
#      _args['frame']=@context_frames[_context]
#    else
#      _args['frame']=@frame
#    end
    if @last_context && _context != @last_context 
      new_separator
    end
    @last_context = _context
    _args['frame']=@frame
    super(_sender, _args)
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
    def initialize(_sender, _args)
      super(_sender, _args)
      _image = TkPhotoImage.new('data' => @image_data) if @image_data
      _command = proc{
        Arcadia.process_event(@event_class.new(_sender, @event_args))
      } if @event_class
      #_menu = @menu[@parent]
      @item_obj = @menu.insert('end', :command, 
        'image'=>_image,
        'label'=>@caption, 
        'compound'=>'left',
        'command'=>_command )
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
#    menu.foreground('black')
#    menu.activeforeground('#6679f1')
#    menu.relief('flat')
#    menu.borderwidth(0)
#    menu.font(Arcadia.conf('main.mainmenu.font'))
  end

  def get_menu_context(_menubar, _context)
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
      _menubar.add_menu([[_context],[]])[1].delete(0)
    end
  end
  
  def get_sub_menu(menu_context, folder=nil)
    if folder
      s_i = -1 
      i_end = menu_context.index('end')
      if i_end
        0.upto(i_end){|j|
          l = menu_context.entrycget(j,'label')
          if l == folder
           s_i = j
           break
          end
        }
      end
    end
    if s_i > -1 && menu_context.menutype(s_i) == 'cascade'
      sub = menu_context.entrycget(s_i, 'menu')
    else
      sub = TkMenu.new(
        :parent=>@pop_up,
        :tearoff=>0
      )
      sub.configure(Arcadia.style('menu'))
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
  
  def get_menu(_menubar, _context, context_path)
    context_menu = get_menu_context(_menubar, _context)
    folders = context_path.split('/')
    sub = context_menu
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
    _args['menu']=get_menu(@menu, conte, _args['context_path'])
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
      ['Cut', $arcadia['main.action.edit_cut'], 2],
      ['Copy', $arcadia['main.action.edit_copy'], 0],
      ['Paste', $arcadia['main.action.edit_paste'], 0],
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
      ['Load from edited prefs', proc{$arcadia.load_config}, 0]
    ]
    menu_spec_help = [['Help', 0],
    ['About', $arcadia['action.show_about'], 2],]
    @menu.add_menu(menu_spec_file)
    @menu.add_menu(menu_spec_edit)
    @menu.add_menu(menu_spec_search)
    @menu.add_menu(menu_spec_view)
    @menu.add_menu(menu_spec_tools)
    @menu.add_menu(menu_spec_help)
  
    #@menu.bind_append("1", proc{
#      chs = TkWinfo.children(@menu)
#      hh = 25
#      @last_post = nil
#      chs.each{|ch|
#        ch.bind_append("Enter", proc{|x,y,rx,ry| 
#          @last_post.unpost if @last_post
#          ch.menu.post(x-rx,y-ry+hh)
#          @last_post=ch.menu}, "%X %Y %x %y")
#        ch.bind_append("Leave", proc{
#          @last_post.unpost if @last_post
#        })
#      }
    #})
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
    @tkLabel1 = TkLabel.new(self){
      text  'Arcadia'
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.conf('splash.title.font')
      justify  'left'
      place('width' => '190','x' => 110,'y' => 10,'height' => 25)
    }
    @tkLabelRuby = TkLabel.new(self){
      image TkPhotoImage.new('data' =>RUBY_DOCUMENT_GIF)
      background  _bgcolor
      place('x'=> 150,'y' => 40)
    }
    @tkLabel2 = TkLabel.new(self){
      text  'Ruby ide'
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.subtitle.font']
      justify  'left'
      place('width' => '90','x' => 170,'y' => 40,'height' => 19)
    }
    @tkLabelVersion = TkLabel.new(self){
      text  'version: '+$arcadia['applicationParams'].version
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.version.font']
      justify  'left'
      place('width' => '120','x' => 150,'y' => 65,'height' => 19)
    }
    @tkLabel21 = TkLabel.new(self){
      text  'by Antonio Galeone - 2004/2009'
      background  _bgcolor
      foreground  '#ffffff'
      font Arcadia.instance['conf']['splash.credits.font']
      justify  'left'
      place('width' => '210','x' => 100,'y' => 95,'height' => 25)
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
    _height = 240
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
    :background=>'black',
    :troughcolor=>'black',
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
    @text = TkScrollText.new(self, Arcadia.style('text')){
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
    @text.show
    @text.show_v_scroll
    @text.show_h_scroll
    @input_buffer = ''
    @wait = true
    @result = false
    prompt
    @text.bind_append("KeyPress"){|e| input(e.keysym)}
    @text.bind_append("Control-Shift-KeyPress"){|e| input(e.keysym)}
    @text.bind_append("Shift-KeyPress"){|e| input(e.keysym)}
    
    geometry = '800x200+10+10'
    geometry(geometry)
    
  end
  
  def exec_buffer
    out("\n")
    exec(@input_buffer)
    @input_buffer=''
  end
  
  def input(_char)
    case _char
      when 'Return'
        Thread.new{exec_buffer}
        Tk.callback_break
      when 'Shift_L','Up','Down','Left','Right','Super_L'
      when 'bar'
        @input_buffer+='|'
      when 'backslash'
        @input_buffer+='\\'
      when 'slash'
        @input_buffer+='\/'
      when 'minus'
        @input_buffer+='-'
      when 'ISO_Level3_Shift'
        @input_buffer+='\~'
      when 'Delete'
      when 'BackSpace'
        @input_buffer = @input_buffer[0..-2]
      when 'space'
        @input_buffer+=' '
      else
        @input_buffer+=_char
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
  end

  def exec_prompt(_cmd)
    out("#{_cmd}\n")
    exec(_cmd)
  end
  
  def prepare_exec(_cmd)
    @input_buffer=_cmd
    out("#{_cmd}")
  end
  
  def exec(_cmd)
    return if _cmd.nil? || _cmd.length ==0
    @b_exec.destroy if defined?(@b_exec)   
    @b_exit.destroy if defined?(@b_exit)   
    require "open3"
    case _cmd
      when 'clear'
        @text.delete('0.0','end')
    else
      begin
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
      rescue Exception => e
         out("#{e.message}\n",'error') 
         @result = false
      end
    end
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
    enanch
    Arcadia.attach_listener(self, _event)
  end
  def enanch
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
    cmd = "gem install #{name}"
    cmd="sudo #{cmd}" if !is_windows?
    cmd+=" --source=#{repository}" if repository
    sh.prepare_exec(cmd)    
    while sh.wait
      Tk.update
      #sleep(1)
    end
    ret=sh.result
    sh.destroy
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
    icon = _event.level
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
           if cfrs && cfrs.length == 1 && cfrs[0].instance_of?(TkTitledFrame) && TkWinfo.parent(@panels[dom]['notebook'])== cfrs[0].frame
             ret_doms << dom
             frame_found = true
           end       
         elsif @panels[dom]['root'].instance_of?(TkTitledFrame) && @panels[dom]['root'].parent == _frame 
             ret_doms << dom
             frame_found = true
         end
      end
    }    
    
    if !frame_found
      cfrs = TkWinfo.children(_frame)
      if cfrs && cfrs.length == 1 && cfrs[0].instance_of?(TkTitledFrame)
        @wrappers.each{|name, ffw|
          if ffw.hinner_frame.frame == cfrs[0].frame
            ret_doms << ffw.domain 
          end
        }
      end
    end
    ret_doms
  end

  def close_runtime_old(_domain)
    splitted_adapter = find_splitted_frame(@panels[_domain]['root'])
    splitted_adapter_frame = splitted_adapter.frame
    vertical = splitted_adapter.instance_of?(AGTkVSplittedFrames)
    
    _row, _col = _domain.split('.')
    
    if @frames[_row.to_i][_col.to_i] == splitted_adapter.frame1
      close_first = true
    elsif @frames[_row.to_i][_col.to_i] == splitted_adapter.frame2
      close_first = false
    end
    
    return if close_first.nil?    
    
    #source_domains = domains_on_frame(splitted_adapter.frame1).concat(domains_on_frame(splitted_adapter.frame2))
    #Arcadia.console(self,'msg'=>"domini coinvolti = #{source_domains.to_s}")
    
    @panels[_domain]['sons'].each{|name,ffw|
      unregister_panel(ffw, false, false)
    }
    unbuild_titled_frame(_domain)
    if close_first
      #left_frame
      other_ds = domains_on_frame(@panels[_domain]['splitted_frames'].frame2)
      if other_ds.length == 1
        source_domain = other_ds[0]
      elsif other_ds.length > 1
        max = other_ds.length-1
        j = 0
        while j <= max
          if source_domain.nil?
            source_domain = other_ds[j]
          else
            r,c = source_domain.split('.')
            new_r,new_c = other_ds[j].split('.')
            if new_r.to_i < r.to_i || new_r.to_i == r.to_i && new_c.to_i < c.to_i
              source_domain = other_ds[j]
            end
          end
          j = j+1
        end
      else
        if vertical
          source_domain = domain_name(_row.to_i, _col.to_i+1)
        else
          source_domain = domain_name(_row.to_i+1, _col.to_i)
        end
      end
      if vertical
        ref_source_domain = domain_name(_row.to_i, _col.to_i+1)
      else
        ref_source_domain = domain_name(_row.to_i+1, _col.to_i)
      end

      destination_domain = _domain
            
      if @panels[source_domain]['splitted_frames'] != @panels[destination_domain]['splitted_frames']
        if @panels[source_domain]['root_splitted_frames'] && @panels[source_domain]['root_splitted_frames'] != @panels[destination_domain]['splitted_frames']
          other_root_splitted_adapter = @panels[source_domain]['root_splitted_frames']
        elsif @panels[source_domain]['splitted_frames']
          other_root_splitted_adapter = @panels[source_domain]['splitted_frames']
        end
      end

      if other_root_splitted_adapter
        p "primo quadrante"
        other_root_splitted_adapter.detach_frame
        splitted_adapter.detach_frame
        splitted_adapter.destroy
        other_root_splitted_adapter.attach_frame(splitted_adapter_frame)
        if source_domain == ref_source_domain
          if vertical
            rows = domains_on_splitter_rows(other_root_splitted_adapter)
            rows.each{|r|
              shift_left(r.to_i,_col.to_i)
            }
          else
            cols = domains_on_splitter_cols(other_root_splitted_adapter)
            cols.each{|c|
              shift_top(_row.to_i,c.to_i)
            }
          end
        else
          @panels.delete(_domain)
          @frames[_row.to_i][_col.to_i] = nil
         # @domains[_row.to_i][_col.to_i] = nil
#          ref_r,ref_c = ref_source_domain.split('.')
#          real_r,real_c=source_domain.split('.')
#          gap_r = ref_r.to_i - real_r.to_i
#          gap_c = ref_c.to_i - real_c.to_i
#          if gap_r != 0 && gap_c == 0 # vertical
#            doms = domains_on_splitter(other_root_splitted_adapter)
#            doms.each{|d|
#              r,c=d.split('.')
#              cur_r = r.to_i+gap_r
#              cur_domain = "#{cur_r}.#{_col}"
#              if @panels[cur_domain] != nil
#                shift_bottom(cur_r,_col.to_i)
#              end
#              @panels[cur_domain] = @panels[d]
#              @panels[cur_domain]['root'].set_domain(cur_domain)
#              @panels[cur_domain]['sons'].each{|name,ffw| ffw.domain=cur_domain}
#              @frames[cur_r.to_i][_col.to_i] = @frames[r.to_i][c.to_i]
#              @domains[cur_r.to_i][_col.to_i] = @domains[r.to_i][c.to_i]
#              
#              @panels.delete(d)
#              @frames[r.to_i][c.to_i] = nil
#              @domains[r.to_i][c.to_i] = nil
#            }
#          elsif gap_c != 0
#          end
        end
        @panels.delete(source_domain)
        if vertical
          @frames[_row.to_i][_col.to_i+1] = nil
         # @domains[_row.to_i][_col.to_i+1] = nil
        else
          @frames[_row.to_i+1][_col.to_i] = nil
         # @domains[_row.to_i+1][_col.to_i] = nil
        end
      else
        p "secondo quadrante"
        source_save = Hash.new
        source_save.update(@panels[source_domain]['sons']) if @panels[source_domain]
        source_save.each{|name,ffw|
          unregister_panel(ffw, false, false)
        }
        splitted_adapter.detach_frame
        splitted_adapter.destroy
        @panels[destination_domain]['root']=splitted_adapter_frame
        @frames[_row.to_i][_col.to_i] = splitted_adapter_frame
       # @domains[_row.to_i][_col.to_i] = destination_domain
        build_titled_frame(destination_domain)
        @panels.delete(source_domain)
        if vertical
          @frames[_row.to_i][_col.to_i+1] = nil
         # @domains[_row.to_i][_col.to_i+1] = nil
        else
          @frames[_row.to_i+1][_col.to_i] = nil
         # @domains[_row.to_i+1][_col.to_i] = nil
        end
        source_save.each{|name,ffw|
          ffw.domain = destination_domain
          register_panel(ffw, ffw.hinner_frame)
        }
        #-----
        parent_splitted_adapter = find_splitted_frame(@panels[destination_domain]['root'])
        if  parent_splitted_adapter
          @panels[destination_domain]['splitted_frames']=parent_splitted_adapter
        else
          @panels[destination_domain]['splitted_frames']= nil
        end
        #-----
        source_row,source_col = source_domain.split('.')
#        shift_left(source_row.to_i,source_col.to_i)
        if vertical
          shift_left(source_row.to_i,source_col.to_i-1)
        else
          shift_top(source_row.to_i-1,source_col.to_i)
        end
      end
    else  # CLOSE OTHER
      other_ds = domains_on_frame(@panels[_domain]['splitted_frames'].frame1)
      if other_ds.length == 1
        other_dom = other_ds[0]
      else
        if vertical
          other_dom = domain_name(_row.to_i, _col.to_i-1)
        else
          other_dom = domain_name(_row.to_i-1, _col.to_i)
        end
      end
      if @panels[_domain]['splitted_frames'] != @panels[other_dom]['splitted_frames']
        if @panels[other_dom]['root_splitted_frames'] && @panels[other_dom]['root_splitted_frames'] != @panels[_domain]['splitted_frames']
          other_root_splitted_adapter = @panels[other_dom]['root_splitted_frames']
        elsif @panels[other_dom]['splitted_frames']
          other_root_splitted_adapter = @panels[other_dom]['splitted_frames']
        end
      end

      if other_root_splitted_adapter
        p "terzo quadrante"
        other_root_splitted_adapter.detach_frame
        splitted_adapter.detach_frame
        splitted_adapter.destroy
        other_root_splitted_adapter.attach_frame(splitted_adapter_frame)

        @frames[_row.to_i][_col.to_i] = nil
       # @domains[_row.to_i][_col.to_i] = nil
        @panels.delete(_domain)
      else
        p "quarto quadrante"
        source_save = Hash.new
        source_save.update(@panels[other_dom]['sons'])
        source_save.each{|name,ffw|
          unregister_panel(ffw, false, false)
        }
        splitted_adapter.detach_frame
        splitted_adapter.destroy
        @panels[other_dom]['root']=splitted_adapter_frame 

        @frames[_row.to_i][_col.to_i] = nil
       # @domains[_row.to_i][_col.to_i] = nil
        build_titled_frame(other_dom)
        @panels.delete(_domain)
  
        source_save.each{|name,ffw|
          ffw.domain = other_dom
          register_panel(ffw, ffw.hinner_frame)
        }
        #-----
        parent_splitted_adapter = find_splitted_frame(@panels[other_dom]['root'])
        if  parent_splitted_adapter
          @panels[other_dom]['splitted_frames']=parent_splitted_adapter
        else
          @panels[other_dom]['splitted_frames']= nil
        end
        other_row,other_col = other_dom.split('.')
        @frames[other_row.to_i][other_col.to_i] = splitted_adapter_frame
       # @domains[other_row.to_i][other_col.to_i] = other_dom
#        if vertical
#          @frames[_row.to_i][_col.to_i-1] = splitted_adapter_frame
#         # @domains[_row.to_i][_col.to_i-1] = other_dom
#        else
#          @frames[_row.to_i-1][_col.to_i] = splitted_adapter_frame
#         # @domains[_row.to_i-1][_col.to_i] = other_dom
#        end
      end

      if vertical
        shift_left(_row.to_i,_col.to_i)
      else
        shift_top(_row.to_i,_col.to_i)
      end
    end 
    build_invert_menu(true)
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
      tframe = TkTitledFrame.new(@panels[domain]['root']).place('x'=>0, 'y'=>0,'relheight'=>1, 'relwidth'=>1)
      mb = tframe.add_menu_button('ext')
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
    tt1= @panels[_target_domain]['root'].top_text
    source_domain = @wrappers[_source_name].domain
    source_has_domain = !source_domain.nil?
    tt2= @panels[source_domain]['root'].top_text if source_has_domain
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
      @panels[_target_domain]['root'].top_text(tt2)
      @panels[source_domain]['root'].top_text(tt1)
    elsif source_has_domain && @panels[source_domain]['sons'].length >= 1
      ffw2 = @panels[source_domain]['sons'][_source_name]
      unregister_panel(ffw2, false, false)
      ffw2.domain = _target_domain
      register_panel(ffw2, ffw2.hinner_frame)
      @panels[_target_domain]['root'].top_text(tt2)
      @panels[source_domain]['root'].top_text('')
    elsif !source_has_domain
      ffw2 = @wrappers[_source_name]
      ffw2.domain = _target_domain
      register_panel(ffw2, ffw2.hinner_frame)
      @panels[_target_domain]['root'].top_text('')
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
        if titledFrame.instance_of?(TkTitledFrame)
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
      if titledFrame.instance_of?(TkTitledFrame)
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
        if titledFrame.instance_of?(TkTitledFrame)
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

  def register_panel(_ffw, _adapter=nil)
    _domain_name = _ffw.domain
    _name = _ffw.name
    _title = _ffw.title
    pan = @panels[_domain_name]
    @wrappers[_name]=_ffw
    if pan!=nil
      num = pan['sons'].length
      if @headed
        pan['root'].title(_title)
        if !pan['root'].frame.instance_of?(TkFrameAdapter) && num==0
          if _adapter
            adapter = _adapter
          else
            adapter = TkFrameAdapter.new(self.root, Arcadia.style('frame'))
          end
          adapter.attach_frame(pan['root'].frame)
          adapter.raise
          #@wrappers[_name]=wrapper
        end
        root_frame = pan['root'].frame
      else
        root_frame = pan['root']
      end
      if (num == 0 && @autotab)
        #api = ArcadiaPanelInfo.new(_name,_title,wrapper,_ffw)
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
  					    pan['root'].top_text('') 
         	         Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>pan['sons'][api.name].extension, 'frame_name'=>pan['sons'][api.name].name))
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
      	     Arcadia.process_event(LayoutRaisingFrameEvent.new(self,'extension_name'=>_ffw.extension, 'frame_name'=>_ffw.name))
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
      w.detach_frame
      w.attach_frame(@panels[_domain_name]['root'].frame)
      @panels[_domain_name]['root'].title(t)
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
      if child.instance_of?(TkTitledFrame)
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