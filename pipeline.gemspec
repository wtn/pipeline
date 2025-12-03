require_relative 'lib/pipeline/version'

Gem::Specification.new do |spec|
  spec.name = 'pipeline'
  spec.version = Pipeline::VERSION
  spec.authors = ['Danilo Sato']
  spec.email = ['danilo@dtsato.com']

  spec.summary = 'Run asynchronous processes in a configurable pipeline'
  spec.description = 'Pipeline is a Rails plugin/gem to run asynchronous processes in a configurable pipeline.'
  spec.homepage = 'https://github.com/dtsato/pipeline'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines(?\x0, chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ Gemfile .git])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 8.0'
  spec.add_dependency 'activesupport', '>= 8.0'
  spec.add_dependency 'delayed_job', '>= 4.1'
end
