# -*- coding: utf-8 -*-
require 'rubygems'
require 'bundler/setup'
require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'term/ansicolor'
require 'grit'
require 'fileutils'

Dir[File.join(File.dirname(__FILE__), '.lib', '*.rb')].each { |f| require f }
Dir[File.join(File.dirname(__FILE__), '.lib', '*.rake')].each { |f| load f }

_C = Term::ANSIColor

AllColors = %w(red green yellow blue magenta cyan white)

task :default do
  system('rake -T')
end
