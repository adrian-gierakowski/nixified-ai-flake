{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
  nanobind,
  cmake,
  ninja,
  torch,
  cudaPackages,
}:

buildPythonPackage rec {
  pname = "comfy-kitchen";
  version = "0.2.7";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "Comfy-Org";
    repo = "comfy-kitchen";
    rev = "v${version}";
    hash = "sha256-1yzvyyz2fn1j67qq8w643ax6hd7j90jnpdc77mn285pz35c4sk5z";
  };

  nativeBuildInputs = [
    setuptools
    wheel
    cmake
    ninja
    nanobind
    cudaPackages.cuda_nvcc
  ];

  buildInputs = [
    torch
    cudaPackages.cuda_cudart
  ];

  env.CUDA_HOME = "${lib.getDev cudaPackages.cuda_nvcc}";

  meta = with lib; {
    description = "Fast Kernel Library for ComfyUI with multiple compute backends";
    homepage = "https://github.com/Comfy-Org/comfy-kitchen";
    license = licenses.apache2;
    maintainers = with maintainers; [ ];
  };
}
