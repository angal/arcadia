# In this file init configuration
load_ok=true
if load_ok
begin
  require 'rubygems' # for a few dependencies
rescue LoadError => e
load_ok=false
print <<EOL
 ----------------------------------------------
       *** LOAD ERROR ***
 ----------------------------------------------
       Arcadia require rubygems     
       you must install before run ...       
 ----------------------------------------------
EOL
end
end

if load_ok
begin
  require 'tk'
rescue LoadError => e
load_ok=false
print <<EOL
 ----------------------------------------------
       *** LOAD ERROR ***
 ----------------------------------------------
       Arcadia require ruby-tk extension     
       and tcl/tk run-time                   
       you must install before run ...       
 ----------------------------------------------
EOL
end
end

if !load_ok
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
 ----- LoadError Details-----------------------
    Platform : "#{RUBY_PLATFORM}"          
    Ruby version : "#{RUBY_VERSION}"
    Message : 
    "#{msg}"
 ----------------------------------------------
EOL
exit
end
Tk.tk_call "eval","set auto_path [concat $::auto_path tcl]"
#Tk.tk_call "eval","set tk_strictMotif true"