# Contributing

## Adding a new formula

### Supporting mTLS (for use in CircleCI/non Zcaler environments)

There's 2 things to consider:

1. Connection for downloading the package
2. Connection for the livecheck

#### Downloading the package

If the package is hosted on Nexus you can implement the CustomCurlDownloadStrategy which can be seen in kraken-cli formulae.
This overrides the default download and adds cert/key to the curl command if the HOMEBREW_CIRCLECI environment variable is set. This is the current pattern designed for when CircleCI is set up in accordance with the Nexus Circle CI Setup guide.

#### Implementing livecheck

Livecheck is important to ensure that the formula version, hash, url etc are updatable with the built in homebrew tools (ie brew bump).

Generally speaking, it's best to implement a non git strategy. If the package is hosted on Nexus, the 'NexusJson' strategy is suitable and can be used like so:

```ruby
livecheck do
  url "https://nexus.ktl.net/service/rest/v1/search?repository=<repository_name>&name=<package_name>"
  strategy :nexus_json
end
```

As with the download strategy, the cert/key is added to the curl command if the HOMEBREW_CIRCLECI environment variable is set.

### Zscaler connectivity

If any part of the formula requires Zscaler connectivity, by default homebrew will throw some unhelpful errors if ZPA is inactive or if the user is unauthenticated.

A brief connectivity check can be implemented as part of the Download Strategy. See the CustomCurlDownloadStrategy in the kraken-cli formulae for an example.

## Format formulae using rubocop

This project comes preconfigured with rubocop set up for ruby, however you'll need to install the rubocop plugin:

### Install ruby with mise
```shell
mise install
```

### Install rubocop

```shell
bundle install
```

Then you can run rubocop to lint and format the formulae and livecheck strategies:

Lint:
```shell
bundle exec rubocop
```
Apply safe fixes:
```shell
bundle exec rubocop -a
```
