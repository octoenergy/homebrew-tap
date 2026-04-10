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

class KrakenCliTest < Formula
  desc "Tools for Kraken Tech"
  homepage "https://github.com/octoenergy/kraken-cli/"
  url "https://nexus.ktl.net/repository/pypi-kraken-private/packages/kraken-cli/0.44.8/kraken_cli-0.44.8.tar.gz",
      using: CustomCurlDownloadStrategy
  sha256 "c5ec8a4f5b34f490ef7b16dfe9d7a384263b5eadb333642ddf399ba5671bd163"
  head "https://github.com/octoenergy/kraken-cli.git", branch: "main"

  livecheck do
    url "https://nexus.ktl.net/service/rest/v1/search?repository=pypi-kraken-private&name=kraken-cli"
    strategy :nexus_json
  end

  depends_on "aws-iam-authenticator"
  depends_on "awscli@2"
  depends_on "cryptography"
  depends_on "docker-credential-helper-ecr"
  depends_on "fzf"
  depends_on "helm" => :recommended
  depends_on "k9s" => :recommended
  depends_on "kubectx" => :recommended
  depends_on "kubernetes-cli"
  depends_on "python@3.13"
  depends_on "sops"
  depends_on "stern" => :optional
  depends_on "uv"

  def install
    uv = Formula["uv"].opt_bin / "uv"
    python = Formula["python@3.13"].opt_bin / "python3.13"

    system uv, "venv", libexec, "--python", python

    ENV["UV_PROJECT_ENVIRONMENT"] = libexec.to_s
    ENV["VIRTUAL_ENV"] = libexec.to_s

    if ENV["HOMEBREW_CIRCLECI"]
      # Set required UV env vars for mutual auth to Nexus
      # These are set in the CircleCI config
      ENV["UV_NO_CONFIG"] = ENV.fetch("HOMEBREW_UV_NO_CONFIG", nil)
      ENV["UV_NATIVE_TLS"] = ENV.fetch("HOMEBREW_UV_NATIVE_TLS", nil)
      ENV["UV_INDEX_URL"] = ENV.fetch("HOMEBREW_UV_INDEX_URL", nil)
      ENV["UV_EXTRA_INDEX_URL"] = ENV.fetch("HOMEBREW_UV_EXTRA_INDEX_URL", nil)
      ENV["SSL_CLIENT_CERT"] = ENV.fetch("HOMEBREW_SSL_CLIENT_CERT", nil)
    end

    # Install deps + package into venv
    cd buildpath do
      system uv, "sync", "--no-dev", "--no-editable"
    end

    bin.install_symlink(libexec / "bin/kraken")
    bin.install_symlink libexec / "bin/kraken-credentials"
  end

  def post_install
    # We can't modify $HOME in post_install and install runs in a
    # sandbox, so this is a hack since the metadata services' cache
    # is created when the metadata client is created which can't be
    # modified right now.
    ENV["_SKIP_METADATA_CACHE"] = "1"

    # Generate shell completions
    generate_completions_from_executable(bin / "kraken", "completion")
  end

  def caveats
    <<~EOS
                          %@&%%%%%%%%%%%@@.
                      @%%%%%%%%%%%%%%%%%%%%@/
                    @%%%%%%%%%%%%%%%%%%%%%%%%%(
                  #%%%%%//%%%%%%%%%%%%%%%/%%%%%@
                  ,%%%#  @@@ (%%%%%%%%%  @@@  %%%@
                  @%%%/      *%(%%%%#%%       %%%%
               .  (%%%%%%*,%%%%%    (%%%%#/#%%%%%(
        @@%%%%%%  (((%%%%%%%%%%%%%%%%%%%%%%%%(((( %%%%%%&@
        %%%%#((((%   @@@@@#  %%%%%%%%%%  ,@@@@@,  (%(((#%%%%&
      @ (%((     @@@#  @@@@@@ .%%%%%/ @@@@*  (@@@,    .(#% @@
        %%#(   *@@@@@@@@@@@@@  (%%%%% @@@@ *%%  @@&   /(%%#
        %@ %, , &@@@@@@@@@@@@@@ ((#%%%%%. *%%%%% @@@ /  %  @
            @@@@@@@@@@@@@@@@@@@@ *(((%%%%%%%#((  @@@@@@@
        %% .&@@@@@@@( %@@ %  @@@@&  @*@ * @@&  &@@@@@@@&% %%.
        #%( &&&@@@@@@  .%% @  /@@@@&&%(*. .#&&@@@@@@@@&& .%%.
      @ %%(. /&&&&&&@@ %%%    @@@&@@@@@@@@@@@@@&&&&&&  #%%% %
        #@* %%#. (%.  ,%%% @%. &&&&&&&@@@@@@@&&&    *((%% @//
            @ @ ,(((%%%(   / %   (   &&&&&&,  (((   @ @
                  .(((,*@,     @&,#((     ,((#%.
                                  #%%%%%%%%%%%%.%.
                                  #@ %%%%%% /@#
                                    .%((@

      Thank you for installing the Kraken CLI

      To get started, run `kraken --help` to see the available commands.

      For more information, see the documentation at:
      https://www.notion.so/kraken-tech/Getting-started-with-Cloudfarer-98b6e160e41c43e583c236bc97a9fc36?pvs=4
    EOS
  end

  test do
    assert_match "kraken, version", shell_output("#{bin}/kraken --version")
  end
end
