# -*- coding: utf-8 -*-

# This is a mapping from owner name to remote name, origin should always
# be the user using this task. THIS NEEDS TO BE CHANGED TO BE MORE FLEXIBLE.

GithubUser = `git config --get github.user`.chomp

ProjectCfg =
  YAML.load(File.open(File.dirname(__FILE__) + "/projects.adtekio.yml").read)

# Hashmap from the github user name to remote name. Remote names should
# be first name and not the github user name. Also the 'origin' remote becomes
# automagically the fork of the github user, so pushs go the local repo.
RepoRemotes =
  Hash[ProjectCfg["forkmap"].
       map { |k,v| k == GithubUser ? [k,'origin'] : [k,v] }]

ReposProjectDesc =
  Hash[ProjectCfg["repos"].
       map { |k,v| [k, (v[:deprecated] ? "(D) " : "") +
                    v[:description] + (v[:travis] ? " (T)" : "")]}]

RepoHerokuMap =
  Hash[ProjectCfg["repos"].
       reject {|_,v| v[:heroku].nil? }.
       map { |k,v| [k, v[:heroku]] }]

GistRepos =
  Hash[ProjectCfg["repos"].
       select {|_,v| !v[:gist].nil? }]

ForksMap =
  Hash[ProjectCfg["repos"].
       select {|_,v| v[:gist].nil? }.
       map { |k,v| [k, v[:forks] || []] }]

missing_repos = ((ForksMap.keys - ReposProjectDesc.keys) +
                 (ReposProjectDesc.keys - ForksMap.keys) -
                 GistRepos.keys).uniq

unless missing_repos == []
  abort((<<-EOF).remove_indent)
    Sorry but there appears to be an issue with your ForkMaps and
    repo definitions.

    #{missing_repos}
  EOF
end

GithubOwner = ProjectCfg['github']['owner']

namespace :project do
  _C = Term::ANSIColor

  namespace :adtekio do
    desc <<-EOF
      Describe the work flow.
    EOF
    task :workflow do
      output_help((<<-EOF).remove_indent)
        From http://scottchacon.com/2011/08/31/github-flow.html

          1. Anything in the master branch is deployable
          2. To work on something new, create a descriptively named branch off of
             master (ie: new-oauth2-scopes)
          3. Commit to that branch locally and regularly push your work to the same
             named branch on the server
          4. When you need feedback or help, or you think the branch is ready for
             merging, open a pull request
          5. After someone else has reviewed and signed off on the feature, you
             can merge it into master

        Once it is merged and pushed to ‘master’, you can and should deploy immediately
      EOF
    end

    dev_task <<-EOF
      Provide details on gemset and ruby version.
    EOF
    task :rvmrc do
      str = ReposProjectDesc.collect do |name, _|
        file = File.join(name, ".ruby-version")
        unless File.exists?(file)
          "%s: %s" % [ _C.yellow(name.ljust(20)), _C.red('not using rvm')]
        else
          rvm_details = rvm_parse(File.open(file))
          gemset = File.open(File.join(name, ".ruby-gemset")).read.chomp rescue ""

          s = "%s (%s) %s %s" % [ rvm_details[:ruby_version].ljust(8),
                                  rvm_details[:ruby_release].center(8),
                                  rvm_details[:ruby_patch].ljust(8),
                                  gemset.ljust(20) ]
          "%s: %s" % [ _C.yellow(name.ljust(20)), s]
        end
      end.join("\n")

      puts "#{'='*25} #{_C.white("Rvmrc details".center(20))} #{'='*24}"
      s = "%s (%s) %s %s" % [ "Version".ljust(8), "Release".center(8),
                              "Patch".ljust(8), "Gemset".ljust(20) ]
      puts _C.on_red(_C.white("%s: %s" % [ "Project".ljust(20), s]))
      puts str
    end

    dev_task <<-EOF
      Provide a description of all our git repos.
    EOF
    task :desc do
      str = ReposProjectDesc.collect do |name, desc|
        "%s: %s" % [ _C.yellow(name.ljust(20)), desc]
      end.join("\n")
      output_help(str)
    end

    dev_task <<-EOF
      Git status and branch of each project.
    EOF
    task :status do
      ReposProjectDesc.each do |name, _|
        puts "======= #{_C.yellow(name)}"
        tmpstat=`cd #{name} && git status && cd ..`
        tmpstat = case true
                  when !!(tmpstat =~ /working directory clean/)
                    _C.green('clean')
                  when !!(tmpstat =~ /Untracked files:/)
                    _C.blue('untracked files')
                  when !!(tmpstat =~ /Changes not staged for commit/)
                    _C.magenta('commit needed')
                  else
                    puts tmpstat
                    _C.red("UNKNOWN")
                  end
        brcnt=`git --git-dir=#{name}/.git branch | wc -l`.strip
        currbr=`git --git-dir=#{name}/.git branch | grep '^*'`.gsub(/[*]/,'').strip
        clr = currbr == "master" ? "green" : "white"
        puts "  Current Branch: #{_C.send(clr,currbr)}"
        puts "        Branches: #{brcnt}"
        puts "          Status: #{tmpstat}"
      end
    end

    dev_task <<-EOF
      Clone all applications.
    EOF
    task :setup_git => "git:tools" do
      ReposProjectDesc.each do |gitrepo,_|
        check_gitignore_for(gitrepo)
        git_clone_repo(gitrepo, GithubOwner)
        setup_repo(gitrepo)
      end

      puts "=✓= updating #{_C.yellow('this repo')}"
      gitobj = Grit::Repo.new(".")
      setup_hub(gitobj)
      setup_origin_and_master_for_toplevel(gitobj)
      setup_commit_hook(".")
    end

    dev_task <<-EOF
      All that needs to be done to be onboarded.
    EOF
    task :onboard => [:setup_git] do
      output_help((<<-EOF).remove_indent)
        You should now have all the repos you require. In addition you'll need access
        to the following sites:

          https://github.com/#{GithubOwner} - master of all masters

        Bookmark these links in a project folder.
      EOF
    end
  end
end
