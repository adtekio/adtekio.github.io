require 'pry'

require 'term/ansicolor'

desc "Start a pry shell and load all gems"
task :shell do
  Pry.editor = "emacs"
  Pry.start
end
