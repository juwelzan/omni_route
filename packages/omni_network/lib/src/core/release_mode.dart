/// Tracks whether `omni_network` is running in release/product mode.
///
/// Overridable via `OmniNetwork.isReleaseBuild` in tests.
bool omniNetworkReleaseBuild = const bool.fromEnvironment('dart.vm.product');
