require 'glue/util'
require 'open3'
# Helper functions to make sense of the mess that is handling
# different pipeline environments.
module Glue::EnvHelper
  include Glue::Util
  def get_finding_path(finding)
    pathname_regex = Regexp.new(%r{(\./|#<Pathname:)(?<file_path>.*)(?<file_ext>\.py|\.java|\.class|\.js|\.ts|.xml)(>)?}i)
    unless finding.source[:file].to_s.match(pathname_regex).nil?
      matches = finding.source[:file].match(pathname_regex)
      matches[:file_path] + matches[:file_ext]
    else finding.source[:file].to_s
    end
  end

  def bitbucket_linker(finding)
    filepath = get_finding_path(finding)
    linenumber = finding.source[:line]
    if ENV['BITBUCKET_REPO_FULL_NAME'].nil? # we are probably still inside Jenkins
      "#{ENV['GIT_URL'].gsub('git@', '').gsub(':', '/').gsub('.git', '').insert(0, 'https://')}/src/#{ENV['GIT_COMMIT']}/#{filepath}#lines-#{linenumber}"
    else
      "https://bitbucket.org/#{ENV['BITBUCKET_REPO_FULL_NAME']}/src/#{ENV['BITBUCKET_COMMIT']}/#{filepath}#lines-#{linenumber}"
    end
  end

  def read_git_branch
    Open3.popen3("git log -n 1 --pretty=%d HEAD | awk '{print $2}' | cut -d ')' -f 1") do |stdout, stderr, wait_thr|
      return stdout.read
    end
  end

  def read_git_repo_name
    Open3.popen3("git config --get remote.origin.url | cut -d ':' -f 2 | cut -d '.' -f 1 | cut -d '/' -f 2") do |stdout, stderr, wait_thr|
      return stdout.read
    end
  end

  def bitbucket_pr_linker(pr_number, job_name)
    # The link should be something like:
    # https://bitbucket.org/<project_name>/<repo_name>/pull-requests/<pr_number>
    # AFAIK, the rest of the URL gets populated by Bitbucket, there's no need to mess with
    # git refs and the like.
    branch = read_git_branch
    project = job_name.split('-')[0]

    # We no longer have the luxury of getting the current repository name, so we get it
    # from the current remote.
    repo = read_git_repo_name

    "https://bitbucket.org/#{project}/#{repo}/pull-requests/#{pr_number}/#{branch}"
  end

  def jenkins_environment(git_env)
    git_env[:commit] = ENV['GIT_COMMIT']
    Glue.warn git_env[:commit]
    git_env[:branch] = ENV['GIT_BRANCH'].sub('origin/', '')
    Glue.warn git_env[:branch]
    if git_env[:branch].include? 'PR'
      Glue.warn '***** This build comes from a Bitbucket Pull Request, the link will point to that.'
      return git_env[:url] = bitbucket_pr_linker(git_env[:branch].sub('PR-', ''), ENV['JOB_NAME'])
    else
      # Converts an SSH link to a HTTPS one
      git_env[:url] = ENV['GIT_URL']
                      .gsub('git@', '')
                      .gsub(':', '/')
                      .gsub('.git', '')
                      .insert(0, 'https://')
      return git_env
    end
  end

  def bitbucket_environment(git_env)
    git_env[:commit] = ENV['BITBUCKET_COMMIT']
    git_env[:branch] = ENV['BITBUCKET_BRANCH'].sub('origin/', '')
    git_env[:url] = 'https://bitbucket.org/' + ENV['BITBUCKET_REPO_FULL_NAME']
    # Returns the env
    puts git_env
    git_env
  end

  def get_git_environment
    git_env = {}
    if ENV['GIT_COMMIT'].nil? && ENV['BITBUCKET_COMMIT'].nil?
      Glue.warn '***** No Git enviroment variables found, the report will be generated with broken links'
      git_env[:commit] = git_env[:branch] = git_env[:url] = ''
    elsif ENV['BITBUCKET_COMMIT'].nil? # If nil, we're probably inside a Jenkins build
      Glue.warn '***** No Bitbucket variables found, is this a Jenkins build?'
      jenkins_environment(git_env) # Do Jenkins specific stuff
    elsif ENV['GIT_COMMIT'].nil? # If nil, we're probably inside a Bitbucket pipeline
      Glue.warn '***** No Jenkins variables found, is this a Bitbucket build?'
      bitbucket_environment(git_env) # Do Bitbucket specific stuff
    end
    git_env
  end
end
