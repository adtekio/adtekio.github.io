# -*- coding: utf-8 -*-
require 'RedCloth'

module ReadmeMacros
  extend self

  def method_missing(method, *args, &block)
    (respond_to?(method) ? send(method) : "!!#{method}!!")+"\n"
  end

  def external_links(attrs)
    links = [attrs[:applink]].flatten.compact.map do |lnk|
      "\"&#128279;\":#{lnk}"
    end.join(" ")
  end

  def repo_to_row(repo_name, owner, attrs)
    name, url = repo_name.sub(/^mops[.]/,''), gitrepo_addr(repo_name, owner)
    (url = "https://gist.github.com/" + attrs[:gist]) if attrs[:gist]

    trvlogo = if attrs[:travis]
                if attrs[:opensource]
                  travis_logo_opensource(repo_name,owner)
                else
                  travis_logo(repo_name,owner)
                end
              end

    herkou_links = attrs[:heroku] ? heroku_links(attrs[:heroku],owner) : ""

    links = external_links(attrs)
    "| \"#{name}\":#{url} | #{attrs[:description]} #{links} #{herkou_links} |" +
      (attrs[:travis] ? " #{trvlogo}" : "") +
      (attrs[:heroku] ? " #{deploy_to_heroku(url)} |" : " &nbsp; |")
  end

  def DeprecatedRepos
    ProjectCfg["repos"].
      select { |_,v| v[:deprecated] }.
      sort_by { |k, _| k }.
      map do |repo_name, attrs|
      links = external_links(attrs)
      desc  = attrs[:description]
      name  = repo_name,
      url   = gitrepo_addr(repo_name, ProjectCfg['github']['owner'])

      (url = "https://gist.github.com/" + attrs[:gist]) if attrs[:gist]
      "* \"#{name}\":#{url} #{desc} #{links}"
    end.join("\n") + "\n"
  end

  def CurrentRepos
    categories = ProjectCfg["repos"].
      reject { |_,v| v[:deprecated] }.map { |_,v| v[:category] }.compact.uniq

    repos = ProjectCfg["repos"].
      reject { |_,v| v[:deprecated] }.sort_by { |k,_| k.sub(/^mops[.]/,'') }

    categories.sort_by(&:to_s).map do |category|
      headline = category.is_a?(String) ? category : category.to_s.capitalize
      ["h2. #{headline}", "",
       repos.
       select { |_,v| v[:category] == category }.
       map do |repo_name, attrs|
         repo_to_row(repo_name, ProjectCfg['github']['owner'], attrs)
       end, ""]
    end.flatten.join("\n") + "\n"
  end
end

namespace :doco do
  namespace :generate do
    desc <<-EOF
      Generate the textile readme from template.
    EOF
    task :"readme.textile" do
      File.open("README.textile","w+") do |file|
        File.open(File.join(File.dirname(__FILE__),"readme.template")).each do |line|
          file << (line =~ /^\[\[(.+)\]\]$/ ? ReadmeMacros.send($1) : line)
        end
      end
    end

    desc <<-EOF
      Generate the README.textile as html.
    EOF
    task :"readme.html" => :"readme.textile" do
      File.open("README.html","w+") do |file|
        file << RedCloth.new(File.open("README.textile").read).to_html
      end
      `open -a Safari README.html`
    end
  end
end
