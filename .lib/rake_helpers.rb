# -*- coding: utf-8 -*-
def git_clone_repo(gitrepo, owner)
  _C = Term::ANSIColor

  if File.exists?(gitrepo)
    type = is_gist?(gitrepo) ? "gist" : "repo"
    puts "=✓= #{type} #{_C.yellow(gitrepo)} exists"
  else
    puts "=!= cloning #{_C.yellow(gitrepo)}"
    system("git clone #{gitrepo_url(gitrepo, owner)} #{gitrepo}")
  end
end

def gitrepo_url(repo_name, owner)
  if is_gist?(repo_name)
    "git@gist.github.com:#{ProjectCfg["repos"][repo_name][:gist]}.git"
  else
    "git@github.com:#{owner}/#{repo_name}.git"
  end
end

def gitrepo_addr(repo_name, owner)
  gitrepo_url(repo_name,owner).
    sub(/git@/,'https://').sub(/com:/,"com/").sub(/\.git/,'')
end

def travis_logo(repo_name,owner)
  "!https://magnum.travis-ci.com/#{owner}/#{repo_name}.svg?token="+
    "tokenmissing&branch=master!:https://magnum.travis-ci.com"+
    "/#{owner}/#{repo_name}"
end

def travis_logo_opensource(repo_name,owner)
  "!https://travis-ci.org/#{owner}/#{repo_name}.svg?branch=master!:" +
    "https://travis-ci.org/#{owner}/#{repo_name}"
end

def opensource_logo(owner)
  "!https://github.com/#{owner}/init/blob/master/.images/os.png!:http://opensource.org"
end

def heroku_repos_for(gitrepo_name)
  (RepoHerokuMap[gitrepo_name] &&
   RepoHerokuMap[gitrepo_name].to_a) || []
end

def heroku_links(heroku_details, owner)
  heroku_details.map do |remote_name, link|
    name = $1 if link =~ /:(.+)[.]git$/
    hlink = "https://dashboard.heroku.com/apps/#{name}"
    "!.images/heroku.png!:#{hlink}"
  end.join(" ")
end

def deploy_to_heroku(repo_url)
  "!https://www.herokucdn.com/deploy/button.png!:https://heroku.com/deploy?template=#{repo_url}"
end

def config_for(repo, stage)
  File.join(repo, 'config', 'deploy', stage + '.rb')
end

def is_gist?(gitrepo)
  ProjectCfg["repos"][gitrepo] && ProjectCfg["repos"][gitrepo][:gist]
end

def admin_task(str)
  _C = Term::ANSIColor
  desc _C.red('ADMIN') + " #{str.remove_indent}"
end

def dev_task(str)
  _C = Term::ANSIColor
  desc _C.yellow('DEV'.ljust(5)) + " #{str.remove_indent}"
end

def output_help(str)
  _C = Term::ANSIColor
  puts((<<-EOF).remove_indent)
    =========== #{_C.red('Help'.center(18))} ============
    #{str}
    ===========================================
  EOF
end

def rvm_parse(file)
  rvmver, gemset = file.read.gsub(/.*rvm use (--create)?/,'').strip.split(/@/)
  rubyver, rubypatch = rvmver.split(/-/)

  {
    :ruby_release => "",
    :ruby_version => rubyver|| "",
    :ruby_patch   => rubypatch|| "",
    :gemset       => gemset|| "",
  }
end

def setup_repo(gitrepo)
  return unless File.exists?(gitrepo)

  Grit::Repo.new(gitrepo).tap do |gitobj|
    setup_hub(gitobj)

    (remotes_for_repo(gitrepo).map do |owner, remote_name|
       if remote_name =~ /^git[@]/
         [owner, remote_name]
       else
         [remote_name, gitrepo_url(gitrepo, owner)]
       end
     end +
     [["master", gitrepo_url(gitrepo, GithubOwner)]] +
     heroku_repos_for(gitrepo)).
      each do |remote_name, remote_url|
      git_check_remote(gitobj, remote_name, remote_url)
    end

    git_check_origin_and_master(gitobj) unless is_gist?(gitrepo)
  end

  setup_commit_hook(gitrepo)
end

def setup_origin_and_master_for_toplevel(gitobj)
  # toplevel only has two remotes: origin and master.
  _C = Term::ANSIColor
  cfg = Grit::Config.new(gitobj)

  # get reponame, assume that there is a origin url ...
  reponame = $1 if cfg['remote.origin.url'] =~ /\/(.+)[.]git$/
  if reponame.nil? || reponame == ""
    puts " !! #{_C.red('TODO')} reponame not found, quitting..."
    return
  end

  master_url = gitrepo_url(reponame, GithubOwner)
  git_check_remote(gitobj, "master", master_url)

  origin_url = gitrepo_url(reponame, GithubUser)
  git_check_remote(gitobj, "origin", origin_url)
end


def git_check_origin_and_master(gitobj)
  _C = Term::ANSIColor
  cfg = Grit::Config.new(gitobj)

  if cfg['remote.origin.url'] == cfg['remote.master.url']
    puts " !! #{_C.red('TODO')} change the origin remote to your fork of"
    puts " !! #{_C.red('TODO')} the repository --> origin == master currently"
    puts " !! #{_C.red('TODO')} and origin url should be url of developer"
  else
    remoteurl = cfg['remote.origin.url']
    owner = RepoRemotes.select { |_,v| v == 'origin'}.first.first
    if remoteurl =~ /#{owner}/
      puts " ✓ origin remote url is developer fork: #{_C.cyan(remoteurl)}"
    elsif remoteurl.nil?
      puts " !! #{_C.yellow('TODO')} no origin url"
    elsif
      puts " #{_C.red('!!')} origin url incorrect #{_C.cyan(remoteurl)}"
    end
  end
end

def git_check_remote(gitobj, remote_name, remote_url)
  _C = Term::ANSIColor
  cfg = Grit::Config.new(gitobj)
  if gitobj.remote_list.include?(remote_name)
    if remote_url == cfg["remote.#{remote_name}.url"]
      puts " ✓ remote: #{_C.yellow(remote_name)} exists"
    else
      puts " #{_C.red('!!')} resetting url on remote: #{_C.blue(remote_name)}"
      cfg["remote.#{remote_name}.url"] = remote_url
    end
  else
    puts " == creating remote: #{_C.blue(remote_name)}"
    gitobj.remote_add(remote_name, remote_url)
  end
end

def setup_hub(gitobj)
  cfg = Grit::Config.new(gitobj)
  puts " ✓ setting up hub with owner and commands"
  cfg['hub.owner']    = GithubOwner
  cfg['hub.commands'] =
    File.expand_path(File.join(File.dirname(__FILE__), "..", ".hub.d"))
end

def setup_commit_hook(gitrepo_path)
  _C = Term::ANSIColor
  if File.exists?( gitrepo_path )
    hook_name = File.join(gitrepo_path, '.git', 'hooks', 'commit-msg')

    if File.exists?(hook_name)
      puts " ✓ #{_C.cyan('commit-msg hook exist, skipping.')}"
    else
      puts " == installing #{_C.yellow('local commit-msg hook')}"
      hook_dir = File.expand_path(File.join(File.dirname(__FILE__),
                                            "..", ".githooks"))
      FileUtils.ln_s(File.expand_path('commit-msg', hook_dir), hook_name)
    end
  end
end

def remotes_for_repo(repo)
  h = ((m = ForksMap[repo]) && Hash[m.map { |a| [a, RepoRemotes[a]]}].
       merge(GithubUser => "origin")) || RepoRemotes

  h.keys.select { |a| a =~ /^gitrepo\|/ }.each do |keyname|
    h.delete(keyname)
    _,url,name = keyname.split(/\|/)
    h[name] = url
  end

  is_gist?(repo) ? {} : h
end

def check_gitignore_for(dirname)
  `if ! egrep '^#{dirname}/' .gitignore >/dev/null; then echo "#{dirname}/" >> .gitignore ; fi`
end


##
## Helper Classes and monkey patches
##
class String
  def remove_newline(rstr=' ')
    gsub(/[\r\n]/,rstr)
  end

  def remove_indent
    self =~ /\A([ \t]+)/ ? gsub(/\n#{$1}/, "\n").strip : self
  end
end

# Workaround for the broken remote_list of Grit::Repo, see
#   https://github.com/mojombo/grit/issues/91
# for details.
module Grit
  class Repo
    def remote_list
      Grit::Config.new(self).keys.collect do |keyname|
        keyname =~ /^remote[.](.*)[.]url$/ ? $1 : nil
      end.compact
    end
  end
end
