_std_ = "ruby"
$*.each{|arg|
  _std_=_std_+" "+arg
}
if Kernel.system(_std_)
  Kernel.system('y')
end
