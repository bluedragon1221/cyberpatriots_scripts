# How to run on linux!? (probably works on macos too)
Use QEMU

## Steps
1. Create a new dir for the images: `mkdir cp19; cd cp19`
2. Extract image: `unzip cp19*.zip`
3. Find the right image file. It's the one that's a `.vmdk` file, but without a `s00[1-9]` part.
4. Convert the image to `qcow2` (qemu format):
```sh
qemu-img convert \
  -f vmdk \
  -O qcow2 \
  "<PATH TO THE .vmdk FILE>" \
  ./converted_image.qcow2
```
5. Run the image with these exact settings:
```sh
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -drive file=converted_image.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -vga virtio \
  -display default
```
(helps to save this in a script or something)
