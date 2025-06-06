# https://docs.brew.sh/Formula-Cookbook
# https://rubydoc.brew.sh/Formula
class KrakenCli < Formula
  include Language::Python::Virtualenv

  desc "Tools for Kraken Tech"
  homepage "https://github.com/octoenergy/kraken-cli/"
  url "https://nexus.ktl.net/repository/pypi-kraken/packages/kraken-cli/0.0.90/kraken_cli-0.0.90.tar.gz"
  sha256 "670ae2feff44ff6e6799df60f89f86f4941fab97bef472561e8125f6de2e208e"
  license "UNLICENSED"
  head "https://github.com/octoenergy/kraken-cli.git", branch: "main"

  depends_on "aws-iam-authenticator"
  depends_on "awscli@2"
  depends_on "cryptography"
  depends_on "kubernetes-cli"
  depends_on "python@3.13"
  depends_on "sops"
  depends_on "uv"
  depends_on "fzf" => :recommended
  depends_on "helm" => :recommended
  depends_on "k9s" => :recommended
  depends_on "kubectx" => :recommended
  depends_on "stern" => :optional

  def install
    venv = virtualenv_create(libexec)

    ENV["UV_PROJECT_ENVIRONMENT"] = venv.root

    if ENV["HOMEBREW_CIRCLECI"]
      # Set required UV env vars for mutual auth to Nexus
      ENV["UV_NO_CONFIG"] = ENV["HOMEBREW_UV_NO_CONFIG"]
      ENV["UV_NATIVE_TLS"] = ENV["HOMEBREW_UV_NATIVE_TLS"]
      ENV["UV_INDEX_URL"] = ENV["HOMEBREW_UV_INDEX_URL"]
      ENV["UV_EXTRA_INDEX_URL"] = ENV["HOMEBREW_UV_EXTRA_INDEX_URL"]
      ENV["SSL_CLIENT_CERT"] = ENV["HOMEBREW_SSL_CLIENT_CERT"]
    end

    system "uv", "sync", "--no-dev", "--no-editable"

    bin.install_symlink venv.root/"bin/kraken"
  end

  def post_install
    # We can't modify $HOME in post_install and install runs in a
    # sandbox, so this is a hack since the metadata services' cache
    # is created when the metadata client is created which can't be
    # modified right now.
    ENV["_SKIP_METADATA_CACHE"] = "1"

    # Generate shell completions
    generate_completions_from_executable(bin/"kraken", "completion")
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test kraken-cli`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system bin/"program", "do", "something"`.
    # system "kraken", "--version"
    assert_match "kraken, version", shell_output("kraken --version")
  end
end
