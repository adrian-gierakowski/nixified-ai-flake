{
  python3Packages,
  comfyuiNpins,
  comfyuiLib,
  cudaPackages,
}:
let
  npin = comfyuiLib.nodePropsFromNpinSource comfyuiNpins.comfy-kitchen;
in
python3Packages.callPackage (
  {
    buildPythonPackage,
    lib,
    setuptools,
    wheel,
    nanobind,
    cmake,
    ninja,
    torch,
  }:
  buildPythonPackage rec {
    pname = "comfy-kitchen";
    inherit (npin) version src;
    format = "pyproject";

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
      license = licenses.asl20;
      maintainers = with maintainers; [ ];
    };
  }
) { }
