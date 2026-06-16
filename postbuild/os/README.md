# Booting Validation OS Image

## Preparing the Windows Validation OS (WinVOS) Image

WinVOS is a pared down Windows OS image that is convenient for basic development while also booting relatively quickly under QEMU.  

You can manually download the ISO from the link here: https://aka.ms/DownloadValidationOS_arm64 and create your own winvos image or you can run the `winvos.ps1` script which will download and create the image for you with the default settings

## Booting QEMU `virt` to Windows

After you have created a ValidationOS.vhdx with your required files, simply copy it to the prebuilt folder and from the root folder run
    `make run_os`

This will generate the qcow2 image from the vhdx and run your BIOS in the parent folder path and boot to a command prompt. Your output display will be redirected to VNC port 5900 by default. You can use and VNC Viewer to open the display `127.0.0.1:5900`. 

If you want you can force regeneration of the winvos.qcow2 image using
    `make qcow2`

## Connecting with Windbg

GDB server is at:  `127.0.0.1:5555`. 

Windbg can be connected on  `windbg -k com:ipport=56789,port=127.0.0.1 -v`
