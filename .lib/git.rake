# -*- coding: utf-8 -*-
namespace :git do
  _C = Term::ANSIColor

  dev_task <<-EOF
    Retrieve some git shortcuts that makes working with multiple repos easier.
  EOF
  task :tools do
    sh_tools_dir, tools_dir = File.join('.shtools'), File.join('.gittools')
    github_gist_host = "https://raw.github.com/gist"
    output_help("Installing git/shell helpers")

    [tools_dir, sh_tools_dir].each do |dirname|
      if File.exists? dirname
        puts " ✓ Exists #{_C.yellow(dirname)}"
      else
        FileUtils.mkdir_p dirname
        puts " == Created #{_C.yellow(dirname)}"
      end
    end

    # commit hook
    # retrieve local commit hook.
    hook_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".githooks"))

    unless File.exists?(hook_dir) && File.exists?(File.join(hook_dir, "commit-msg"))
      FileUtils.mkdir_p hook_dir
      urlstr = "https://gist.githubusercontent.com/gorenje/1012062/raw"+
        "/e2f6ff6cb78bc362fd70c4d936a5f08b253bf5b1/commit-msg-goclone"

      system("wget '#{urlstr}' --no-check-certificate "+
             "-O #{hook_dir}/commit-msg")

      FileUtils.chmod 0755, "#{hook_dir}/commit-msg"
      puts _C.red("ERROR: gawk is required, please install") unless system('which gawk >/dev/null')
    end

    # hub extensions
    giturl = "git://gist.github.com/2621377.git"
    abspath = File.expand_path(File.join(File.dirname(__FILE__),"..",".hub.d"))

    if Dir.exists? abspath
      puts " ✓ Exists #{_C.yellow(abspath)} - updating"
      `cd #{abspath} && git pull`
    else
      puts " ✓ Creating #{_C.yellow(abspath)}"
      `git clone git://gist.github.com/2621377.git #{abspath}`
    end

    # shell tools
    {
      "1339013/e2fde124eb9aa91bc39afb8fd5c615bed2c1b299/find-rails.bash"    => sh_tools_dir,
      "1014155/508d9af8e2fc33ba53af61bc11e3c463752a0b85/git_aliases"        => tools_dir,
      "1031349/d35e24a677e22c0244020afeb223176bac54e8b3/gitosis_init.bash"  => sh_tools_dir,
      "1012002/7ad3b03f1a4d3c8d1210b955bd8dd2d1444e6fa8/git_fetch_all.bash" => sh_tools_dir,
      "1011862/4158749d3e1a9f7213820d25cb45145a1b7cf33a/cd_bundle_to.bash"  => sh_tools_dir,
      "2622894/be42b37a401412a910b4f60db69c66e807bb0b35/hub"                => tools_dir,
    }.each do |url_path, toolpath|
      url, dest_path, permission = if url_path =~ /^http/
                                     [url_path, File.join(toolpath.last, toolpath.first),
                                      '755']
                                   else
                                     ["%s/%s" % [github_gist_host, url_path],
                                      File.join(toolpath, File.basename(url_path)),nil]
                                   end

      if File.exists?(dest_path)
        puts " ✓ Exists #{_C.yellow(dest_path)} - delete to replace"
      else
        puts " == Creating #{_C.yellow(dest_path)}"
        system("wget '#{url}' --no-check-certificate -O #{dest_path} 2>/dev/null")
        system("chmod #{permission} #{dest_path}") if permission
      end
    end
  end
end
