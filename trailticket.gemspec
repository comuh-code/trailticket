require_relative "lib/trailticket/version"

Gem::Specification.new do |spec|
  spec.name        = "trailticket"
  spec.version     = Trailticket::VERSION
  spec.authors     = ["Thyago"]
  spec.email       = ["thyago@comuh.co"]
  spec.summary     = "Headless support tickets for Rails that carry the user's context."
  spec.description = "A mountable Rails engine with a JSON API and Ruby API for support tickets. " \
                     "Each ticket can carry the page the user was on, a screenshot, the path they " \
                     "took and the fields they filled in, with sensitive data masked by default."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.homepage = "https://github.com/comuh-code/trailticket"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,db,lib}/**/*", "README.md", "CHANGELOG.md", "MIT-LICENSE"]
  end

  spec.add_dependency "rails", ">= 7.1"
end
