require 'glue'
require 'glue/event'
require 'glue/tracker'
require 'glue/finding'
require 'glue/util'
include Glue::Util

describe '.get_git_environment' do
  # after(:each) do
  #   # Flushes the ENV after each test
  #   ENV = {}
  # end
  it 'Should populate values from Jenkins build environment' do
    stub_env('GIT_COMMIT', 'testJenkinsCommit')
    stub_env('GIT_BRANCH', 'origin/master')
    stub_env('GIT_URL', 'git@bitbucket.org:testfolder/testrepo.git')
    stub_env('JOB_NAME', 'job_folder/PR-1/master')

    expect(get_git_environment).to include(
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

    expect(get_git_environment).to include(
      branch: 'master',
      commit: 'testBitbucketCommit',
      url: 'https://bitbucket.org/project_name/repo_name/src/branch_name/'
    )
  end
  it 'Should return empty strings if it fails to retreive the build environment' do
    expect(get_git_environment). to include(
      branch: '',
      commit: '',
      url: ''
    )
  end
end
