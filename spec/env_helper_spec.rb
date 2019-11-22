require 'glue'
require 'glue/event'
require 'glue/tracker'
require 'glue/finding'
require 'glue/env_helper'

describe '#env_helper' do
  # We encapsulate the EnvHelper module in a dummy class
  # in order to be able to test it.
  class EnvClass end
  before(:each) do
    @env_class = EnvClass.new
    @env_class.extend(Glue::EnvHelper)
  end

  context '.bitbucket_pr_linker' do
    it 'Should produce a valid Bitbucket PR link from the ENV that Jenkins provides' do
      allow(ENV).to receive(:[]).with('JOB_NAME').and_return('projectName-build-bitbucket/repoName/PR-10')
      allow(@env_class).to receive(:read_git_branch).and_return('feature-TestFeature')
      allow(@env_class).to receive(:read_git_repo_name).and_return('repoName')
      expect(@env_class.bitbucket_pr_linker('10', ENV['JOB_NAME'])).to eq('https://bitbucket.org/projectName/repoName/pull-requests/10')
    end
  end

  context '.bitbucket_enviroment' do
    it 'should return the correct git_env for a Bitbucket pipeline' do
      allow(ENV).to receive(:[]).with('BITBUCKET_COMMIT').and_return('testBitbucketCommit')
      allow(ENV).to receive(:[]).with('BITBUCKET_BRANCH').and_return('origin/master')
      allow(ENV).to receive(:[]).with('BITBUCKET_REPO_FULL_NAME').and_return('project_name/repo_name/src/branch_name/')
      allow(ENV).to receive(:[]).with('BITBUCKET_TAG').and_return('1.0')
      allow(ENV).to receive(:[]).with('BITBUCKET_BUILD_NUMBER').and_return('1.0')
      git_env = {}
      expect(@env_class.bitbucket_environment(git_env)).to include(
        branch: 'master',
        commit: 'testBitbucketCommit',
        url: 'https://bitbucket.org/project_name/repo_name/src/branch_name/'
      )
    end
  end

  context '.jenkins_enviroment' do
    it 'should return the correct git_env for a Jenkins pipeline' do
      allow(ENV).to receive(:[]).with('GIT_COMMIT').and_return('testJenkinsCommit')
      allow(ENV).to receive(:[]).with('GIT_BRANCH').and_return('origin/master')
      allow(ENV).to receive(:[]).with('GIT_URL').and_return('git@bitbucket.org:testfolder/testrepo.git')
      allow(ENV).to receive(:[]).with('JOB_NAME').and_return('job_folder/PR-1/master')
      git_env = {}
      expect(@env_class.jenkins_environment(git_env)).to include(
        branch: 'master',
        commit: 'testJenkinsCommit',
        url: 'https://bitbucket.org/testfolder/testrepo'
      )
    end
  end

  context '.get_git_environment' do
    it 'Should populate values from Jenkins build environment' do
      stub_env('GIT_COMMIT', 'testJenkinsCommit')
      stub_env('GIT_BRANCH', 'origin/master')
      stub_env('GIT_URL', 'git@bitbucket.org:testfolder/testrepo.git')
      stub_env('JOB_NAME', 'job_folder/PR-1/master')

      expect(@env_class.get_git_environment).to include(
        branch: 'master',
        commit: 'testJenkinsCommit',
        url: 'https://bitbucket.org/testfolder/testrepo'
      )
    end
    it 'Should populate values from Bitbucket build enviroment' do
      stub_env('BITBUCKET_COMMIT', 'testBitbucketCommit')
      stub_env('BITBUCKET_BRANCH', 'origin/master')
      stub_env('BITBUCKET_REPO_FULL_NAME', 'project_name/repo_name/src/branch_name/')
      stub_env('BITBUCKET_TAG', '1.0')
      stub_env('BITBUCKET_BUILD_NUMBER', '1')

      expect(@env_class.get_git_environment).to include(
        branch: 'master',
        commit: 'testBitbucketCommit',
        url: 'https://bitbucket.org/project_name/repo_name/src/branch_name/'
      )
    end
    it 'Should return empty strings if it fails to retreive the build environment' do
      expect(@env_class.get_git_environment). to include(
        branch: '',
        commit: '',
        url: ''
      )
    end
  end
end
