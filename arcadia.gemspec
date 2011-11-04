# gemspec for Arcadia
# Antonio Galeone (antonio-galeone@rubyforge.org)
 	
require 'rubygems'
  SPEC = Gem::Specification.new do |s|
  s.name = "arcadia"
  s.version = "0.11.0"
  s.date = "2011-11-04"
  s.author = "Antonio Galeone"
  s.email = "antonio-galeone@rubyforge.org"
  s.homepage = "http://arcadia.rubyforge.org"
  s.rubyforge_project = "arcadia"  
  s.platform = Gem::Platform::RUBY
  s.description = "Arcadia Ide"
  s.summary = "Light Editor Ide written in Ruby using the classic tcl/tk GUI toolkit."
    candidates = Dir.glob("{lib,ext/*,tcl}/**/*")
    candidates << "README"
    candidates << "bin/arcadia"
    candidates << "bin/arcadia.bat"
    candidates << "bin/arc"
    candidates << "conf/arcadia.conf"
    candidates << "conf/arcadia.init.rb"
    candidates << "conf/arcadia.res.rb"
    candidates << "conf/theme-dark.conf"
    candidates << "conf/theme-dark.res.rb"
  s.files =  candidates.delete_if do |item|
      item.include?("CVS") || item.include?("rdoc")|| item.include?("cvs")|| item.include?(".git")
  end
  s.bindir = "bin"
  s.executables << "arcadia"
  s.executables << "arc"
  s.default_executable = 'arcadia'
  s.rdoc_options << '--title' << 'Arcadia Documentation' <<  '--main'  << 'README' << '-q'
  s.extra_rdoc_files = ["README"]
  s.add_dependency("coderay",">= 1.0.3")
#  s.add_dependency("ruby-debug", ">= 0.9.3") # TODO 
#  s.add_dependency("rdp-rbeautify") # prettifier plugin TODO uncomment once published
#  s.add_dependency("whichr")
#  s.add_dependency("ruby-wmi") # doesn't build on linux
#  s.add_dependency("win32-process") # same here
end