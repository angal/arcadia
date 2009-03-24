#
#   ae-rad-libs.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

class ArcadiaLib
  attr_reader :arcadia_lib_params
  attr_reader :classes

  def initialize(_arcadia, _arcadia_lib_params)
    @arcadia = _arcadia
    @arcadia_lib_params = _arcadia_lib_params
    @classes = Array.new
    @requires = Array.new
    @require4class = Hash.new
    register_classes
  end

  def add_class(arcadia_class=nil, _is_top=false)
    _self = self
    if arcadia_class
      class << arcadia_class
        def library=(lib)
          @library = lib
        end
        def library
          @library
        end

      end
      arcadia_class.library = self
      if _is_top
        class << arcadia_class
          def is_top
            true
          end
        end
      else
        class << arcadia_class
          def is_top
            false
          end
        end
      end
      @classes << arcadia_class
    end
  end

  protected :add_class
  def register_classes
  end
  protected :register_classes

end


class ArcadiaLibs
  attr_reader :arcadia
  ArcadiaLibParams = Struct.new( "ArcadiaLibParams",
    :name,
    :source,
    :require,
    :classLib
  )

  def initialize(_arcadia)
    @arcadia = _arcadia
    @@libs = Array.new
  end

  def list
    @@libs
  end

  def add_lib(arcadia_lib_params=nil)
    if arcadia_lib_params
      @@libs << arcadia_lib_params.classLib.new(@arcadia,arcadia_lib_params)
    end
  end

  def ArcadiaLibs.check_dictionary
    if !defined?(@@wrappers_for_classes)
      @@wrappers_for_classes = Hash.new
      @@libs.each{|_lib|
        _lib.classes.each{|_class|
          @@wrappers_for_classes[_class.class_wrapped]=_class
        }
      }
    end
  end

  def ArcadiaLibs.wrapper_class(_class)
    check_dictionary
    return @@wrappers_for_classes[_class]
  end

  def ArcadiaLibs.copy_wrapper_of_class_to_class(_of_class, _to_class)
    check_dictionary
    @@wrappers_for_classes[_to_class] = @@wrappers_for_classes[_of_class]
  end

end

class PropType
  def initialize
  end
end

class StringType < PropType
  def initialize
  end
end

class NumberType < PropType
  def initialize
  end
end

class ProcType < PropType
  def initialize(_proc)
    @p = _proc
  end
  def procReturn
    @p.call
  end
end

class EnumType < PropType
  attr_reader :values
  def initialize(*args)
    if args.class == Array
      @values = *args
    else
      @values = [*args]
    end
  end
end

class EnumProcType < EnumType
  def initialize(_proc, *args)
    @p = _proc
    super(*args)
  end
  def procReturn
    @p.call
  end
end

class ObjEnumProcType < EnumProcType
  attr_reader :it
  def initialize(_obj, _proc, *args)
    @it = me
    super(_proc, *args)
  end
end

class AGSniffer
  attr_reader :sons
  def initialize(_obj)
    @obj = _obj
    @sons = Array.new
    find_sons
  end
  def find_sons

  end
  def has_sons?
    @sons.length > 0
  end
end

class AGRenderer
  #INDENT_UNIT = "\t"
  INDENT_UNIT = "\s"*2
  def initialize(_agobj=nil)
    if _agobj
      @agobj = _agobj
    else
      exit
    end
  end

  def class_code(_ind=0, _args=nil)
    args = render_on_create_properties(_args) 
    return class_begin(_ind, args), class_hinner_begin(_ind+1), class_hinner_end(_ind+1), class_end(_ind)
  end

  def class_begin(_ind=0, _args=nil)
    code = INDENT_UNIT*_ind,'class ', @agobj.getInstanceClass,  ' < ', @agobj.getObjClass
    code_attr=''
    code_hinner_class=''
    @agobj.sons.each {|value|
      if (value.sons.length > 0)
        code_hinner_class = code_hinner_class,"\n", value.renderer.class_code(_ind+1)
      end
      code_attr = code_attr,"\n",INDENT_UNIT*(_ind+1),'attr_reader :', value.i_name
    }
    code = code,code_attr if (code_attr.length >0)
    code = code,code_hinner_class,"\n" if (code_hinner_class.length >0)
    code = code,"\n", INDENT_UNIT*(_ind+1),"def initialize(parent=nil, *args)\n"
    if _args
      code = code, INDENT_UNIT*(_ind+2),"super(parent, "+_args+")\n"
    else
      code = code, INDENT_UNIT*(_ind+2),"super(parent, *args)\n"
    end
  end
  
  def class_hinner_begin(_ind=0)
    return render_family(_ind+1,'property','default')
  end
  
  def class_hinner_end(_ind=0)
    code = ''
    @agobj.sons.each {|value|
      if (value.sons.length > 0)
        code = code, value.renderer.obj_begin(_ind+1),"\n"
      else
        code = code, value.renderer.obj_code(_ind+1),"\n"
      end
    }
    return code.to_s
  end
  
  def class_end(_ind=0)
    code = code, "\n", INDENT_UNIT*(_ind+1),"end\n",INDENT_UNIT*(_ind),"end"
    return code.to_s
  end
  
  def obj_code(_ind=0)
    return obj_begin(_ind), "{ ",obj_hinner_begin(_ind+1), obj_hinner_end(_ind+1), obj_end(_ind),"}"
  end

  def obj_begin(_ind=0)
    _s_ind = INDENT_UNIT*_ind
    if _s_ind == nil
      _s_ind = ''
    end
    if @agobj.sons.length > 0
      _class = @agobj.getInstanceClass
    else
      _class = @agobj.class.class_wrapped.to_s
    end
    return "\n",_s_ind+'@'+@agobj.i_name+' = '+_class+'.new(self)'
  end
  
  def obj_hinner_begin(_ind=0)
    return class_hinner_begin(_ind)
  end
  
  def obj_hinner_end(_ind=0)
    code = ''
    _s_attr_reader = ''
    _s_ind = INDENT_UNIT*_ind
    _s_attr_reader = ''
    @agobj.sons.each{|son|
      code = code , "\n", son.renderer.obj_code(_ind)
      _s_attr_reader = _s_attr_reader, "\n", _s_ind,INDENT_UNIT*2 ,':',son.i_name
    }
    if code.length > 0 then
      code = code , "\n",_s_ind,"class << self"
      code = code , "\n",_s_ind,"  attr_reader",_s_attr_reader
      code = code , "\n",_s_ind,"end"
    end
    return code
  end

  def obj_end(_ind=0)
    _s_ind = INDENT_UNIT*_ind
    if _s_ind == nil
      _s_ind = ''
    end
    _s_ind
  end
  
  def render_on_create_properties(_args = nil)
    ret = nil
    if _args
      ret = ''
      _args.each{|k,v|
        if ret.strip.length > 0
          ret = ret + ', '
        end
        ret = ret + "'"+k+"' => '"+v+"'"
      }
    end
    aprop = @agobj.props_kinds['property']['on-create']
    if aprop 
      ret = '' if ret == nil
      aprop.each{|name|
        next if _args && _args.has_key?(name)
        prop = @agobj.props['property'][name]
	      _val = render_value(prop, 'property')
        if _val == nil
          next
        end
        if ret.strip.length > 0
          ret = ret +', '
        end 
        #Tk.messageBox('message'=>_val.to_s)
        if (prop['def'] == '')||(prop['def'] == nil) #significa che possiamo inserire nel blocco come chiave,valore
          ret = ret + "'"+ prop['name'] +"' => "+ _val.to_s
        elsif (prop['def'] != nil)&&(prop['def'] != 'nodef')
          ret = ret + prop['def'].call(_val.to_s)
        end
      }
    end
    ret = nil if ret != nil && ret.strip.length == 0
    return ret 
  end
	
	def render_value(_prop, _family)
      #Tk.messageBox('message'=>_prop['name'])
      return nil if _prop == nil
      _val = _prop['get'].call
      
      if @agobj.defaults_values[@agobj.class][_family][_prop['name']]==_val
        return nil
      end

      _prop['def_string'] != nil && !_prop['def_string'] ? is_string = false: is_string = true

      if _val.kind_of?(String) && is_string
        _val = "'",_val,"'"
      elsif _val != nil
        _val = _val.to_s
      end
      #Tk.messageBox('message'=>_val)
      return _val
	end  

	def render_value_default(_prop, _family)
      return nil if _prop == nil
      _val = _prop['value']
      _prop['def_string'] != nil && !_prop['def_string'] ? is_string = false: is_string = true
      if _val.kind_of?(String) && is_string
        _val = "'",_val,"'"
      elsif _val != nil
        _val = _val.to_s
      end
      return _val
	end  



  def render_family(_ind=0, _family='', _kind=nil, _default=false)
    if @agobj.props[_family] == nil
      return ''
    end
    _s_block = ''
    _s_ind = INDENT_UNIT*_ind

    render_group =  @agobj.props_def[_family] != nil
    if render_group
      @agobj.props_def[_family]['sep'] != nil ? render_group_sep = @agobj.props_def[_family]['sep']:render_group_sep = ''
      @agobj.props_def[_family]['default'] != nil ? render_group_default = @agobj.props_def[_family]['default']:render_group_default = proc{|nome,x| "'#{nome}' #{x}"}
    end
    if _kind == nil
      properties_list = Array.new
      @agobj.props_kinds[_family].each_value{|p|
        properties_list.concat(p)
      }
    else
      properties_list = @agobj.props_kinds[_family][_kind]
    end
    properties_list.each{|name|
      value = @agobj.props[_family][name]
      if _default
      		_val = render_value_default(value, _family)
      else
      		_val = render_value(value, _family)
      end
      if _val == nil
        next
      end
      
      if render_group
        if _s_block.length > 0
          _s_block = _s_block, render_group_sep
        end
        _s_block = _s_block,"\n",_s_ind, INDENT_UNIT
        if (value['def'] == '')||(value['def'] == nil) #significa che possiamo inserire nel blocco come chiave,valore
          _s_block = _s_block, render_group_default.call(value['name'] , _val)
        elsif (value['def'] != nil)&&(value['def'] != 'nodef')
          _s_block = _s_block, value['def'].call(_val)
        end
      else
        if (value['def'] == '')||(value['def'] == nil) #significa che possiamo inserire nel blocco come chiave,valore
          _s_block = _s_block, "\n",_s_ind , value['name'] ,INDENT_UNIT , _val
        elsif (value['def'] != nil)&&(value['def'] != 'nodef')
          _s_block = _s_block , "\n",  _s_ind ,value['def'].call(_val)
        end
      end
    }

    if render_group
      _ss_block =  "\n",_s_ind
      if @agobj.props_def[_family]['path'] != nil
        _ss_block = _ss_block, @agobj.props_def[_family]['path']
      end
      _ss_block = _ss_block, @agobj.props_def[_family]['before'],	_s_block, "\n",_s_ind, @agobj.props_def[_family]['after']
    else
      _ss_block = _s_block
    end
    #p _ss_block.to_s
    return _ss_block
  end
end

class AG
  attr_reader :props, :props_def, :i_name, :i_ag, :ag_parent, :obj_class, :obj 
  attr_reader :sons, :renderer
  attr_reader :sniffer
  attr_reader :persistent
  #attr_reader :props_seq
  attr_reader :props_kinds
  attr_writer :props, :i_name, :i_ag

  def initialize(_ag_parent = nil, _object = nil)
    @ag_parent = _ag_parent
    if _object == nil
      new_object
    else
      passed_object(_object)
    end

    @obj_class = self.class.near_class_wrapped(@obj)
    @sons = Array.new
    @renderer=self.class.class_renderer.new(self)
    @sniffer=self.class.class_sniffer.new(@obj)
    yield(self) if block_given?
    if !defined?(@i_name)
      @i_name = self.class.class_wrapped.to_s.gsub('::','_') + new_id
      @i_name = @i_name.sub(/^./) { $&.downcase}
    end
    @i_ag = 'ag' + @i_name
    @props = Hash.new
    @props_def = Hash.new
    @props_kinds = Hash.new
    @persistent = Hash.new
    @requires = Hash.new
    properties
    defaults(_object != nil )
    if _object != nil
      retrive_values
    else
      start_properties
    end
    self.register
  end

  def add_require(_require)
    if @requires[_require] == nil
      @requires[_require] = 1
    else
      @requires[_require] += 1
    end
  end

  def del_require(_require)
    @requires[_require] -= 1
    if @requires[_require] == 0
      @requires[_require] = nil
    end
  end

  def select
    InspectorContract.instance.select(self, 'wrapper'=>self)
    self
  end

  
  def activate
    @@active = self
  end


  def build_sons
    iv = @obj.instance_variables
    if iv.length > 0
      cod = " class << @obj"+"\n"
      iv.each{|i|
        i.delete!('@')
        cod = cod + "  attr_reader  :"+i+"\n"
      }
      cod = cod +"end\n"
      eval(cod)
    end
    iv_obj = Hash.new
    iv.each{|i|
      iv_obj[i] = eval("@obj."+i)
    }
    i_name = nil
    self.sniffer.sons.each{|obj_son|
      clazz = self.class.near_class_wrapper(obj_son)
      if clazz != nil
        iv_obj.each{|key, value|
          if value == obj_son
            i_name=key
          end
        }
        if i_name == nil
          clazz.new(self,obj_son)
        else
          clazz.new(self,obj_son){|_self| _self.i_name = i_name}
        end
      end
    }
  end

  def register(_agobj=self)
    @sons << _agobj if _agobj!=self && _agobj.ag_parent == self
    if @ag_parent
      return @ag_parent.register(_agobj)
    else
    		WrapperContract.instance.wrapper_created(self,'wrapper'=>_agobj)
#
#	    _tobj = InspectorActionContract::TInspectorActionObj.new(self)
# 		  _tobj.wrapper = _agobj
#    		InspectorActionContract.instance.register(_tobj)
    end
  end

  def has_sons
    return (self.sons.length > 0)
  end

  def new_id
    if !defined?(@@ag_id)
      @@ag_id = Hash.new
    end
    if (@@ag_id[self.class]==nil)
      @@ag_id[self.class] = 1
    else
      @@ag_id[self.class] = @@ag_id[self.class] + 1
    end
    return @@ag_id[self.class].to_s
  end

  def defaults_values
    @@defaults_values
  end

  def defaults(_new=false)
    if !defined?(@@defaults_values)
      @@defaults_values = Hash.new
    end
    if (!defined?(@@defaults_values[self.class]))||(@@defaults_values[self.class] == nil)
      @@defaults_values[self.class] = Hash.new
      if _new
        _obj = @obj_class.new
        fill_defaults_value_from_agobj(_obj)
      else
        fill_defaults_value_from_agobj
      end
    end
  end

  def fill_defaults_value_from_agobj(_obj=nil)
    #return if _obj == nil
    _obj_save = @obj
    if _obj
      @obj = _obj
    end
    begin
      @props.each{|_key,_family|
        #Tk.messageBox('message'=>_key)
        if @@defaults_values[self.class][_key] == nil
          @@defaults_values[self.class][_key] = Hash.new
        end
        _family.each_value{|value|
          if (value['name'] != nil) && @@defaults_values[self.class][_key][value['name']] == nil
            if (value['default'] != nil)
              @@defaults_values[self.class][_key][value['name']] = value['default']
            elsif (value['get'] != nil)
              @@defaults_values[self.class][_key][value['name']] = value['get'].call
            end
          end
        }
      }
    ensure
      if _obj
        @obj = _obj_save
        _obj.destroy
      end
    end

  end


  def delete
  		InspectorContract.instance.delete_wrapper(self, 'wrapper'=>self)
  end

  def AG.class_wrapped
    nil
  end

  def AG.class_renderer
    AGRenderer
  end

  def AG.class_sniffer
    AGSniffer
  end

  def AG.active
    @@active
  end


  def getFileName
    __FILE__
  end
  
  def AG.publish_property(_name, args = nil)
#        class_eval(%Q[
#          def #{_name}
#            @#{_name}
#						#{args('get').call}
#          end
#  
#          def #{_name}=(value)
#            @#{_name} = value
#						#{args('set').call(value)}
#          end
#        ])

  end
   

  def new_object
    if self.class.class_wrapped
      @obj = self.class.class_wrapped.new
    end
  end

  def AG.near_class_wrapped(_obj)
    clazz = _obj.class
    while (ArcadiaLibs.wrapper_class(clazz) == nil)&&(clazz!=nil)
      clazz = clazz.superclass
    end
    return clazz
  end

  def AG.near_class_wrapper(_obj)
    ArcadiaLibs.wrapper_class(self.near_class_wrapped(_obj))
  end


  def passed_object(_obj)
    @obj = _obj
  end

  def start_properties
    @props.each_value{|family|
      family.each_value{|value|
        if value['start'] != nil
          value['set'].call(value['start'])
        end
      }
    }
  end

  def retrive_values
    @props.each_value{|family|
      family.each_value{|prop|
        prop['value'] = prop['get'].call
      }
    }
  end

  def getViewClassName
    return 'V',@i_name
  end

  def getControlClassName
    return @i_name.capitalize
  end

  def getInstanceClass
    return @i_name.capitalize
    #return 'C',@i_name
  end

  def get_path_i_name
    _return = @i_name
    _agstart = self
    while _agstart.ag_parent != nil
      _return = _agstart.ag_parent.i_name,'.',_return
      _agstart = _agstart.ag_parent
    end
    return _return
  end

  def get_implementation_new(_variable = false)
    if (ag_parent == nil)|| _variable
      result = '@',@i_name,' = ', getInstanceClass ,'.new(', '@',@ag_parent.i_name, ")\n"
    end
    result = result, self.class, '.new(', '@',@ag_parent.i_ag,", @",get_path_i_name,")"
  end

  def get_implementation_block
    result = result, "  @i_name = '", @i_name, "'\n"
    result = result, "  @i_ag = '", @i_ag, "'\n"
    result = result, "  @obj_class = '", getObjClass, "'\n"
  end

  def get_implementation_code
    result = result, get_implementation_new, "{\n"
    result = result, get_implementation_block
    @requires.each_key do |key|
      result = result,"  @object_inspector.addRequire('#{key}')\n"
    end
    
    result = result,"}"
  end
  

  def getObjClass
    if defined? @obj_class
      return @obj_class
    else
      return @obj.class
    end
  end

  def publish_def(_family, args = nil)
    @props_def[_family]=args
  end

#  def AG.publish_def(_family, args = nil)
#    @@props_def = Hash.new if !defined?(@@props_def)
#    @@props_def[_family]=args
#  end
    

  def publish(_family, args = nil)
    if @props[_family] == nil
      @props[_family] = Hash.new
    end
    @props[_family][args['name']]=args
    args['kind'] != nil ? kind = args['kind']:kind = 'default'
    if @props_kinds[_family] == nil
      @props_kinds[_family] = Hash.new
    end
    if @props_kinds[_family][kind] == nil
      @props_kinds[_family][kind] = Array.new
    end
    @props_kinds[_family][kind] << args['name']
  end

    


#  def AG.publish(_family, args = nil)
#    @@props = Hash.new if !defined?(@@props) 
#    if @@props[_family] == nil
#      @@props[_family] = Hash.new
#    end
#    @@props[_family][args['name']]=args
#    args['kind'] != nil ? kind = args['kind']:kind = 'default'
#    @@props_kinds = Hash.new if !defined?(@props_kinds)
#    if @@props_kinds[_family] == nil
#      @@props_kinds[_family] = Hash.new
#    end
#    if @@props_kinds[_family][kind] == nil
#      @@props_kinds[_family][kind] = Array.new
#    end
#    @@props_kinds[_family][kind] << args['name']
#  end


  def publish_mod(_family, args = nil)
    args.each do |key, value|
      @props[_family][args['name']]["#{key}"] = value
    end
  end

#  def AG.publish_mod(_family, args = nil)
#    args.each do |key, value|
#      @@props[_family][args['name']]["#{key}"] = value if !defined?(@@props) 
#    end
#  end


  def publish_del(_family, _name=nil)
    if _name == nil
      @props.delete(_family)
    else
      @props[_family].delete(_name)
    end
  end

#  def AG.publish_del(_family, _name=nil)
#    if _name == nil
#      @@props.delete(_family)
#    else
#      @@props[_family].delete(_name)
#    end
#  end

  def properties
    publish( 'property',
    'name' => 'name',
    'get'=> proc{@i_name},
    'set'=> proc{|n| self.i_name = n},
    'def'=> 'nodef'
    )
  end



#  def delete
#    @obj.destroy
#  end

#  def setp(_family, _name, _value)
#    @props[_family][_name]['set'].call(_value)
#    tobj = InspectorActionContract::TInspectorActionObj.new(self)
#    tobj.wrapper = self
#    tobj.property_family = _family
#    tobj.property_name = _name
#    tobj.property_value = _value
#    InspectorActionContract.instance.update_property(tobj)
#  end

  def update_property(_sender, _family,_name,_value)
  	 old_value = @props[_family][_name]['get'].call(_value)
  	 if old_value != _value
    		@props[_family][_name]['set'].call(_value)
    end
  		WrapperContract.instance.property_updated(self, 
  					'wrapper'=>self,
  					'property_name'=> _name,
  					'property_family'=>_family,
  					'property_old_value'=>old_value,
  					'property_new_value'=>_value  				
  		)
  end
  
#  def updatep(_family, prop, value, _call_from_inspector=false)
#    @props[_family][prop]['set'].call(value)
#  end

end


class ObserverCallbackContract < ObserverCallback
	def initialize(_publisher, _subscriber, _method_update_to_call=:update, _channel=nil)
	  super(_publisher, _subscriber, _method_update_to_call)
	  @channel = _channel
	  @channel_conf = @subscriber.conf(@publisher.class.to_s+'.channel') if @subscriber.respond_to?(:conf)
  end

	def filter(_event)
	  @channel_conf != nil && @channel_conf != _event.channel
	end
  
	def update(_event, *args)
	  super(_event, *args) if !filter(_event)
  end
end


class ObserverCallbackContractThread < ObserverCallbackContract
	def update(*args)
		Thread.new do
		  super(*args)
		end
	end

end



# The contract define the interface beetwhen extension
# in particulare define method than raise event to observers client
# and a way to retreive state from client

class ArcadiaContract
  include Observable
  include Singleton
  class ContractEvent 
    	attr_reader :contract
    	attr_reader :signature
    	attr_reader :context
    	attr_reader :channel
    	attr_reader :time
    	attr_writer :action
    	
    	SIGNATURE = "NOT_DEFINED"
     def initialize(_contract, _signature=SIGNATURE, _context=nil)
       @contract = _contract
     		@signature = _signature
     		@context = _context
     		_context.channel != nil ?@channel=_context.channel: @channel='0'
     		@time = Time.new
     		@action = false
     end
     
    	def handled(_from)
    	  MainContract.instance.event_handled(_from,'caused_by'=>self)
    	end
    	
    	def is_action? 
    	  @action
    	end
  end
  
  class TObj
   	attr_reader :sender
    attr_accessor :caused_by
   	attr_accessor :channel
   	DEFAULT_CHANNEL='0'
   	def initialize(_sender, _args=nil)
		  @sender=_sender
		  @channel = DEFAULT_CHANNEL
		  if _args 
		  	  _args.each do |key, value|
		  	    self.send(key+'=', value)
		  	  end
		  end
		  
	  end
	  
#	  properties.each do |prop|
#	    define_method(prop) {
#        instance_variable_get("@#{prop}")
#      }
#      define_method("#{prop}=") do |value|
#        instance_variable_set("@#{prop}", value)
#      end
#		end

#			define_method(prop)
#				attr_reader prop.to_sym # prop by itself also worked for me
#				# code snip ? setter method
#			end

			
#		def TObj.property(*properties)
#      properties.each { |property|
#        class_eval(%Q[
#          def #{property}
#            @#{property}
#          end
#  
#          def #{property}=(value)
#            @#{property} = value
#          end
#        ])
#      }
#		end	  
	end
	
  class EventInfo
  	 attr_reader :method
  	 attr_reader :label
  	 attr_reader :icon
    def initialize(_method)
      @method = @method
    end
  end

  SObj = Struct.new("GenericState",
    :caller
  )
 
  def _event_forge(_event_signature, _tobj) 
    ContractEvent.new(self, _event_signature, _tobj)
  end
  private :_event_forge
  
  
  def raise_event(_event_signature, _tobj, *args)
     _raise_event(_event_forge(_event_signature, _tobj),*args)
  end

  def _raise_event(_event, *args)
     changed
     notify_observers(_event, *args)
     if self.class != ArcadiaContract
       self.class.superclass.instance._raise_event(_event, *args)
     end
  end
  #protected :_raise_event
  
  def raise_action(_event_signature, _tobj, *args)
     _raise_action(_event_forge(_event_signature, _tobj),*args)
  end

  def _raise_action(_event, *args)
 	  _event.action = true 
 		_raise_event(_event, *args)
  end
  private :_raise_action

  def ArcadiaContract.publish_action(_method)
    _info = EventInfo.new(_method)
    @@actions = Array.new if !defined?(@@actions)
    @@actions << _info
  end

end

class ArcadiaContractListener
	def initialize(_subscriber, _class, _method, _channel=nil)
	  @subscriber = _subscriber
	  @class = _class
	  @method = _method
	  @channel = _channel
	  create_callback(_class.instance)
	end
	
	def create_callback(_contract)
	  ObserverCallbackContract.new(_contract, @subscriber, @method, @channel)
	end
	
end

class ArcadiaContractListenerThread < ArcadiaContractListener
	
	def create_callback(_contract)
	  #Thread.new do super(_contract, _subscriber, _method) end
	  ObserverCallbackContractThread.new(_contract, @subscriber, @method, @channel)
	end
	
end


#---------------- contracts ----------------------
class InspectorContract < ArcadiaContract
  SObj = Struct.new("InspectorActionState"
  )
  class TInspectorObj < TObj
  		attr_accessor	 :wrapper, :requires, :property_family,:property_name,:property_value
  end

  SELECT_WRAPPER = "SELECT_WRAPPER"
  #ACTIVATE_WRAPPER = "ACTIVATE_WRAPPER"
  DELETE_WRAPPER = "DELETE_WRAPPER"
  ADD_REQUIRE = "ADD_REQUIRE"
  REGISTER_WRAPPER = "REGISTER_WRAPPER"
#  UPDATE_PROPERTY = "UPDATE_PROPERTY"
  DELETE_INSPECTOR = "DELETE_INSPECTOR"
  RAISE_LAST_WIDGET = "RAISE_LAST_WIDGET"
  RAISE_ACTIVE_TOPLEVEL = "RAISE_ACTIVE_TOPLEVEL"
  
  def delete_wrapper(_sender, *args)
  		raise_action(DELETE_WRAPPER, TInspectorObj.new(_sender, *args))
  end
  
  def raise_last_widget(_sender, *args)
  		raise_action(RAISE_LAST_WIDGET, TInspectorObj.new(_sender, *args))
  end

  def raise_active_toplevel(_sender, *args)
  		raise_action(RAISE_ACTIVE_TOPLEVEL, TInspectorObj.new(_sender, *args))
  end
  
  def select(_sender, *args)
  		raise_action(SELECT_WRAPPER, TInspectorObj.new(_sender, *args))
  end 

  def add_require(_sender, *args)
  		raise_action(ADD_REQUIRE, TInspectorObj.new(_sender, *args))
  end
  
  def register(_sender, *args)
  		raise_action(REGISTER_WRAPPER, TInspectorObj.new(_sender, *args))
  end 
  
  def delete_inspector(_sender, *args)
    raise_action(DELETE_INSPECTOR, TInspectorObj.new(_sender, *args))
  end
  
  publish_action :raise_active_object
end

class WrapperContract < ArcadiaContract
  class TWrapperObj < TObj
  		attr_accessor	 :wrapper, :property_name, :property_family, :property_old_value, :property_new_value
  end
  WRAPPER_AFTER_CREATE="WRAPPER_AFTER_CREATE"
  PROPERTY_AFTER_UPDATE="PROPERTY_AFTER_UPDATE"
  UPDATE_PROPERTY="UPDATE_PROPERTY"
  def update_property(_sender, *args)
    raise_action(UPDATE_PROPERTY, TWrapperObj.new(_sender, *args))
  end
  def property_updated(_sender, *args)
    raise_event(PROPERTY_AFTER_UPDATE, TWrapperObj.new(_sender, *args))
  end
  def wrapper_created(_sender, *args)
    raise_event(WRAPPER_AFTER_CREATE, TWrapperObj.new(_sender, *args))
  end
end

class PaletteContract < ArcadiaContract
  class TPaletteObj < TObj
  		attr_accessor	 :parent, :x, :y
  end
  MAKE_SELECTED_WRAPPER = "MAKE_SELECTED_WRAPPER"
  def make_selected(_sender, *args)
    raise_action(MAKE_SELECTED_WRAPPER, TPaletteObj.new(_sender, *args))
  end
end



#class AeContractListener
#	def initialize(_arcadia)
#	  
#	end
#	def listen_on(_aeclip_name, _method_update_to_call=:update)
#	end
#	def update(_tobj)
#	end
#end
