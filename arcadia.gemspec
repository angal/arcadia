# gemspec for Arcadia
# Antonio Galeone (antonio-galeone@rubyforge.org)
 	
require 'rubygems'
  SPEC = Gem::Specification.new do |s|
  s.name = "arcadia"
  s.version = "0.8.0"
  s.date = "2009-07-22"
  s.author = "Antonio Galeone"
  s.email = "antonio-galeone@rubyforge.org"
  s.homepage = "http://arcadia.rubyforge.org"
  s.rubyforge_project = "arcadia"  
  s.platform = Gem::Platform::RUBY
  s.description = "Arcadia Ruby Ide"
  s.summary = "An light Ide for Ruby written in Ruby using the classic tcl/tk GUI toolkit."
    candidates = Dir.glob("{lib,ext/*,tcl}/**/*")
    candidates << "README"
    candidates << "bin/arcadia"
    candidates << "bin/arcadia.bat"
    candidates << "bin/arc"
    candidates << "conf/arcadia.conf"
    candidates << "conf/arcadia.init.rb"
    candidates << "conf/arcadia.res.rb"
  s.files =  candidates.delete_if do |item|
      item.include?("CVS") || item.include?("rdoc")|| item.include?("cvs")|| item.include?(".git")
  end
  s.bindir = "bin"
  s.executables << "arcadia"
  s.executables << "arc"
  s.default_executable = 'arcadia'
  s.rdoc_options << '--title' << 'Arcadia Documentation' <<  '--main'  << 'README' << '-q'
  s.extra_rdoc_files = ["README"]
#  s.add_dependency("ruby-debug", ">= 0.9.3") # TODO 
#  s.add_dependency("rdp-rbeautify") # prettifier plugin TODO uncomment once published
  s.add_dependency("whichr")
#  s.add_dependency("ruby-wmi") # doesn't build on linux
#  s.add_dependency("win32-process") # same here
end

