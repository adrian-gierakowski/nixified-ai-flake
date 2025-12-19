{
  symlinkJoin,
  makeWrapper,
  python3Packages,
  stdenv,
  writeTextFile,
  comfyuiPackages,
  lib,
  linkFarm,
  writeShellScript,
  withCustomNodes ? [ ],
  withModels ? [ ],
  extraModelsBasePath ? null,
  gccStdenv,
  comfyuiLib,
}:
let
  customNodes = withCustomNodes;
  models = withModels;

  # TODO: Maybe we should have a golden test, to check whether new folders have been unexpectedly added upstream
  supportedFolders = lib.attrNames (
    builtins.readDir (comfyuiPackages.comfyui-unwrapped.src + "/models")
  );

  unsupportedFolders = lib.flatten (map (f: f.comfyui.installPaths) models);

  createModelsDir =
    models:
    let
      # Creates entires for the second linkFarm argument like:
      # [ { name = "hello-test"; path = pkgs.hello; } ]
      linkFarmEntries = builtins.concatMap (
        modelDrv:
        map (
          installPath:
          let
            name = "${python3Packages.python.sitePackages}/models/${installPath}/${modelDrv.name}";
            traceMessage = ''
              installPath "${installPath}" for "${modelDrv.name}" does not occur in the models folder upstream, so may be unused comfyui at runtime
            '';
            checkedName = lib.warnIfNot (lib.elem installPath supportedFolders) traceMessage name;
          in
          {
            name = checkedName;
            path = modelDrv;
          }
        ) modelDrv.passthru.comfyui.installPaths
      ) models;
    in
    linkFarm "comfyui-models" linkFarmEntries;

  modelsDir = createModelsDir models;

  modelPathsFile =
    let
      modelsDirPath = "${modelsDir}/${python3Packages.python.sitePackages}";
      extraModelsConfig = lib.optionalAttrs (extraModelsBasePath != null) {
        extra_models = {
          base_path = extraModelsBasePath;
          checkpoints = "models/checkpoints";
          configs = "models/configs";
          loras = "models/loras";
          vae = "models/vae";
          text_encoders = "models/text_encoders";
          diffusion_models = "models/unet";
          clip_vision = "models/clip_vision";
          style_models = "models/style_models";
          embeddings = "models/embeddings";
          diffusers = "models/diffusers";
          vae_approx = "models/vae_approx";
          controlnet = "models/controlnet";
          gligen = "models/gligen";
          upscale_models = "models/upscale_models";
          latent_upscale_models = "models/latent_upscale_models";
          custom_nodes = "custom_nodes";
          hypernetworks = "models/hypernetworks";
          photomaker = "models/photomaker";
          classifiers = "models/classifiers";
          model_patches = "models/model_patches";
          audio_encoders = "models/audio_encoders";
        };
      };
    in
    writeTextFile {
      name = "extra_model_paths.yaml";
      text = lib.generators.toYAML { } ({
        comfyui = (
          (lib.genAttrs (supportedFolders ++ unsupportedFolders) (
            nodeName: "${modelsDirPath}/models/${nodeName}"
          ))
          // {
            custom_nodes = "@CUSTOM_NODES@";
          }
        );
      } // extraModelsConfig);
    };
in
symlinkJoin {
  name = "comfyui-wrapped";
  paths = [
    comfyuiPackages.comfyui-unwrapped
    (modelsDir)
  ]
  ++ customNodes;
  propagatedBuildInputs = [
    gccStdenv.cc
  ]
  ++ customNodes;
  nativeBuildInputs = [
    makeWrapper
  ];
  postBuild =
    let
      preStartScript = writeShellScript "comfyui-wrapped-prestart.sh" ''
        echo ${toString supportedFolders}
        set -x
        DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/comfyui"
        mkdir -p "$DATA_HOME"
        cp -rT ${comfyuiPackages.comfyui-unwrapped.src} "$DATA_HOME"
        chmod -R +w "$DATA_HOME" || true
      '';
    in
    ''
      rm $out/bin/comfyui
      cp ${comfyuiPackages.comfyui-unwrapped}/bin/comfyui $out/bin/comfyui
      chmod +w $out/bin/comfyui
      echo $PYTHONPATH
      wrapProgram $out/bin/comfyui \
        --run ${preStartScript} \
        --prefix PYTHONPATH : "$PYTHONPATH" \
        --add-flags "--extra-model-paths-config $out/bin/extra_model_paths.yaml"
        cp --no-preserve=mode ${modelPathsFile} $out/bin/extra_model_paths.yaml
      substituteInPlace $out/bin/extra_model_paths.yaml --replace-fail "@CUSTOM_NODES@" "$out/${python3Packages.python.sitePackages}/custom_nodes"
    '';
  meta = {
    mainProgram = "comfyui";
  };
  passthru = {
    inherit
      modelsDir
      modelPathsFile
      comfyuiLib
      ;
    # TODO: Make this exist and be composable. Multiple applications like
    # (x.withCustomNodes (n: [])).withModels (m: []) doesn't work.
    #
    # withCustomNodes = nodesFunction: comfyuiPackages.comfyui.override {
    #   customNodes = nodesFunction comfyuiPackages;
    # };
    # withModels = function: comfyuiPackages.comfyui.override {
    #   comfyuiModels = function comfyuiPackages;
    # };
    pkgs = comfyuiPackages;
    mkComfyUICustomNode = comfyuiLib.mkComfyUICustomNode;
  };
}
