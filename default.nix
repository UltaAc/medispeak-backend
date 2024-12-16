{ pkgs ? import <nixpkgs> {}, 
  ruby ? pkgs.ruby_3_2,
  stdenv ? pkgs.stdenv
}:

let
  # Environment variables and configuration using placeholders
  env = {
    RAILS_ENV = "production";
    BACKEND_PORT = "$PORT";

    # Placeholders for Coolify environment variables
    DB_HOST = "$DB_HOST";
    DB_NAME = "$DB_NAME";
    DB_USERNAME = "$DB_USERNAME";
    DB_PASSWORD = "$DB_PASSWORD";

    OPENAI_ACCESS_TOKEN = "$OPENAI_ACCESS_TOKEN";
    OPENAI_ORGANIZATION_ID = "$OPENAI_ORGANIZATION_ID";

    AWS_ACCESS_KEY_ID = "$AWS_ACCESS_KEY_ID";
    AWS_SECRET_ACCESS_KEY = "$AWS_SECRET_ACCESS_KEY";
    AWS_REGION = "$AWS_REGION";
    AWS_BUCKET = "$AWS_BUCKET";

    PLUGIN_BASE_URL = "$PLUGIN_BASE_URL";

    # Additional placeholders for potential services
    STORAGE_SERVICE = "$STORAGE_SERVICE";
    MINIO_BUCKET = "$MINIO_BUCKET";
    MINIO_ACCESS_KEY_ID = "$MINIO_ACCESS_KEY_ID";
    MINIO_SECRET_ACCESS_KEY = "$MINIO_SECRET_ACCESS_KEY";
    MINIO_ENDPOINT = "$MINIO_ENDPOINT";
    MINIO_REGION = "$MINIO_REGION";

    # Secret key base for Rails
    SECRET_KEY_BASE = "$SECRET_KEY_BASE";
  };

  # Ruby application build
  rubyApp = stdenv.mkDerivation {
    name = "medispeak-backend";
    src = ./.;

    buildInputs = with pkgs; [
      ruby
      bundler
      git
      libvips
      pkg-config
      stdenv.cc.cc.lib
      zlib
      openssl
    ];

    # Bundle install and precompile assets
    buildPhase = ''
      export HOME=$(mktemp -d)
      export RAILS_ENV=${env.RAILS_ENV}
      export SECRET_KEY_BASE=$(openssl rand -hex 64)

      # Install dependencies
      ${ruby}/bin/bundle config set --local deployment 'true'
      ${ruby}/bin/bundle config set --local without 'development test'
      ${ruby}/bin/bundle install

      # Precompile assets
      ${ruby}/bin/bundle exec bootsnap precompile app/ lib/
      SECRET_KEY_BASE_DUMMY=1 ${ruby}/bin/bundle exec rails assets:precompile
    '';

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

  # Entrypoint script
  entrypoint = pkgs.writeShellScriptBin "medispeak-entrypoint" ''
    # Set environment variables
    ${pkgs.lib.concatStringsSep "\n" 
      (pkgs.lib.mapAttrsToList (name: value: "export ${name}=${value}") env)}

    # Run database migrations
    cd ${rubyApp}
    ${ruby}/bin/bundle exec rails db:migrate

    # Start the Rails server
    ${ruby}/bin/bundle exec rails server -p $PORT -b 0.0.0.0
  '';

in pkgs.mkShell {
  buildInputs = [
    ruby
    bundler
    entrypoint
  ];

  shellHook = ''
    echo "MediSpeak development environment"
    echo "Use 'medispeak-entrypoint' to start the application"
  '';
}
