class KrakenCli < Formula
  include Language::Python::Virtualenv

  desc "Tools for Kraken Tech"
  homepage "https://github.com/octoenergy/kraken-cli/"

  url "https://nexus.ktl.net/repository/pypi-kraken-private/packages/kraken-cli/0.28.1/kraken_cli-0.28.1.tar.gz"
  sha256 "eb92f9115d92dc198dd54cbc436988a58fa72117da86e8acba8006b4a91886a4"
  version "0.28.1"
  license "UNLICENSED"

  depends_on "python@3.13"
  depends_on "cryptography"
  depends_on "docker-credential-helper-ecr"
  depends_on "aws-iam-authenticator"
  depends_on "awscli@2"
  depends_on "fzf"
  depends_on "kubernetes-cli"
  depends_on "sops"
  depends_on "helm" => :recommended
  depends_on "k9s" => :recommended
  depends_on "kubectx" => :recommended
  depends_on "stern" => :optional

  def install
    venv = virtualenv_create(libexec)
    
    ENV["UV_PROJECT_ENVIRONMENT"] = venv.root
    
    # Install uv using pre-built wheels
    system venv.root/"bin/python3", "-m", "pip", "install", "--prefer-binary", "uv"
    
    if ENV["HOMEBREW_CIRCLECI"]
      ENV["UV_NO_CONFIG"] = ENV["HOMEBREW_UV_NO_CONFIG"]
      ENV["UV_NATIVE_TLS"] = ENV["HOMEBREW_UV_NATIVE_TLS"]
      ENV["UV_INDEX_URL"] = ENV["HOMEBREW_UV_INDEX_URL"]
      ENV["UV_EXTRA_INDEX_URL"] = ENV["HOMEBREW_UV_EXTRA_INDEX_URL"]
      ENV["SSL_CLIENT_CERT"] = ENV["HOMEBREW_SSL_CLIENT_CERT"]
    end
    
    # Change to buildpath where the tarball is extracted
    # Use uv sync to install dependencies from pyproject.toml
    cd buildpath do
      system venv.root/"bin/python3", "-m", "uv", "sync", "--no-dev"
    end
    
    # Install the main package from the tarball
    system venv.root/"bin/python3", "-m", "uv", "pip", "install", buildpath
    
    bin.install_symlink (venv.root/"bin/kraken")
  end

  def post_install
    ENV["_SKIP_METADATA_CACHE"] = "1"   
    generate_completions_from_executable(bin/"kraken", "completion")
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
    assert_match "kraken, version", shell_output("kraken --version")
  end
end
