class KeyringsCodeartifact < Formula
  include Language::Python::Virtualenv

  desc "Python keyring backend for AWS CodeArtifact"
  homepage "https://pypi.org/project/keyrings.codeartifact/"
  url "https://files.pythonhosted.org/packages/source/k/keyrings.codeartifact/keyrings_codeartifact-2.1.2.tar.gz"
  sha256 "ac7b0082840216ee5445c786b5b6c599a455cb3a0dc02dd40fd4d50d0bcaac2e"
  license "MIT"

  depends_on "python@3.12"

  resource "boto3" do
    url "https://files.pythonhosted.org/packages/9e/e6/8fdd78825de6d8086aa3097955f83d8db3c5a3868b73da233c49977a7444/boto3-1.42.45.tar.gz"
    sha256 "4db50b8b39321fab87ff7f40ab407887d436d004c1f2b0dfdf56e42b4884709b"
  end

  resource "botocore" do
    url "https://files.pythonhosted.org/packages/7a/b1/c36ad705d67bb935eac3085052b5dc03ec22d5ac12e7aedf514f3d76cac8/botocore-1.42.45.tar.gz"
    sha256 "40b577d07b91a0ed26879da9e4658d82d3a400382446af1014d6ad3957497545"
  end

  resource "jmespath" do
    url "https://files.pythonhosted.org/packages/d3/59/322338183ecda247fb5d1763a6cbe46eff7222eaeebafd9fa65d4bf5cb11/jmespath-1.1.0.tar.gz"
    sha256 "472c87d80f36026ae83c6ddd0f1d05d4e510134ed462851fd5f754c8c3cbb88d"
  end

  resource "python-dateutil" do
    url "https://files.pythonhosted.org/packages/66/c0/0c8b6ad9f17a802ee498c46e004a0eb49bc148f2fd230864601a86dcf6db/python-dateutil-2.9.0.post0.tar.gz"
    sha256 "37dd54208da7e1cd875388217d5e00ebd4179249f90fb72437e91a35459a0ad3"
  end

  resource "s3transfer" do
    url "https://files.pythonhosted.org/packages/05/04/74127fc843314818edfa81b5540e26dd537353b123a4edc563109d8f17dd/s3transfer-0.16.0.tar.gz"
    sha256 "8e990f13268025792229cd52fa10cb7163744bf56e719e0b9cb925ab79abf920"
  end

  resource "six" do
    url "https://files.pythonhosted.org/packages/94/e7/b2c673351809dca68a0e064b6af791aa332cf192da575fd474ed7d6f16a2/six-1.17.0.tar.gz"
    sha256 "ff70335d468e7eb6ec65b95b99d3a2836546063f63acc5171de367e834932a81"
  end

  resource "urllib3" do
    url "https://files.pythonhosted.org/packages/c7/24/5f1b3bdffd70275f6661c76461e25f024d5a38a46f04aaca912426a2b1d3/urllib3-2.6.3.tar.gz"
    sha256 "1b62b6884944a57dbe321509ab94fd4d3b307075e0c2eae991ac71ee15ad38ed"
  end

  def install
    venv = virtualenv_create(libexec, "python3.12")

    # Install deps + the backend itself into the venv
    venv.pip_install resources
    venv.pip_install buildpath

    # Future-proofing: copy everything importable into a stable directory
    vendor = libexec/"vendor"
    vendor.mkpath

    site_packages = Language::Python.site_packages("python3.12")
    sp = libexec/site_packages

    # Copy *contents* of site-packages into vendor
    # (keyrings/, boto*, requests*, dist-info, etc.)
    cp_r (sp/"."), vendor

    config_vendor_path = opt_libexec/"vendor/site-packages"

    (bin/"configure-keyrings-codeartifact").write <<~EOS
      #!/bin/bash
      exec "#{Formula["python@3.12"].opt_bin}/python3.12" - <<'PY'
      import configparser
      import os
      from pathlib import Path

      VENDOR_PATH = #{config_vendor_path.to_s.inspect}

      # XDG config location (what keyring uses on macOS/Linux)
      xdg = os.environ.get("XDG_CONFIG_HOME")
      config_dir = Path(xdg) if xdg else (Path.home() / ".config")
      keyring_dir = config_dir / "python_keyring"
      cfg_path = keyring_dir / "keyringrc.cfg"

      keyring_dir.mkdir(parents=True, exist_ok=True)

      cp = configparser.ConfigParser()

      if cfg_path.exists():
        cp.read(cfg_path)

      if "backend" not in cp:
        cp["backend"] = {}

      cp["backend"]["keyring-path"] = VENDOR_PATH

      if not cp["backend"].get("default-keyring"):
        cp["backend"]["default-keyring"] = "keyring.backends.chainer.ChainerBackend"

      with cfg_path.open("w") as f:
        cp.write(f)

      print(f"Updated {cfg_path}")
      PY
    EOS
    chmod 0755, bin/"configure-keyrings-codeartifact"
  end

  def caveats
    <<~EOS
      To enable discovery of this backend by the `keyring` CLI, run:

        configure-keyrings-codeartifact

    EOS
  end

  test do
    system "#{libexec}/bin/python", "-c", "import keyrings.codeartifact"
  end
end
