# In this file init configuration

begin
  require 'tk'
rescue LoadError => e
print <<EOL
 ----------------------------------------------
       Arcadia require ruby-tk extension     
       and tcl/tk run-time                   
       you must install before run ...       
 ----------------------------------------------
EOL
i=30
l=i
msg=e.message
while l < msg.length
  while l < msg.length-1 && msg[l..l]!="\s"
    l=l+1
  end
  msg = msg[0..l]+"\n"+"\s"*4+msg[l+1..-1]
  l=l+i
end
print <<EOL
 ---Tk LoadError Details-----------------------
    Platform : "#{RUBY_PLATFORM}"          
    Ruby version : "#{RUBY_VERSION}"
    Message : 
    "#{msg}"
 ----------------------------------------------
EOL
exit
end

Tk.tk_call "eval","set auto_path [concat $::auto_path tcl]"