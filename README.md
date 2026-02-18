# Kraken Homebrew Tap

Official Homebrew tap for Kraken Technologies tooling.

## What is this?

This tap provides Homebrew formulae for Kraken Technologies command-line tools and utilities.

## Installation

Add this tap to your Homebrew installation:

```shell
brew tap octoenergy/tap
```

Then install a package:

```shell
brew install <package>
```

## Available Formulae

- **kraken-cli**: CLI tool to help Kraken developers work with AWS, Kubernetes, and other KTL services

## Updating

Keep your installed packages up to date:

```shell
brew update
brew upgrade
```

# Contributing

## Format formulae using prettier

This project comes preconfigured with prettier set up for ruby, however you'll need to install the prettier plugin:

### Install dependencies

First install the ruby prettier plugin:

```shell
npm install
```

Then install the dependencies for the prettier plugin:

```shell
gem install bundler prettier_print syntax_tree syntax_tree-haml syntax_tree-rbs
```

### Format the formulae

Then you can run prettier to format the formulae:

```shell
npx prettier --write ./**/*.rb
```

or install the vscode extension.
