{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  setuptools-scm,
  wheel,
  cudaPackages,
  autoAddDriverRunpath,
}:

buildPythonPackage rec {
  pname = "comfy-aimdo";
  version = "0.1.7";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "Comfy-Org";
    repo = "comfy-aimdo";
    rev = "v${version}";
    hash = "sha256-1hwnc7j3by0yzcfwfmzbyxjzwald6w1yccf1jmw7ck37md693ls4";
  };

  nativeBuildInputs = [
    setuptools
    setuptools-scm
    wheel
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  buildInputs = [
    cudaPackages.cuda_cudart
  ];

  # Manually compile the shared object
  preBuild = ''
    gcc -shared -o comfy_aimdo/aimdo.so -fPIC \
      -I${lib.getDev cudaPackages.cuda_cudart}/include \
      -L${lib.getLib cudaPackages.cuda_cudart}/lib/stubs \
      src/control.c src/debug.c src/model-vbar.c src/pyt-cu-plug-alloc.c -lcuda
  '';

  meta = with lib; {
    description = "AI Model Dynamic Offloader for ComfyUI";
    homepage = "https://github.com/Comfy-Org/comfy-aimdo";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
