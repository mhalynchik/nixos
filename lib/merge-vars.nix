defaults: user:

let
  mergeSection = section:
    defaults.${section} // (user.${section} or {});
in
defaults // user // {
  features = mergeSection "features";
  programs = mergeSection "programs";
  vpn = mergeSection "vpn";
  location = defaults.location // (user.location or {});
}
