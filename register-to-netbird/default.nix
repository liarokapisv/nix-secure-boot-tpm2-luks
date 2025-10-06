{ qrencode, python3 }:
python3.pkgs.buildPythonApplication {
  name = "register-to-netbird";
  src = ./.;
  format = "other";
  propagatedBuildInputs = [
    qrencode
  ];
  doCheck = false;
  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 app.py $out/bin/register_to_netbird
  '';
}
