require "net/http"
require "uri"

class CustomCurlDownloadStrategy < CurlDownloadStrategy
  ZSCALER_CHECK_URL = URI("https://ismyzscalerconnected.ktl.net").freeze

  def fetch(timeout: nil)
    return super if ENV["HOMEBREW_CIRCLECI"]

    zscaler_ok =
      begin
        uri = ZSCALER_CHECK_URL
        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl:      true,
          open_timeout: 2,
          read_timeout: 2,
        ) { |http| http.get(uri.request_uri).body.strip.downcase }
      rescue
        ""
      end
    raise <<~EOS unless zscaler_ok.to_s.include?("yes")
      Zscaler does not appear to be connected.

      Please connect to Zscaler Private Access and try again.

      Check your status at: #{ZSCALER_CHECK_URL}
    EOS

    super
  end

  def curl_args(*)
    args = super
    cert_path = ENV["HOMEBREW_SSL_CLIENT_CERT"]
    if cert_path.to_s != "" && File.exist?(File.expand_path(cert_path))
      args += ["--key", File.expand_path(cert_path), "--cert", File.expand_path(cert_path)]
    end
    args
  end
end

class KaChowCli < Formula
  include Language::Python::Virtualenv

  desc "Ka-Chow!"
  homepage "https://github.com/octoenergy/ka-chow/"
  url "https://nexus.us.ktl.net/repository/pypi-kraken-private/packages/ka-chow-cli/0.1.1/ka_chow_cli-0.1.1.tar.gz",
      using: CustomCurlDownloadStrategy
  sha256 "afc525a633e2d39cfebc0d38bcd14c37c66760c5b780d7c9b1503d069d36375e"
  head "https://github.com/octoenergy/ka-chow.git", branch: "main"

  livecheck do
    url "https://nexus.us.ktl.net/service/rest/v1/search?repository=pypi-kraken-private&name=ka-chow-cli"
    strategy :nexus_json
  end

  depends_on "python@3.13"

  def install
    venv = virtualenv_create(libexec)

    ENV["UV_PROJECT_ENVIRONMENT"] = venv.root

    # Install uv using pre-built wheels
    system venv.root / "bin/python3",
           "-m",
           "pip",
           "install",
           "--prefer-binary",
           "uv"

    if ENV["HOMEBREW_CIRCLECI"]
      # Set required UV env vars for mutual auth to Nexus
      # These are set in the CircleCI config
      ENV["UV_NO_CONFIG"] = ENV.fetch("HOMEBREW_UV_NO_CONFIG", nil)
      ENV["UV_NATIVE_TLS"] = ENV.fetch("HOMEBREW_UV_NATIVE_TLS", nil)
      ENV["UV_INDEX_URL"] = ENV.fetch("HOMEBREW_UV_INDEX_URL", nil)
      ENV["UV_EXTRA_INDEX_URL"] = ENV.fetch("HOMEBREW_UV_EXTRA_INDEX_URL", nil)
      ENV["SSL_CLIENT_CERT"] = ENV.fetch("HOMEBREW_SSL_CLIENT_CERT", nil)
    end

    # Change to buildpath where the tarball is extracted
    # Use uv sync to install dependencies from pyproject.toml
    cd buildpath do
      system venv.root / "bin/python3", "-m", "uv", "sync", "--no-dev"
    end

    # Install the main package from the tarball
    system venv.root / "bin/python3", "-m", "uv", "pip", "install", buildpath

    bin.install_symlink(venv.root / "bin/ka-chow")
  end

  def post_install
    # We can't modify $HOME in post_install and install runs in a
    # sandbox, so this is a hack since the metadata services' cache
    # is created when the metadata client is created which can't be
    # modified right now.
    ENV["_SKIP_METADATA_CACHE"] = "1"
  end

  def caveats
    <<~EOS
      ░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
      ░▒▓███████▓▒░░▒▓████████▓▒░▒▓█▓▒░      ░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓█████████████▓▒░░▒▓█▓▒░


      Thank you for installing Ka-Chow!
    EOS
  end

  test do
    assert_match "ka-chow, version", shell_output("#{bin}/ka-chow --version")
  end
end
