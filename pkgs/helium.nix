{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, alsa-lib
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libdrm
, libX11
, libXScrnSaver
, libXcomposite
, libXcursor
, libXdamage
, libXext
, libXfixes
, libXi
, libXrandr
, libXrender
, libXtst
, libxcb
, libxkbcommon
, nspr
, nss
, pango
, pipewire
, udev
, zlib
}:

let
  version = "0.14.9.1";
  srcs = {
    aarch64-linux = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-arm64_linux.tar.xz";
      sha256 = "1yh7xrn1znrasng50b2icyxmblxv82wcq2xcaq70yg9b16p0ll59";
    };
    x86_64-linux = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64_linux.tar.xz";
      sha256 = "0gb7gs1i26lg24dbgh3rwvmyj6ax569wlrhwqlr5pkd92bgifrh6";
    };
  };
in
stdenv.mkDerivation {
  pname = "helium";
  inherit version;

  src = srcs.${stdenv.hostPlatform.system} or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libxcb
    libxkbcommon
    nspr
    nss
    pango
    pipewire
    udev
    zlib
  ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/helium
    cp -r . $out/share/helium/

    mkdir -p $out/bin
    makeWrapper $out/share/helium/helium $out/bin/helium \
      --add-flags "--ozone-platform=wayland" \
      --prefix LD_LIBRARY_PATH : "$out/share/helium"

    mkdir -p $out/share/applications
    cp helium.desktop $out/share/applications/helium.desktop
    sed -i "s|Exec=.*helium|Exec=$out/bin/helium|" \
      $out/share/applications/helium.desktop

    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath $out/share/helium
  '';

  meta = {
    description = "Privacy-focused browser built on Chromium";
    homepage = "https://helium.computer";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "helium";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
