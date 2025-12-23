source 'https://rubygems.org'

# Allow any Ruby version >= 3.1.0 (you are on 3.3.10)
ruby '>= 3.1.0'

gem 'rails', '~> 7.0'
gem 'pg', '~> 1.1'
gem 'puma', '~> 6.0'
gem 'rack-cors'

gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin, :jruby]

group :development, :test do
  # NOTE: Bundler warns that :mingw and :x64_mingw are deprecated; it's safe for now.
  # We can switch to :windows later if needed.
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'listen', '~> 3.3'
end

