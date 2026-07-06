{
  pkgs,
  ...
}:

{
  languages.ruby = {
    enable = true;
    version = "4.0.5";
    lsp.enable = false;
  };

  packages = [
    pkgs.nodejs
    pkgs.git
    pkgs.watchman

    # Native gem dependencies
    pkgs.pkg-config
    pkgs.libyaml
    pkgs.openssl
    pkgs.zlib
    pkgs.sqlite
    pkgs.libxml2
    pkgs.libxslt

    # Useful if you later enable Active Storage variants with image_processing
    pkgs.vips
  ];

  env = {
    RAILS_ENV = "development";
    NODE_ENV = "development";
  };

  scripts.setup.exec = ''
    set -e
    bundle check || bundle install
    npm install
    bin/rails db:prepare
  '';

  scripts.dev.exec = ''
    bin/dev
  '';

  enterShell = ''
    echo "crucible dev environment"
    echo "Ruby: $(ruby --version)"
    echo "Node: $(node --version)"
    echo "npm: $(npm --version)"
  '';
}
