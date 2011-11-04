#
#   ae-editor.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#
#   &require_dir_ref=../..
#   &require_omissis=#{Dir.pwd}/conf/arcadia.init

require 'tk'
require 'tktext'
require "#{Dir.pwd}/lib/a-tkcommons"
#require 'lib/a-commons' 
require "#{Dir.pwd}/lib/a-core"
require "#{Dir.pwd}/ext/ae-editor/lib/rbeautify"

class SourceTreeNode
  attr_reader :sons
  attr_reader :parent
  attr_reader :kind
  attr_accessor :rif, :rif_end, :label, :helptext, :sortable
  def initialize(parent=nil, kind='class', sortable=true)
    @sons = Array.new
    @parent = parent
    @kind = kind
    @sortable = sortable
    if @parent !=nil
      @parent.sons << self
    end
    yield(self) if block_given?
  end

  def <=> (other)
    if self.sortable && other.sortable
      self.label.strip <=> other.label.strip
    elsif !self.sortable
      -1
    elsif !other.sortable
      1
    end
  end

end


class SourceStructure
  attr_reader :root
  
  def initialize
    @root = SourceTreeNode.new(nil, 'root'){|_node|
      _node.rif= 'root'
      _node.label=''
    }
  end
  
  def node_by_line(_from_node, _line)
    _found_node = nil
    _begin = _from_node.rif.to_i
    _end = _from_node.rif_end.to_i
    if _line.to_i <= _end && _line.to_i >= _begin
      _found_node = _from_node
    else 
      _sons = _from_node.sons
      for inode in 0.._sons.length - 1
        _son = _sons[inode]
        _found_node = node_by_line(_son, _line)
        break if _found_node
      end
    end
    return _found_node
  end
  
  def deep_node_by_line(_from_node, _line, _found_node=nil)
    _begin = _from_node.rif.to_i
    _end = _from_node.rif_end.to_i
    if _line.to_i <= _end && _line.to_i >= _begin
      _found_node = _from_node
    end
    _sons = _from_node.sons
    for inode in 0.._sons.length - 1
      _son = _sons[inode]
      _found_node = deep_node_by_line(_son, _line, _found_node)
    end
    return _found_node
  end
  
  def class_node_by_line(_line)
    line_node = node_by_line(@root, _line)
    class_node = line_node
    while class_node != nil && class_node.kind != "class"
      class_node = class_node.parent
    end
    return class_node
  end
  
end

class CtagsSourceStructure < SourceStructure
  SUPPORTED_LANG = ['Ant','Asm','Asp','Awk','Basic','BETA','C','C++','C#','Cobol','DosBatch','Eiffel','Erlang','Flex','Fortran','HTML','Java','JavaScript','Lisp','Lua','Make','MatLab','OCaml','Pascal','Perl','PHP','Python','REXX','Ruby','Scheme','Sh','SLang','SML','SQL','Tcl','Tex','Vera','Verilog','VHDL','Vim','YACC']
  def initialize(_file, _ctags_string='ctags', _language=nil)
    super()
    @file = _file
    @ctags_string = _ctags_string
    @language = (_language.nil?)?nil:_language.capitalize
    @classes = Hash.new
    @last_root = @root
    @last_class_node = @root
    @last_node = @root    
    build_structure
  end

  def build_structure
    output = ctags
    output.each {|line|
      b1,brest =  line.split("/^")
      b2,b3 = brest.split('$/;"')
      name,file = b1.strip.split("\t")
      definition = b2.strip
      fields_raw = b3.strip.split("\t")
      fields = Hash.new
      fields_raw.each{|item|
        k,v=item.split(":")
        fields[k.strip]=v.strip if !k.nil? && !v.nil?
      }      
      if fields['class'] != nil
        parent = @classes[fields['class']]
      elsif fields['interface'] != nil
        parent = @classes[fields['interface']]
      elsif ['method','singleton method'].include?(fields['kind'])
        parent = @last_class_node
      else
        parent = @last_root
      end
      
      node = SourceTreeNode.new(parent, fields['kind'])
      node.label = name
      node.helptext = definition
      node.rif = fields['line']
      @last_node.rif_end = (node.rif.to_i-1).to_s
      
      if ['class','module','interface','package'].include?(fields['kind'])
        if fields['class'] != nil
          @classes["#{fields['class']}.#{name}"]=node
        else
          @classes[name]=node          
        end
        @last_class_node = node
      end
      node.sortable =  !['package','field'].include?(fields['kind'])
      @last_node = node
    }   
      
    
  end
  
  def ctags
    if @language != nil && SUPPORTED_LANG.include?(@language)
      @ctags_string = "#{@ctags_string} --language-force=#{@language}"
    end
    _cmd_ = "|#{@ctags_string} --fields=+a+f+m+i+k+K+n+s+S+t+z -uf - #{@file}"
    to_ret = ''
    begin
      open(_cmd_, "r"){|f| 
        to_ret = f.readlines
      }
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
    to_ret
  end
end


class RubyCtagsSourceStructure < CtagsSourceStructure
  attr_reader :injected_row
  
  def initialize(_file, _ctags_string='ctags')
    super(_file, _ctags_string, 'Ruby')
  end
  
  def scheletor_from_node(_node, _source='', _injected_source='', _injected_class='')
    _hinner_source = ''
    #_sons = _node.sons.sort
    _sons = _node.sons
    for inode in 0.._sons.length - 1
      _son = _sons[inode]
      if _son.kind == 'class'
         _hinner_source = "#{_hinner_source}#{_son.helptext}\n"
      elsif _son.kind == 'module'
         _hinner_source = "#{_hinner_source}#{_son.helptext}\n"
      elsif _son.kind == 'method' && _son.label != 'initialize'         
         _hinner_source = "#{_hinner_source}  def #{_son.label}\n"
         _hinner_source = "#{_hinner_source}  end\n"
      elsif _son.kind == 'singleton method'
         _hinner_source = "#{_hinner_source}  def #{_son.label}\n"
         _hinner_source = "#{_hinner_source}  end\n"
      end
      _hinner_source= scheletor_from_node(_son, _hinner_source, _injected_source, _injected_class)
    end
    _source = "#{_source}#{_hinner_source}" if _hinner_source.strip.length>0
    if _node.kind == 'class' && _node.label == _injected_class
      _source = "#{_source}  def initialize\n  #{_injected_source}  end\n"
      @injected_row = _source.split("\n").length-2
    end
    _source = "#{_source}end\n" if _node.kind == 'class' || _node.kind == 'module'
    _source
  end
end

class RubySourceStructure < SourceStructure
  attr_reader :injected_row

  def initialize(_source)
    super()
    parse_source(_source)
  end


  def parse_source(_source)
    _row = 1
    _liv = 0
    _livs = Array.new
    _livs[_liv]=@root
    _source.each_line{|line|
      line = "\s"+line.split("#")[0]+"\s"
      m = /[\s\n\t\;]+(module|class|def|if|unless|begin|case|for|while|do)[\s\n\t\;]+/.match("\s#{line}")
      if m
        index = m.post_match.strip.length - 1
        if m.post_match.strip[index,index]=='{'
          _row = _row +1
          next
        end
        _liv>=0? _liv = _liv + 1:_liv=1
        _pliv = _liv
        _parent = nil
        while (_parent == nil && _pliv>=0)
          _pliv = _pliv -1
          _parent = _livs[_pliv]
        end
        if _parent
          _helptext = m.post_match.strip
          _label = _helptext.split('<')[0]
          if _label == nil || _label.strip.length==0
            _label = _helptext
          end
          if (m[0].strip[0..4] == "class" && m.pre_match.strip.length==0)
            _kind = 'class'
            if m.post_match.strip[0..1]=='<<'
              hinner_class = true
            else
              hinner_class = false
            end
          elsif (m[0].strip[0..4] == "class" && m.pre_match.strip.length>0)
            _row = _row +1
            _liv = _liv - 1
            next
          elsif (m[0].strip[0..5] == "module" && m.pre_match.strip.length==0)
            _kind = 'module'
          elsif (m[0].strip[0..5] == "module" && m.pre_match.strip.length>0)
            _row = _row +1
            _liv = _liv - 1
            next
          elsif ((m[0].strip[0..4] == "begin")||(m[0].strip[0..3] == "case") ||(m[0].strip[0..4] == "while") || (m[0].strip[0..2] == "for") || (m[0].strip[0..1] == "do") || ((m[0].strip[0..1] == "if" || m[0].strip[0..5] == "unless") && m.pre_match.strip.length==0))
            _row = _row +1
            next
          elsif ((m[0].strip[0..1] == "if" || m[0].strip[0..5] == "unless") && m.pre_match.strip.length>0)
            _row = _row +1
            _liv = _liv - 1
            next
          elsif (m[0].strip[0..2] == "def" && m.pre_match.strip.length==0)
            _kind = 'method'
            if _label.include?(_parent.label + '.')
              _kind = 'singleton method'
            end
#          elsif (m[0].strip[0..10] == "attr_reader" && m.pre_match.strip.length==0)
#            _kind = 'KAttr_reader'
#            _liv = _liv - 1
#            _row = _row +1
          end
          
          if  _livs[_liv-1] && (_livs[_liv-1].kind != 'method' || (_livs[_liv-1].kind == 'method' && _kind == 'class' && hinner_class))
            SourceTreeNode.new(_parent, _kind){|_node|
              _node.label = _label
              _node.helptext = _helptext
              _node.rif = _row.to_s
              _livs[_pliv + 1]=_node
            }
          else
            SourceTreeNode.new(_livs[_liv-3], _kind){|_node|
              _node.label = _label
              _node.helptext = _helptext
              _node.rif = _row.to_s
              _livs[_pliv-1]=_node
            }
            _liv = _liv - 2
          end
        else
          _row = _row +1
          _liv = _liv - 1
          next
        end
      end
      m_end = /[\s\n\t\;]+end[\s\n\t\;]+/.match(line)
      if m_end
        if _livs[_liv]
          _livs[_liv].rif_end = _row
          #p "#{_livs[_liv].helptext} rif_end = #{_livs[_liv].rif_end}"
        end
        _liv = _liv - 1
      end
      _row = _row +1
    }
  end


  def scheletor_from_node(_node, _source='', _injected_source='', _injected_class='')
    _hinner_source = ''
    #_sons = _node.sons.sort
    _sons = _node.sons
    for inode in 0.._sons.length - 1
      _son = _sons[inode]
      if _son.kind == 'class'
         _hinner_source = "#{_hinner_source}class #{_son.helptext}\n"
      elsif _son.kind == 'module'
         _hinner_source = "#{_hinner_source}module #{_son.helptext}\n"
      elsif _son.kind == 'method' && _son.helptext != 'initialize'
         
         _hinner_source = "#{_hinner_source}  def #{_son.helptext}\n"
         _hinner_source = "#{_hinner_source}  end\n"
      elsif _son.kind == 'singleton method'
         _hinner_source = "#{_hinner_source}  def #{_son.helptext}\n"
         _hinner_source = "#{_hinner_source}  end\n"
      end
      _hinner_source= scheletor_from_node(_son, _hinner_source, _injected_source, _injected_class)
    end
    _source = "#{_source}#{_hinner_source}" if _hinner_source.strip.length>0
    if _node.kind == 'class' && _node.label == _injected_class
      _source = "#{_source}  def initialize\n  #{_injected_source}  end\n"
      @injected_row = _source.split("\n").length-2
    end
    _source = "#{_source}end\n" if _node.kind == 'class' || _node.kind == 'module'
    _source
  end


  def classies
  end
  def modules
  end
  def class_methods(_class)
  end
end


class SafeCompleteCode
  attr_reader :modified_row, :modified_col
  attr_reader :filter
  def initialize(_editor, _row, _col)
    @editor = _editor
    @source = _editor.text_value
    #@file = _file
    @row = _row.to_i
    @col = _col.to_i
    if _editor && _editor.has_ctags?
      tmp_file = _editor.create_temp_file
      begin
        @ss = RubyCtagsSourceStructure.new(tmp_file, _editor.ctags_string)
      ensure
        File.delete(tmp_file)
      end
    else
      @ss = RubySourceStructure.new(_source)
    end
    @filter=''
    @words = Array.new
    process_source
  end
  
#  def dot_trip(_var_name)
#    ret = "_class=#{_var_name}.class.name\n"
#    ret = ret +" _methods=#{_var_name}.methods\n"
#    ret = ret +"owner_on = Method.instance_methods.include?('owner')\n"
#    ret = ret + "_methods.each{|m|\n"
#    ret = ret + "meth = #{_var_name}.method(m)\n"
#    ret = ret +"if owner_on\n"
#    ret = ret +"_owner=meth.owner.name\n"
#    ret = ret +"else\n"
#    ret = ret +"meth_insp = meth.inspect\n"
#    ret = ret +"to_sub ='#<Method:\s'+_class\n"
#    ret = ret +"_owner=meth_insp.sub(to_sub,'').split('#')[0].strip.sub('(','').sub(')','')\n"
#    ret = ret +"_owner=_class if _owner.strip.length==0\n"
#    ret = ret +"end\n"
#    ret = ret + "if _owner != _class\n"
#    ret = ret + "print _owner+'#'+m+'#'+meth.arity.to_s+'\n'\n"
#    ret = ret +"else\n"
#    ret = ret + "print ''+'#'+m+'#'+meth.arity.to_s+'\n'\n"
#    ret = ret +"end\n"
#    ret = ret + "}\n"
#    ret = ret + "exit\n"
#    ret
#  end

  def dot_trip(_var_name)
    ret = "_class=#{_var_name}.class.name\n"
    ret = ret +"_methods=#{_var_name}.methods\n"
    ret = ret +"owner_on = Method.instance_methods.include?('owner')\n"
    ret = ret +"_methods.each{|m|\n"
    ret = ret +"meth = #{_var_name}.method(m)\n"
    ret = ret +"if owner_on\n"
    ret = ret +"  _owner=meth.owner.name\n"
    ret = ret +"else\n"
    ret = ret +"  meth_insp = meth.inspect\n"
    ret = ret +"  to_sub ='#<Method:\s'+_class\n"
    ret = ret +"  _owner=meth_insp.sub(to_sub,'').split('#')[0].strip.sub('(','').sub(')','')\n"
    ret = ret +"  _owner=_class if _owner.strip.length==0\n"
    ret = ret +"end\n"
    ret = ret +"if _owner != _class\n"
    ret = ret +'  print %Q{#{_owner}##{m}##{meth.arity.to_s}\n}'+"\n"
    ret = ret +"else\n"
    ret = ret +'  print %Q{##{m}##{meth.arity.to_s}\n}'+"\n"
    ret = ret +"end\n"
    ret = ret + "}\n"
    ret = ret + "exit\n"
    ret
  end
  
  def scope_trip
    ret = "ObjectSpace.each_object(Class){|o|\n"
    ret = ret + " o_name = o.name\n"
    ret = ret + " print '#'+o_name+'\n' if o_name && o_name.strip.length>0 \n"
    ret = ret + "}\n"
    ret = ret + dot_trip('self')
    ret
  end
  
  def declaration(_dec_line='')
    if _dec_line.include?('.new')
      pre, post = _dec_line.split('.new')
      dec_line_processed = "#{pre}.new"
      post.strip! if post
      if post && post[0..0]=='('
        k=0
        ch = '('
        while k < post.length && ch != ')'
          k = k+1
          ch=post[k..k]
        end
        if ch == ')'
          args = post[1..k-1]
          args_array = args.split(',')
          n_args = args_array.length
          if n_args > 0
            new_args = ''
            1.upto( n_args ){
               if new_args.length > 0
                 new_args = "#{new_args},"
               end
               new_args = "#{new_args}nil"
            }
            dec_line_processed = "#{dec_line_processed}(#{new_args})"
          end
        end
      end
    else
      dec_line_processed = _dec_line
    end
    dec_line_processed
  end
  
  def is_dot?
    @is_dot
  end

  def refresh_words
    @words.clear
    _re = /[\s\t\n"'(\[\{=><]#{@filter}[a-zA-Z0-9\-_]*/
    m = _re.match(@source)
    while m && (_txt=m.post_match)
      can = m[0].strip
      if  ['"','(','[','{',"'",'=','>','<'].include?(can[0..0])
        can = can[1..-1]
      end
      @words << can if can != @filter
      m = _re.match(_txt)
    end
  end

  def process_source
    @modified_source = ""
    @modified_row = @row
    @modified_col = @col
    source_array = @source.split("\n")
    #---------------------------------
    focus_line = source_array[@row-1]
    focus_line = focus_line[0..@col] if focus_line
    #-----
#    if ["\s",'(','{','['].include?(focus_line[-1..-1])
#      p "focus_line[-1..-1] e uguale a #{focus_line[-1..-1]}"
#      focus_line = ''
#    else
#      focus_line_split = focus_line.split
#      if focus_line_split && focus_line_split.length >0
#        old_focus_line_length = focus_line.length 
#        focus_line = focus_line_split[-1]
#        @col = @col - (old_focus_line_length = focus_line.length)
#      end
#    end
    #---
    focus_line = '' if focus_line.nil?
    focus_world = ''
    if focus_line && focus_line.strip.length > 0
      if focus_line[@col-1..@col-1] == '.'
        @is_dot=true
        focus_segment = focus_line[0..@col-2]
      elsif focus_line.include?('.')
        @is_dot=true
        focus_segment_array = focus_line.split('.')
        focus_segment = ''
        focus_segment_array[0..-2].each{|seg|
          if focus_segment.strip.length > 0
            focus_segment = focus_segment+'.'
          end
          focus_segment = focus_segment+seg
        }
        @filter = focus_word(focus_segment_array[-1].strip)
      else
        focus_segment = ''
        @filter = focus_word(focus_line[0..@col-1].strip)
      end
      focus_world= focus_word(focus_segment)
    end
    @class_node = @ss.class_node_by_line(@row)
    focus_line_to_evaluate = focus_line
    #---------------------------------
    @modified_source = "#{@modified_source}Dir.chdir('#{File.dirname(@editor.file)}')\n" if @editor.file
    @modified_row = @modified_row+1
    source_array.each_with_index{|line,j|
      # 0) if a comment I do not consider it
      if line.strip.length > 0 && line.strip[0..0]=='#'
        @modified_row = @modified_row-1
        m = /&require_dir_ref=[\s]*(.)*/.match(line)
        if m 
          require_dir_ref=line.split('&require_dir_ref=')[1].strip
          @modified_source = "#{@modified_source}Dir.chdir('#{require_dir_ref}')\n"
          @modified_row = @modified_row+1
        end   
        m = /&require_omissis=[\s]*(.)*/.match(line)
        if m 
          require_omissis=line.split('&require_omissis=')[1].strip
          @modified_source = "#{@modified_source}require \"#{require_omissis}\"\n"
          @modified_row = @modified_row+1
        end   
        
             
      # 1) includiano i require
      elsif line.strip.length>7 && (line.strip[0..7]=="require " || line.strip[0..7]=="require(")
        @modified_source = "#{@modified_source}#{line}\n"
        if line.strip[8..-1].include?("tk")
          @modified_source = "#{@modified_source}Tk.root.destroy if Tk && Tk.root\n"
        end
        #@modified_row = @modified_row+1
        #Arcadia.console(self, 'msg'=>"per require @modified_row=#{@modified_row}")
      # 2) includiano la riga da evaluare con un $SAFE 3
      elsif j.to_i == @row-1
        focus_line_to_evaluate = line
        break
      # 3) eliminiamo la riga
      else
        @modified_row = @modified_row-1
      end
      break if j.to_i >= @row - 1
    }
    if focus_line_to_evaluate
      # ricerchiamo una eventuale dichiarazione
        if focus_world && focus_world.strip.length > 0
          begin
            re = Regexp::new('[\s\n\t\;]('+focus_world.strip+')[\s\t]*=(.)*')
            source_array.each_with_index  do |line,j|
              #m = /[\s\n\t\;](#{focus_world})[\s\t]*=(.)*/.match(line)
              if j >= @row-1
                break
              else
                m = re.match("\s#{line}")
                if m
                  @dec_line = line
                  @class_dec_line_node = @ss.class_node_by_line(j+1)
                  break
                end
              end
            end
        		rescue Exception => e
#            Arcadia.console(self, 'msg'=>e.inspect, 'level'=>'error')
          end
          
        end

        if @class_node
          to_iniect = "$SAFE = 3\n"
          if @class_dec_line_node && @class_dec_line_node.label == @class_node.label
            to_iniect = "#{to_iniect}#{declaration(@dec_line)}\n"
          end
          if focus_world.length > 0
            to_iniect = "#{to_iniect}#{dot_trip(focus_world)}\n"
          else
            to_iniect = "#{to_iniect}#{scope_trip}\n"
          end
          #to_iniect = "#{to_iniect}#{focus_line}\n"
          to_iniect_class = @class_node.label
        else
          to_iniect = ''
          to_iniect_class = ''
        end

        ss_source = @ss.scheletor_from_node(@ss.root,'',to_iniect, to_iniect_class)
        ss_source_array = ss_source.split("\n")
        ss_len = ss_source_array.length
        if ss_len>0 && ss_source_array[0].strip != focus_line_to_evaluate.strip
          @modified_source = "#{@modified_source}#{ss_source}"
          if @class_node
            @modified_source = "#{@modified_source}#{@class_node.label.downcase} = #{@class_node.label}.new\n"
          end
        else
          ss_len = 0
          @class_node = nil
        end
        if @class_node
          @modified_row = @modified_row + @ss.injected_row
        else
          @modified_source = "#{@modified_source}$SAFE = 3\n"
          if @dec_line
            @modified_source = "#{@modified_source}#{declaration(@dec_line)}\n"
            @modified_row = @modified_row+1
          end
          #@modified_source = "#{@modified_source}_candidates=@candidates\n"
          if focus_world.length > 0
            @modified_source = "#{@modified_source}#{dot_trip(focus_world)}\n"
          else
            @modified_source = "#{@modified_source}#{scope_trip}\n"
          end
          #@modified_source = "#{@modified_source}@candidates=_candidates\n"

          
          #@modified_source = "#{@modified_source}#{focus_line}\n"
          @modified_row = @modified_row+1+ss_len
        end
    end
    if @filter.strip.length > 0 && !is_dot?
        refresh_words
    end

#    Arcadia.console(self, 'msg'=>@modified_source)
#    Arcadia.console(self, 'msg'=>"@modified_row=#{@modified_row}")
#    Arcadia.console(self, 'msg'=>"focus_line=#{focus_line}") if focus_line
#    Arcadia.console(self, 'msg'=>"focus_world=#{focus_world}") if focus_world
#    Arcadia.console(self, 'msg'=>"@filter=#{@filter}") if @filter
#    Arcadia.console(self, 'msg'=>"@dec_line=#{@dec_line}") if @dec_line
#    Arcadia.console(self, 'msg'=>"declaration(@dec_line)=#{declaration(@dec_line)}") if @dec_line
  end

  def focus_word(focus_segment)
      focus_world = ''
      char = focus_segment[-1..-1]
      while [")","]","}"].include?(char) 
        char=focus_segment[-2..-2]
        focus_segment = focus_segment[0..-2]
      end
      j = focus_segment.length - 1
      while !["\s","\t",";",",","(","[","{",">"].include?(char) && j >= 0
        focus_world = "#{char}#{focus_world}"
        j=j-1
        char = focus_segment[j..j]
      end
      focus_world
  end
  
  def candidates(_show_error = false)
    temp_file = create_modified_temp_file(@editor.file)
    begin
      Arcadia.is_windows??ruby='rubyw':ruby=Arcadia.ruby
      _cmp_s = "|#{ruby} '#{temp_file}'"
      _ret = nil
      open(_cmp_s,"r") do  |f|
        _ret = f.readlines.collect!{| line | 
          #line.chomp
          line.strip
        } 
      end
      if @filter.strip.length > 0 && !is_dot?
        @words.each{|w| 
          if !(_ret.include?(w) || _ret.include?("##{w}")) 
            _ret << w
          end
        }
      end
      _ret.sort
    rescue Exception => e
      Arcadia.runtime_error(e)
      #Arcadia.console(self, 'msg'=>e.to_s, 'level'=>'error')
    ensure
      File.delete(temp_file) if File.exist?(temp_file)
    end
  end

  def create_modified_temp_file(_base_file=nil)
    if _base_file
    File.basename(_base_file)
      _file = File.join(File.dirname(_base_file),'~~'+File.basename(_base_file))
    else
      _file = File.join(Arcadia.instance.local_dir,'~~buffer')
    end
    f = File.new(_file, "w")
    begin
      if f
        f.syswrite(@modified_source)
      end
    ensure
      f.close unless f.nil?
    end
    _file
  end

end


#class TkArcadiaText < TkText
#  
#  def insert(insert, chars,*tags)
#    super(insert, chars,*tags)
#    self.modified=true
#   # event_generate("<Modified>")
#  end
#end


class TkTextListBox < TkText
  def initialize(parent=nil, keys={})
    super(parent, keys)
    wrap  'none'
    tag_configure('selected','background' =>Arcadia.conf('hightlight.sel.background'),'borderwidth'=>1, 'relief'=>'raised')
    tag_configure('class', 'foreground' => Arcadia.conf('hightlight.sel.foreground'))
    @count = 0
    @selected = -1
    self.bind_append('KeyPress'){|e| key_press(e)}
    self.bind_append('KeyRelease'){|e| key_release(e)}
    self.bind_append("ButtonPress-1", proc{|x,y| button_press(x,y)}, "%x %y")
  end  
  

  def insert(index, chars, *tags)
    super(index, chars, *tags)
  end  
  
  def add(chars)
    meth_str, class_str = chars.split('-')
    if meth_str && meth_str.strip.length>0 && class_str
      insert('end', "#{meth_str}")
      insert('end', "-#{class_str}\n", 'class')
    elsif meth_str && meth_str.strip.length==0 && class_str
      insert('end', "-#{class_str}\n")
    else
      insert('end', "#{chars}\n")
    end
    @count = @count+1
  end  
  
  def clear
    delete('1.0','end')
    @count = 0
  end

  def button_press(x,y)
    _index = self.index("@#{x},#{y}")
    _line = _index.split('.')[0].to_i
    self.select(_line)
  end
  
  def key_press(_e)
      case _e.keysym
        when 'Up'
          if @selected > 0
            select(@selected-1)
          end
        when 'Down'
          if @selected < @count
            select(@selected+1)
          end
      end
  end  

  def key_release(_e)
      case _e.keysym
        when 'Next','Prior'
         index = self.index('@0,0')
         line = index.split('.')[0].to_i
         select(line)
      end
  end  

  def selected_line
    if @selected > 0
      self.get("#{@selected}.0", "#{@selected}.0 lineend")
    end
  end

  def select(_row)
    self.tag_remove('selected', '1.0', 'end')
    _start_index = "#{_row.to_s}.0"
    _end_index = "#{_start_index} +1 lines linestart"
    self.tag_add('selected', _start_index, _end_index)
    self.set_insert(_start_index)
    self.see(_start_index)
    @selected = _row
  end

end

class AgEditorOutlineToolbar
  attr_accessor :sync
  def initialize(_controller)
    @controller = _controller
    @panel = @controller.main_instance.frame(1).root.add_panel(@controller.main_instance.frame(1).name, "sync");
    @cb_sync = TkCheckButton.new(@panel, Arcadia.style('checkbox').update('background'=>@panel.background)){
      text  'Sync'
      justify  'left'
      indicatoron 0
      offrelief 'flat'
      image Arcadia.image_res(SYNC_GIF)
      pack
    }        
    Tk::BWidget::DynamicHelp::add(@cb_sync, 
      'text'=>'Link open editors with content in the Navigator')

    do_check = proc {
      if @cb_sync.cget('onvalue')==@cb_sync.cget('variable').value.to_i
        sync_on
      else
        sync_off
      end
    }
    @sync = false
    @cb_sync.command(do_check)
  end

  def sync_on
    @sync = true
    e = @controller.active_instance.raised
    if e
      e.outline.select_without_event(e.outline.last_row) if e.outline.last_row
    end
  end

  def sync_off
    @sync = false
  end

  def is_sync_on?
    @sync
  end

end

class AgEditorOutline
  attr_reader :last_row
  attr_reader :tree_exp
  attr_reader :ss
  def initialize(_editor, _frame, _bar, _lang=nil)
    @editor = _editor
    @frame = _frame
    @bar = _bar
    @lang = _lang
    initialize_tree(_frame)
  end

  def update_row(_row=0)
    @last_row=_row
    if @bar.is_sync_on?
      select_without_event(_row)
    end
  end
  
  # I think this is "if synced expand out the outline for the current selection"
  def shure_select_node(_node)
    return if @selecting_node
    #return if @tree_exp.exist?(_node.rif)
    @selecting_node = true
    _proc = @tree_exp.selectcommand
    @tree_exp.selectcommand(nil)
    begin
      @tree_exp.selection_clear
      @tree_exp.selection_add(_node.rif)
      @opened = false
      to_open = @last_open_node
      parent = _node.parent
      while !parent.nil? && parent.rif != 'root'
        @tree_exp.open_tree(parent.rif, false)
        @opened = to_open==parent.rif || @opened
        @last_open_node=parent.rif
        parent = parent.parent
      end

      @tree_exp.close_tree(to_open) if to_open && !@opened

      @tree_exp.see(_node.rif)
      
    ensure
      @tree_exp.selectcommand(_proc)
      @selecting_node = false
    end
    @tree_exp.call_after_next_show_h_scroll(proc{Tk.update;@tree_exp.see(_node.rif)})    
  end

  def select_without_event(_line)
    if @ss
      _node=@ss.deep_node_by_line(@ss.root, _line)
      if _node && @tree_exp.exist?(_node.rif) && _node.rif!='root'
        shure_select_node(_node)
      end
    end
  end

  def initialize_tree(_frame)
    _tree_goto = proc{|_self|
      sync_val = @bar.sync
      @bar.sync=false
      begin
        #_line = _self.selection_get[0]
        _line = _self.selected
        _index =_line.to_s+'.0'
        _hinner_text = @tree_exp.itemcget(_line,'text').strip
        _editor_line = @editor.text.get(_index, _index+ '  lineend')
        if !_editor_line.include?(_hinner_text)
          Arcadia.console(self, 'msg'=>"... rebuild tree \n")
          if @tree_thread && @tree_thread.alive?
            @tree_thread.exit # kill the old tree
          end
          @tree_thread = Thread.new{
            build_tree(_line)
            Tk.update
          }
          #_line = _self.selection_get[0]
          _line = _self.selected
          _index =_line.to_s+'.0'
        end
        @editor.text.set_focus
        @editor.text.see(_index)
        @editor.text.tag_remove('selected','1.0','end')
        @editor.text.tag_add('selected',_line.to_s+'.0',(_line+1).to_s+'.0')
      ensure
        @bar.sync = sync_val
      end
    }
    @tree_exp = BWidgetTreePatched.new(_frame, Arcadia.style('treepanel')){
      showlines false
      deltay 18
      dragenabled true
      selectcommand proc{ _tree_goto.call(self) } 
      crosscloseimage  Arcadia.image_res(ARROWRIGHT_GIF)      
      crossopenimage  Arcadia.image_res(ARROWDOWN_GIF)
    }
    @tree_exp.extend(TkScrollableWidget)
    self.show
    pop_up_menu_tree
  end

  def destroy
    #@tree_scroll_wrapper.destroy
    @tree_exp.hide
    @tree_exp.destroy
    Tk.update
  end
  
  def show
    #@tree_scroll_wrapper.show(0,26)
    @tree_exp.show(0,0)
    Tk.update
  end

  def hide
    @tree_exp.hide
    #@tree_scroll_wrapper.hide
  end

  def build_tree_from_node(_node, _label_match=nil)
    @image_class = Arcadia.image_res(TREE_NODE_CLASS_GIF)
    @image_module =  Arcadia.image_res(TREE_NODE_MODULE_GIF)
    @image_method =  Arcadia.image_res(TREE_NODE_METHOD_GIF)
    @image_singleton_method =  Arcadia.image_res(TREE_NODE_SINGLETON_METHOD_GIF)
    
    _sorted_sons = _node.sons.sort 
    for inode in 0.._sorted_sons.length - 1
      _son = _sorted_sons[inode]
      if _son.kind == 'class'
          _image = @image_class
      elsif _son.kind == 'module'
          _image = @image_module
      elsif _son.kind == 'method' || _son.kind == 'procedure'
          _image = @image_method
      elsif _son.kind == 'singleton method'
          _image = @image_singleton_method
      end
      @tree_exp.insert('end', _son.parent.rif ,_son.rif, {
        'text' =>  _son.label ,
        'helptext' => _son.helptext,
        #'font'=>$arcadia['conf']['editor.explorer_panel.tree.font'],
        'image'=> _image
      }.update(Arcadia.style('treeitem'))
      )
      if (_label_match) && (_label_match.strip == _son.label.strip)
        @selected = _son
      end
      build_tree_from_node(_son, _label_match) # recursion -- if there are no sons it will do nothing
    end
  end

  def build_tree(_sel=nil)
    #Arcadia.console(self,"msg"=>"build for #{@file}")
    if _sel
      _label_sel = @tree_exp.itemcget(_sel,'text')
    end
    
    #clear tree
    begin
      @tree_exp.delete(@tree_exp.nodes('root'))
    rescue Exception
      # workaround on windows
      @tree_exp.delete(@tree_exp.nodes('root'))
    end
    
    
    _txt = @editor.text.get('1.0','end')
    if @editor.has_ctags?
      if @editor.file
        @ss = CtagsSourceStructure.new(@editor.file, @editor.ctags_string)
      else
        tmp_file = @editor.create_temp_file
        begin
          @ss = CtagsSourceStructure.new(tmp_file, @editor.ctags_string, @lang)
        ensure 
          File.delete(tmp_file)
        end
      end
    else
      @ss = RubySourceStructure.new(_txt)
    end
    @selected = nil
    build_tree_from_node(@ss.root, _label_sel)
    if @selected
      @tree_exp.selection_add(@selected.rif)
      @tree_exp.open_tree(@selected.parent.rif) if @selected.parent.rif != 'root'
      @tree_exp.see(@selected.rif)
    end
  end
  
  def pop_up_menu_tree
    @pop_up_tree = TkMenu.new(
      :parent=>@tree_exp,
      :tearoff=>0,
      :title => 'Menu tree'
    )
    @pop_up_tree.extend(TkAutoPostMenu)
    @pop_up_tree.configure(Arcadia.style('menu'))
    #Arcadia.instance.main_menu.update_style(@pop_up_tree)
    @pop_up_tree.insert('end',
      :command,
      :label=>'Rebuild',
      :hidemargin => false,
      :command=> proc{build_tree}
    )
    @tree_exp.areabind_append("Button-3",
      proc{|x,y|
        _x = TkWinfo.pointerx(@tree_exp)
        _y = TkWinfo.pointery(@tree_exp)
        @pop_up_tree.popup(_x,_y)
      },
    "%x %y")
  end
  
end

class AgEditor
  attr_accessor :file
  attr_accessor :line_numbers_visible
  attr_accessor :id
  attr_reader :read_only 
  attr_reader :page_frame
  attr_reader :text, :root
  attr_reader :highlighting
  attr_reader :last_tmp_file
  attr_reader :lang
  attr_reader :file_info  
  attr_reader :outline  
  def initialize(_controller, _page_frame)
    @controller = _controller
    @page_frame = _page_frame
    @set_mod = false
    @modified_from_opening=false
    @font = Arcadia.conf('edit.font')
    @font_bold = "#{Arcadia.conf('edit.font')} bold"
    @font_metrics = TkFont.new(@font).metrics
    @font_metrics_bold = TkFont.new(@font_bold).metrics
    @highlighting = false
    @classbrowsing = false
    @codeinsight = false
    @find = @controller.get_find
    @read_only=false
    @loading=false
    @tabs_show = false
    @spaces_show = false
    @line_numbers_visible = @controller.conf('line-numbers') == 'yes'
    @id = -1
    @file_info = Hash.new
  end

  def modified_from_opening?
    @modified_from_opening
  end
  
  def show_line_numbers
    if !@line_numbers_visible
      #@fm1.hide_right
      @fm1.show_left
      @line_numbers_visible = true
      do_line_update
    end
  end
  
  def hide_line_numbers
    if @line_numbers_visible
      @fm1.hide_left
      @line_numbers_visible = false
    end
  end
  
  def show_hide_line_numbers
    if @line_numbers_visible
      hide_line_numbers
    else
      show_line_numbers
    end
  end
  
  def xy_insert
    _index_now = @text.index('insert')
    _rx, _ry, _width, _heigth = @text.bbox(_index_now);
    _x = _rx + TkWinfo.rootx(@text)  
    _y = _ry + TkWinfo.rooty(@text)  + @font_metrics[2][1]
    _xroot = _x - TkWinfo.rootx(Arcadia.instance.layout.root)  
    _yroot = _y - TkWinfo.rooty(Arcadia.instance.layout.root)  
    return _xroot, _yroot
  end
  

  def initialize_text(_frame)
    @text = TkArcadiaText.new(_frame, Arcadia.style('text')){|j|
      wrap  'none'
      undo true
#      insertofftime 200
#      insertontime 200
#      highlightthickness 0
#      insertwidth 3
      exportselection true
      autoseparators true
      padx 0
      tabs $arcadia['conf']['editor.tabs']
    }
    
    _self_editor = self
    class << @text
      attr_accessor :editor
      def tag_adds(tag, *args)
        tk_send_without_enc('tag', 'add', _get_eval_enc_str(tag), 
                            *args.flatten)
        self
      end
      
      def do_upper_case
        @editor.do_upper_case if @editor
      end
    
      def do_lower_case
        @editor.do_lower_case if @editor
      end
    end
    @text.editor = self
    #do_tag_configure_global('debug')
    @text.tag_configure('eval','foreground' => 'yellow', 'background' =>'red','borderwidth'=>1, 'relief'=>'raised')
    @text.tag_configure('errline','borderwidth'=>1, 'relief'=>'groove')
    #@text.tag_configure('debug', 'background' =>'#b9c6d9', 'borderwidth'=>1 ,'relief'=>'raise')
    @buffer = text_value
    pop_up_menu
    @text.extend(TkScrollableWidget).show
    @text.extend(TkInputThrow)
    begin
      @text_cursor = @text.cget('cursor')
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
      #p "RuntimeError : #{e.message}"
    end
  end

  def create_temp_file
    if @file
      n=0
      while File.exist?("#{File.join(File.dirname(@file),'~~'+File.basename(@file))}#{'_'*n}")
        n+=1
      end
      _file = "#{File.join(File.dirname(@file),'~~'+File.basename(@file))}#{'_'*n}"
#      while File.exist?("~~#{@file}#{n*'_'}")
#        n+=1
#      end
#      _file = "~~#{@file}#{n*'_'}"
    else
      if @lang == 'java'
        m = Regexp::new(/(class[\s][\s]*)[A-Za-z0-9_]*[\s]*/).match(text_value)
        if m && m.length > 0
          a = m[0].split
          if a && a.length > 1            
            tmp_dir = "~~#{a[1].strip.downcase}"
            full_tmp_dir = File.join(Arcadia.instance.local_dir,tmp_dir) 
            Dir.mkdir(full_tmp_dir) if !File.exist?(full_tmp_dir)
            basename = File.join(tmp_dir,"#{a[1].strip}.java")            
          end
        end
        basename = "~~buffer.java" if basename.nil?        
      else
        n=0
        while File.exist?(File.join(Arcadia.instance.local_dir,"~~buffer#{n}"))
          n+=1
        end
        basename = "~~buffer#{n}"
      end
      _file = File.join(Arcadia.instance.local_dir, basename)
    end
    f = File.new(_file, "w")
    begin
      if f
        f.syswrite(text_value)
      end
    ensure
      f.close unless f.nil?
    end
    @last_tmp_file = _file
    _file
  end

  def create_temp_file_for_completion(_row)
    _custom_text = ""
    text_value_array = text_value.split("\n")
    text_value_array.each_with_index{|line,j|
      # 1) includiano i require e la riga da includere
      if line.include?("require") || j.to_i == _row.to_i-1
        _custom_text = "#{_custom_text}#{line}\n"
        #p "inserisco=>#{line} alla riga=>#{j}"
      elsif j.to_i == _row.to_i-2
        _custom_text = "#{_custom_text}$SAFE = 3\n"
      else
        _custom_text = "#{_custom_text}\n"
        #p "inserisco=>blank alla riga=>#{j}"
      end
      #p "riga:#{j}"
      break if j.to_i >= _row.to_i - 1
    }
    Arcadia.console(self, 'msg'=>_custom_text)

    if @file
      _file = "#{File.join(File.dirname(@file),'~~'+File.basename(@file))}"
    else
      _file = File.join(Arcadia.instance.local_dir,'~~buffer')
    end
    f = File.new(_file, "w")
    begin
      if f
        f.syswrite(_custom_text)
      end
    ensure
      f.close unless f.nil?
    end
    _file
  end

  def complete_code_begin
    @n_complete_task = 1
    @text.configure('cursor'=> 'hand2')
    #disactivate_key_binding
  end

  def complete_code_end
    @text.configure('cursor'=> @text_cursor)
    #activate_key_binding
    @n_complete_task = 0
  end


  def complete_code
    @do_complete = @do_complete && @controller.accept_complete_code
    if @do_complete
      line, col = @text.index('insert').split('.')
      mss = SafeCompleteCode.new(self, line.to_i, col.to_i)
      candidates = mss.candidates
      raise_complete_code(candidates, line.to_s, col.to_s, mss.filter) if candidates && candidates.length > 0 
    end
  end
  
  def arity_to_str(_arity=0)
    ret = ''
    jolly_args = _arity < 0
    if jolly_args 
      _arity = _arity.abs - 1
    end
    j = _arity
    while j > 0
      if ret.strip.length > 0
        ret = "#{ret},"
      end
      ret = "#{ret}arg#{_arity-j+1}"
      j = j-1
    end
    if jolly_args 
      if ret.strip.length > 0
        ret = "#{ret},"
      end
      ret = "#{ret}*"
    end    
    ret    
  end


  def raise_complete_code(_candidates, _row, _col, _filter='')    
    @raised_listbox_frame.destroy if @raised_listbox_frame != nil
    _index_call = _row+'.'+_col
    _index_now = @text.index('insert')
    if _index_call == _index_now 
      _target = @text.get('insert - 1 chars wordstart','insert')
      if _target.strip == '('
        _target = @text.get('insert - 2 chars wordstart','insert')
      else
        _line = @text.get("insert linestart",'insert lineend')
        ei = _line.index(_target)
        if !ei.nil?
          j=1
          pre_target = ''
          while ei-j>=0 && !["\s",'(','[','{'].include?(_line[ei-j..ei-j])
            pre_target = _line[ei-j..ei-j] + pre_target
            j+=1
          end
          _target= pre_target + _target
        end       
      end
      
      if _target.strip.length > 0 && _target != '.'
        extra_len = _target.length.+@
        _begin_index = _index_now<<' - '<<extra_len.to_s<<' chars'
        @text.tag_add('sel', _begin_index, _index_now)
      else
        _begin_index = _index_now
        extra_len = 0
      end
      if _filter.length > 0 
        begin_index_for_delete = "insert - #{_filter.length}chars"
      else
        for_delete = @text.get(_begin_index,"insert")
        if for_delete && ['.','(','[','{','=','<','!','>'].include?(for_delete.strip[-1..-1])
          begin_index_for_delete = "insert"
        elsif for_delete && for_delete.include?('.')
          begin_index_for_delete = "insert - #{for_delete.split('.')[-1].length}chars"
        else
          begin_index_for_delete = _begin_index
        end 
      end

      if _candidates.length >= 1 
          _rx, _ry, _width, heigth = @text.bbox(_begin_index);
          _x = _rx + TkWinfo.rootx(@text)  
          _y = _ry + TkWinfo.rooty(@text)  + @font_metrics[2][1]
          _xroot = _x - TkWinfo.rootx(Arcadia.instance.layout.root)  
          _yroot = _y - TkWinfo.rooty(Arcadia.instance.layout.root)  
          
          _max_height = TkWinfo.screenheight(Arcadia.instance.layout.root) - _y - 5
          self.complete_code_begin
          
      #    @raised_listbox_frame = TkResizingTitledFrame.new(Arcadia.instance.layout.root)
          @raised_listbox_frame = TkFrame.new(Arcadia.instance.layout.root, {
            :padx=>"1",
            :pady=>"1",
            :background=> Arcadia.conf("foreground")
          })
          
          @raised_listbox = TkTextListBox.new(@raised_listbox_frame, {
            :takefocus=>true}.update(Arcadia.style('listbox')))
          _char_height = @font_metrics[2][1]
          _width = 0
          _docs_entries = Hash.new
          _item_num = 0
          _update_list = proc{|_in|
              _in.strip!
              @raised_listbox.clear
              _length = 0
              _candidates.each{|value|
                _doc = value.strip
                _class, _key, _arity = _doc.split('#')
                if _key && _arity
                  args = arity_to_str(_arity.to_i)
                  if args.length > 0
                    _key = "#{_key}(#{args})"
                  end
                end
                
                if _key && _class && _key.strip.length > 0 && _class.strip.length > 0 
                  _item = "#{_key.strip} - #{_class.strip}"
                elsif _key && _key.strip.length > 0
                  _item = "#{_key.strip}"
                else
                  _key = "#{_doc.strip}"
                  _item = "#{_doc.strip}"
                end
                if _in.nil? || _in.strip.length == 0 || _item[0.._in.length-1] == _in 
                #|| _item[0.._in.length-1].downcase == _in
                  _docs_entries[_item]= _doc
         #         @raised_listbox.insert('end', _item)
                  @raised_listbox.add(_item)
                  _temp_length = _item.length
                  _length = _temp_length if _temp_length > _length 
                  _item_num = _item_num+1 
                  _last_valid_key = _key
                end
              }
              _width = _length*8
              @raised_listbox.select(1)
 #             p "_update_list end-->#{Time.new}"

              Tk.event_generate(@raised_listbox, "1") if TkWinfo.mapped?(@raised_listbox)
          }
          

          _insert_selected_value = proc{
            #_value = @raised_listbox.get('active').split('-')[0].strip
            if @raised_listbox.selected_line && @raised_listbox.selected_line.strip.length>0
              _value = @raised_listbox.selected_line.split('-')[0].strip
              @raised_listbox_frame.grab("release")
              @raised_listbox_frame.destroy
              #_menu.destroy
              @text.focus
              @text.delete(begin_index_for_delete,'insert')

              # workaround for @ char
              _value = _value.strip
              if _value[0..0] !=_target[0..0] && _value[1..1] == _target[0..0]
                _value = _value[1..-1]
              end
              @text.insert('insert',_value)
              complete_code_end
              
              _to_search = 'arg1'
              _argindex = @text.search(_to_search,_begin_index)
              if !(_argindex && _argindex.length>0)
                _to_search = '*'
                _argindex = @text.search(_to_search,_begin_index)
              end
              if _argindex && _argindex.length>0
                _argrow, _argcol = _argindex.split('.')
                if _argrow.to_i == _row.to_i
                  _argindex_sel_end = _argrow.to_i.to_s+'.'+(_argcol.to_i+_to_search.length).to_i.to_s
                  @text.tag_add('sel', _argindex,_argindex_sel_end)
                  @text.set_insert(_argindex)
                end
              end
            end
            
            Tk.callback_break
          }
          _update_list.call(_filter)
          if _item_num == 0
            @raised_listbox_frame.destroy
            self.complete_code_end
            return
          elsif _item_num == 1 
            _insert_selected_value.call
            return
          end
          _width = _width + 30
          #_height = (candidates.length+1)*_char_height
          _height = 15*_char_height
          _height = _max_height if _height > _max_height
          
          _buffer = @text.get(_begin_index, 'insert')
          _buffer_ini_length = _buffer.length
          @raised_listbox_frame.place('x'=>_xroot,'y'=>_yroot, 'width'=>_width, 'height'=>_height)
          @raised_listbox.extend(TkScrollableWidget).show(0,0) 
          @raised_listbox.focus
          #@raised_listbox.activate(0)
          @raised_listbox.select(1)
          @raised_listbox_frame.grab("set")
       #   Tk.event_generate(@raised_listbox, "1")
       
       
          @raised_listbox.bind_append("Double-ButtonPress-1", 
            proc{|x,y| 
              _index = @raised_listbox.index("@#{x},#{y}")
              _line = _index.split('.')[0].to_i
              @raised_listbox.select(_line)
              _insert_selected_value.call
                }, "%x %y")
          @raised_listbox.bind_append('Shift-KeyPress'){|e|
            # todo
            case e.keysym
              when 'parenleft'
                @text.insert('insert','(')
                _buffer = _buffer + '('
                _item_num = 0
                _update_list.call(_buffer)
                if _item_num == 1
                  _insert_selected_value.call
                end
                Tk.callback_break
              when 'A'..'Z','equal','greater'
                if e.keysym == 'equal'
                  ch = '='
                elsif e.keysym == 'greater'
                  ch = '>'
                else
                  ch = e.keysym
                end
                @text.insert('insert',ch)
                _buffer = _buffer + ch
                _update_list.call(_buffer)
                Tk.callback_break
              else
                if e.keysym.length > 1 
                  p ">#{e.keysym}<"
                  Tk.callback_break
                end
            end
          }
          @raised_listbox.bind_append('KeyPress'){|e|
            case e.keysym
              when 'Escape'
                @raised_listbox.grab("release")
                @raised_listbox_frame.destroy
                complete_code_end
                @text.focus
                #_menu.destroy
                Tk.callback_break
#                when 'Return'
#                  _insert_selected_value.call
              when 'F1'
                _key = @raised_listbox.selected_line.split('-')[0].strip
                _x, _y = xy_insert
                Arcadia.process_event(DocCodeEvent.new(self, 'doc_entry'=>_docs_entries[_key], 'xdoc'=>_x, 'ydoc'=>_y))
                #EditorContract.instance.doc_code(self, 'doc_entry'=>_docs_entries[_key], 'xdoc'=>_x, 'ydoc'=>_y)
              when 'a'..'z','less','space'
                if e.keysym == 'less'
                  ch = '<'
                elsif e.keysym == 'space'
                  ch = ''
                else
                  ch = e.keysym
                end
                @text.insert('insert',ch)
                _buffer = _buffer + ch
                _update_list.call(_buffer)
                Tk.callback_break
              when 'BackSpace'
                if _buffer.length > _buffer_ini_length
                  @text.delete("#{_begin_index} + #{_buffer.length-1} chars" ,'insert')
                  _buffer = _buffer[0..-2]
                  Tk.update
                  _update_list.call(_buffer)
                  Tk.callback_break
                end
              when 'Next', 'Prior'
              else
                Tk.callback_break
            end
          }
          @raised_listbox.bind_append('KeyRelease'){|e|
            case e.keysym
              when 'Return'
                _insert_selected_value.call
            end
          }
        elsif _candidates.length == 1 && _candidates[0].length>0
          @text.delete(begin_index_for_delete,'insert');
          @text.insert('insert',_candidates[0].split[0])
          complete_code_end
        end
    end
  end
   
  
  def activate_complete_code_key_binding
    @n_complete_task = 0
    # key binding for complete code
    @text.bind_append("Control-KeyPress"){|e|
      case e.keysym
      when 'space'
        if @n_complete_task == 0
          @do_complete = true
          complete_code
        end
      end
    }
    
    @text.bind_append("KeyPress"){|e|
      if e.keysym == "Escape"
        if @n_complete_task == 0
          @do_complete = true
          complete_code
        end
      else
        @do_complete = false
      end
    }    

    @text.bind_append("KeyRelease"){|e|
      case e.keysym
        when 'period'
          _focus_line = @text.get('insert linestart','insert')
          if _focus_line.strip[0..0] != '#'
            Thread.new do
              @do_complete = true
              sleep(1)
              if @do_complete && @n_complete_task == 0
                complete_code
              end
            end
          end
      end
    }

  end
  
  #
  # setup all key bindings (normal, +control, etc)
  #
  def activate_key_binding
    activate_complete_code_key_binding if @is_ruby

    @text.bind_append("Control-KeyPress"){|e|
      case e.keysym
      when 'o'  
        if @file
          _dir = File.dirname(@file)
        else
          _dir = MonitorLastUsedDir.get_last_dir
        end
        Arcadia.process_event(OpenBufferEvent.new(self,'file'=>Tk.getOpenFile('initialdir'=>_dir)))
        break
      when 's'
        save
        #Tk.callback_break
      when 'f'
        find
      when 'egrave'
        @text.insert('insert',"{")
      when 'plus'
        @text.insert('insert',"}")
      when 'g'
        Arcadia.process_event(GoToLineBufferEvent.new(self))
      when 'n'
        Arcadia.process_event(NewBufferEvent.new(self))
      when 'w'
        Arcadia.process_event(CloseCurrentTabEvent.new(self))
      end
    }

    @text.bind_append("Control-Shift-KeyPress"){|e|
      case e.keysym
      when 'I'
        _r = @text.tag_ranges('sel')
        _row_begin = _r[0][0].split('.')[0].to_i
        _row_end = _r[_r.length - 1][1].split('.')[0].to_i
        n_space = $arcadia['conf']['editor.tab-replace-width-space'].to_i
        if n_space > 0
          suf = "\s"*n_space
        else
          suf = "\t"
        end

        for _row in _row_begin..._row_end
          @text.insert(_row.to_s+'.0',suf)
        end
      when 'U'
        decrease_indent
      when 'C'
        _r = @text.tag_ranges('sel')
        _row_begin = _r[0][0].split('.')[0].to_i
        _row_end = _r[_r.length - 1][1].split('.')[0].to_i

        for _row in _row_begin..._row_end
          if @text.get(_row.to_s+'.0',_row.to_s+'.1') == "#"
            @text.delete(_row.to_s+'.0',_row.to_s+'.1')
          else
            @text.insert(_row.to_s+'.0',"#")
          end
          #rehighlightline(_row) if @highlighting
        end
        rehighlightlines(_row_begin, _row_end) if @highlighting
      when 'F'
        Arcadia.process_event(AckInFilesEvent.new(self))
      end
    }
    
    @text.bind_append("KeyPress"){|e|
      @last_keypress = e.keysym
      case e.keysym
#      when 'BackSpace'
#        _index = @text.index('insert')
#        _row, _col = _index.split('.')
#        rehighlightlines(_row.to_i,_row.to_i) if @highlighting
#      when 'Delete'
#        _index = @text.index('insert')
#        _row, _col = _index.split('.')
#        rehighlightlines(_row.to_i, _row.to_i) if @highlighting
      when 'F5'
        run_buffer
      when 'F3'
        @find.do_find_next
      when 'F1'
        line, col = @text.index('insert').split('.')
        _x, _y = xy_insert
        _file = create_temp_file
        begin
          Arcadia.process_event(DocCodeEvent.new(self, 'file'=>_file, 'row'=>line.to_s, 'col'=>col.to_s, 'xdoc'=>_x, 'ydoc'=>_y))
        ensure
          File.delete(_file) 	if File.exist?(_file)
        end
        #EditorContract.instance.doc_code(@controller, 'file'=>_file, 'line'=>line.to_s, 'col'=>col.to_s, 'xdoc'=>_x, 'ydoc'=>_y)
      when 'Tab'
        n_space = $arcadia['conf']['editor.tab-replace-width-space'].to_i
        _r = @text.tag_ranges('sel')
        if _r && _r[0]
          _row_begin = _r[0][0].split('.')[0].to_i
          _row_end = _r[_r.length - 1][1].split('.')[0].to_i
          if n_space > 0
            suf = "\s"*n_space
          else
            suf = "\t"
          end
          for _row in _row_begin..._row_end
            @text.insert(_row.to_s+'.0', suf)
          end
          break
        elsif n_space > 0
          @text.insert('insert', "\s"*n_space)
          break
        end
      end
    }

    @text.bind_append("KeyRelease"){|e|
      @last_keyrelease = e.keysym
      #return if @last_keypress != e.keysym
      case e.keysym
#      when 'Up','Down'
#          refresh_outline
      when 'Left', 'Right'
        if Arcadia.instance.last_focused_text_widget != @text
          @text.select_throw
        end
      when 'Return' #,'Control_L', 'Control_V', 'BackSpace', 'Delete'
        _index = @text.index('insert')
        _row, _col = _index.split('.')
        _txt = @text.get((_row.to_i-1).to_s+'.0',_index)
        if _txt.length > 0
          m = /\s*/.match(_txt)
          if m
            if (m[0] != "\n")
              _sm = m[0]
              _sm = _sm.sub(/\n/,"")
              @text.insert('insert',_sm)
            end
          end
        end
        if _row.to_i + 1  ==  @text.index('end').split('.')[0].to_i
          do_line_update
        end
        if @highlighting
          rehighlightlines(_row.to_i, _row.to_i)
        end
      when 'Shift_L','Shift_R','Control_L','Control_R' ,'Prior', 'Next', 'Up','Down'
        # do nothing because od do_line_update
      else 
#        if ['BackSpace', 'Delete'].include?(e.keysym)
#          do_line_update
#        end
        if @highlighting
          row = @text.index('insert').split('.')[0].to_i
          rehighlightlines(row, row)
        end
      end
      check_modify if !['Shift_L','Shift_R','Control_L','Control_R','Up','Down','Left', 'Right', 'Prior', 'Next'].include?(e.keysym)      
    }


    @text.bind_append("Shift-KeyPress"){|e|
      @last_keypress = e.keysym
      case e.keysym
      when 'Tab','ISO_Left_Tab'
        _r = @text.tag_ranges('sel')
        if _r && _r[0]
          _row_begin = _r[0][0].split('.')[0].to_i
          _row_end = _r[_r.length - 1][1].split('.')[0].to_i
          
          n_space = $arcadia['conf']['editor.tab-replace-width-space'].to_i
          if n_space > 0
            suf = "\s"*n_space
          else
            suf = "\t"
            n_space = 1
          end
          for _row in _row_begin..._row_end
            if @text.get(_row.to_s+'.0',_row.to_s+'.'+n_space.to_s) == suf
              @text.delete(_row.to_s+'.0',_row.to_s+'.'+n_space.to_s)
            end
          end
          break
        end
      end
    }
  end

  def decrease_indent
    _r = @text.tag_ranges('sel')
    _row_begin = _r[0][0].split('.')[0].to_i
    _row_end = _r[_r.length - 1][1].split('.')[0].to_i
    n_space = $arcadia['conf']['editor.tab-replace-width-space'].to_i
    if n_space > 0
      suf = "\s"*n_space
      else
        suf = "\t"
      end
      _l_suf = 	suf.length.to_s
      for _row in _row_begin..._row_end
        if @text.get(_row.to_s+'.0',_row.to_s+'.'+_l_suf) == suf
          @text.delete(_row.to_s+'.0',_row.to_s+'.'+_l_suf)
        end
      end
  end

  # show the "find in file" dialog
  def find
    _r = @text.tag_ranges('sel')
    if _r.length>0
      _text=@text.get(_r[0][0],_r[0][1])
      if _text.length > 0
        @find.e_what.text(_text)
      end
    else
    end
    @find.use(self)
    @find.e_what.focus
    @find.show
  end

  def disactivate_key_binding
    @text.bind_remove('KeyPress')
    @text.bind_remove('KeyRelease')
    @text.bind_remove('Control-KeyPress')
    @text.bind_remove('Control-Shift-KeyPress')
    @text.bind_remove('Shift-KeyPress')
  end
  
  def do_enter
    check_file_last_access_time
  end
  
  def initialize_text_binding
    @text.add_yscrollcommand(proc{|first,last| self.do_line_update()})
    
    @text.tag_bind('selected', 'Enter', proc{@text.tag_remove('selected','1.0','end')})

    @text.bind_append("Enter", proc{do_enter})

    @text.bind("<Modified>"){|e|
      check_modify
    }
    activate_key_binding
    @text.bind_append("1"){
      #Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>@text))
      refresh_outline
    }
  end

  def refresh_outline
    if defined?(@outline)
      Tk.after(1,proc{@outline.update_row(self.row)})
    end
  end

  def run_buffer
    if !@file      
      @lang='ruby' if !@lang
      RunCmdEvent.new(self, {'file'=>'*CURR', 'persistent'=>false, 'lang'=>@lang}).go!
    else
      save if !@read_only && modified?
      RunCmdEvent.new(self, {'file'=>@file, 'lang'=>@lang}).go!
    end
  end
  
  def initialize_line_number(_frame)
    @text_line_num = TkText.new(_frame, Arcadia.style('textline')){
      wrap  'none'
      #relief 'flat'
      undo false
      takefocus 0
      insertofftime 0
      exportselection true
      autoseparators true
      cursor nil
      insertwidth 0
      font Arcadia.conf('edit.font')
      place(
        'x'=>0,
        'y'=>0,
        'relheight'=>1,
        'relwidth'=>1,
        'bordermode'=>'outside'
      )
    }
    if Arcadia.conf("textline.spacing3")
      @text_line_spacing3 = Arcadia.conf("textline.spacing3").to_i
    else
      @text_line_spacing3 = 0
    end
    delta = (@font_metrics_bold[2][1]-@font_metrics[2][1]) + @text_line_spacing3
    @text_line_num.tag_configure('normal_case', 'justify'=>'right')
    @text_line_num.tag_configure('bold_case', 'spacing3'=>delta, 'justify'=>'right')
    @text_line_num.tag_configure('breakpoint', 'background'=>'red','foreground'=>'yellow','borderwidth'=>1, 'relief'=>'raised')
    @text_line_num.tag_configure('current', 
      'background'=>Arcadia.conf("activebackground"),
      'foreground'=>Arcadia.conf("activeforeground"),
      'relief'=>'flat'
    )
    
    @text_line_num.bind("Double-ButtonPress-1", 
      proc{|x,y| 
        _index = @text_line_num.index("@#{x},#{y}")
        _line = @text_line_num.get(_index+' linestart',_index+' lineend').strip
        toggle_breakpoint(_index)
      }, "%x %y")

    @text_line_num.bind("ButtonPress-1", proc{|x,y|
      _index = @text_line_num.index("@#{x},#{y}")
      _line = @text_line_num.get(_index+' linestart',_index+' lineend').strip
      @text_line_num_current_index = _index
      @text_line_num_current_line = _line
      @text_line_num.tag_remove('current',"0.1","end")
      @text_line_num.tag_add('current',_index+' linestart',_index+' lineend')
      @text_line_num.tag_raise('breakpoint')
      },
    "%x %y")
    
    #@text_line_num.configure('font', @font);
    @text_line_num.tag_configure('line_num',
      'foreground' => '#FFFFFF',
      'background' =>'#0000a0',
      'borderwidth'=>2,
      'relief'=>'raised'
    )
    
    #--- menu
    _pop_up = TkMenu.new(
      :parent=>@text_line_num,
      :tearoff=>0,
      :title => 'Menu'
    )
    _pop_up.extend(TkAutoPostMenu)
    _pop_up.configure(Arcadia.style('menu'))
    #Arcadia.instance.main_menu.update_style(@pop_up)
    _title_item = _pop_up.insert('end',
      :command,
      :label=>'...',
      :state=>'disabled',
      :background=>Arcadia.conf('titlelabel.background'),
      :hidemargin => true
    )

    _pop_up.insert('end',
      :command,
      :label=>'Toggle breakpoint',
      :hidemargin => false,
      :command=> proc{ 
        if defined?(@text_line_num_current_index)
          toggle_breakpoint(@text_line_num_current_index)
        end
      }
    )

    @text_line_num.bind("Button-3",
      proc{|*x|
        _x = TkWinfo.pointerx(@text_line_num)
        _y = TkWinfo.pointery(@text_line_num)
        _pop_up.entryconfigure(0,'label'=>"line #{@text_line_num_current_line}")

        _pop_up.popup(_x,_y)
      })
    
  end

  def file_line_to_text_line_num_line(_line)
    rel_line = nil
    line_begin = @text_line_num.get('1.0','1.end').strip.to_i
    line_end = @text_line_num.index('end').split('.')[0].to_i+line_begin
    if _line.to_i >= line_begin && _line.to_i <= line_end
      rel_line = _line.to_i - line_begin +1
    end  
    rel_line
  end
  
  def add_tag_breakpoint(_line)
      rel_line = file_line_to_text_line_num_line(_line)
      if rel_line
        i1 = "#{rel_line}.0"
        i2 = i1+' + 2 chars'
        @text_line_num.tag_add('breakpoint',i1,i2)
      end
  end

  def remove_tag_breakpoint(_line)
      rel_line = file_line_to_text_line_num_line(_line)
      if rel_line
        i1 = "#{rel_line}.0"
        i2 = i1+' lineend'
        @text_line_num.tag_remove('breakpoint',i1,i2)
      end
  end



#  def add_tag_breakpoint(_index=nil)
#      _i1 = _index+' linestart'
#      _i2 = _i1+' + 2 chars'
#      @text_line_num.tag_add('breakpoint',_i1,_i2)
#  end
  
#  def remove_tag_breakpoint(_index=nil)
#      _i1 = _index+' linestart'
#      _i2 = _index+' lineend'
#      #p "Editor: _i1:#{_i1}  _i2:#{_i2}"
#      @text_line_num.tag_remove('breakpoint',_i1,_i2)
#  end

  def toggle_breakpoint(_index=nil)
    if !_index.nil?
      _line = @text_line_num.get(_index+' linestart',_index+' lineend').strip
      _i1 = _index+' linestart'
      _i2 = _i1+' + 2 chars'
      
      if @file && @controller.breakpoint_lines_on_file(@file).include?(_line)
        #remove_tag_breakpoint(_index)
        @controller.breakpoint_del(@file, _line, @id)
      elsif @file.nil? && @controller.breakpoint_lines_on_file("__TMP__#{@id}").include?(_line)
        #remove_tag_breakpoint(_index)
        @controller.breakpoint_del(@file, _line, @id)
      else
        @text_line_num.tag_remove('current',_i1,_i2)
        #add_tag_breakpoint(_index)
        @controller.breakpoint_add(@file, _line, @id)
      end
    end
  end

  def reset_highlight(_from_row=nil)
    if _from_row &&  @highlighting
      invalidated_begin_zone= zone_of_row(_from_row)
      @is_line_bold.delete_if {|key, value| key >= invalidated_begin_zone }
      @is_line_comment.delete_if {|key, value| key >= invalidated_begin_zone }
      @highlight_zone.delete_if {|key, value| key >= invalidated_begin_zone }
    elsif @highlighting
      @is_line_bold.clear
      @is_line_comment.clear
      @highlight_zone.clear 
    end
    @last_line_begin=0
    @last_line_end=0
    @last_zone_begin=0
    @last_zone_end=0
  end

  def change_highlight(_ext)
    new_highlight_scanner = @controller.highlight_scanner(_ext)
    if new_highlight_scanner != @highlight_scanner
      @highlight_scanner.classes.each{|c|
        @text.tag_remove(c,'1.0', 'end')
        @text.tag_delete(c)
        @is_tag_bold.delete(c)
      }
      @highlight_scanner = new_highlight_scanner
      reset_highlight
      if @highlight_scanner
        @highlight_scanner.classes.each{|c|
          do_tag_configure(c)
        }
        @highlighting = true
      else
        @highlighting = false
      end
    end
  end

  def initialize_highlight(_ext)
    @highlight_scanner = @controller.highlight_scanner(_ext)
    @is_line_bold = Hash.new
    @is_line_comment = Hash.new
    @is_tag_bold = Hash.new
    do_tag_configure_global('debug')
    if @lang_hash.nil? || @highlight_scanner.nil?
      @highlighting = false
      return
    end
    @highlighting = true
    @highlight_zone = Hash.new;
#    @highlight_zone_length = 45;
    @highlight_zone_length = 60;
    @last_line_begin = 0
    @last_line_end = 0
    @last_zone_begin=0;
    @last_zone_end=0;
    @highlight_scanner.classes.each{|c|
      do_tag_configure(c)
    }

    ['sel','selected','tabs','spaces'].each{|_name|
      if @lang_hash['hightlight.'+_name+'.foreground']
        do_tag_configure(_name)
      else
        do_tag_configure_global(_name)
      end
    }
  end

  def do_tag_configure(_name)
    h = Hash.new
    if @lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.foreground']
      h['foreground']=@lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.foreground']
    end
    if @lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.background']
      h['background']=@lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.background']
    end
    if @lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.style']== 'bold'
      h['font']=@font_bold
      @is_tag_bold[_name]= true
    else
      @is_tag_bold[_name]= false
    end
    if @lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.relief']
      h['relief']=@lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.relief']
    end
    if @lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.borderwidth']
      h['borderwidth']=@lang_hash["#{@lang_hash['scanner']}.hightlight."+_name+'.borderwidth']
    end
    begin
      @text.tag_configure(_name, h)
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
      #p "RuntimeError : #{e.message}"
    end
  end

  def do_tag_configure_global(_name)
    h = Hash.new

    if Arcadia.conf('editor.hightlight.'+_name+'.foreground')
      h['foreground']=Arcadia.conf('editor.hightlight.'+_name+'.foreground')
    elsif Arcadia.conf('hightlight.'+_name+'.foreground')
      h['foreground']=Arcadia.conf('hightlight.'+_name+'.foreground')
    end
    
    if Arcadia.conf('editor.hightlight.'+_name+'.background')
      h['background']=Arcadia.conf('editor.hightlight.'+_name+'.background')
    elsif Arcadia.conf('hightlight.'+_name+'.background')
      h['background']=Arcadia.conf('hightlight.'+_name+'.background')
    end

    if Arcadia.conf('editor.hightlight.'+_name+'.style')== 'bold'
      h['font']=@font_bold
      @is_tag_bold[_name]= true
    elsif Arcadia.conf('hightlight.'+_name+'.style')== 'bold'
      h['font']=@font_bold
      @is_tag_bold[_name]= true
    else
      @is_tag_bold[_name]= false
    end

    if Arcadia.conf('editor.hightlight.'+_name+'.relief')
      h['relief']=Arcadia.conf('editor.hightlight.'+_name+'.relief')
    elsif Arcadia.conf('hightlight.'+_name+'.relief')
      h['relief']=Arcadia.conf('hightlight.'+_name+'.relief')
    end
    
    if Arcadia.conf('editor.hightlight.'+_name+'.borderwidth')
      h['borderwidth']=Arcadia.conf('editor.hightlight.'+_name+'.borderwidth')
    elsif Arcadia.conf('hightlight.'+_name+'.borderwidth')
      h['borderwidth']=Arcadia.conf('hightlight.'+_name+'.borderwidth')
    end
    
    begin
      @text.tag_configure(_name, h)
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
      #p "RuntimeError : #{e.message}"
    end
  end

  def pop_up_menu
    @pop_up = TkMenu.new(
      :parent=>@text,
      :tearoff=>0,
      :title => 'Menu'
    )
    @pop_up.extend(TkAutoPostMenu)
    @pop_up.configure(Arcadia.style('menu'))
    
    @pop_up.insert('end',
      :command,
      :state=>'disabled',
      :background=>Arcadia.conf('titlelabel.background'),
      :font => "#{Arcadia.conf('menu.font')} bold",
      :hidemargin => true
    )
    #Arcadia.instance.main_menu.update_style(@pop_up)
    @pop_up.insert('end',
      :command,
      :label=>'Save as',
      :hidemargin => false,
      :command=> proc{save_as}
    )
    @pop_up.insert('end',
      :command,
      :label=>'Save',
      :hidemargin => false,
      :command=> proc{save}
    )

    @pop_up.insert('end', :separator)

    @pop_up.insert('end',
      :command,
      :label=>'Close',
      :hidemargin => false,
      :command=> proc{@controller.close_editor(self)}
    )

    @pop_up.insert('end',
      :command,
      :label=>'Close others',
      :hidemargin => false,
      :command=> proc{@controller.close_others_editor(self)}
    )

    @pop_up.insert('end',
      :command,
      :label=>'Close all',
      :hidemargin => false,
      :command=> proc{@controller.close_all_editor(self)}
    )

    @pop_up.insert('end', :separator)

    @pop_up.insert('end',
      :command,
      :label=>'Copy',
      :hidemargin => false,
      :command=> proc{
        @text.event_generate("Control-KeyPress",:keysym=>'c')
        @text.event_generate("Control-KeyRelease",:keysym=>'c')
      }
    )

    @pop_up.insert('end',
      :command,
      :label=>'Cut',
      :hidemargin => false,
      :command=> proc{
        @text.event_generate("Control-KeyPress",:keysym=>'x')
        @text.event_generate("Control-KeyRelease",:keysym=>'x')
      }
    )


    @pop_up.insert('end',
      :command,
      :label=>'Paste',
      :hidemargin => false,
      :command=> proc{
        @text.event_generate("Control-KeyPress",:keysym=>'v')
        @text.event_generate("Control-KeyRelease",:keysym=>'v')
      }
    )


    @pop_up.insert('end',
      :command,
      :label=>'Undo',
      :hidemargin => false,
      :command=> proc{
        @text.event_generate("Control-KeyPress",:keysym=>'z')
        @text.event_generate("Control-KeyRelease",:keysym=>'z')
      }
    )


    @pop_up.insert('end', :separator)

    @pop_up.insert('end',
      :command,
      :label=>'Color',
      :hidemargin => false,
      :command=> proc{
        #@text.insert('insert',Tk.chooseColor)
        @text.insert('insert',Tk::BWidget::SelectColor::Dialog.new.create)
      }
    )

    @pop_up.insert('end',
      :command,
      :label=>'View color from data',
      :hidemargin => false,
      :command=> proc{
        _r = @text.tag_ranges('sel')
        if _r.length>0
          _data=@text.get(_r[0][0],_r[0][1])
          if _data.length > 0
            _b = TkButton.new(@text, 
              'command'=>proc{_b.destroy},
              'bg'=>_data,
              'relief'=>'groove')
            TkTextWindow.new(@text, _r[0][1], 'window'=> _b)
          end
        end
      }
    )

    @pop_up.insert('end',
      :command,
      :label=>'Font',
      :hidemargin => false,
      :command=> proc{
        @text.insert('insert', $arcadia['action.get.font'].call)
      }
    )
    
    @pop_up.insert('end',
      :command,
      :label=>'Data from file',
      :hidemargin => false,
      :command=>       proc{
        file = Arcadia.open_file_dialog
        if file
          require 'base64'
          f = File.open(file,"rb")
          data = f.read
          f.close
          encoded = Base64.encode64( data )
          @text.insert('insert', File.basename(file).gsub('.gif','_gif').gsub('-','_').upcase + "=<<EOS\n")
          @text.insert('insert', "#{encoded}")
          @text.insert('insert', "EOS\n")
        end
      }
    )

    @pop_up.insert('end',
      :command,
      :label=>'View image from data',
      :hidemargin => false,
      :command=> proc{
        _r = @text.tag_ranges('sel')
        if _r.length>0
          _data=@text.get(_r[0][0],_r[0][1])
          if _data.length > 0
            _b = TkButton.new(@text, 
              'command'=>proc{_b.destroy},
              'image'=> Arcadia.image_res(_data),
              'relief'=>'groove')
            TkTextWindow.new(@text, _r[0][1], 'window'=> _b)
          end
        end
      }
    )


    @pop_up.insert('end',
      :command,
      :label=>'Data image to file',
      :hidemargin => false,
      :command=> proc{
        _r = @text.tag_ranges('sel')
        if _r.length>0
          _data=@text.get(_r[0][0],_r[0][1])
          if _data.length > 0
            file = Tk.getSaveFile("filetypes"=>[["Image", [".gif"]],["All Files", [".*"]]])
            if file
              require 'base64'
              decoded = Base64.decode64(_data)
              f = File.new(file, "w")
              begin
                if f
                  f.syswrite(decoded)
                end
              ensure
                f.close unless f.nil?
              end
            end
          end
        end
      }
    )

    @pop_up.insert('end', :separator)

    #---- debug menu
    _sub_debug = TkMenu.new(
      :parent=>@pop_up,
      :tearoff=>0,
      :title => 'Debug'
    )
    _sub_debug.extend(TkAutoPostMenu)
    _sub_debug.configure(Arcadia.style('menu'))
    _sub_debug.insert('end',
      :command,
      :label=>'Eval selected',
      :hidemargin => false,
      :command=> proc{
        _r = @text.tag_ranges('sel')
        if _r.length>0
          _text=@text.get(_r[0][0],_r[0][1])
          if _text.length > 0
            Arcadia.process_event(EvalExpressionEvent.new(self, 'expression'=>_text))
            #EditorContract.instance.eval_expression(self, 'text'=>_text)
          end
        end
      }
    )

    @pop_up.insert('end',
      :cascade,
      :label=>'Debug',
      :menu=>_sub_debug,
      :hidemargin => false
    )


    #---- code menu
    _sub_code = TkMenu.new(
      :parent=>@pop_up,
      :tearoff=>0,
      :title => 'Code'
    )
    _sub_code.extend(TkAutoPostMenu)
    _sub_code.configure(Arcadia.style('menu'))
    _sub_code.insert('end',
      :command,
      :label=>'Set wrap',
      :hidemargin => false,
      :command=> proc{@text.configure('wrap'=>'word');@text.hide_h_scroll}
    )

    _sub_code.insert('end',
      :command,
      :label=>'Set no wrap',
      :hidemargin => false,
      :command=> proc{@text.configure('wrap'=>'none');@text.show_h_scroll}
    )

    _sub_code.insert('end',
      :command,
      :label=>'Selection to uppercase',
      :hidemargin => false,
      :command=> proc{do_upper_case}
    )

    _sub_code.insert('end',
      :command,
      :label=>'Selection to downcase',
      :hidemargin => false,
      :command=> proc{do_lower_case}
    )



    _sub_code.insert('end',
      :command,
      :label=>'Show tabs',
      :hidemargin => false,
      :command=> proc{show_tabs}
    )


    _sub_code.insert('end',
      :command,
      :label=>'Hide tabs',
      :hidemargin => false,
      :command=> proc{hide_tabs}
    )

    _sub_code.insert('end',
      :command,
      :label=>'Show spaces',
      :hidemargin => false,
      :command=> proc{show_spaces}
    )


    _sub_code.insert('end',
      :command,
      :label=>'Hide spaces',
      :hidemargin => false,
      :command=> proc{hide_spaces}
    )


    _sub_code.insert('end',
      :command,
      :label=>'Space to tabs indentation',
      :hidemargin => false,
      :command=> proc{indentation_space_2_tabs}
    )

    _sub_code.insert('end',
      :command,
      :label=>'Tabs to space indentation',
      :hidemargin => false,
      :command=> proc{indentation_tabs_2_space}
    )

    
    @pop_up.insert('end',
      :cascade,
      :label=>'Code',
      :menu=>_sub_code,
      :hidemargin => false
    )
    
    @text.bind(@controller.conf('popup.bind.shortcut'),
      proc{|x,y|
        _x = TkWinfo.pointerx(@text)
        _y = TkWinfo.pointery(@text)
        #@pop_up.entryconfigure(1, 'label'=>File.basename(@file)) if @file
        @pop_up.entryconfigure(0, 'label'=>File.basename(@file)) if @file
        @pop_up.popup(_x,_y)
      },
    "%x %y")
  end

  def unmark_debug(_index)
    @text.tag_remove('debug',_index +' linestart', _index +' +1 lines linestart')
    #@text.tag_remove('debug',_index+' linestart', _index+' lineend')
  end

  def mark_debug(_index)
    @text.tag_add('debug',_index +' linestart', _index +' +1 lines linestart')
    #@text.tag_add('debug',_index +' linestart', _index +' lineend')
  end

  def mark_selected(_index)
    @text.tag_remove('selected','1.0', 'end')
    @text.tag_add('selected',_index +' linestart', _index +' +1 lines linestart')
  end

  def insert_popup_menu_item(_where, *args)
    @pop_up.insert(_where,*args)
  end

  def text_value
    return @text.value
  end
  
  def text_selected
    _text = ''
    _r = @text.tag_ranges('sel')
    if _r.length>0
      _text=@text.get(_r[0][0],_r[0][1])
    end
    _text
  end
  
  def text_replace_selected_with(_text_for_replace='')
    _r = @text.tag_ranges('sel')
    if _r.length>0
      bl = _r[0][0].split('.')[0].to_i
      @text.delete(_r[0][0],_r[0][1])
      @text.insert(_r[0][0],_text_for_replace)
      el = @text.index('insert').split('.')[0].to_i
      if highlighting
        reset_highlight(bl)
        rehighlightlines(bl,el,true)
      end
    end
  end

  def text_replace_value_with(_text_for_replace='')
    pos_index = @text.index('insert') 
    @text.delete('1.0','end')
    reset_highlight if @highlighting
    @text.insert('end',_text_for_replace)
    do_line_update
    @text.see(pos_index)
    @text.set_insert(pos_index)
    check_modify
  end
  
  def do_upper_case
    _text = text_selected
    if _text.length > 0
      text_replace_selected_with(_text.upcase)
    end
  end

  def do_lower_case
    _text = text_selected
    if _text.length > 0
      text_replace_selected_with(_text.downcase)
    end
  end
  
  # vertical scrollbar : ON/OFF
  def vscroll(mode)
    st = TkGrid.info(@v_scroll)
    if mode && st == [] then
      @v_scroll.grid('row'=>0, 'column'=>1, 'sticky'=>'ns')
    elsif !mode && st != [] then
      @v_scroll.ungrid
    end
    self
  end

  # horizontal scrollbar : ON/OFF
  def hscroll(mode, wrap_mode="char")
    st = TkGrid.info(@h_scroll)
    if mode && st == [] then
      @h_scroll.grid('row'=>1, 'column'=>0, 'sticky'=>'ew')
      @text.configure('wrap'=> 'none')
    elsif !mode && st != [] then
      @h_scroll.ungrid
      @text.configure('wrap'=> wrap_mode)
    end
    self
  end

  def rowcol(_index, _gap_row = nil, _gap_col = nil)
    _riga, _colonna = _index.split('.')
    if _gap_row == nil
      _riga = '1'
      _gap_row = 0
    end
    if _gap_col == nil
      _colonna = '0'
      _gap_col = 0
    end
    return (_riga.to_i + _gap_row).to_s + '.'+ (_colonna.to_i + _gap_col).to_s
  end

#  def find_and_set_tag_ml(_re, _row, _txt, _tag, _tag_rem = nil)
#    m = _re.match(_txt)
#    _offset = 0
#    _s_txt = _txt
#    #_old_txt = ''
#    while m && (_txt=m.post_match)
#      if !defined?(_old_txt) || _txt != _old_txt
#
#        apos =  pos_to_index(_s_txt, _offset+m.begin(0))
#        _offset = _offset + m.end(0)
#        
#        
#        _old_txt = _txt
#        _r = _row + apos[0]
#        _ibegin = _r.to_s+'.'+apos[1].to_s
#        _iend = _r.to_s+'.'+(apos[1]+m.end(0)-m.begin(0)).to_s
#        if _tag_rem
#          _tag_rem.each {|value|
#            @text.tag_remove(value,_ibegin, _iend)
#          }
#        end
#        @text.tag_add(_tag,_ibegin, _iend)
#        if @is_tag_bold[_tag]
#          @is_line_bold[_r]=true
#        end
#
#        if @op_only_first.include?(_tag) && _txt
#          #eliminino la prima riga a partire dal risultato
#          _p = _txt.index("\n")+1
#          if _p
#              _txt = _txt[_p..-1]
#              _offset = _offset + _p
#          else
#            m = nil
#          end
#        end
#        m = _re.match(_txt)
#        
#      else
#        m = nil
#      end
#    end
#  end


#  def find_and_set_tag(_re, _row, _txt, _tag, _tag_rem = nil)
#    m = _re.match(_txt)
#    _end = 0
#    if m && @is_tag_bold[_tag]
#      @is_line_bold[_row]=true
#    end
#    #_old_txt = ''
#    while m && (_txt=m.post_match)
#      if !defined?(_old_txt) || _txt != _old_txt
#        _old_txt = _txt 
#        _ibegin = _row.to_s+'.'+(m.begin(0)+_end).to_s
#        _end = m.end(0) + _end
#        _iend = _row.to_s+'.'+(_end.to_s)
#        if _tag_rem
#          _tag_rem.each {|value|
#            @text.tag_remove(value,_ibegin, _iend)
#          }
#        end
#        @text.tag_add(_tag,_ibegin, _iend)
#        if @op_only_first.include?(_tag)
#          m = nil
#        else
#          m = _re.match(_txt)
#        end
#      else
#        m = nil
#      end
#    end
#  end


  def text_value_lines
    if String.method_defined?(:lines)
      return @text.value.lines
    else
      return @text.value
    end
  end

  def show_spaces
    @spaces_show = true
    _row = 1
    text_value_lines.each{|_line|
      show_chars_line(_row, _line, /[ ^\t]\s*/, 'spaces')
      _row = _row+1
    }
  end


  def show_tabs
    @tabs_show = true
    _row = 1
    text_value_lines.each{|_line|
      show_chars_line(_row, _line, /\t/, 'tabs')
      _row = _row+1
    }
  end


  def show_chars_line(_row, _line, _re, _tag)
    m = _re.match(_line)
    _end = 0
    while m
      _txt = m.post_match
      _ibegin = _row.to_s+'.'+(m.begin(0)+_end).to_s
      _end = m.end(0) + _end
      _iend = _row.to_s+'.'+(_end.to_s)
      @text.tag_add(_tag,_ibegin, _iend)
      m = _re.match(_txt)
    end
  end 

  def indentation_space_2_tabs(_n_space=2)
    _row = 1
    text_value_lines.each{|_line|
      m = /\s*/.match(_line)
      _end = 0
      if m && m.begin(0)==0
        _s = m[0]
        if !_s.include?("\n") && !_s.include?("\t")
          _ibegin = _row.to_s+'.0'
          _iend = _row.to_s+'.'+m.end(0).to_s
          _n_tab = (_s.length / _n_space).round
          @text.delete(_ibegin, _iend)
          @text.insert(_ibegin,"\t"*_n_tab )
        end
      end
      _row = _row+1
    }
    check_modify    
  end

  def indentation_tabs_2_space(_n_space=2)
    _row = 1
    text_value_lines.each{|_line|
      m = /\t*/.match(_line)
      _end = 0
      if m && m.begin(0)==0
        _s = m[0]
        if !_s.include?("\n")
          _ibegin = _row.to_s+'.0'
          _iend = _row.to_s+'.'+m.end(0).to_s
          @text.delete(_ibegin, _iend)
          @text.insert(_ibegin,"\s"*_s.length*_n_space )
        end
      end
      _row = _row+1
    }
    check_modify    
  end


  def hide_tabs
    @text.tag_remove('tabs','1.0', 'end')
    @tabs_show = false
  end

  def hide_spaces
    @text.tag_remove('spaces','1.0', 'end')
    @spaces_show = false
  end


  # modify in this instance means the (...) in the tab header of each file
  def modified?
    return !(@buffer === text_value)
  end

  def set_modify
    if !@set_mod
      @set_mod = true
      @modified_from_opening = true
      @controller.change_tab_set_modify(@page_frame)
    end
  end
  
  def tab_title
    @controller.tab_title(@page_frame)
  end

  def reset_modify(_reset_tab=true)
    @controller.change_tab_reset_modify(@page_frame) if _reset_tab
    @set_mod = false
    @file_info['mtime'] = File.mtime(@file) if @file
    #@file_last_access_time = File.mtime(@file) if @file
    @controller.refresh_status
    update_toolbar
  end

  def pos_to_index(_txt, _pos)
    _a= _txt[0.._pos].split("\n")
    if _a && _a.length > 0
      _row = _a.length
      if _a.length == 2
        _col = _a[-1].length - 1
      else
        _col = _pos
      end
      return [_row,_col]
    else
      return nil
    end
  end


  def rehighlightlines(_row_begin, _row_end, _check_mod=false)
    _ibegin = _row_begin.to_s+'.0'
    _iend = (_row_end+1).to_s+'.0'
    @highlight_scanner.classes.each{|c| @text.tag_remove(c,_ibegin, _iend)}
    highlightlines(_row_begin, _row_end, _check_mod)
  end

  def row(_index='insert')
    _row = @text.index(_index).split('.')[0].to_i
    return _row
  end
  
  def zone_of_row(_row)
    ((_row) / @highlight_zone_length).to_i + 1
  end
  
  def do_line_update
    #re num in @text_line_num the portion of visibled screen  of @text
      return if @loading
      if @text_line_num
        line_begin_index = @text.index('@0,0')
        line_begin = line_begin_index.split('.')[0].to_i
        line_end = @text.index('@0,'+TkWinfo.height(@text).to_s).split('.')[0].to_i + 1
        wrap_on = @text.cget("wrap") != 'none'
        if @highlighting
          _zone_begin = ((line_begin) / @highlight_zone_length).to_i + 1
          _zone_end = ((line_end) / @highlight_zone_length).to_i + 1
          #Arcadia.new_msg(self, "for lines #{line_begin}..#{line_end} \n
          #_zone_begin=#{_zone_begin} ; _zone_end=#{_zone_end}")
          (_zone_begin >=@last_zone_begin)?_zone_begin.upto(_zone_end+1){|_zone| 
            highlight_zone(_zone)
          }:_zone_end.downto(_zone_begin-1){|_zone| 
            highlight_zone(_zone)		
          }
          @last_line_begin = line_begin
          @last_line_end = line_end
          @last_zone_begin = _zone_begin
          @last_zone_end = _zone_end
        end
        if @line_numbers_visible
          # breakpoint
          b = @controller.breakpoint_lines_on_file(@file)
          
          @text_line_num.delete('1.0','end')
          _rx, _ry, _width, _heigth = @text.bbox(line_begin_index);
          
          if _ry && _ry < 0 
            real_line_end = line_end + 1
          else
            real_line_end = line_end
          end
          #@fm1
          _tags = Array.new
          for j in line_begin...real_line_end
            nline = j.to_s.rjust(line_end.to_s.length+2)
            _index = @text_line_num.index('end')
            _tags.clear
            if @highlighting && @is_line_bold[j]
              _tags << 'bold_case'
            else
              _tags << 'normal_case'
            end
            
            if wrap_on
              w_rx_b, w_ry_b, w_width_b, w_heigth_b = @text.bbox("#{(j).to_s}.0");
              w_rx_e, w_ry_e, w_width_e, w_heigth_e = @text.bbox("#{(j).to_s}.0 lineend");
              if w_ry_e && w_ry_b 
                delta = w_ry_e - w_ry_b
                if delta > 1   
                  _tag = "wrap_case_#{j}"
                  @text_line_num.tag_configure(_tag, 'spacing3'=>delta + @text_line_spacing3)  
                  _tags << _tag
                end
              end
            end
  
            @text_line_num.insert(_index, "#{nline}\n",_tags)
            if b.include?(j.to_s)
              add_tag_breakpoint(j)
            end
          end
          if _ry && _ry < 0 
            @text_line_num.yview_scroll(_ry.abs+2,"pixels")
          end
          resize_line_num
        end
      end
      refresh_outline if Tk.focus==@text
  end

  def resize_line_num
    if TkWinfo.mapped?(@text_line_num)
      if @last_line_end_chars.nil?
        @last_line_end_chars = 0
      end
      _line_end=row('end')
      line_end_chars  = _line_end.to_s.length  
      if @last_line_end_chars != line_end_chars || @need_recalc
        if @line_num_rx_e.nil? || @need_recalc
          @line_num_rx_e, @line_num_ry_e, @line_num_width_e, @line_num_heigth_e = @text_line_num.bbox("0.1 lineend - 1 chars");
          if @line_num_width_e.nil?
            @line_num_width_e = @font.split()[-1].strip.to_i
            @need_recalc = true            
#            linfo_x, linfo_y, linfo_w, linfo_h, linfo_b  = @text_line_num.dlineinfo('0.1')            
#            if linfo_w
#              @line_num_width_e = linfo_w.to_f/(line_end_chars+1.5)
#            end
          else
            @need_recalc = false   
          end
        end
        
        
        if @line_num_width_e && line_end_chars >0 
          need_width = (line_end_chars+1)*@line_num_width_e
          @fm1.resize_left(need_width)
          @last_line_end_chars = line_end_chars
        else
          @last_line_end_chars = -1
        end
      end
    end
  end

  def refresh_visible_highlighting
    line_begin_index = @text.index('@0,0')
    line_begin = line_begin_index.split('.')[0].to_i
    line_begin = @comment_line_begin if !@comment_line_begin.nil? && @comment_line_begin < line_begin
    line_end = @text.index('@0,'+TkWinfo.height(@text).to_s).split('.')[0].to_i + 1
    reset_highlight(line_begin)
    zone_begin = zone_of_row(line_begin)
    zone_end = zone_of_row(line_end)
    zone_begin.upto(zone_end){|z| highlight_zone(z)}
    highlight_zone(zone_of_row(line_end+1)) if @is_line_comment[line_end]
    
    #rehighlightlines(line_begin,line_end,true)
    if @is_line_comment[line_end]
      line_end.downto(line_begin){|l|
        @comment_line_begin = l if @is_line_comment[l]
      }
    else
      @comment_line_begin = nil
    end
  end


  def highlightlines(_row_begin, _row_end, _check_mod = false)
    if _check_mod 
      check_modify
    end
    is_comment = _row_begin == _row_end
    if _row_begin == _row_end && (@is_line_comment[_row_end-1] || @is_line_comment[_row_end+1])
      if  !['apostrophe','quotedbl'].include?(@last_keypress)
        refresh_visible_highlighting
        return  
      end
    end
    #_row_begin = _row_begin+1
    _ibegin = _row_begin.to_s+'.0'
    _iend = (_row_end+1).to_s+'.0'
    @highlight_scanner.classes.each{|c| @text.tag_remove(c,_ibegin, _iend)}
    _lines = @text.get(_ibegin, _iend)
    tags_map = @highlight_scanner.highlight_tags(_row_begin,_lines)
    tags_map.each do |key,value|      
      is_comment = is_comment && key == :comment
      break if is_comment
      to_tag = Array.new
      value.each{|ite|
        to_tag.concat(ite)
        if ite.length==2
          row_begin = ite[0].split('.')[0].to_i
          row_end = ite[1].split('.')[0].to_i
          for row in row_begin..row_end 
            @is_line_bold[row] = @is_tag_bold[key.to_s]
            @is_line_comment[row] = key == :comment
          end
        end
      }
#      to_tag.each{|p|
#        if @i.nil?
#          @one = p
#          @i = 1
#          next
#        else
#          @two = p
#          @i = nil
#        end
#        row_begin = @one.split('.')[0].to_i
#        row_end = @two.split('.')[0].to_i
#        for row in row_begin...row_end 
#          @is_line_comment[row] = key == :comment
#        end
#      }
      @text.tag_adds(key.to_s,to_tag)
    end
    refresh_visible_highlighting if is_comment

    if @tabs_show || @spaces_show
      if !defined?(@rescanner)
        if @lang_hash['scanner']!='re'
          @rescanner = ReHighlightScanner.new(@lang_hash) if !defined?(@rescanner)
        else
          @rescanner = @highlight_scanner
        end
      end
      @rescanner.highlight_tags(_row_begin,_lines,['tabs']) if @tabs_show
      @rescanner.highlight_tags(_row_begin,_lines,['spaces']) if @spaces_show
    end
  end

  def highlight_zone(_zone, _force_highlight=false)
    if !@highlight_zone[_zone] || _force_highlight
      _b = @highlight_zone_length*(_zone - 1) +1
      _e = @highlight_zone_length*(_zone) #+ 1      
      _b -=1 while @is_line_comment[_b-1]      
      rehighlightlines(_b,_e)
      @highlight_zone[_zone] = true
    end
  end

  def text_see(_index=nil)
    if _index
      @text.see(_index)
    end
  end

  def text_insert_index
    @text.index('insert')
  end

  def text_insert(index, chars, *tags, &b)
    if block_given?
      instance_eval(&b)
    end
    _index = @text.index(index)
    _row, _col  = _index.split('.')
    _row = (_row.to_i - 1).to_s
    chars.each_line {|line|
      @text.insert(_row+'.0', line, *tags)
      if !defined?(m_begin)||(m_begin == nil)
        m_begin = /=begin/.match(line)
      end
      if @highlighting
        if m_begin &&(m_begin.begin(0)==0)
          _ibegin = _row+'.0'
          _iend = _row+'.'+(line.length - 1).to_s
          @text.tag_add('comment',_ibegin, _iend)
        else
          #highlightline(_row.to_i, line, false)
          highlightlines(_row.to_i, _row.to_i, false)
        end
      end
      _row = (_row.to_i + 1).to_s
    }
    if defined?(_edit_reset)
      if _edit_reset
        @text.edit_reset
      end
    else
      @text.edit_reset
    end
  end
  
  
  def save ignore_read_only = false
    if !@file
      save_as
    elsif @read_only && !ignore_read_only
      r=Arcadia.dialog(self,
      'type' => 'yes_no_cancel',
      'title' =>"#{@file}:read-only",
      'msg' =>"The file : #{@file} is read-only! -- save anyway?",
      'level' =>'warning')
      if r=="yes"
        save true
      end
    else
      f = File.new(@file, "wb")
      begin
        if f
	        to_write = text_value
	        if @dos_line_endings
        	    # we stripped these out, previously...
        	    # for now assume they want them all this way, no mixing and matching...
        	    to_write = to_write.gsub("\n", "\r\n")
        	 end
          f.syswrite(to_write)
          @buffer = text_value
          reset_modify
        end
      ensure
        f.close unless f.nil?
      end
      #EditorContract.instance.file_saved(self,'file' =>@file)
    end
  end

  def save_as
    file = Tk.getSaveFile("filetypes"=>[["Ruby Files", [".rb", ".rbw"]],["All Files", [".*"]]])
    file = nil if file == ""  # cancelled
    if file
      new_file_name(file)
      save
      #@controller.change_file_name(@page_frame, file)
      @last_tmp_file = nil if @last_tmp_file != nil
      Arcadia.process_event(OpenBufferEvent.new(self,'file'=>file))
      @controller.do_buffer_raise(@controller.page_name(@page_frame))
      #EditorContract.instance.file_created(self, 'file'=>@file)
    end
  end

  def new_file_name(_new_file)
    @file =_new_file
    @controller.change_file_name(@page_frame, file)
    base_name= File.basename(_new_file)
    if base_name.include?('.')
      self.change_highlight(base_name.split('.')[-1])
    end
  end

  def update_toolbar
    save = Arcadia.toolbar_item('save')
    save.enable=@set_mod if save    
  end

  def check_modify
    return  if @loading
    if modified?
      set_modify if !@set_mod
    else
      reset_modify
    end
    update_toolbar
  end

  def modified_by_others?
    ret = false 
    if @file_info['mtime'] && @file 
      if File.exist?(@file)
        ftime = File.mtime(@file)
        ret = @file_info['mtime'] != ftime
      else
        ret = true
      end
    end
    ret
  end

  def reset_file_last_access_time
    if @file
      if File.exist?(@file)
        @file_info['mtime'] = File.mtime(@file)
      else
        @file_info['mtime'] = nil
        @file = nil
      end
    end
  end
  
  def check_file_last_access_time
    #@controller.activate
    if @file
      file_exist = File.exist?(@file)
      if @file_info['mtime'] && file_exist
        ftime = File.mtime(@file)
        if @file_info['mtime'] != ftime
          msg = 'File "'+@file+'" is changed! Reload?'
          ans = Tk.messageBox('icon' => 'error', 'type' => 'yesno',
            'title' => '(Arcadia) Libs', 'parent' => @text,
            'message' => msg)
          if ans == 'yes'
            reload
          else
            @file_info['mtime'] = ftime
          end
        end
      elsif !file_exist
        msg = 'Appears that file "'+@file+'" was deleted by other process! Do you want to resave it?'
        if Tk.messageBox('icon' => 'error', 'type' => 'yesno',
          'title' => '(Arcadia) editor', 'parent' => @text,
          'message' => msg) == 'yes'
          save
        else
          @file = nil
          @buffer = ''
          set_modify
        end
      end
    end
  end
  
  def reload
    pos_index = @text.index('insert') 
    @text.delete('1.0','end')
    reset_highlight if @highlighting
    load_file(@file)
    @text.see(pos_index)
    @text.set_insert(pos_index)
  end
  
  def has_ctags?
    @controller.has_ctags
  end
  
  def ctags_string
    @controller.ctags_string
  end

  def initialize_editing(_ext=nil, _lang=nil)
    if _lang 
      @is_ruby = _lang=='ruby'
    else
      @is_ruby = _ext=='rb' || _ext=='rbw'
    end
    @classbrowsing = @is_ruby || has_ctags?
    @codeinsight = @is_ruby
    if _lang
      @lang_hash = @controller.language_hash_by_lang(_lang)
    else
      @lang_hash = @controller.language_hash_by_ext(_ext)
    end
    if @lang_hash
      @lang = @lang_hash['language']
    else
      @lang = 'ruby'
    end
#    @highlight_scanner = @controller.highlight_scanner(_ext)
#    if !_ext.nil? && @is_ruby
#      @fm = AGTkVSplittedFrames.new(@page_frame,_w1)
#      @fm1 = AGTkVSplittedFrames.new(@fm.right_frame,_w2)
#      initialize_tree(@controller.frame(1).hinner_frame)
#      initialize_tree(@fm.left_frame)
#    else
#      @fm1 = AGTkVSplittedFrames.new(@page_frame,_w2)
#    end
    @fm1 = AGTkVSplittedFrames.new(@page_frame,@page_frame,0,5,false,false)
    @fm1.splitter_frame.configure('relief'=>'flat')
    initialize_text(@fm1.right_frame)
    initialize_highlight(_ext)
    initialize_line_number(@fm1.left_frame)
    initialize_text_binding
  end
  
  def show_outline
    if defined?(@outline)
      @outline.show
    else
      @outline=AgEditorOutline.new(self, @controller.main_instance.frame(1).hinner_frame, @controller.outline_bar, @lang)
      refresh
    end
  end

  def hide_outline
    #@outline.hide if defined?(@outline)
    @outline.hide if @outline
  end

  def destroy_outline
    @outline.destroy if @outline
    @outline = nil
  end
  
  def load_file(_filename = nil)
    #if filename is nil then open a new tab
    @loading=true
    @dos_line_endings=false
    begin
      @file = _filename
      if _filename
        File::open(_filename,'rb'){ |file|
          @text.insert('end',file.readlines.collect!{| line | line.chomp}.join("\n"))
          #@text.insert('end',file.read)
        }
	      File.open(_filename, 'rb') { |file|
	        @dos_line_endings=true if file.read.include?("\r\n") # pesky windows line endings
	      }
      end
      set_read_only(!File.stat(_filename).writable?)
      reset(false)
      refresh
    ensure
      @loading=false
    end
  end
  
  def set_read_only(_value)
    if @read_only != _value
      @read_only = _value
      if @read_only
        #@text.configure('state'=>'disabled')
        @controller.change_tab_set_read_only(@page_frame)
      else
        #@text.configure('state'=>'normal')
        @controller.change_tab_reset_read_only(@page_frame)
      end
    end
  end
  
  def reset(_reset_tab=true)
    @buffer = text_value
    reset_modify(_reset_tab)
    @text.edit_reset
  end
  
  def refresh
    @outline.build_tree if defined?(@outline) && @classbrowsing #&& !is_exp_hide?
  end
end

class AgMultiEditorView
  #attr_reader :enb
  def initialize(parent=nil, _usetabs=true)
    @parent = parent
    @usetabs = _usetabs
    if @usetabs
      initialize_tabs
    end
    @pages = {}
    @page_binds = {}
    @raised_page=nil
  end
  
  def initialize_tabs
    @enb = Tk::BWidget::NoteBook.new(@parent.hinner_frame, Arcadia.style('tabpanel')){
      tabbevelsize 0
      internalborderwidth 2
      side Arcadia.conf('editor.tabs.side')
      font Arcadia.conf('editor.tabs.font')
      pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
    }
    refresh_after_map = proc{
      if !@enb.pages.empty?
        if @enb.raise.nil? || @enb.raise.strip.length == 0
          @enb.raise(@enb.pages[0]) 
           @enb.see(@enb.pages[0])
        end
      end
    }
    @enb.bind_append("Map",refresh_after_map)
  end
  
  def switch_2_tabs
    raised = raise
    @usetabs = true
    initialize_tabs
    @pages.each{|name, value|
      oldframe = value['frame'].frame
      value['frame'].detach_frame
      oldframe.destroy
      add_page(name, value['file'], value['text'], value['image'], value['raisecmd'], value['frame'])
    }
    raise(raised)
    @page_binds.each{|event, proc| page_bind(event, proc)}    
  end

  def switch_2_notabs
    raised = raise
    @usetabs = false
    @pages.each{|name, value|
      value['frame'].detach_frame
      add_page(name, value['file'], value['text'], value['image'], value['raisecmd'], value['frame'])
    }
    @enb.destroy
    raise(raised)
    @page_binds.each{|event, proc| 
      page_bind(event, proc)
    }    
  end
  
  def root_frame
    if @usetabs
      @enb
    else
      @parent.hinner_frame
    end
  end
  
  def exist_buffer?(_name)
    if @usetabs
      @enb.index(_name) != -1
    else
      @pages.include?(_name)
    end
  end  
  
  def index(_name)
    if @usetabs
      @enb.index(_name)
    else
      _index = @pages.values.index(@pages[_name])
      _index = -1 if _index.nil?
      _index
    end
  end
  
  def pages
    if @usetabs
      @enb.pages
    else
      @pages.keys
    end
  end
  
  def page_title(_name, _title=nil, _image=nil)
    @pages[_name]['text'] = _title if _title != nil
    @pages[_name]['image'] = _image if _image != nil
    title = _title
    if @usetabs
      if _title.nil? && _image.nil?
        title = @enb.itemcget(_name, 'text')
      else
        args = {}
        if _title != nil
          args['text']=_title
        end 
        if _image != nil
          args['image']=_image
        end
        @enb.itemconfigure(_name, args)      
      end
    else
      if _title.nil? && _image.nil?
        title = @pages[_name]['text'] if @pages[_name]
      end
    end
    @parent.root.top_text(page(_name)['text'], page(_name)['image']) if page(_name) && raised?(_name)
    title
  end
  
  def add_page(_name, _file, _title, _image, _raise_proc, _adapter=nil)
    if @usetabs
      frame = @enb.insert('end', _name ,
        'text'=> _title,
        'image'=> _image,
        'background'=> Arcadia.style("tabpanel")["background"],
        'foreground'=> Arcadia.style("tabpanel")["foreground"],
        'raisecmd'=>_raise_proc
      )
    else
      frame = TkFrame.new(@parent.hinner_frame) #.pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
    end
    if _adapter.nil?
      adapted_frame = TkFrameAdapter.new(@parent.hinner_frame)
    else
      adapted_frame = _adapter
    end
    adapted_frame.attach_frame(frame)
    adapted_frame.raise
    @pages[_name]={'frame'=>adapted_frame, 'file'=>_file, 'text'=>_title, 'image' => _image, 'raisecmd'=>_raise_proc}
    adapted_frame
  end

  def delete_page(_name)
    if @usetabs
      @enb.delete(_name)
    end
    adapter_frame = @pages.delete(_name)['frame']
    adapter_frame.frame.destroy if adapter_frame.frame
    adapter_frame.destroy 
  end

  def page_bind(_event, _proc)
    @page_binds[_event] = _proc
    if @usetabs
      @enb.tabbind_append("Button-3",_proc)
      @parent.root.top_text_bind_remove("Button-3")   
    else
      @parent.root.top_text_bind_append("Button-3", _proc)   
    end    
  end

  def page(_name)
    @pages[_name]
  end
  
  def page_frame(_name)
    if @usetabs
      @enb.get_frame(_name)
    else
      @pages[_name]['frame'] if @pages[_name]
    end    
  end
  
  def page_name(_frame)
    res = nil
    @pages.each{|k,v|
      res = k if v['frame'] == _frame
      break if !res.nil?
    }
    res
  end
  
  def raise(_page=nil)
    if @usetabs
      if _page.nil?
        @raised_page = @enb.raise
      else  
        @enb.raise(_page)
      end
    else
      if _page.nil?
        @raised_page
      else
        if @raised_page
          @pages[@raised_page]['frame'].unpack if @pages[@raised_page]
        end
        @raised_page = _page
        @pages[_page]['frame'].pack('fill'=>'both', :padx=>0, :pady=>0, :expand => 'yes')
        @pages[_page]['raisecmd'].call
      end
    end
    @raised_page
  end
  
  def raised?(_name)
    @raised_page==_name
  end
  
  def see(_page)
    if @usetabs
      @enb.see(_page) 
    else
    end
  end
  
  def move(_name, _pos)
    if @usetabs
      @enb.move(_name,_pos) if _pos
    else
    end
  end
  
end

class HighlightScanner
  
  def initialize(_langs_conf)
    @langs_conf = _langs_conf
    @lang=@langs_conf['language'].to_sym if @langs_conf['language']
  end
  
  def highlight_tags(_row_begin,_code)
  end
  
  def classes
    if !defined?(@h_classes)
      @h_classes = @langs_conf["#{@langs_conf['scanner']}.classes"].split(',')
    end
    @h_classes
  end
end

class ReHighlightScanner < HighlightScanner
  def initialize(_langs_conf)
    super(_langs_conf)
    @h_re = Hash.new
    @op_to_end_line = Array.new
    @op_to_end_line.concat(@langs_conf['re_op.to_line_end'].split(',')) if @langs_conf['re_op.to_line_end']

    @op_only_first = Array.new
    @op_only_first.concat(@langs_conf['re_op.only_first'].split(',')) if @langs_conf['re_op.only_first']
    
    self.classes.each{|c|
      @h_re[c]=Regexp::new(@langs_conf["re.#{c}"].strip) if @langs_conf["re.#{c}"]
    }
  end


  def find_tag(_tag, _row, _line_txt)
    _txt = _line_txt
    to_ret = []
    _re = @h_re[_tag]
    m = _re.match(_txt)
    _end = 0
#    index = _line_txt.index("oldaccel1")
#    stampa = index && index >0
#    stampa=true
#    p "_line_txt=#{_line_txt}" if stampa
#    p "_tag=#{_tag}" if stampa
    while m && (_txt=m.post_match)
      if !defined?(_old_txt) || _txt != _old_txt
        b1 = _line_txt[m.begin(0)+_end-1..m.begin(0)+_end-1]
        b2 = _line_txt[m.begin(0)+_end..m.begin(0)+_end]
        e1 = _line_txt[m.end(0)+_end..m.end(0)+_end]        
        e2 = _line_txt[m.end(0)-1+_end..m.end(0)+_end-1]
        achar = ["\s","\t","\n",nil,')',']','}','',':','=',">","<"]
        
        ok = (achar.include?(b1)||achar.include?(b2)) && (achar.include?(e1)||achar.include?(e2))
        ok = ok || _line_txt[m.begin(0)+_end..m.end(0)+_end-1].strip.length==1
        
        

#        p "" if stampa
#        p "_line_txt[m.begin(0)+_end..m.begin(0)+_end]=#{_line_txt[m.begin(0)+_end..m.begin(0)+_end]}"   if stampa
#        p "_line_txt[m.end(0)+_end..m.end(0)+_end]=#{_line_txt[m.end(0)+_end..m.end(0)+_end]}"   if stampa
#        p "_line_txt[m.begin(0)+_end..m.end(0)+_end]=#{_line_txt[m.begin(0)+_end..m.end(0)+_end]}"   if stampa
#        p "ok=#{ok}"  if stampa
        
        if ok
          _old_txt = _txt
          _ibegin = _row.to_s+'.'+(m.begin(0)+_end).to_s
          _end = m.end(0) + _end  
          _iend = _row.to_s+'.'+(_end.to_s)
          to_ret << [_ibegin, _iend]
        end
        if @op_only_first.include?(_tag) && ok
          m = nil
        else
          m = _re.match(_txt)
        end
      else
        m = nil
      end
    end
    to_ret
  end
  
  def highlight_tags(_row_begin,_code,_classes=self.classes)
    super(_row_begin,_code)
    tags_map = Hash.new 
    lines = _code.split("\n")
    lines.each_with_index{|_line,_i|
      _line+="\n"
      _row = _row_begin+_i
      #p "_row=#{_row}-_line=#{_line}"
      _txt = _line
      _end = 0
      @op_to_end_line.each{|c|
        if _classes.include?(c) && @h_re[c]
          m_c = @h_re[c].match(_txt)
          if m_c then
            _ibegin = _row.to_s+'.'+(m_c.begin(0)).to_s
            _iend = _row.to_s+'.'+(_line.length - 1).to_s
            tags_map[c] = [] if tags_map[c].nil?
            tags_map[c] << [_ibegin, _iend]
            _txt = m_c.pre_match
          end
        end
      } if @langs_conf['re_op.to_line_end']
  
      _classes.each{|c|
        if !@op_to_end_line.include?(c) && @h_re[c]
          _tags = find_tag(c, _row, _txt)
          if _tags.length >0
            tags_map[c] = [] if tags_map[c].nil?
            tags_map[c].concat(_tags)
          end
        end
      } if _txt.strip.length > 0  
    }
    tags_map
  end
end
  
class CoderayHighlightScannerOld < HighlightScanner
  def initialize(_langs_conf)
    super(_langs_conf)
    require 'coderay'
  end
#  def highlight_tags(_row_begin,_code)
#    super(_row_begin,_code)
#    case @lang
#      when :ruby
#        _highlight_tags_ruby(_row_begin,_code)
#    end
#  end
  def highlight_tags(_row_begin,_code)
    super(_row_begin,_code)
    c_scanner = CodeRay::Scanners[@lang].new _code
    row=_row_begin
    col=0
    tags_map = Hash.new 
    c_scanner.tokens.each{|tok|
      #p tok
      if tok[1]==:space && tok[0].include?("\n")
        row+=tok[0].count("\n")
        begin_gap = tok[0].split("\n")[-1]
        if begin_gap && tok[0][-1..-1]!="\n"
          col = begin_gap.length
        else
          col = 0
        end
      elsif !([:open,:close].include?(tok[0])&& tok[1].class==Symbol)
        toklength = tok[0].length
        t_begin="#{row}.#{col}"
        if tok[0].include?("\n")
          ar = tok[0].split
          row+=tok[0].count("\n")

          begin_gap = ar[-1]
          if begin_gap && tok[0][-1..-1]!="\n"
            col = begin_gap.length
          else
            col = 0
          end
        else
          col+=toklength
        end
        t_end="#{row}.#{col}"
        if tok[1]!=:space
          tags_map[tok[1]] = [] if tags_map[tok[1]].nil?
          tags_map[tok[1]] << [t_begin,t_end]
          #Arcadia.console(self, 'msg'=>"#{tok[1]}=#{[t_begin,t_end]}", 'level'=>'error')          
          #p [t_begin,t_end]
        end
      end  
    }
    tags_map
  end
end

class CoderayHighlightScanner < HighlightScanner

  def initialize(_langs_conf)
    super(_langs_conf)
    require 'coderay'
  end

  def highlight_tags(_row_begin,_code)
    super(_row_begin,_code)
    c_scanner = CodeRay::Scanners[@lang].new _code
    row=_row_begin
    col=0
    tags_map = Hash.new 
    c_scanner.tokens.each{|t|
      #p tok
      if @i.nil?
        @tok = []
        @tok << t
        @i = 1
        next
      else
        @tok << t
        @i = nil
      end 
      tok = @tok
      
      #p tok
      
      if tok[1]==:space && tok[0].include?("\n")
        row+=tok[0].count("\n")
        begin_gap = tok[0].split("\n")[-1]
        if begin_gap && tok[0][-1..-1]!="\n"
          col = begin_gap.length
        else
          col = 0
        end
      elsif !([:open, :close, :begin_group,:end_group].include?(tok[0])&& tok[1].class==Symbol)
        toklength = tok[0].length
        t_begin="#{row}.#{col}"
        if tok[0].include?("\n")
          ar = tok[0].split("\n")
          row+=tok[0].count("\n")
          begin_gap = ar[-1]
          if begin_gap && tok[0][-1..-1]!="\n"
            col = begin_gap.length
          else
            col = 0
          end
        else
          col+=toklength
        end
        t_end="#{row}.#{col}"
        if tok[1]!=:space
          tags_map[tok[1]] = [] if tags_map[tok[1]].nil?
          tags_map[tok[1]] << [t_begin,t_end]
          #Arcadia.console(self, 'msg'=>"#{tok[1]}=#{[t_begin,t_end]}", 'level'=>'error')          
          #p [t_begin,t_end]
        end
      end  
    }
    tags_map
  end
end


class AgMultiEditor < ArcadiaExtPlus
  include Configurable
#  attr_reader :breakpoints
  attr_reader :splitted_frame
#  attr_reader :outline_bar
  attr_reader :has_ctags, :ctags_string
  def on_before_build(_event)
    Arcadia.is_windows? ? @ctags_string="lib/ctags.exe" : @ctags_string='ctags'
    @has_ctags = !Arcadia.which(@ctags_string).nil?
    if !@has_ctags
      msg = "\"ctags\" package is required by class browsing, without it only ruby language is supported!" 
      ArcadiaProblemEvent.new(self, "type"=>ArcadiaProblemEvent::DEPENDENCE_MISSING_TYPE,"title"=>"Ctags missing!", "detail"=>msg).go!
    end
    @breakpoints =Array.new
    @tabs_file =Hash.new
    @tabs_editor =Hash.new
    @raw_buffer_name = Hash.new 
    @editor_seq=-1
    @editors =Array.new
    initialize_status
    #@statusbar_item.pack('side'=>'left','anchor'=>'e','expand'=>'yes')
    Arcadia.attach_listener(self, BufferEvent)
    Arcadia.attach_listener(self, DebugEvent)
  #  Arcadia.attach_listener(self, RunRubyFileEvent)
    Arcadia.attach_listener(self, RunCmdEvent)
  # Arcadia.attach_listener(self, StartDebugEvent)
    Arcadia.attach_listener(self, FocusEvent)
  end
  
#  def on_before_run_ruby_file(_event)
#    _filename = _event.file
#    if _filename.nil?
#      current_editor = self.raised
#       if current_editor
#         if current_editor.file
#           _event.file = current_editor.file
#           _event.persistent = true
#         else
#           _event.file = current_editor.create_temp_file
#         end
#       end
#    end
#  end
  
  def on_before_run_cmd(_event)
    _filename = _event.file
    _event.persistent = true
    if _filename.nil? || _filename == "*CURR"
      current_editor = self.raised
      if current_editor
        if current_editor.file
          _event.file = current_editor.file
        else
          _event.persistent = false
          _event.file = current_editor.create_temp_file
          _event.title = current_editor.tab_title
        end
      end
      # here insert persistent entry of runner instance
      bn = File.basename(_event.file) 
      if _event.persistent && _event.runner_name && Arcadia.persistent("runners.#{bn}").nil?
        entry_hash = Hash.new
        entry_hash[:runner]= _event.runner_name
        entry_hash[:file]= _event.file
        entry_hash[:dir]= _event.dir if _event.dir
        entry_hash[:title]= "#{bn}"
        
        Arcadia.persistent("runners.#{bn}", entry_hash.inspect)
        # here add new menu' item
        mr = Arcadia.menu_root('runcurr')
        if mr
          _command = proc{
              _event = Arcadia.process_event(
              RunCmdEvent.new(self, entry_hash)
            )
          }
          exts = ''
          run = Arcadia.runner(entry_hash[:runner])
          if run
            file_exts = run[:file_exts]
          end
          
          mr.insert('0', 
            :command ,{
              :image => Arcadia.file_icon(file_exts),
              :label => entry_hash[:title],
              :compound => 'left',
              :command => _command
            }
          )
        end
      end
    end
   
    if _event.file  == "*LAST"
      _event.file = Arcadia.persistent('run.file.last')
      _event.cmd = Arcadia.persistent('run.cmd.last')
    else
      if _event.dir.nil?
        _event.dir = File.dirname(_event.file)
      end
      
      if _event.cmd.nil?
        if _event.runner_name
          runner = Arcadia.runner(_event.runner_name)
        elsif _event.lang && Arcadia.runner_for_lang(_event.lang)
          runner = Arcadia.runner_for_lang(_event.lang)
        else
          runner = Arcadia.runner_for_file(_event.file)
        end
        if runner
          _event.cmd = runner[:cmd]
        else
          _event.cmd = _event.file
        end        
      end
      if _event.file && _event.cmd.include?('<<RUBY>>')
        _event.cmd = _event.cmd.gsub('<<RUBY>>',Arcadia.ruby)
      end
      if _event.file && _event.cmd.include?('<<FILE>>')
        _event.cmd = _event.cmd.gsub('<<FILE>>',_event.file)
      end
      if _event.dir && _event.cmd.include?('<<DIR>>')
        _event.cmd = _event.cmd.gsub('<<DIR>>',_event.dir)
      end
      if _event.file && _event.cmd.include?('<<FILE_BASENAME_WITHOUT_EXT>>')
        _event.cmd = _event.cmd.gsub('<<FILE_BASENAME_WITHOUT_EXT>>',File.basename(_event.file).split('.')[0])
      end
      if _event.file && _event.cmd.include?('<<FILE_BASENAME>>')
        _event.cmd = _event.cmd.gsub('<<FILE_BASENAME>>',File.basename(_event.file))
      end
    end 
    _event.title = _event.file if _event.title.nil?
  end
  
#  def on_before_start_debug(_event)
#    _filename = _event.file
#    if _filename.nil?
#      current_editor = self.raised
#      _event.file =current_editor.file if current_editor
#    end
#  end

  def on_build(_event)
#    self.frame.hinner_frame.bind_append("Enter", proc{activate})
    @usetabs = conf('use-tabs')=='yes'
    @main_frame = AgMultiEditorView.new(self.frame, @usetabs)
    @@outline_bar = AgEditorOutlineToolbar.new(self) if !defined?(@@outline_bar)
    create_find # this is the "find within current file" one
    begin
      pop_up_menu
    rescue RuntimeError => e
      Arcadia.runtime_error(e)
    end
    frame.root.add_button(
      self.name,
      'Close current',
      proc{self.activate;Arcadia.process_event(CloseCurrentTabEvent.new(self))}, 
      CLOSE_DOCUMENT_GIF)
    frame.root.add_sep(self.name, 1)
    @buffer_number = TkVariable.new
    @buffer_number.value = 0
    @buffer_menu = frame.root.add_menu_button(
      self.name, 'files', DOCUMENT_COMBO_GIF, 'right', 
      {'relief'=>:raised, 'borderwidth'=>1, 'compound'=> 'left','anchor'=>'w', 'textvariable'=> @buffer_number, 'width'=>40}).cget('menu')
    load_languages_hash
  end

  def on_activate_instance(_event)
    if _event.name == @name
      refresh_status
      _e = raised
      change_outline(_e, true) if  _e      
    end
  end

  def outline_bar
    @@outline_bar
  end

  def add_buffer_menu_item(_filename, is_file=true)
    @buffer_number.numeric += 1
    index = 'end'
    i_end = @buffer_menu.index('end')
    if i_end
      0.upto(i_end){|j|
        type = @buffer_menu.menutype(j)
        if type != 'separator'
          #label = @buffer_menu.entrycget(j,'label')
          #if label > _filename
          value = @buffer_menu.entrycget(j,'value').to_s
          if value > _filename
            index=j
            break
          end
        end
      }
    end
    
    @buffer_menu.insert(index,:radio,
      :label=>File.basename(_filename),
      :value=>_filename,
      :image=> Arcadia.file_icon(_filename),
      :compound=>'left',
      :command=>proc{
        if is_file
          open_file(_filename)
        else
          open_buffer(tab_name(_filename))             
        end
      },
      :hidemargin => true
    )
  end

  def del_buffer_menu_item(_file)
    @buffer_number.numeric -= 1
    to_del = -1
    i_end = @buffer_menu.index('end')
    0.upto(i_end){|j|
      type = @buffer_menu.menutype(j)
      if type != 'separator'
        #label = @buffer_menu.entrycget(j,'label')
        #if label == _file
        value = @buffer_menu.entrycget(j,'value')
        if value == _file
          to_del=j
          break
        end
      end
    }
    @buffer_menu.delete(to_del) if to_del != -1
  end

  def mod_buffer_menu_item(_file, _newtext, _newvalue = nil)
    to_mod = -1
    i_end = @buffer_menu.index('end')
    0.upto(i_end){|j|
      type = @buffer_menu.menutype(j)
      if type != 'separator'
        value = @buffer_menu.entrycget(j,'value')
        if value == _file
          to_mod=j
          break
        end
      end
    }
    @buffer_menu.entryconfigure(to_mod, 'label'=>_newtext) if to_mod != -1
    if to_mod != -1 && _newvalue != nil
      is_file = File.exists?(_newvalue)
      @buffer_menu.entryconfigure(to_mod, 
        :value => _newvalue,
        :image=> Arcadia.file_icon(_newvalue),
        :command=>proc{
          if is_file
            open_file(_newvalue)
          else
            open_buffer(tab_name(_newvalue))             
          end
        }
      )
    end
  end

  def refresh_selected_buffer_menu_item
    i_end = @buffer_menu.index('end')
    p_name =  @main_frame.raise
    if @tabs_editor[p_name] && @tabs_editor[p_name].file
      to_select = @tabs_editor[p_name].file
    else
      to_select = unname_modified(tab_title_by_tab_name(p_name))
    end
    0.upto(i_end){|j|
      type = @buffer_menu.menutype(j)
      if type != 'separator'
        value = @buffer_menu.entrycget(j,'value')
        if value == to_select
          @buffer_menu.entryconfigure(j, 'state'=>'disabled')
        else
          @buffer_menu.entryconfigure(j, 'state'=>'normal')
        end
      end
    }
  end

  def on_initialize(_event)
    self.open_last_files
    reset_status if @main_frame.pages.empty?
  end

  def on_exit_query(_event)
    _event.can_exit=true
    @tabs_editor.each_value{|editor|
      _event.can_exit = can_close_editor?(editor)
      if !_event.can_exit
        _event.break
        break 
      end
    }
  end

  def on_after_focus(_event)
    if raised && _event.focus_widget == raised.text
      if [CutTextEvent, PasteTextEvent, UndoTextEvent, RedoTextEvent].include?(_event.class)
        if raised.highlighting
          raised.refresh_visible_highlighting
        else
          raised.check_modify
        end      
      end
    end
  end
  
  def highlight_scanner(_ext=nil)
    return nil if _ext.nil?
    scanner = nil
    @highlight_scanner_hash = Hash.new if !defined?(@highlight_scanner_hash)
    lh = language_hash_by_ext(_ext)
    if lh && lh['language'] && lh['scanner']  
      if @highlight_scanner_hash[lh['language']].nil?
        case lh['scanner']
          when 'coderay'
            @highlight_scanner_hash[lh['language']]=CoderayHighlightScanner.new(lh)
          when 're'
            @highlight_scanner_hash[lh['language']]=ReHighlightScanner.new(lh)
        end
      end
      scanner = @highlight_scanner_hash[lh['language']]
    end
    scanner
  end

  def load_languages_hash
    @langs_hash_by_ext = Hash.new
    @langs_hash_by_lang = Hash.new
    lang_files_dir = "#{File.dirname(__FILE__)}/langs"
    files = Dir["#{lang_files_dir}/*"].sort
  	 files.each{|lang_file|
      af = lang_file.split('.')
      if af[-1] == 'lang'
    	   lang_props = properties_file2hash(lang_file)
        if lang_props && lang_props['@include'] != nil
          include_file = "#{lang_files_dir}/#{lang_props['@include']}"
          if File.exist?(include_file)
            include_hash = properties_file2hash(include_file)
            lang_props = include_hash.merge(lang_props)
          end
        end 
        self.resolve_properties_link(lang_props, Arcadia.instance['conf']) if lang_props
        lang = lang_props['language']
        lang_exts = lang_props['exts'].split(',').collect{|x| x.strip} if lang_props['exts']
        @langs_hash_by_lang[lang] = lang_props if lang
        lang_exts.each{|ext|
          @langs_hash_by_ext[ext] = lang_props
        } if lang_exts
      
      
      
      end
    }
  end

  def language_hash_by_ext(_ext=nil)
    @langs_hash_by_ext[_ext]
  end

  def language_hash_by_lang(_lang=nil)
    @langs_hash_by_lang[_lang]
  end

#  def languages_hash(_ext=nil)
#    @langs_hash = Hash.new if !defined?(@langs_hash)
#    return nil if _ext.nil?
#    if @langs_hash[_ext].nil?
#      #_ext='' if _ext.nil?
#      lang_file = File.dirname(__FILE__)+'/langs/'+_ext+'.lang'
#      if File.exist?(lang_file)
#        @langs_hash[_ext] = properties_file2hash(lang_file)
#      elsif File.exist?(lang_file+'.bind')
#        b= properties_file2hash(lang_file+'.bind')
#        if b 
#          if @langs_hash[b['bind']].nil?
#            lang_file_bind = File.dirname(__FILE__)+'/langs/'+b['bind']+".lang"
#            if File.exist?(lang_file_bind)
#              @langs_hash[b['bind']]=properties_file2hash(lang_file_bind)
#              @langs_hash[_ext]=@langs_hash[b['bind']]
#            end
#          else
#            @langs_hash[_ext]=@langs_hash[b['bind']]
#          end
#        end
#      end
#      if @langs_hash[_ext] && @langs_hash[_ext]['@include'] != nil
#        include_file = "#{File.dirname(__FILE__)}/langs/#{@langs_hash[_ext]['@include']}"
#        if File.exist?(include_file)
#          include_hash = properties_file2hash(include_file)
#          @langs_hash[_ext] = include_hash.merge(@langs_hash[_ext])
#        end
#      end 
#      self.resolve_properties_link(@langs_hash[_ext], Arcadia.instance['conf']) if @langs_hash[_ext]
#    end
#    @langs_hash[_ext]
#  end


  def pop_up_menu
    @pop_up = TkMenu.new(
      :parent=> self.frame.hinner_frame,
      :tearoff=>0,
      :title => 'Menu'
    )
    @pop_up.extend(TkAutoPostMenu)
    @pop_up.configure(Arcadia.style('menu'))
    #Arcadia.instance.main_menu.update_style(@pop_up)


    @c = @pop_up.insert('end',
      :command,
      :label=>'Close',
      #:font => conf('font'),
      :hidemargin => false,
      :command=> proc{
        if @selected_tab_name_from_popup != nil
          _e = @tabs_editor[@selected_tab_name_from_popup]
          self.close_editor(_e) if _e
        end
      }
    )
    @c = @pop_up.insert('end',
      :command,
      :label=>'Close others',
      #:font => conf('font'),
      :hidemargin => false,
      :command=> proc{
        if @selected_tab_name_from_popup != nil
          _e = @tabs_editor[@selected_tab_name_from_popup]
          self.close_others_editor(_e)
        end
      }
    )
    @c = @pop_up.insert('end',
      :command,
      :label=>'Close all',
      #:font => conf('font'),
      :hidemargin => false,
      :command=> proc{
        if @selected_tab_name_from_popup != nil
          _e = @tabs_editor[@selected_tab_name_from_popup]
          self.close_all_editor(_e)
        end
      }
    )

    @pop_up.insert('end',
      :command,
      :label=>'...',
      :state=>'disabled',
      :background=>Arcadia.conf('titlelabel.background'),
      :font => "#{Arcadia.conf('menu.font')} bold",
      :hidemargin => false
    )

    @main_frame.page_bind("Button-3",
      proc{|*x|
        _x = TkWinfo.pointerx(@main_frame.root_frame)
        _y = TkWinfo.pointery(@main_frame.root_frame)
        if @usetabs
          @selected_tab_name_from_popup = x[0].split(':')[0]
        else
          @selected_tab_name_from_popup = @main_frame.raise
        end
        _index = @main_frame.index(@selected_tab_name_from_popup)
        if _index == -1 
          @selected_tab_name_from_popup = 'ff'+@selected_tab_name_from_popup
          _index = @main_frame.index(@selected_tab_name_from_popup)
        end

        if _index != -1 
          _file = @tabs_file[(@selected_tab_name_from_popup)] # full path of file
          @pop_up.entryconfigure(3, 'label'=> _file)
          @pop_up.popup(_x,_y+10)
        end
      })
  end


#  def do_debug_event(_event)
    #@arcadia.outln('_sender ----> '+_sender.to_s)	  
    #@arcadia.outln('_event.signature ----> '+_event.signature)
#    case _event.signature 
#      when DebugContract::DEBUG_BEGIN
#        self.debug_begin
#      when DebugContract::DEBUG_END
#        self.debug_end
#      when DebugContract::DEBUG_STEP
#        if _event.context.file
#          self.open_file_in_debug(_event.context.file, _event.context.line)
#        end
#    end
#  end

  def on_before_step_debug(_event)
    debug_reset
  end

  def on_before_debug(_event)
    case _event
      when StartDebugEvent
        _event.persistent=true
        _filename = _event.file
        if _filename  == "*LAST"
          _event.file = Arcadia.persistent('run.file.last')
        elsif _filename.nil? || _filename == "*CURR"
          current_editor = self.raised
          if current_editor
            if current_editor.file
              _event.file=current_editor.file
            else
              _event.file=current_editor.create_temp_file
              _event.id=current_editor.id
              _event.persistent=false
            end
          end
        end
        self.debug_begin
      when SetBreakpointEvent
        if _event.active == 1
          if _event.file
            @breakpoints << {:file=>_event.file,:line=>_event.row}
            _e = @tabs_editor[tab_file_name(_event.file)]
          elsif _event.id
            @breakpoints << {:file=>"__TMP__#{_event.id}",:line=>_event.row}
            _e = @editors[_event.id]
          end
          if _e
            _index =_event.row+'.0'
            _line = _e.text.get(_index, _index+ '  lineend')
            _event.line_code = _line.strip if _line
            _e.add_tag_breakpoint(_event.row) 
          else
            # TODO: 
            _line = File.readlines(_event.file)[_event.row.to_i-1]
            _event.line_code = _line.strip if _line
          end
        end
    end  
  end
  
  def on_after_debug(_event)
    case _event
      when StepDebugEvent
        if _event.command == :quit_yes 
          self.debug_end
        elsif _event.command == :quit_no 
          @last_e.mark_debug(@last_index) if @last_e
        end
#      when SetBreakpointEvent
#        if _event.active == 1
#          @breakpoints << {:file=>_event.file,:line=>_event.row}
#          _e = @tabs_editor[tab_file_name(_event.file)]
#          _e.add_tag_breakpoint(_event.row) if _e
#        end
      when UnsetBreakpointEvent
        #p "ae-editor : UnsetBreakpointEvent file : #{_event.file}"
        #p "ae-editor : UnsetBreakpointEvent _event.row : #{_event.row}"
        if _event.file
          @breakpoints.delete_if{|b| (b[:file]==_event.file && b[:line]==_event.row)}
          _e = @tabs_editor[tab_file_name(_event.file)]
        elsif _event.id
          @breakpoints.delete_if{|b| (b[:file]=="__TMP__#{_event.id}" && b[:line]==_event.row)}
          _e = @editors[_event.id]
        end
        _e.remove_tag_breakpoint(_event.row) if _e
    end
  end
  
  def on_debug_step_info(_event)
    #Arcadia.new_debug_msg(self, "file: #{_event.file}:#{_event.row}")
    #Arcadia.console(self, :msg=> "ae-editor -> DebugStepInfoEvent")
    if _event.file
      self.open_file_in_debug(_event.file, _event.row)
    end
    Tk.update
  end

#  def on_before_buffer(_event)
#  Arcadia.new_error_msg(self, "on_before_buffer #{_event.class}")
#  end

  def on_buffer(_event)
    #Arcadia.new_error_msg(self, "on_buffer #{_event.class}")
    case _event
      when NewBufferEvent
        self.open_buffer(nil, nil, nil, _event.lang)
      when OpenBufferEvent
        if _event.file
          if _event.row
            _index = _event.row.to_s+'.0' 
          end
          if _event.kind_of?(OpenBufferTransientEvent) && conf('close-last-if-not-modified')=="yes"
            if defined?(@last_transient_file) && !@last_transient_file.nil? && @last_transient_file != _event.file
              _e = @tabs_editor[tab_name(@last_transient_file)]
              if _e && !_e.modified_from_opening?
                close_editor(_e)
              end
            end
            if !editor_exist?(_event.file)
              @last_transient_file = _event.file
            else
              @last_transient_file = nil
            end
          end
          if _event.select_index.nil?
            select_index = true
          else
            select_index = _event.select_index
          end
          if _event.file == '*CURR'
            er = raised
            if er && _index != nil
              er.text_see(_index)
              er.mark_selected(_index) if select_index
            end   
          else
            self.open_file(_event.file, _index, select_index)
          end
        elsif _event.text
          if _event.title 
            _tab_name = self.tab_name(_event.title)
            self.open_buffer(_tab_name, _event.title)
            _e = @tabs_editor[_tab_name]
            _e.text_insert('end',_event.text)
            _e.reset
            _e.refresh
            #add_reverse_item(_e)
          end
        else
          _event.file = Arcadia.open_file_dialog
          self.open_file(_event.file)
        end
      when CloseBufferEvent
        if _event.file
          self.close_file(_event.file)
        end
      when SaveAsBufferEvent
        if _event.file == nil
          self.raised.save_as
        else
          self.save_as_file(_event.file)          
        end
        _event.new_file = self.raised.file
      when SaveBufferEvent
        if _event.file == nil && _event.title == nil 
          self.raised.save
        elsif _event.file != nil
          self.save_file(_event.file)
        elsif _event.title != nil
          self.save_file(_event.title)
        end
      when SearchBufferEvent
        if _event.what == nil
          @find.show
        end
      when GoToLineBufferEvent
        if _event.line == nil
          @find.show_go_to_line_dialog
        end
      when CloseCurrentTabEvent
         close_raised
      when PrettifyTextEvent
#        require 'rbeautify.rb' # gem
#        self.raised.save # so we can beautify it kludgely here...
#        path = raised.file
#        RBeautify.beautify_file(path)
#        self.raised.reload

        rbea = RBeautify.beautify_string(raised.text_value_lines)
        if rbea && rbea.length >1 && !rbea[1]
          raised.text_replace_value_with(rbea[0])
        else
          msg = "Problems in prettify #{raised.tab_title}"
          Arcadia.dialog(self, 
            'type'=>'ok', 
            'title' => "(Arcadia) code prettify", 
            'msg'=>msg,
            'level'=>'error')
        end
        
      when MoveBufferEvent
        if _event.old_file && _event.new_file && editor_exist?(_event.old_file)
          #close_file(_event.old_file)
          change_file(_event.old_file, _event.new_file)          
        end
    end
  end

  def get_find
    @find
  end
  
  def create_find
    @find = Finder.new(@arcadia.layout.root, self)
    @find.on_close=proc{@find.hide}
    @find.hide
  end

  def start_find
    _e = raised
    _e.find if _e
  end

  def show_hide_current_line_numbers
    _e = active_instance.raised
    _e.show_hide_line_numbers if _e
  end

  def show_hide_tabs
    if active? 
      if @usetabs
        @main_frame.switch_2_notabs
        @usetabs = false
        Arcadia['conf']["#{@name}.use-tabs"]='no'
      else
        @main_frame.switch_2_tabs
        @usetabs = true
        Arcadia['conf']["#{@name}.use-tabs"]='yes'
      end
    else
      active_instance.show_hide_tabs
    end
  end

  def on_finalize(_event)
    @batch_files = true
    _files =''
    _raised = self.raised
    Arcadia.persistent("#{@name}.files.last", _raised.file) if _raised
    @tabs_editor.each_value{|editor|
      if editor.file != nil
        #_insert_index = editor.text.index('insert')
        _insert_index = editor.text.index('@0,0')
        _files=_files+'|' if _files.strip.length > 0
        _files=_files + "#{editor.file};#{_insert_index};#{editor.line_numbers_visible.to_s}"
      end
      #p editor.text.dump_tag('0.1',editor.text.index('end'))
      close_editor(editor,true)
    }
    Arcadia.persistent("#{@name}.files.open", _files)
    clear_temp_files
#    _breakpoints = '';
#    @breakpoints.each{|point|
#      if point[:file] != nil
#        _breakpoints=_breakpoints+'|' if _breakpoints.strip.length > 0
#        _breakpoints=_breakpoints + "#{point[:file]}@@@#{point[:line]}"
#      end
#    }
#    Arcadia.persistent('editor.debug_breakpoints', _breakpoints)
    @batch_files = true
  end


  def clear_temp_files
    files = Dir[File.join(Arcadia.instance.local_dir,"*")]
    files.each{|f|
      if File.stat(f).file? && File.basename(f)[0..1] == '~~'
        File.delete(f)
      elsif File.stat(f).directory? && File.basename(f)[0..1] == '~~'
        Dir[File.join(f,"*")].each{|file|
          File.delete(file)
        }
        Dir.delete(f)        
      end
    }
  end

  def raised
    if @main_frame
      _page = @main_frame.raise
      return @tabs_editor[resolve_tab_name(_page)]
    else
      nil
    end
  end

  def close_raised
    _e = @tabs_editor[resolve_tab_name(@main_frame.raise)]
    close_editor(_e) if _e
  end

  def breakpoint_add(_file,_line,_id=-1)
    Arcadia.process_event(SetBreakpointEvent.new(self, 'id'=>_id, 'file'=>_file, 'row'=>_line, 'active'=>1))
  end

  def breakpoint_del(_file,_line,_id=-1)
    Arcadia.process_event(UnsetBreakpointEvent.new(self, 'id'=>_id, 'file'=>_file, 'row'=>_line))
  end

  def breakpoint_lines_on_file(_file)
    result = Array.new
    @breakpoints.each{|value|
      if value[:file]==_file
        result << value[:line]
      end
    }
    return result
  end
  
  def on_layout_raising_frame(_event)
    if _event.extension_name == "editor" && _event.frame_name=="editor_outline"
      _e = raised
      change_outline(_e, true) if  _e
    end
  end

#  def update(_kind,_name)
#    if _kind == 'RAISE' && _name == 'editor'
#      _e = raised
#      change_outline(_e) if  _e
#    end
#  end

  def open_last_files
    @batch_files = true
    if Arcadia.persistent("#{@name}.files.open")
      _files_index =Arcadia.persistent("#{@name}.files.open").split("|")
      _files_index.each do |value| 
        _file,_index,_line_numbers_visible_as_string = value.split(';')
        if _file && _index
          ed = open_file(_file,_index,false)
        else
          ed = open_file(_file)
        end
        if ed && _line_numbers_visible_as_string && ed.line_numbers_visible
          ed.line_numbers_visible = _line_numbers_visible_as_string == 'true'
        end
      end
    end
    @batch_files = false
    to_raise_file = Arcadia.persistent("#{@name}.files.last")
    if to_raise_file
      raise_file(to_raise_file,0)
    else
      _first_page = @main_frame.pages[0] if @main_frame.pages.length > 0
      if _first_page
        @main_frame.raise(_first_page) if frame_def_visible?
        @main_frame.see(_first_page)
      end
    end
    main_instance.frame(1)
    Arcadia.attach_listener(self, LayoutRaisingFrameEvent)
    self
  end
  
  def bookmark_add(_file, _index)
    if @bookmarks == nil
      @bookmarks = Array.new
      @bookmarks_index = - 1 
    else
      _cur_file, _cur_index = @bookmarks[@bookmarks_index]
      if _cur_file == _file && _cur_index == _index
        #@arcadia.outln('uguale ----> '+_file+':'+_index)
        return 
      end
      @bookmarks = @bookmarks[0..@bookmarks_index]
    end
    @bookmarks << [_file, _index]
    @bookmarks_index = @bookmarks.length - 1
    #@arcadia.outln('add ----> '+_file+':'+_index)
  end

  def bookmark_clear
    @bookmarks.clear
    @bookmarks_index = - 1
  end

  def bookmark_next
    return if @bookmarks == nil || @bookmarks_index >= @bookmarks.length - 1
    bookmark_move(+1)
  end

  def bookmark_move(_n=0)
    @bookmarks_index = @bookmarks_index + _n
    #Tk.messageBox('message'=>@bookmarks_index.to_s)
    _file, _index = @bookmarks[@bookmarks_index]
    _line, _col = _index.split('.') if _index
    open_file(_file, _index)
    #openfile(@bookmarks[@bookmarks_index])
  end


  def bookmark_prev
    return if @bookmarks == nil || @bookmarks_index <= 0
    bookmark_move(-1)
  end


#  def get_tab_from_name(_name=nil)
#    return @main_frame.enb.get_frame(_name)
#  end
  
  def name_read_only(_name)
    '[READ-ONLY] '+_name
  end

  def unname_read_only(_name)
    return _name.gsub("[READ-ONLY] ",'')
  end

  def name_modified(_name)
    '(...)'+_name
  end

  def unname_modified(_name)
    return _name.gsub("(...)",'')
  end
  
  
  def change_tab_set_read_only(_tab)
    _new_name = name_read_only(@main_frame.page_title(page_name(_tab)))
    change_tab_title(_tab, _new_name)
  end

  def change_tab_reset_read_only(_tab)
    _new_name = unname_read_only(@main_frame.page_title(page_name(_tab)))
    if _new_name
      change_tab_title(_tab, _new_name)
    end
  end


  def change_tab_set_modify(_tab)
    change_tab_title(_tab, name_modified(@main_frame.page_title(page_name(_tab))))
  end

  def tab_title(_tab)
    @main_frame.page_title(page_name(_tab))
  end

  def tab_title_by_tab_name(_tab_name)
    @main_frame.page_title(resolve_tab_name(_tab_name))
  end

  def tab_name(_str="")
    tn = 'ff'+_str.downcase.gsub("/","_").gsub(".","__").gsub(":","___").gsub("\\","____").gsub("*","_____")
    resolve_tab_name(tn)
  end
  
  def tab_file_name(_filename="")
    _fstr = File.expand_path(_filename)
    _fstr =  _filename if _fstr == nil
    tab_name(_fstr)
  end
  
  def page_name(_page_frame)
    @main_frame.page_name(_page_frame)
#    pn = TkWinfo.appname(_page_frame).sub('f','')
#    resolve_tab_name(pn)
  end
  
  def resolve_tab_name(_tab_name)
    if @raw_buffer_name[_tab_name]
      return @raw_buffer_name[_tab_name]
    else
      return _tab_name
    end 
  end
  
  def change_tab_reset_modify(_tab)
    #_new_name = @main_frame.enb.itemcget(@tabs_name[_tab], 'text').gsub!("(...)",'')
    if @main_frame.index(@main_frame.page_name(_tab))
	    _new_name = unname_modified(@main_frame.page_title(page_name(_tab)))
     	if _new_name
        change_tab_title(_tab, _new_name)
     	end
    end
  end

  def change_frame_caption(_name, _new_caption)
    if @arcadia.layout.headed?
      if frame.root.title == frame.title
        frame.root.top_text(@main_frame.page(_name)['text'], @main_frame.page(_name)['image']) if @main_frame.page(_name)
        frame.root.top_text_hint(_new_caption)
      end  
      frame.root.save_caption(frame.name, @main_frame.page(_name)['text'], @main_frame.page(_name)['image'])
    end
  end

  
  def change_outline_frame_caption(_new_caption)
    if @arcadia.layout.headed?
      if main_instance.frame(1).root.title == main_instance.frame(1).title
        main_instance.frame(1).root.top_text(_new_caption)
      end  
      main_instance.frame(1).root.save_caption(frame.name, _new_caption)
    end
  end

  def change_tab_title(_tab, _new_text, _new_file=nil)
    p_name = page_name(_tab)
    old_text = @main_frame.page_title(p_name)

    if @tabs_editor[p_name] && @tabs_editor[p_name].file
      mod_buffer_menu_item(@tabs_editor[p_name].file, _new_text, _new_file)
    else
      mod_buffer_menu_item(unname_modified(tab_title_by_tab_name(p_name)), _new_text)
    end
#    mod_buffer_menu_item(@main_frame.page(p_name)['file'], _new_text)
    @main_frame.page_title(p_name, _new_text)
  end

  def change_tab_icon(_tab, _new_text)
    @main_frame.page_title(page_name(_tab), nil, Arcadia.file_icon(_new_text))
  end

  def change_file(_old_file, _new_file)
    _tab_name=tab_file_name(_old_file)
    _tab = @main_frame.page_frame(_tab_name)
    e =  @tabs_editor[_tab_name]
    change_file_name(_tab, _new_file)
    e.new_file_name(_new_file) if e
  end

  def change_file_name(_tab, _new_file)
    @tabs_file[page_name(_tab)] = _new_file
    @raw_buffer_name[tab_file_name(_new_file)]=page_name(_tab)
    _new_label = File.basename(_new_file)
    change_tab_title(_tab, _new_label, _new_file)
    change_tab_icon(_tab, _new_label)
    #change_frame_caption(_new_file)
    #@tabs_editor[tab_file_name(_new_file)]=@tabs_editor[page_name(_tab)]

    #@tabs_file[tab_file_name(_new_file)] = _new_file
    #@tabs_editor[tab_file_name(_new_file)] = editor_of(_new_file)
  end

  def debug_begin
    if @editors_in_debug != nil
      @editors_in_debug.clear
    else
      @editors_in_debug = Array.new
    end
  end

  def debug_end
    #debug_reset
    @editors_in_debug.each{|e|
      close_editor(e)
      #p "close editor #{e.file}"
    }
  end

  def debug_reset
    if @last_index && @last_e
      @last_e.unmark_debug(@last_index)
    end
  end
  
  def open_file_in_debug(_filename=nil, _line=nil)
    #debug_reset
    if _filename && _line && File.exists?(_filename)
      @last_index = _line.to_s+'.0'
      #_editor_exist = editor_exist?(_filename)
      _editor = editor_of(_filename)
      if _editor
        @last_e = raise_editor(_editor, @last_index, false, false)
      else
        @last_e = open_file(_filename, @last_index, false, false)
      end
      #@last_e.hide_exp
      @last_e.mark_debug(@last_index) if @last_e
      #if !_editor_exist
      if _editor.nil?
        @editors_in_debug <<  @last_e
        # workaround for hightlight
        #p "add editor for close #{_filename}"
        @last_e.do_line_update
      end
    else
      p "file #{_filename} do not exist !"
    end
  end
  
  def change_outline(_e, _raised=false)
    return if defined?(@@last_outline_e) && @@last_outline_e == _e
    _raised = _raised || main_instance.frame(1).raised?
    if !@batch_files && _raised
      @@last_outline_e.hide_outline if defined?(@@last_outline_e)
      if _e && _e.file
        change_outline_frame_caption(File.basename(_e.file))
      end
      _e.show_outline
      @@last_outline_e = _e
    end
  end
  
  def do_buffer_raise(_name, _title='...')
    _index = @main_frame.index(resolve_tab_name(_name))
    _new_caption = '...'
    if _index != -1
      _e = @tabs_editor[resolve_tab_name(_name)]
      change_outline(_e) if _e
      if _e && _e.file != nil
        _new_caption = _e.file
        @find.use(_e)
        _e.check_file_last_access_time
      else
        _new_caption = _title
      end
      _lang = _e.lang
      _e.update_toolbar
    end
    change_frame_caption(_name, _new_caption)
    refresh_status
    _title = @tabs_file[_name] != nil ? File.basename(@tabs_file[_name]) :_name
    Arcadia.broadcast_event(BufferRaisedEvent.new(self, 'title'=>_title, 'file'=>@tabs_file[_name], 'lang'=>_lang ))
    Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>_e.text)) if _e
    refresh_selected_buffer_menu_item
    #EditorContract.instance.buffer_raised(self, 'title'=>_title, 'file'=>@tabs_file[_name])
  end
  
  def initialize_status
    if !defined?(@@statusbar_items)
      @@statusbar_items = Hash.new
      @@statusbar_items['file_size'] = Arcadia.new_statusbar_item("File size")
      @@statusbar_items['file_mtime'] = Arcadia.new_statusbar_item("File modification time")
      @@statusbar_items['file_name'] = Arcadia.new_statusbar_item("File name")
    end
  end

  def reset_status
    @@statusbar_items['file_name'].text = '?'
    @@statusbar_items['file_mtime'].text =  '?'
    @@statusbar_items['file_size'].text = '?' 
  end
  
  def refresh_status
    #@statusbar_item.text("#{_title} | #{_e.file_info['mtime'].strftime("%d/%m/%Y %H:%m:%S") if _e}")
    if raised && raised.file
      size = File.size(raised.file)
      if size > 1024
        size_str = "#{size/1024} kb"
      else
        size_str = "#{size} b"      
      end
      @@statusbar_items['file_name'].text(File.basename(raised.file))
      @@statusbar_items['file_mtime'].text =  raised.file_info['mtime'].localtime
      @@statusbar_items['file_size'].text = size_str 
      #@statusbar_item.text("#{File.basename(raised.file)} | #{raised.file_info['mtime'].localtime} | #{size_str}")
    else
      reset_status
    end
  end
  
  def editor_of(_filename)
    _ret = nil
    @editors.each{|e|
      if e.file == _filename || e.last_tmp_file == _filename
        _ret = e
        break
      end
    } 
    if _ret.nil?
      _basefilename = File.basename(_filename)
      _name = self.tab_file_name(_filename)
      _index = @main_frame.index(resolve_tab_name(_name))
      if _index == -1
        _name = name_read_only(_name)
        _index = @main_frame.index(resolve_tab_name(_name))
      end
      if _index != -1
        _ret = @tabs_editor[resolve_tab_name(_name)]
      end
    end
    _ret
  end
  
  def editor_exist?(_filename)
    _basefilename = File.basename(_filename)
    #_basename = _basefilename.split('.')[0]+'_'+_basefilename.split('.')[1]
    
    _name = self.tab_file_name(_filename)
    _index = @main_frame.index(resolve_tab_name(_name))
    if _index == -1
      _index = @main_frame.index(resolve_tab_name(name_read_only(_name)))
    end
    if _index == -1
      @editors.each{|e|
        if e.last_tmp_file == _filename
          _index = 0
          break
        end
      } 
    end
    return _index != -1
  end
  
  def raise_file(_filename=nil, _pos=nil)
    if _filename && frame_def_visible?
      tab_name=self.tab_file_name(_filename)
      if  @main_frame.index(tab_name) != -1
          @main_frame.move(tab_name,_pos) if _pos
          @main_frame.raise(tab_name)
          @main_frame.see(tab_name)
      end
    end    
  end
  
  def open_file(_filename = nil, _text_index='1.0', _mark_selected=true, _exp=true)
    return if _filename == nil || !File.exist?(_filename) || File.ftype(_filename) != 'file'
    _basefilename = File.basename(_filename)
    _tab_name = self.tab_file_name(_filename)
    #_index = @main_frame.enb.index(_tab_name)
    #_exist_buffer = _index != -1
    _exist_buffer = @tabs_file[_tab_name] != nil
    if _exist_buffer
      open_buffer(_tab_name)
    else
      @tabs_file[_tab_name]= _filename
      open_buffer(_tab_name, _basefilename, _filename)
      @tabs_editor[_tab_name].reset_highlight
      begin
        @tabs_editor[_tab_name].load_file(_filename)
      rescue RuntimeError => e
        #Arcadia.dialog(self,'type'=>'ok', 'level'=>'error','title' => 'RuntimeError', 'msg'=>"RuntimeError : #{e.message}")
        #p "RuntimeError : #{e.message}"
        close_editor(@tabs_editor[_tab_name], true)
        Arcadia.runtime_error(e)
      end
      change_outline_frame_caption(File.basename(_filename)) if _filename    
    end
    editor = @tabs_editor[_tab_name]
    if _text_index != nil && _text_index != '1.0' && editor
      editor.text_see(_text_index)
      editor.mark_selected(_text_index) if _mark_selected 
    end

    return editor
  end


  def open_buffer(_buffer_name = nil, _title = nil, _filename=nil, _lang=nil)
    _index = @main_frame.index(resolve_tab_name(_buffer_name))
    if _buffer_name == nil
    		_title_new = '*new'
    		tmp_buffer_num = 0
    		_buffer_name = tab_name(_title_new)
    		#_buffer_name = tab_name('new')
    end
    
    if _index != -1
      _tab = @main_frame.page_frame(resolve_tab_name(_buffer_name))
      @main_frame.raise(resolve_tab_name(_buffer_name)) if frame_visible?
    else
      _n = 1
      while @main_frame.index(_buffer_name) != -1
        _title_new = '*new'+_n.to_s
        tmp_buffer_num = _n
        _buffer_name = tab_name(_title_new)
        #_buffer_name = tab_name('new')+_n.to_s
        _n =_n+1
      end
      if _title == nil
        _title =  _title_new
        if _lang
          _image = Arcadia.lang_icon(_lang)
        else
          _image = Arcadia.lang_icon('Ruby')
        end  
        _ext = language_hash_by_lang(_lang)
      else
        _image = Arcadia.file_icon(_title)
      end
      _tab = @main_frame.add_page(_buffer_name, _filename, _title, _image, proc{do_buffer_raise(_buffer_name, _title)})
#      _tab = @main_frame.enb.insert('end', _buffer_name ,
#        'text'=> _title,
#        'image'=> _image,
# #       'image'=> Arcadia.file_icon(lang_sign),
#        'background'=> Arcadia.style("tabpanel")["background"],
#        'foreground'=> Arcadia.style("tabpanel")["foreground"],
#        'raisecmd'=>proc{do_buffer_raise(_buffer_name, _title)}
#      )
      @raw_buffer_name[_buffer_name]=_buffer_name
      if _filename
        add_buffer_menu_item(_filename)
      else
        add_buffer_menu_item(_title, false)
      end
      _e = AgEditor.new(self, _tab)
      @editor_seq=@editor_seq+1
      _e.id=@editor_seq
      @editors[@editor_seq]=_e
      ext = Arcadia.file_extension(_title)
      ext='rb' if ext.nil?
      _e.initialize_editing(ext, _lang)
      _e.text.set_focus
      #@tabs_file[_buffer_name]= nil
      @tabs_editor[_buffer_name]=_e
    end
    begin
      if raised != @tabs_editor[resolve_tab_name(_buffer_name)]
        @main_frame.move(resolve_tab_name(_buffer_name), 0)
        @main_frame.raise(resolve_tab_name(_buffer_name)) if frame_visible?
        @main_frame.see(resolve_tab_name(_buffer_name))
      else
        @main_frame.move(resolve_tab_name(_buffer_name), 0)
      end
    rescue Exception => e
      Arcadia.runtime_error(e)
    end
    return _tab
  end

  def raise_editor(_editor = nil, _text_index='0.0', _mark_selected=true, _exp=true)
    return if _editor == nil
    _tab_name = nil
    @tabs_editor.each{|tn,e|
      if e == _editor
        _tab_name = tn
      end
    }
    if _tab_name
      _index = @main_frame.index(resolve_tab_name(_tab_name))
      _exist_buffer = _index != -1
      if _exist_buffer
        open_buffer(_tab_name)
        if _text_index != nil && _text_index != '0.0'
          _editor.text_see(_text_index)
          _editor.mark_selected(_text_index) if _mark_selected 
        end
      end
    end
    return _editor
  end

  def close_others_editor(_editor, _mod=true)
    @batch_files = true
  		@tabs_editor.values.each do |_e|
  		    close_editor(_e) if _e != _editor
  		end
    @batch_files = false
  end

  def close_all_editor(_editor, _mod=true)
    @batch_files = true
  		@tabs_editor.values.each do |_e|
  		    close_editor(_e)
  		end
    @batch_files = false
  end
  
  def can_close_editor?(_editor)
    ret = true
    if _editor.modified?
      filename = page_name(_editor.page_frame)
      message = @main_frame.page_title(filename)+"\n modified. Save?"
      r=Arcadia.dialog(self,
          'type'=>'yes_no_cancel', 
          'level'=>'warning',
          'title'=> 'Confirm saving', 
          'msg'=>message)
      if r=="yes"
        _editor.save
        ret = !_editor.modified?
      elsif r=="cancel"
        ret = false
      end
    elsif _editor.modified_by_others?
      filename = page_name(_editor.page_frame)
      message = @main_frame.page_title(filename)+"\n modified by other process. Continue closing?"
      r=Arcadia.dialog(self,
          'type'=>'yes_no', 
          'level'=>'warning',
          'title'=> 'Continue closing', 
          'msg'=>message)
      if r=="yes"
        _editor.reset_file_last_access_time
        refresh_status
        ret = !_editor.modified_by_others?
      else
        ret = false
        #raise_file(filename) 
      end
    end
    ret
  end

  def close_editor(_editor, _force=false)
    if _force || can_close_editor?(_editor)
      file = _editor.file
      index = _editor.text.index("@0,0")
      r,c = index.split('.')
      _editor.destroy_outline
      change_outline_frame_caption('') if raised==_editor      
      close_buffer(_editor.page_frame)
      BufferClosedEvent.new(self,'file'=>file,'row'=>r.to_i, 'col'=>c.to_i).shot!
    else
      return
    end
  end

  def close_buffer(_page_frame)
    _name = page_name(_page_frame)
    if @tabs_editor[_name] && @tabs_editor[_name].file
      del_buffer_menu_item(@tabs_editor[_name].file)
    else
      del_buffer_menu_item(unname_modified(tab_title_by_tab_name(_name)))
    end
    @tabs_editor.delete(_name)
    @tabs_file.delete(_name)
    @raw_buffer_name.delete_if {|key, value| value == _name }  
   
    _index = @main_frame.index(_name)
    @main_frame.delete_page(_name)
    if !@main_frame.pages.empty?
      @main_frame.raise(@main_frame.pages[_index-1]) if TkWinfo.mapped?(@main_frame.root_frame)
    else
      frame.root.top_text_clear if TkWinfo.mapped?(frame.hinner_frame)
      reset_status
    end
  end

  def close_file(_filename)
    _e = @tabs_editor[tab_name(_filename)]
    close_editor(_e) if _e
  end

  def save_file(_filename)
    @tabs_editor[tab_name(_filename)].save
  end

  def save_as_file(_filename)
    @tabs_editor[tab_name(_filename)].save_as
  end

  def accept_complete_code
    @ok_complete = true
    if !defined?(@ok_complete)
    
msg =<<EOS
"Complete code" is actually based on rcodetools 
that exec code for retreave candidades. 
So it can be dangerous for example if you write system call. 
Do you want to activate it?
EOS
      @ok_complete = Arcadia.dialog(self, 
        'level'=>'warning',
        'type'=>'yes_no', 
        'title' => '(Arcadia) Complete code', 
        'msg'=>msg.upcase)=='yes'
      
    end
    return @ok_complete
  end


end

class Findview < TkFloatTitledFrame
  def initialize(_parent)
    super(_parent)
    #stop_resizing
 	  y0 = 10
    d = 23    
    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text 'Find what:'
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
    @e_what = Tk::BWidget::ComboBox.new(self.frame, Arcadia.style('combobox')){
      editable true
      justify  'left'
      #relief  'ridge'
      autocomplete 'true'
      expand 'tab'
      takefocus 'true'
      #pack('padx'=>10, 'fill'=>'x')
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_what_entry = TkWinfo.children(@e_what)[0]

    #@e_what_entry.bind_append("1",proc{Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>@e_what_entry))})
    @e_what_entry.extend(TkInputThrow)


    y0 = y0 + d
    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text 'Replace with:'
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
   
    @e_with = Tk::BWidget::ComboBox.new(self.frame, Arcadia.style('combobox')){
      editable true
      justify  'left'
      autocomplete 'true'
      expand 'tab'
      takefocus 'true'
      #pack('padx'=>10, 'fill'=>'x')
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
    }
    @e_with_entry = TkWinfo.children(@e_with)[0]
    #@e_with_entry.bind_append("1",proc{Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>@e_with_entry))})
    @e_with_entry.extend(TkInputThrow)
    y0 = y0 + d
    @cb_reg = TkCheckButton.new(self.frame, Arcadia.style('checkbox')){|_cb_reg|
      text  'Use Regular Expression'
      justify  'left'
      #relief  'flat'
      #pack('side'=>'left', 'anchor'=>'e')
      place('x' => 8,'y' => y0,'height' => 22)
    }
    y0 = y0 + d
    @cb_back = TkCheckButton.new(self.frame, Arcadia.style('checkbox')){|_cb_reg|
      text  'Search backwards'
      justify  'left'
      #relief  'flat'
      #pack('side'=>'left', 'anchor'=>'e')
      place('x' => 8,'y' => y0,'height' => 22)
    }
    y0 = y0 + d
    @cb_ignore_case = TkCheckButton.new(self.frame, Arcadia.style('checkbox')){|_cb_reg|
      text  'Ignore case'
      justify  'left'
      #relief  'flat'
      #pack('side'=>'left', 'anchor'=>'e')
      place('x' => 8,'y' => y0,'height' => 22)
    }
    
    y0 = y0 + d
    y0 = y0 + d
    y0 = y0 + d
    @buttons_frame = TkFrame.new(self.frame, Arcadia.style('panel')).pack('fill'=>'x', 'side'=>'bottom')	

    @b_replace_all = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
    		state 'disabled'
      default  'disabled'
      text  'Replace All'
      #overrelief  'raised'
      justify  'center'
      #width 15
      pack('side'=>'right','ipadx'=>5, 'padx'=>5)
      #place('width' => 50,'x' => 0,'y' => y0,'height' => 23,'bordermode' => 'inside')
    }


    @b_replace = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
    		state 'disabled'
      default  'disabled'
      text  'Replace'
      #overrelief  'raised'
      justify  'center'
      #width 15
      pack('side'=>'right','ipadx'=>5, 'padx'=>5)
      #place('width' => 50,'x' => 0,'y' => y0,'height' => 23,'bordermode' => 'inside')
    }

    
    @b_go = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
      compound  'none'
      default  'disabled'
      text  'Find Next'
      #background  '#ffffff'
      #image TkPhotoImage.new('dat' => FIND_GIF)
      #overrelief  'raised'
      justify  'center'
      #relief  'ridge'
      #width 15
      pack('side'=>'right','ipadx'=>5, 'padx'=>5)
      #place('width' => 50,'x' => 0,'y' => y0,'height' => 23,'bordermode' => 'inside')
    }
    #place('x'=>0,'y'=>0,'relheight'=> 1,'relwidth'=> 1)
    place('x'=>100,'y'=>100,'height'=> 240,'width'=> 300)
    
  end

  def show
    super
    self.focus
    @e_what.focus
    @e_what_entry.select_throw
    @e_what_entry.selection_range(0,'end')
  end

  
end

class Finder < Findview
  attr_reader :e_what
  def initialize(_frame, _controller)
    super(_frame)
    #@l_file.configure('text'=>_title)
    #Tk.tk_call('wm', 'title', self, _title )
    @controller = _controller
    @forwards = true
    @find_action = proc{
      do_find_next
      hide
    }
    @b_go.bind('1', @find_action)
    
  	 @b_replace.bind('1', proc{do_replace})  
    
  	 @b_replace_all.bind('1', proc{do_replace_all})  

    @e_what_entry.bind_append('KeyRelease'){|e|
      case e.keysym
      when 'Return'
        @find_action.call
        Tk.callback_break
      else
        widget_state
      end
    }
    e2 =  TkWinfo.children(@e_with)[0]
    e2.bind_append('KeyPress'){|e|
        widget_state
    }
    @last_index='insert'
    
    @goto_line_dialog = GoToLine.new(_frame).hide
    @goto_line_dialog.on_close=proc{@goto_line_dialog.hide}

    @goto_line_dialog.b_go.bind('1',proc{go_line})
    @goto_line_dialog.e_line.bind_append('KeyRelease'){|e|
      case e.keysym
      when 'Return'
        go_line
        Tk.callback_break
      end
    }

  end

  def do_replace
    if do_find_next
        _message = 'Replace "'+@e_what.value+'" with "'+@e_with.value+'" ?'
        if TkDialog2.new('message'=>_message, 'buttons'=>['Yes','No']).show() == 0
          self.editor.text.delete(@idx1,@idx2)
          self.editor.text.insert(@idx1,@e_with.value)
          self.editor.check_modify
        end
    end
  end

  def do_replace_all
    while do_find_next
        _message = 'Replace "'+@e_what.value+'" with "'+@e_with.value+'" ?'
        _rc = TkDialog2.new('message'=>_message, 'buttons'=>['Yes','No','Annulla']).show()
        if _rc == 0
          self.editor.text.delete(@idx1,@idx2)
          self.editor.text.insert(@idx1,@e_with.value)
          self.editor.check_modify
        elsif _rc == 2
          break
        end
    end
  end
  
  def widget_state
   		if (@e_what.value.length > 0) && (@e_with.value.length > 0)
   			@b_replace.configure('state'=>'active')
   			@b_replace_all.configure('state'=>'active')
   		else
   			@b_replace.configure('state'=>'disabled')
   			@b_replace_all.configure('state'=>'disabled')
   		end
  end


  def editor
    if @editor_caller == nil
      @editor_caller = @controller.raised
    end
    return @editor_caller
  end

  def show_go_to_line_dialog
    use(@controller.raised)
    @goto_line_dialog.show
  end

  def go_line
    if @goto_line_dialog.e_line.value.length > 0
      _row = @goto_line_dialog.e_line.value
      _index = _row.strip+'.1'
      self.editor.text.see(_index)
      self.editor.text.tag_remove('selected','1.0','end')
      self.editor.text.tag_add('selected',_index,_index+' lineend')
      #self.editor.text.tag_add('sel', _index,_index+' lineend')
      self.editor.text.set_insert(_index)
      @controller.bookmark_add(self.editor.file, _index)
    @goto_line_dialog.hide
    end
    #self.hide()
  end

  def use(_editor)
    if (_editor != @editor_caller)
      @last_index='insert'
      @editor_caller = _editor
      _title = '?'
      _title = File.basename(_editor.file) if _editor.file  
      title(_title)
      @goto_line_dialog.title(_title) if @goto_line_dialog
    end
  end

  def show
    super
    use(@controller.raised)
  end

  def update_combo(_txt)
    values = @e_what.cget('values')
    if (values != nil && !values.include?(_txt))
      @e_what.insert('end', @e_what.value)
    end
  end

  def do_find(_istart=nil)
    @forwards =  @cb_back.cget('onvalue') != @cb_back.cget('variable').value.to_i
    _found = false
    @idx1 = nil
    @idx2 = nil
    if @e_what.text.length > 0
      update_combo(@e_what.text)
      if !_istart && self.editor.text.index('insert')!=nil
        _istart ='insert'
      elsif defined?(@last_index)
      		_istart = @last_index
      else
        _istart = '1.0'
      end
      
      # propagate some search options
      options = []
      if !@forwards
        options << 'backwards'
      end
      if @cb_reg.cget('onvalue')==@cb_reg.cget('variable').value.to_i
        options << 'regexp'
      end
      if @cb_ignore_case.cget('onvalue')==@cb_ignore_case.cget('variable').value.to_i
        options << 'nocase'
      end
      _index = self.editor.text.tksearch(options,@e_what.text,_istart)
      
      if _index && _index.length>0
        self.editor.text.see(_index)
        _row, _col = _index.split('.')
        _index_sel_end = _row.to_i.to_s+'.'+(_col.to_i+@e_what.text.length).to_i.to_s
        if @forwards
          @last_index= _index_sel_end
        else
          @last_index= _row.to_i.to_s+'.'+(_col.to_i-1).to_i.to_s
        end
        self.editor.text.tag_add('sel', _index,_index_sel_end)
        self.editor.text.set_insert(_index)
        @idx1 =_index
                @idx2 =_index_sel_end
        _found = true
        @controller.bookmark_add(self.editor.file, _index)
      else
        _message = '"'+@e_what.value+'" not found'
        TkDialog2.new('message'=>_message, 'buttons'=>['Ok']).show()
      end

    else
      self.show()
    end
    self.editor.text.focus
    return _found
  end

  def do_find_next
    if @idx1 != nil
    		self.editor.text.tag_remove('sel',@idx1,@idx2)
    end
    do_find(@last_index)
  end
end



class CodeInsight
end

class GoToLine < TkFloatTitledFrame
  attr_reader :e_line
  attr_reader :b_go 
  def initialize(_parent)
    super(_parent)
    #stop_resizing
 	  y0 = 10
    d = 23    
    TkLabel.new(self.frame, Arcadia.style('label')){
   	  text 'Go to line:'
   	  place('x' => 8,'y' => y0,'height' => 19)
    }
    y0 = y0 + d
   	@e_line = TkEntry.new(self.frame, Arcadia.style('edit')){
      justify  'left'
      #relief  'ridge'
      place('relwidth' => 1, 'width'=>-16,'x' => 8,'y' => y0,'height' => 19)
   	}
    #@e_line.bind_append("1",proc{Arcadia.process_event(InputEnterEvent.new(self,'receiver'=>@e_line))})
    @e_line.extend(TkInputThrow)
    
   	y0 = y0 + d
   	y0 = y0 + d
    @buttons_frame = TkFrame.new(self.frame, Arcadia.style('panel')).pack('fill'=>'x', 'side'=>'bottom')	
    
    @b_go = TkButton.new(@buttons_frame, Arcadia.style('button')){|_b_go|
      compound  'none'
      default  'disabled'
      text  'Go'
      #overrelief  'raised'
      #justify  'center'
      pack('side'=>'right','ipadx'=>5, 'padx'=>5)
    }
    place('x'=>150,'y'=>150,'height'=> 120,'width'=> 240)
    
  end
  
  def show
    super
    self.focus
    @e_line.focus
    @e_line.select_throw
    @e_line.selection_range(0,'end')
  end
end