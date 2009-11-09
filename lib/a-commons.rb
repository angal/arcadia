#
#   a-commons.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

require "observer"
require 'singleton'

# +------------------------------------------+
#      Extension
# +------------------------------------------+


class AbstractFrameWrapper
#  def AbstractFrameWrapper.inherited(sub)
#    unless sub.respond_to? :hinner_frame
#      raise NoMethodError, "#{sub} needs to respond to `:hinner_frame'" 
#    end
#    unless sub.respond_to? :title
#      raise NoMethodError, "#{sub} needs to respond to `:title'" 
#    end
#  
#    unless sub.respond_to? :show
#      raise NoMethodError, "#{sub} needs to respond to `:show'" 
#    end
#  
#    unless sub.respond_to? :hide
#      raise NoMethodError, "#{sub} needs to respond to `:hide'" 
#    end
#  
#    unless sub.respond_to? :free
#      raise NoMethodError, "#{sub} needs to respond to `:free'" 
#    end
#  end

  def initialize
    unless sub.respond_to? :hinner_frame
      raise NoMethodError, "#{sub} needs to respond to `:hinner_frame'" 
    end
    unless sub.respond_to? :title
      raise NoMethodError, "#{sub} needs to respond to `:title'" 
    end
  
    unless sub.respond_to? :show
      raise NoMethodError, "#{sub} needs to respond to `:show'" 
    end
  
    unless sub.respond_to? :hide
      raise NoMethodError, "#{sub} needs to respond to `:hide'" 
    end
  
    unless sub.respond_to? :free
      raise NoMethodError, "#{sub} needs to respond to `:free'" 
    end
  end

end

#module AbstractFrameWrapper
#  def hinner_frame
#     raise NoMethodError, "#{self} needs to respond to `:hinner_frame'" 
#  end
#end

class FixedFrameWrapper < AbstractFrameWrapper
#  include AbstractFrameWrapper
  attr_accessor :domain
  attr_reader :name
  attr_reader :title
  attr_reader :extension
  def initialize(_extension, _domain, _name, _title='')
    @extension = _extension
    @domain =_domain
    @name = _name
    @title = _title
    fixed_frame_forge
  end
  
  def fixed_frame_forge
    @fixed_frame = Arcadia.layout.register_panel(self) if @fixed_frame.nil?
  end
  private :fixed_frame_forge
  
  def hinner_frame
    fixed_frame_forge
    @fixed_frame
  end
  
  def top_text(_top_text=nil)
    fixed_frame_forge
    Arcadia.layout.domain(@domain)['root'].top_text(_top_text)
    #@arcadia.layout.domain_for_frame(@domain, @name)['root'].top_text(_title)
  end

  def show
    fixed_frame_forge
    Arcadia.layout.raise_panel(@domain, @name)
  end
  
  def hide
  end
  
  def raised?
    Arcadia.layout.raised?(@domain, @name)
  end

  def maximized?
    Arcadia.layout.domain(@domain) && Arcadia.layout.domain(@domain)['root'].maximized?
  end

  def maximize
    Arcadia.layout.domain(@domain)['root'].maximize
  end

  def resize
    Arcadia.layout.domain(@domain)['root'].resize
  end
  
  def free
    Arcadia.layout.unregister_panel(self)
    @fixed_frame = nil
  end
end


class FloatFrameWrapper < AbstractFrameWrapper
#  include AbstractFrameWrapper
  def initialize(_arcadia, _geometry=nil, _title=nil)
    @arcadia = _arcadia
    @geometry = _geometry
    @title= _title
    float_frame_forge
  end

  def float_frame_forge
    if @obj.nil?
      a = @geometry.scan(/[+-]*\d\d*%*/)
      p_height = TkWinfo.screenheight(@arcadia.layout.root)    
      p_width = TkWinfo.screenwidth(@arcadia.layout.root)    
      if a[0][-1..-1]=='%'
        n = a[0][0..-2].to_i.abs
      		a[0] = (p_width/100*n).to_i
      end
      if a[1][-1..-1]=='%'
        n = a[1][0..-2].to_i.abs
      		a[1] = (p_height/100*n).to_i
      end
      if a[2][-1..-1]=='%'
        n = a[2][0..-2].to_i.abs
      		a[2] = (p_width/100*n).to_i
      end
      if a[3][-1..-1]=='%'
        n = a[3][0..-2].to_i.abs
      		a[3] = (p_height/100*n).to_i
      end
      
      args = {'width'=>a[0], 'height'=>a[1], 'x'=>a[2], 'y'=>a[3]}
      @obj = @arcadia.layout.new_float_frame(args)
      @obj.title(@title) if @title
    end
  end

  def hinner_frame
    float_frame_forge
    @obj.frame if @obj
  end
  
  def title(_title=nil)
    float_frame_forge
    @obj.title(_title)  if @obj
  end

  def show
    float_frame_forge
    @obj.show if @obj 
  end
  
  def hide
    float_frame_forge
    @obj.hide if @obj 
  end
  
  def free
    @obj.destroy if @obj 
    @obj = nil
  end
end

class ArcadiaExt
  attr_reader :arcadia
  def initialize(_arcadia, _name=nil)
    @arcadia = _arcadia
    @arcadia.register(self)
    Arcadia.attach_listener(self, BuildEvent)
    Arcadia.attach_listener(self, ExitQueryEvent)
    Arcadia.attach_listener(self, FinalizeEvent)
    @name = _name
    @frames = Array.new
    @frames_points = conf_array("#{_name}.frames")
    @frames_labels = conf_array("#{_name}.frames.labels")
    @frames_names = conf_array("#{_name}.frames.names")
    @float_frames = Array.new
    @float_geometries = conf_array("#{_name}.float_frames")
    @float_labels = conf_array("#{_name}.float_labels")
    #ObjectSpace.define_finalizer(self, self.method(:finalize).to_proc)
  end
  
  
  def conf_array(_name)
    res = []
    value = @arcadia['conf'][_name]
    res.concat(value.split(',')) if value
    res
  end
  
  def frame_def_visible?(_n=0)
    @arcadia.layout.domains.include?(@frames_points[_n])
    #@frames_points[_n] != '-1.-1'
  end
  
  def frame_visible?(_n=0)
    @frames[_n] != nil && @frames[_n].hinner_frame && TkWinfo.mapped?(@frames[_n].hinner_frame)
  end
  
  def frame(_n=0,create_if_not_exist=true)
	  if @frames[_n] == nil && @frames_points[_n] && create_if_not_exist
	    (@frames_labels[_n].nil?)? _label = @name : _label = @frames_labels[_n]
	    (@frames_names[_n].nil?)? _name = @name : _name = @frames_names[_n]
	    @frames[_n] = FixedFrameWrapper.new(@name, @frames_points[_n], _name, _label)
	  end
    return @frames[_n]
  end
  
  def float_frame(_n=0, _args=nil)
	  if @float_frames[_n].nil? 
	    (@float_labels[_n].nil?)? _label = @name : _label = @float_labels[_n]
	    @float_frames[_n] =  FloatFrameWrapper.new(@arcadia, @float_geometries[_n], _label)
	  end
     @float_frames[_n]
  end

  def conf(_property)
	  @arcadia['conf'][@name+'.'+_property]
  end

#  def conf_global(_property)
#	  @arcadia['conf'][_property]
#  end
	
  def exec(_method, _args=nil)
    if self.respond_to(_method)
      self.send(_method, _args)
    end
  end
  
  def maximized?(_n=0)
    ret= false
    ret=@frames[_n].maximized? if @frames[_n]
    ret
  end

  def maximize(_n=0)
    @frames[_n].maximize if @frames[_n]
  end
  
  def resize(_n=0)
    @frames[_n].resize if @frames[_n]
  end
end


class ObserverCallback
	def initialize(_publisher, _subscriber, _method_update_to_call=:update)
		@publisher = _publisher
		@subscriber = _subscriber
		@method=_method_update_to_call
		@publisher.add_observer(self)
	end
	def update(*args)
		@subscriber.send(@method,*args)
	end
end

# +------------------------------------------+
#      Event
# +------------------------------------------+

class Event
  class Result
    attr_reader :sender
    attr_reader :time
    def initialize(_sender, _args=nil)
      @sender = _sender
      if _args 
        _args.each do |key, value|
          self.send(key+'=', value)
        end
      end
      @time = Time.new
    end
  end
  attr_reader :sender
  attr_accessor :parent
  attr_reader :channel
  attr_reader :time
  attr_reader :results
  def initialize(_sender, _args=nil)
    @breaked = false
    @sender = _sender
    @channel = '0'
    if _args 
      _args.each do |key, value|
        #self.send(key, value)
        self.send(key+'=', value)
      end
    end
    @time = Time.new
    @results = Array.new
  end
  
  def add_finalize_callback(_proc)
    ObjectSpace.define_finalizer(self, _proc) 
  end
  
  def add_result(_sender, _args=nil)
    if self.class::Result
      res = self.class::Result.new(_sender, _args)
    else
      res = Result.new(_sender, _args)
    end
    @results << res
    res
  end
  
  def is_breaked?
    @breaked
  end
  
  def break
    @breaked = true
  end
end

module EventBus #(or SourceEvent)
  def process_event(_event)
    return _event if !defined?(@@listeners)
    event_classes = _event_class_stack(_event.class)
    #before fase
    event_classes.each do |_c|
      _process_fase(_c, _event, 'before')
      break if _event.is_breaked? # not responding to this means "you need to pass in an instance, not a class name
    end unless _event.is_breaked?
    # fase
    event_classes.each do |_c|
      _process_fase(_c, _event)
      break if _event.is_breaked?
    end unless _event.is_breaked?
    #after fase
    event_classes.each do |_c|
      _process_fase(_c, _event, 'after')
      break if _event.is_breaked?
    end unless _event.is_breaked?
    _event
  end
  
  def broadcast_event(_event)
    return _event if !defined?(@@listeners)
    event_classes = _event_class_stack(_event.class)
    event_classes.each do |_c|
      _broadcast_fase(_c, _event)
    end
  end
  
  def _event_class_stack(_class)
    #p "------> chiamato _event_class_stack for class #{_class}"
    res = Array.new
    cur_class = _class
    while cur_class != Object
	#p "#{cur_class} son on #{cur_class.superclass}"
       res << cur_class
       cur_class = cur_class.superclass
    end
    return res
  end
  private :_event_class_stack
  
  def _process_fase(_class, _event, _fase_name = nil)
    # _fase_name cicle
    return if @@listeners[_class].nil?
    _fase_name.nil?? suf = '':suf = _fase_name
    #method_name = 'on_'+suf+_class.to_s.downcase.gsub('event','')
    method_name = _method_name(_class, suf)
    #p _method_name(_event, suf)+' == '+method_name
    #p method_name
    if _class != _event.class
      #sub_method_name = 'on_'+suf+_event.class.to_s.downcase.gsub('event','')
      sub_method_name = _method_name(_event.class, suf)
      @@listeners[_class].each do|_listener|
         if _listener.respond_to?(sub_method_name)
           _listener.send(sub_method_name, _event)
         elsif _listener.respond_to?(method_name)
           _listener.send(method_name, _event)
         end
         break if _event.is_breaked?
      end
    else
      @@listeners[_class].each do|_listener|
        _listener.send(method_name, _event) if _listener.respond_to?(method_name)
        break if _event.is_breaked?
      end
    end
  end
  private :_process_fase
  def _method_name(_class, _suf='')
    _str = _class.to_s
    _pre = _str[0..1]
    _in = _str[2..-1]
    _suf = _suf+'_' if _suf.length >0
    return 'on_'+(_suf+_pre+_in.gsub(/[A-Z]/){|s| '_'+s.to_s}).downcase.gsub('_event','')
  end
  private :_method_name
  def _broadcast_fase(_class, _event)
    return if @@listeners[_class].nil?
    method_name = _method_name(_class)
    if _class != _event.class
      sub_method_name = _method_name(_event.class)
      @@listeners[_class].each do|_listener|
        if _listener.respond_to?(sub_method_name)
  	         Thread.new{_listener.send(sub_method_name, _event)}
        elsif _listener.respond_to?(method_name)
            Thread.new{_listener.send(method_name, _event)}
        end
      end
    else
      @@listeners[_class].each do|_listener|
        Thread.new{
          _listener.send(method_name, _event) if _listener.respond_to?(method_name)
        }
      end
    end
  end
  private :_broadcast_fase

  def detach_listener(_listener, _class_event)
    if @@listeners[_class_event]
      @@listeners[_class_event].delete(_listener)
    end
  end
  
  def attach_listener(_listener, _class_event)
    @@listeners = {} unless defined? @@listeners
    @@listeners[_class_event] = []   unless @@listeners.has_key?(_class_event)
    @@listeners[_class_event] << _listener
  end

end


module Autils
	def full_in_path_command(_command=nil)
	  return nil if _command.nil?
		_ret = nil
		RUBY_PLATFORM =~ /win32|mingw/ ? _sep = ';':_sep=':'
		ENV['PATH'].split(_sep).each{|_path|
			_file = File.join(_path, _command)
			if FileTest.exist?(_file)
	  			_ret = _file
			end
		}
		_ret
	end

  def is_windows?
    RUBY_PLATFORM =~ /mingw|mswin/
  end
	
end

module Configurable
  
  def properties_file2hash(_property_file, _link_hash=nil)
    r_hash = Hash.new
    if _property_file &&  FileTest::exist?(_property_file)
      f = File::open(_property_file,'r')
      begin
        _lines = f.readlines
        _lines.each{|_line|
          _strip_line = _line.strip
          if (_strip_line.length > 0)&&(_strip_line[0,1]!='#')
            var_plat = _line.split('::')
            if var_plat.length > 1
              if (RUBY_PLATFORM.include?(var_plat[0]))
                _line = var_plat[1]
                var_plat[2..-1].collect{|x| _line=_line+'::'+x} if var_plat.length > 2
              else
                _line = ''
              end
            end
            var_ruby_version = _line.split(':@:')
            if var_ruby_version.length > 1
              version = var_ruby_version[0]
              if (RUBY_VERSION[0..version.length-1]==version)
                _line = var_ruby_version[1]
              else
                _line = ''
              end
            end
            
            var = _line.split('=')
            if var.length > 1
              _value = var[1].strip
              var[2..-1].collect{|x| _value=_value+'='+x} if var.length > 2
              if _link_hash 
                _value = resolve_link(_value, _link_hash)
              end
              r_hash[var[0].strip]=_value
            end
          end
        }
      ensure
        f.close unless f.nil?
      end
      return r_hash      
    else
      puts 'warning--file does not exist', _property_file
    end
  end
  
  def Configurable.properties_group(_group, _hash_source)
    @@conf_groups = Hash.new if !defined?(@@conf_groups)
    if @@conf_groups[_group].nil?
      @@conf_groups[_group] = Hash.new
      glen=_group.length
      _hash_source.keys.sort.each{|k|
        if k[0..glen] == "#{_group}."
          @@conf_groups[_group][k[glen+1..-1]]=_hash_source[k]
        elsif @@conf_groups[_group].length > 0
          break
        end
      }
    end
    Hash.new.update(@@conf_groups[_group])
  end
  

  def resolve_link(_value, _hash_source, _link_symbol='>>>', _add_symbol='+++')
      if _value.length > 0 
        _v, _vadd = _value.split(_add_symbol)
      else
        _v = _value
      end
      if _v.length > 3 && _v[0..2]==_link_symbol
        _v=_hash_source[_v[3..-1]] if _hash_source[_v[3..-1]]
        _v=_v+_vadd if _vadd
      end
      return _v
  end
  
  def resolve_properties_link(_hash_target, _hash_source, _link_symbol='>>>', _add_symbol='+++')
    loop_level_max = 10
#    _hash_adding = Hash.new
    _keys_to_extend = Array.new
    _hash_target.each{|k,value|
      loop_level = 0
      if value.length > 0
	v, vadd = value.split(_add_symbol)
      else
	v= value
      end
#      p "value=#{value} class=#{value.class}"
#      p "v=#{v} class=#{v.class}"
#      p "vadd=#{vadd}"
      while loop_level < loop_level_max && v.length > 3 && v[0..2]==_link_symbol
        if k[-1..-1]=='.'
          _keys_to_extend << k
          break
        elsif _hash_source[v[3..-1]]
          v=_hash_source[v[3..-1]]
          v=v+vadd if vadd
        else
          break
        end
        loop_level = loop_level + 1
      end
      _hash_target[k]=v
      if loop_level == loop_level_max
        raise("Link loop found for property : #{k}")
      end
    }
    _keys_to_extend.each do |k|
      v=_hash_target[k]
      g=Configurable.properties_group(v[3..-1], _hash_target)
      g.each do |key,value|
        _hash_target["#{k[0..-2]}.#{key}"]=value if !_hash_target["#{k[0..-2]}.#{key}"]
      end
      _hash_target.delete(k)
    end
  end
  
end

module Persistable
  def override_persistent(_persist_file, _persistent_hash)
    if FileTest::exist?(_persist_file) && File.stat(_persist_file).writable?
      f = File.new(_persist_file, "w")
      begin
        if f
          if _persistent_hash
            _persistent_hash.each{|key,value|
              f.syswrite(key+'='+value+"\n")
            }
          end
        end
      ensure
        f.close unless f.nil?
      end
    end
  end

  def append_persistent_property(_persist_file, _persistent_key, _persistent_value)
    if FileTest::exist?(_persist_file)
      f = File.new(_persist_file, "w+")
      begin
        if f
          if _persistent_key
              f.syswrite(_persistent_key+'='+_persistent_value+"\n")
          end
        end
      ensure
        f.close unless f.nil?
      end
    end
  end
  
end

class Application
  extend EventBus
  include Configurable
  include Persistable
  ApplicationParams = Struct.new( "ApplicationParams",
    :name,
    :version,
    :config_file,
    :persistent_file
  )

  def initialize(_ap=ApplicationParams.new)
    @@instance = self
    eval('$'+_ap.name+'=self') # set $arcadia to this instance
    publish('applicationParams', _ap)
    publish(_ap.name,self)
    @first_run = false
    self['applicationParams'].persistent_file = File.join(local_dir, self['applicationParams'].name+'.pers')
    if !File.exists?(self['applicationParams'].persistent_file)
      File.new(self['applicationParams'].persistent_file, File::CREAT).close
    end
    # read in the settings'
    publish('conf', properties_file2hash(self['applicationParams'].config_file)) if self['applicationParams'].config_file
    publish('origin_conf', Hash.new.update(self['conf'])) if self['conf']
    publish('pers', properties_file2hash(self['applicationParams'].persistent_file)) if self['applicationParams'].persistent_file
    yield(self) if block_given?
  end
  
  def Application.instance
    @@instance
  end

  def Application.conf(_property)
	  @@instance['conf'][_property] if @@instance
  end

  def conf(_property)
	  self['conf'][_property]
  end
  
  def Application.sys_info
    "[Platform = #{RUBY_PLATFORM}]\n[Ruby version = #{RUBY_VERSION}]"
  end
  
  def Application.conf_group(_group)
    @@conf_groups = Hash.new if !defined?(@@conf_groups)
    if @@conf_groups[_group].nil?
      @@conf_groups[_group] = Hash.new
      glen=_group.length
      @@instance['conf'].keys.sort.each{|k|
        if k[0..glen] == "#{_group}."
          @@conf_groups[_group][k[glen+1..-1]]=@@instance['conf'][k]
        elsif @@conf_groups[_group].length > 0
          break
        end
      }
    end
    @@conf_groups[_group]
  end

  def Application.del_conf_group(_group)
      glen=_group.length
      @@instance['conf'].keys.sort.each{|k|
        if k[0..glen] == "#{_group}."
          @@instance['conf'].delete(k)
        end
      }
  end

  def Application.del_conf(_k)
    @@instance['conf'].delete(_k)
  end

  def prepare
  end

  def publish(_name, _obj)
    @objs = Hash.new if !defined?(@objs)
    if @objs[_name] == nil
      @objs[_name] = _obj
    else
      raise("The name #{_name} already exist")
    end
  end

  def local_file_config
    File.join(local_dir, File.basename(self['applicationParams'].config_file))
  end
  
  def update_local_config
      # local_dir is ~/arcadia
      if FileTest.exist?(local_file_config)
        if FileTest.writable?(local_dir)
          f = File.new(local_file_config, "w")
          begin
            if f
              p = self['conf']
              if p
                p.keys.sort.each{|key|
                  if self['origin_conf'][key] == self['conf'][key]
                    f.syswrite('#'+key+'='+self['conf'][key]+"\n") # write it as a comment since it isn't a real change
                  else
                    f.syswrite(key+'='+self['conf'][key]+"\n")
                  end
                }
              end
            end
          ensure
            f.close unless f.nil?
          end
        end
      end
  end
  
  # this method load config file from local directory for personalizations
  def load_local_config(_create_if_not_exist=true)
      if FileTest.exist?(local_file_config)
        self['conf'].update(self.properties_file2hash(local_file_config))
      elsif _create_if_not_exist
        if FileTest.writable?(local_dir)
          f = File.new(local_file_config, "w")
          begin
            if f
              p = self['conf']
              if p
                p.keys.sort.each{|key|
                  f.syswrite('#'+key+'='+self['conf'][key]+"\n")
                }
              end
            end
          ensure
            f.close unless f.nil?
          end
        else
          msg = "Locad dir "+'"'+local_dir+'"'+" must be writable!"
          Arcadia.dialog(self, 'type'=>'ok','title' => '(Arcadia)', 'msg' => msg, 'level'=>'error')
          exit
        end
      end
  end
  
  def load_theme(_name=nil)
    _theme_file = "conf/theme-#{_name}.conf" if !_name.nil?
    if _theme_file && File.exist?(_theme_file)
      self['conf'].update(self.properties_file2hash(_theme_file))
      _theme_res_file = "conf/theme-#{_name}.res.rb"
      if _theme_res_file && File.exist?(_theme_res_file)
        begin
          require _theme_res_file
        rescue Exception => e  
        end

      end
    end  
  end
  
  def local_dir
    home = File.expand_path '~'
    _local_dir = File.join(home,'.'+self['applicationParams'].name) if home
    if _local_dir && !File.exist?(_local_dir)
      if FileTest.exist?(home)
        Dir.mkdir(_local_dir)
        @first_run = true
      else
        msg = "Local dir "+'"'+home+'"'+" must be writable!"
        Arcadia.dialog(self, 'type'=>'ok', 'title' => "(#{self['applicationParams'].name})", 'msg' => msg, 'level'=>'error')
        exit
      end
    end
    return _local_dir
  end

  def create(_name, _class)
    register(_name,_class.new)
  end

  def objects(_name)
    return @objs[_name]
  end

  def [](_name)
    if @objs[_name]
      return @objs[_name]
    else
      return nil
      #raise RuntimeError, "resurce '"+_name+"' unavabled ", caller
    end
  end

  def []=(_name, _value)
    @objs[_name] = _value
#    if @objs[_name]
#      @objs[_name] = _value
#    end
  end


  def run
  end
end