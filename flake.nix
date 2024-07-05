{
  description = "Additional schemas to be used with flake-schemas.";

  outputs = { self }:
  let
    libSchema = {
      version = 1;
      doc = ''
        The `lib` flake output defines libraries.
      '';
      inventory = output:
        let
          recurse = attrs: {
            children = builtins.mapAttrs (attrName: attr:
              if builtins.isFunction attr
              then
                {
                  what = "library function";
                  evalChecks.camelCase = builtins.match "^[a-z][a-zA-Z]*$" attrName == [];
                }
              else if builtins.isAttrs attr
              then
                recurse attr
              else
                throw "unsupported 'lib' type")
              attrs;
          };
        in
        recurse output;
    };

    homeModulesSchema = {
      version = 1;
      doc = ''
        The `homeModules` flake output defines importable [Home Manager modules](https://nix-community.github.io/home-manager/index.xhtml#ch-writing-modules).
      '';
      inventory = output: self.lib.mkChildren (builtins.mapAttrs
        (moduleName: module:
          {
            what = "Home module";
            evalChecks.isFunctionOrAttrs = self.lib.checkModule module;
          })
        output);
    };

    snowfallSchema = {
      version = 1;
      doc = ''
        The `snowfall` flake output contains the configuration data for `snowfall-lib`.
      '';
      inventory = self.lib.derivationsInventory "snowfall-lib config" false;
    };
  in
  {
    # Helper functions
    lib = {
      try = e: default:
        let res = builtins.tryEval e;
        in if res.success then res.value else default;

      mkChildren = children: { inherit children; };

      checkModule = module:
        builtins.isAttrs module || builtins.isFunction module;

      checkDerivation = drv:
        drv.type or null == "derivation"
        && drv ? drvPath
        && drv ? name
        && builtins.isString drv.name;

      derivationsInventory = what: isFlakeCheck: output: self.lib.mkChildren (
        builtins.mapAttrs
          (systemType: packagesForSystem:
            {
              forSystems = [ systemType ];
              children = builtins.mapAttrs
                (packageName: package:
                  {
                    forSystems = [ systemType ];
                    shortDescription = package.meta.description or "";
                    derivation = package;
                    evalChecks.isDerivation = self.lib.checkDerivation package;
                    inherit what;
                    isFlakeCheck = isFlakeCheck;
                  })
                packagesForSystem;
            })
          output);
    };

    schemas = {
      lib = libSchema;
      homeModules = homeModulesSchema;
      snowfall = snowfallSchema;
    };
  };
}