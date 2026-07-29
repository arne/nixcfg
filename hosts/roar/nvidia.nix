# NVIDIA RTX 2000 Ada (AD107) — headless compute, no X/Wayland. The driver is
# enabled here so `nvidia-smi` works and a later phase's `services.ollama` can
# use CUDA with no extra GPU wiring. The Intel Iris Xe iGPU stays the console GPU.
#
# NEW to this repo — every other host is AMD or Apple Silicon. If roar fails to
# come up after a driver/kernel bump, this module is the first suspect. Fallback
# knobs if `nvidia-smi` misbehaves: set `open = false`, or switch `package` to
# `config.boot.kernelPackages.nvidiaPackages.stable`.
{ config, pkgs, ... }:

{
  # GPU userspace libraries — needed even headless (CUDA / NVENC).
  hardware.graphics.enable = true;

  # The nvidia hardware module keys off videoDrivers even with no X server;
  # this is what loads the kernel module and blacklists nouveau.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;                 # open kernel modules — recommended for Turing+/Ada
    modesetting.enable = true;
    nvidiaPersistenced = true;   # keep the GPU initialised with no display attached
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
}
