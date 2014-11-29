# Garlando [![Circle CI](https://circleci.com/gh/miyucy/garlando/tree/master.svg?style=svg)](https://circleci.com/gh/miyucy/garlando/tree/master)

Serve your rails assets from separate process. :briefcase:

## Installation

Add this line to your application's Gemfile:

    gem 'garlando'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install garlando

## Usage

Append one-line to your `spec/spec_helper.rb`.

    Capybara.asset_host = 'http://0.0.0.0:65501'

And, Boot `garlando`. (At your rails project root directory)

    $ garlando

### Appendix

If you want to use with `Guard`.

    guard 'garlando' do
    end

But, it's NO warranty. (I don't use `Guard` :smirk:)

## Contributing

1. Fork it ( http://github.com/miyucy/garlando/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
